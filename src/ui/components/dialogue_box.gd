@tool
class_name DialogueBox
extends Control
## Caja de diálogo de la interfaz de conversación.
##
## Dibuja el marco, la pestaña con el nombre, las franjas decorativas y el
## indicador de «continuar». El texto es un Label hijo para poder animar
## `visible_ratio` (efecto máquina de escribir). Incluye los botones
## «Saltar» y «Auto».

signal skip_pressed
signal auto_toggled(enabled: bool)

const TAB_HEIGHT := 64.0
const SLANT := 30.0

@export var speaker_name: String = "Aiden":
	set(value):
		speaker_name = value
		queue_redraw()

@export var speaker_color: Color = UIStyle.LIME:
	set(value):
		speaker_color = value
		queue_redraw()

@export_multiline var text: String = "Parece que el distrito está más tranquilo de lo habitual.":
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
var _skip: SlantButton
var _auto: SlantButton
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS

	_label = Label.new()
	_label.name = "Text"
	_label.text = text
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var settings := LabelSettings.new()
	settings.font = UIStyle.FONT_ITALIC
	settings.font_size = 38
	settings.font_color = UIStyle.WHITE
	settings.line_spacing = 6
	_label.label_settings = settings
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = 190
	_label.offset_top = TAB_HEIGHT + 44
	_label.offset_right = -110
	_label.offset_bottom = -40
	add_child(_label, false, Node.INTERNAL_MODE_FRONT)

	_skip = _make_button("Saltar", "»»")
	_skip.pressed.connect(func() -> void: skip_pressed.emit())
	_auto = _make_button("Auto", "▶")
	_auto.toggle_mode = true
	_auto.toggled.connect(func(on: bool) -> void: auto_toggled.emit(on))
	_layout_buttons()


func _make_button(label: String, index: String) -> SlantButton:
	var b := SlantButton.new()
	b.label = label
	b.index_label = index
	b.font_size = 26
	b.slant = 18
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(210, 52)
	b.size = Vector2(210, 52)
	add_child(b, false, Node.INTERNAL_MODE_FRONT)
	return b


func _layout_buttons() -> void:
	if _auto == null:
		return
	_auto.position = Vector2(size.x - 230, 6)
	_skip.position = Vector2(size.x - 460, 6)


## Control del texto visible (0..1) para el efecto máquina de escribir.
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


func _draw() -> void:
	var w := size.x
	var h := size.y
	var top := TAB_HEIGHT

	# Cuerpo principal con esquinas cortadas.
	var body := PackedVector2Array([
		Vector2(SLANT, top), Vector2(w - 60, top), Vector2(w - 30, top + 30), Vector2(w, top + 30),
		Vector2(w, h - SLANT), Vector2(w - SLANT, h), Vector2(0, h), Vector2(0, top + SLANT),
	])
	draw_colored_polygon(body, Color(UIStyle.INK, 0.86))
	UIStyle.draw_outline(self, body, Color(UIStyle.WHITE, 0.9), 2.0)

	# Línea interior fina (doble marco).
	draw_line(Vector2(40, h - 14), Vector2(w * 0.5, h - 14), Color(UIStyle.WHITE, 0.25), 1.0)

	# Franjas diagonales decorativas a la izquierda.
	var stripe_top := top + 6.0
	_band(Vector2(26, h - 4), Vector2(110, stripe_top), 26.0, Color(speaker_color, 0.9))
	_band(Vector2(66, h - 4), Vector2(150, stripe_top), 14.0, Color(UIStyle.VIOLET, 0.55))
	_band(Vector2(98, h - 4), Vector2(182, stripe_top), 6.0, Color(UIStyle.WHITE, 0.12))

	# Pestaña del nombre.
	if speaker_name != "":
		var font := UIStyle.FONT_HEAVY_ITALIC
		var name_w := font.get_string_size(speaker_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x
		var tab_w := maxf(name_w + 160.0, 380.0)
		var tab := UIStyle.slanted_rect(Rect2(Vector2(70, 4), Vector2(tab_w, top + 4)), 26)
		draw_colored_polygon(tab, Color(UIStyle.INK, 0.95))
		UIStyle.draw_outline(self, tab, Color(UIStyle.WHITE, 0.9), 2.0)
		draw_colored_polygon(UIStyle.slanted_rect(Rect2(Vector2(110, 16), Vector2(16, 44)), 6), speaker_color)
		draw_string(font, Vector2(142, 54), speaker_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, UIStyle.WHITE)
		UIStyle.draw_stripes(self, Vector2(70 + tab_w - 100, 54), 3, Vector2(14, 14), 6, Color(UIStyle.WHITE, 0.85))

	# Indicador de continuar (chevron lima que rebota).
	if show_continue:
		var bob := sin(_time * 5.0) * 4.0
		var c := Vector2(w - 90, h - 60 + bob)
		draw_polyline(PackedVector2Array([c + Vector2(-16, -8), c, c + Vector2(16, -8)]), UIStyle.LIME, 5.0, true)

	# «///» en la esquina inferior derecha.
	UIStyle.draw_stripes(self, Vector2(w - 140, h - 16), 3, Vector2(16, 14), 6, Color(UIStyle.WHITE, 0.55))


func _band(bottom: Vector2, top_pt: Vector2, width: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		bottom, top_pt, top_pt + Vector2(width, 0), bottom + Vector2(width, 0),
	]), color)
