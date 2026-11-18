@tool
class_name SlantButton
extends Button
## Botón en forma de paralelogramo, como los comandos de combate de las referencias.
##
## - Normal: panel negro con contorno blanco fino.
## - Seleccionado (foco o ratón encima): relleno lima, texto negro y sombra violeta.
## - Deshabilitado: atenuado, pero se puede seleccionar para leer su descripción.

## Texto mostrado. Se usa en lugar de `Button.text` porque el dibujo es propio.
@export var label: String = "Opción":
	set(value):
		label = value
		update_minimum_size()
		queue_redraw()

## Prefijo pequeño a la izquierda (p. ej. «01»). Vacío para ocultarlo.
@export var index_label: String = "":
	set(value):
		index_label = value
		update_minimum_size()
		queue_redraw()

## Texto de ayuda que la pantalla puede mostrar al seleccionar el botón.
@export_multiline var description: String = ""

@export var font_size: int = 32:
	set(value):
		font_size = value
		update_minimum_size()
		queue_redraw()

@export var slant: float = 22.0:
	set(value):
		slant = value
		queue_redraw()

## 0 = oculto (desplazado a la izquierda), 1 = visible. Útil para animar entradas.
@export_range(0.0, 1.0) var reveal: float = 1.0:
	set(value):
		reveal = value
		queue_redraw()

const PADDING := 26.0
const INDEX_GAP := 18.0

var _highlight := 0.0
var _tween: Tween


func _init() -> void:
	# El dibujo estándar de Button se sustituye por el de _draw().
	flat = true
	var empty := StyleBoxEmpty.new()
	for style in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(style, empty)
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(0, 68)


func _ready() -> void:
	focus_entered.connect(_animate_highlight)
	focus_exited.connect(_animate_highlight)
	mouse_entered.connect(_on_mouse_entered)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)


func _on_mouse_entered() -> void:
	if not Engine.is_editor_hint() and not has_focus():
		grab_focus()


func _animate_highlight() -> void:
	var target := 1.0 if has_focus() else 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_highlight, _highlight, target, 0.14)


func _set_highlight(value: float) -> void:
	_highlight = value
	queue_redraw()


func _get_minimum_size() -> Vector2:
	var font := UIStyle.FONT_ITALIC
	var w := slant + PADDING * 2.0 + font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if index_label != "":
		w += font.get_string_size(index_label, HORIZONTAL_ALIGNMENT_LEFT, -1, _index_size()).x + INDEX_GAP
	return Vector2(w + slant, font_size * 2.0)


func _index_size() -> int:
	return int(font_size * 0.55)


func _draw() -> void:
	var h := _highlight
	var alpha := reveal
	var shift := Vector2(lerpf(-60.0, 0.0, reveal) + 10.0 * h, 0.0)
	draw_set_transform(shift)

	var rect := Rect2(Vector2.ZERO, size)
	var shape := UIStyle.slanted_rect(rect, slant)

	# Sombra violeta desplazada cuando está seleccionado.
	if h > 0.01:
		var shadow := UIStyle.slanted_rect(Rect2(Vector2(7, 7), size), slant)
		draw_colored_polygon(shadow, Color(UIStyle.VIOLET, 0.85 * h * alpha))

	var accent := UIStyle.GRAY if disabled else UIStyle.LIME
	var fill := UIStyle.PANEL.lerp(accent, h)
	if get_draw_mode() == DRAW_PRESSED or get_draw_mode() == DRAW_HOVER_PRESSED:
		fill = fill.darkened(0.2)
	fill.a *= alpha
	draw_colored_polygon(shape, fill)

	var outline := UIStyle.WHITE.lerp(accent, h)
	if disabled:
		outline = Color(UIStyle.GRAY, lerpf(0.5, 1.0, h))
	outline.a *= alpha
	UIStyle.draw_outline(self, shape, outline, 2.0)

	# Texto
	var font := UIStyle.FONT_ITALIC
	var text_color := UIStyle.WHITE.lerp(UIStyle.INK, h)
	if disabled:
		text_color = Color(UIStyle.GRAY, 1.0).lerp(UIStyle.INK, h)
	text_color.a *= alpha
	var baseline := (size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	var x := slant + PADDING

	if index_label != "":
		var isz := _index_size()
		var index_color := (UIStyle.GRAY if disabled else UIStyle.LIME).lerp(UIStyle.INK, h)
		index_color.a *= alpha
		draw_string(font, Vector2(x, baseline), index_label, HORIZONTAL_ALIGNMENT_LEFT, -1, isz, index_color)
		x += font.get_string_size(index_label, HORIZONTAL_ALIGNMENT_LEFT, -1, isz).x + INDEX_GAP

	draw_string(font, Vector2(x, baseline), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

	# Marca «///» al final cuando está seleccionado.
	if h > 0.01:
		var stripe_color := Color(UIStyle.INK, h * alpha)
		var origin := Vector2(size.x - slant - 66.0, size.y * 0.5 + 8.0)
		UIStyle.draw_stripes(self, origin, 3, Vector2(9, 16), 5, stripe_color)

	draw_set_transform(Vector2.ZERO)
