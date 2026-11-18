@tool
class_name KeyHintButton
extends Button
## Atajo clicable: insignia con la tecla (o un icono) + texto. Ej.: Ⓜ Mapa, ≡ Menú.

@export var key_text: String = "M":
	set(value):
		key_text = value
		_update_size()

@export var label: String = "Mapa":
	set(value):
		label = value
		_update_size()

## Si se indica (p. ej. "menu"), se dibuja este icono de UIIcons en lugar de la insignia.
@export var icon_name: String = "":
	set(value):
		icon_name = value
		_update_size()

const FONT_SIZE := 25
const BADGE := 34.0
const GAP := 12.0


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for style in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(style, empty)


func _ready() -> void:
	_update_size()
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func _badge_width() -> float:
	if icon_name != "":
		return BADGE
	var w := UIStyle.FONT_BOLD.get_string_size(key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	return maxf(BADGE, w + 18.0)


## Button calcula su tamaño mínimo a partir de su propio texto (vacío), así que
## fijamos custom_minimum_size con el tamaño de nuestro dibujo.
func _update_size() -> void:
	var tw := UIStyle.FONT_REGULAR.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	custom_minimum_size = Vector2(_badge_width() + GAP + tw, 44)
	queue_redraw()


func _draw() -> void:
	var hovered := is_hovered()
	var color := UIStyle.LIME if hovered else UIStyle.WHITE
	var cy := size.y * 0.5
	var bw := _badge_width()
	if icon_name != "":
		UIIcons.draw_named(self, icon_name, Vector2(bw * 0.5, cy), BADGE, color)
	else:
		var sb := StyleBoxFlat.new()
		sb.bg_color = color
		sb.set_corner_radius_all(int(BADGE * 0.5) if key_text.length() == 1 else 8)
		draw_style_box(sb, Rect2(Vector2(0, cy - BADGE * 0.5), Vector2(bw, BADGE)))
		var kf := UIStyle.FONT_BOLD
		var kw := kf.get_string_size(key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(kf, Vector2((bw - kw) * 0.5, cy + 6.5), key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIStyle.INK)
	draw_string(UIStyle.FONT_REGULAR, Vector2(bw + GAP, cy + 9), label, HORIZONTAL_ALIGNMENT_LEFT, -1,
			FONT_SIZE, color)
