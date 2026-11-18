@tool
class_name InfoBar
extends Control
## Barra de descripción inferior: «/ Un rápido corte que inflige daño...».

@export_multiline var text: String = "":
	set(value):
		text = value
		queue_redraw()

@export var font_size: int = 26:
	set(value):
		font_size = value
		queue_redraw()

const SLANT := 18.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var shape := UIStyle.slanted_rect(Rect2(Vector2.ZERO, size), SLANT)
	draw_colored_polygon(shape, Color(UIStyle.NIGHT.darkened(0.3), 0.88))
	UIStyle.draw_outline(self, shape, UIStyle.LINE, 1.5)

	var font := UIStyle.FONT_MEDIUM
	var cy := size.y * 0.5
	# Marca «/» lima.
	var mark := UIStyle.slanted_rect(Rect2(Vector2(SLANT + 20, cy - 14), Vector2(16, 28)), 10)
	draw_colored_polygon(mark, UIStyle.LIME)

	var baseline := cy + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	draw_string(font, Vector2(SLANT + 50, baseline), text, HORIZONTAL_ALIGNMENT_LEFT,
			size.x - SLANT * 2 - 70, font_size, UIStyle.WHITE)
