@tool
class_name PillButton
extends Button
## Botón en forma de píldora hexagonal «‹ ›» con icono, como «Saltar» y «Auto»
## de la interfaz de conversación.
## - Normal: relleno oscuro, contorno blanco fino.
## - Ratón encima: contorno y texto lima.
## - Activado (toggle): relleno lima, texto oscuro.

@export var label: String = "Saltar":
	set(value):
		label = value
		_update_size()

## Nombre de icono de UIIcons ("chevrons", "play"...). Vacío = sin icono.
@export var icon_name: String = "chevrons":
	set(value):
		icon_name = value
		_update_size()

## Seleccionable con teclado/mando: al tener el foco se rellena de lima.
@export var selectable: bool = false:
	set(value):
		selectable = value
		focus_mode = Control.FOCUS_ALL if value else Control.FOCUS_NONE

## Texto de ayuda que la pantalla puede mostrar al seleccionarlo.
@export_multiline var description: String = ""

@export var font_size: int = 26:
	set(value):
		font_size = value
		_update_size()

const TIP := 16.0
const ICON := 26.0


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for style in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(style, empty)


func _ready() -> void:
	_update_size()
	mouse_entered.connect(func() -> void:
		if selectable and not has_focus():
			grab_focus()
		queue_redraw())
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	toggled.connect(func(_on: bool) -> void: queue_redraw())


func _update_size() -> void:
	var tw := UIStyle.FONT_REGULAR_ITALIC.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var iw := (ICON + 18.0) if icon_name != "" else 0.0
	custom_minimum_size = Vector2(maxf(TIP * 2.0 + 44.0 + iw + tw, 200.0), 50)
	queue_redraw()


func _draw() -> void:
	var on := (toggle_mode and button_pressed) or (selectable and has_focus() and not disabled)
	var hover := is_hovered() and not disabled
	var shape := UIStyle.hex_pill(Rect2(Vector2(1, 1), size - Vector2(2, 2)), TIP)

	var fill := UIStyle.LIME if on else Color(UIStyle.NIGHT, 0.9)
	var line := UIStyle.LIME if (hover or on) else UIStyle.LINE
	var ink := UIStyle.INK if on else (UIStyle.LIME if hover else UIStyle.WHITE)
	if get_draw_mode() == DRAW_PRESSED:
		fill = fill.darkened(0.2)

	if disabled:
		fill = Color(UIStyle.NIGHT, 0.7)
		line = Color(UIStyle.GRAY, 0.9 if (selectable and has_focus()) else 0.45)
		ink = Color(UIStyle.GRAY, 0.8)
	draw_colored_polygon(shape, fill)
	UIStyle.draw_outline(self, shape, line, 1.5)

	var font := UIStyle.FONT_REGULAR_ITALIC
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var iw := (ICON + 18.0) if icon_name != "" else 0.0
	var x := (size.x - (iw + tw)) * 0.5
	var cy := size.y * 0.5
	if icon_name != "":
		UIIcons.draw_named(self, icon_name, Vector2(x + ICON * 0.5, cy), ICON, ink)
		x += iw
	var baseline := cy + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	draw_string(font, Vector2(x, baseline), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
