@tool
class_name KeyHintButton
extends Button
## Atajo clicable: insignia con la tecla + texto. Ej.: (M) Mapa.

@export var key_text: String = "M":
	set(value):
		key_text = value
		_update_size()

@export var label: String = "Mapa":
	set(value):
		label = value
		_update_size()

const FONT_SIZE := 26
const BADGE := 38.0


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
	var w := UIStyle.FONT_BOLD.get_string_size(key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	return maxf(BADGE, w + 18.0)


## Button calcula su tamaño mínimo a partir de su propio texto (vacío), así que
## fijamos custom_minimum_size con el tamaño de nuestro dibujo.
func _update_size() -> void:
	var tw := UIStyle.FONT_SEMIBOLD.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	custom_minimum_size = Vector2(_badge_width() + 12.0 + tw, 48)
	queue_redraw()


func _draw() -> void:
	var hovered := is_hovered()
	var cy := size.y * 0.5
	var bw := _badge_width()
	var badge := Rect2(Vector2(0, cy - BADGE * 0.5), Vector2(bw, BADGE))
	var badge_col := UIStyle.LIME if hovered else UIStyle.WHITE
	draw_style_box(_badge_style(badge_col), badge)
	var kf := UIStyle.FONT_BOLD
	var kw := kf.get_string_size(key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_string(kf, Vector2((bw - kw) * 0.5, cy + 7), key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UIStyle.INK)
	draw_string(UIStyle.FONT_SEMIBOLD, Vector2(bw + 12, cy + 9), label, HORIZONTAL_ALIGNMENT_LEFT, -1,
			FONT_SIZE, UIStyle.LIME if hovered else UIStyle.WHITE)


func _badge_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(BADGE * 0.5))
	return sb
