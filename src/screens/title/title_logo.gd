@tool
class_name TitleLogo
extends Control
## Logotipo del título dibujado con la tipografía del juego.

@export var caption: String = "JRPG  ·  NOVELA VISUAL":
	set(value):
		caption = value
		queue_redraw()

@export var line_top: String = "INCURSION":
	set(value):
		line_top = value
		queue_redraw()

@export var line_bottom: String = "FROM BEYOND":
	set(value):
		line_bottom = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _get_minimum_size() -> Vector2:
	return Vector2(980, 320)


func _draw() -> void:
	var f_cap := UIStyle.FONT_BOLD_ITALIC
	var f_big := UIStyle.FONT_HEAVY_ITALIC

	# Barra de acento y rótulo superior.
	draw_rect(Rect2(0, 18, 12, 250), UIStyle.LIME)
	UIStyle.draw_spaced(self, f_cap, Vector2(44, 42), caption, 22, 5.0, Color(UIStyle.WHITE, 0.8))

	# «INCURSION» con sombra violeta.
	var top_pos := Vector2(36, 176)
	draw_string(f_big, top_pos + Vector2(8, 8), line_top, HORIZONTAL_ALIGNMENT_LEFT, -1, 150, Color(UIStyle.VIOLET, 0.9))
	draw_string(f_big, top_pos, line_top, HORIZONTAL_ALIGNMENT_LEFT, -1, 150, UIStyle.WHITE)
	var top_w := f_big.get_string_size(line_top, HORIZONTAL_ALIGNMENT_LEFT, -1, 150).x

	# «FROM BEYOND» en lima, espaciado.
	var bottom_w := UIStyle.draw_spaced(self, f_big, Vector2(44, 256), line_bottom, 62, 10.0, UIStyle.LIME)

	# Subrayado con quiebro y «///».
	var y := 292.0
	var end_x := maxf(top_w, bottom_w) + 40.0
	draw_line(Vector2(0, y), Vector2(end_x, y), UIStyle.WHITE, 2.0, true)
	draw_line(Vector2(end_x, y), Vector2(end_x + 26, y - 24), UIStyle.WHITE, 2.0, true)
	UIStyle.draw_stripes(self, Vector2(end_x + 30, y - 6), 3, Vector2(16, 16), 7, UIStyle.WHITE,
			[UIStyle.WHITE, UIStyle.WHITE, UIStyle.LIME])
