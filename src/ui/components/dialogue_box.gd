@tool
class_name DialogueBox
extends Control
## Caja de diálogo de la interfaz de conversación (ver docs/ui/referencias/03).
##
## Un único marco con:
##  - franja superior: pestaña con el nombre a la izquierda, botones Saltar/Auto
##    a la derecha y un tramo central rebajado entre ambos;
##  - panel interior achaflanado para el texto, con franjas diagonales
##    translúcidas (color del hablante + violeta) a la izquierda;
##  - borde inferior escalonado, doble línea y marcas «///».
## El texto es un Label hijo para animar `visible_ratio` (máquina de escribir).

signal skip_pressed
signal auto_toggled(enabled: bool)

const HEADER := 74.0      ## Alto de la franja superior.
const STEP := 14.0        ## Rebaje del tramo central del borde superior.
const CUT := 30.0         ## Tamaño de los chaflanes.

@export var speaker_name: String = "Aiden":
	set(value):
		speaker_name = value
		queue_redraw()

@export var speaker_color: Color = UIStyle.LIME:
	set(value):
		speaker_color = value
		queue_redraw()

@export_multiline var text: String = "Parece que el distrito está más tranquilo de lo habitual. Aun así, deberíamos avanzar y reunir la información que necesitamos.":
	set(value):
		text = value
		if _label:
			_label.text = value

## Muestra la flecha parpadeante de «continuar».
@export var show_continue: bool = true:
	set(value):
		show_continue = value
		queue_redraw()

var _label: Label
var _skip: PillButton
var _auto: PillButton
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS

	_label = Label.new()
	_label.name = "Text"
	_label.text = text
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var settings := LabelSettings.new()
	settings.font = UIStyle.FONT_REGULAR_ITALIC
	settings.font_size = 40
	settings.font_color = UIStyle.WHITE
	settings.line_spacing = 10
	settings.shadow_color = Color(0, 0, 0, 0.35)
	settings.shadow_offset = Vector2(0, 2)
	_label.label_settings = settings
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = 200
	_label.offset_top = HEADER + 34
	_label.offset_right = -150
	_label.offset_bottom = -40
	add_child(_label, false, Node.INTERNAL_MODE_FRONT)

	_skip = _make_button("Saltar", "chevrons")
	_skip.pressed.connect(func() -> void: skip_pressed.emit())
	_auto = _make_button("Auto", "play")
	_auto.toggle_mode = true
	_auto.toggled.connect(func(on: bool) -> void: auto_toggled.emit(on))
	_layout_buttons()


func _make_button(label: String, icon: String) -> PillButton:
	var b := PillButton.new()
	b.label = label
	b.icon_name = icon
	b.custom_minimum_size = Vector2(250, 52)
	b.size = Vector2(250, 52)
	add_child(b, false, Node.INTERNAL_MODE_FRONT)
	return b


func _buttons_left() -> float:
	return size.x - 36.0 - 250.0 * 2.0 - 12.0


func _layout_buttons() -> void:
	if _auto == null:
		return
	_auto.position = Vector2(size.x - 36.0 - 250.0, 12)
	_skip.position = Vector2(_auto.position.x - 12.0 - 250.0, 12)


## Label del texto (para el efecto máquina de escribir).
func get_text_label() -> Label:
	return _label


func set_auto(enabled: bool) -> void:
	_auto.set_pressed_no_signal(enabled)
	_auto.queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if show_continue:
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_buttons()


func _tab_right() -> float:
	var w := 0.0
	if speaker_name != "":
		w = UIStyle.FONT_ITALIC.get_string_size(speaker_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x
	return maxf(150.0 + w + 150.0, 520.0)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var tab_r := _tab_right()
	var btn_l := _buttons_left() - 24.0
	var step_x := w * 0.46

	# --- Marco exterior -------------------------------------------------------
	var outer := PackedVector2Array([
		Vector2(0, CUT * 2.0), Vector2(CUT * 1.6, 0),                 # chaflán de la pestaña
		Vector2(tab_r, 0), Vector2(tab_r + STEP, STEP),               # baja al tramo central
		Vector2(btn_l - STEP, STEP), Vector2(btn_l, 0),               # sube a la zona de botones
		Vector2(w - CUT, 0), Vector2(w, CUT),
		Vector2(w, h - CUT - STEP), Vector2(w - CUT, h - STEP),       # esquina inferior derecha
		Vector2(step_x + STEP, h - STEP), Vector2(step_x, h),         # escalón inferior
		Vector2(CUT, h), Vector2(0, h - CUT),
	])
	_vgradient_poly(outer, Color(UIStyle.NIGHT, 0.70), Color(UIStyle.NIGHT.darkened(0.3), 0.86))
	UIStyle.draw_outline(self, outer, UIStyle.LINE, 2.0)

	# --- Panel interior --------------------------------------------------------
	var inner_rect := Rect2(Vector2(16, HEADER), Vector2(w - 32, h - HEADER - STEP - 14))
	var inner := UIStyle.chamfer_rect(inner_rect, [CUT, 0.0, CUT, 0.0])
	draw_colored_polygon(inner, Color(0, 0, 0, 0.18))
	UIStyle.draw_outline(self, inner, Color(UIStyle.WHITE, 0.55), 1.5)

	# Franjas diagonales translúcidas (dentro del panel, a la izquierda).
	var top_y := inner_rect.position.y + 4
	var bot_y := inner_rect.end.y - 2
	_band(Vector2(26, bot_y), Vector2(150, top_y), 34.0, speaker_color, 0.85, 0.15)
	_band(Vector2(72, bot_y), Vector2(196, top_y), 22.0, UIStyle.VIOLET, 0.55, 0.08)
	_band(Vector2(108, bot_y), Vector2(232, top_y), 8.0, UIStyle.WHITE, 0.10, 0.0)

	# Doble línea inferior (fuera del marco, a la derecha) y en la base izquierda.
	draw_line(Vector2(w * 0.72, h + 10), Vector2(w - 6, h + 10), Color(UIStyle.WHITE, 0.35), 1.5)
	draw_line(Vector2(CUT + 10, h - 8), Vector2(step_x - 30, h - 8), Color(UIStyle.WHITE, 0.25), 1.0)

	# --- Pestaña del nombre ----------------------------------------------------
	if speaker_name != "":
		var bar := UIStyle.slanted_rect(Rect2(Vector2(78, 16), Vector2(18, 46)), 8)
		draw_colored_polygon(bar, speaker_color)
		var font := UIStyle.FONT_ITALIC
		draw_string(font, Vector2(112, 56), speaker_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, UIStyle.WHITE)
		UIStyle.draw_stripes(self, Vector2(tab_r - 110, 56), 3, Vector2(14, 12), 5, Color(UIStyle.WHITE, 0.9))

	# --- Indicador de continuar y «///» -------------------------------------------
	if show_continue:
		var bob := sin(_time * 5.0) * 4.0
		var c := Vector2(w - 92, h - 70 + bob)
		draw_polyline(PackedVector2Array([c + Vector2(-18, -9), c, c + Vector2(18, -9)]), UIStyle.LIME, 6.0, true)
	UIStyle.draw_stripes(self, Vector2(w - 132, h - 30), 3, Vector2(16, 12), 6, Color(UIStyle.WHITE, 0.7))


## Banda diagonal con degradado vertical de opacidad.
func _band(bottom: Vector2, top_pt: Vector2, width: float, color: Color, a_bottom: float, a_top: float) -> void:
	draw_polygon(
		PackedVector2Array([bottom, top_pt, top_pt + Vector2(width, 0), bottom + Vector2(width, 0)]),
		PackedColorArray([Color(color, a_bottom), Color(color, a_top), Color(color, a_top), Color(color, a_bottom)]))


## Rellena un polígono con degradado vertical (por vértice).
func _vgradient_poly(points: PackedVector2Array, top: Color, bottom: Color) -> void:
	var colors := PackedColorArray()
	for p in points:
		colors.append(top.lerp(bottom, clampf(p.y / maxf(size.y, 1.0), 0.0, 1.0)))
	draw_polygon(points, colors)
