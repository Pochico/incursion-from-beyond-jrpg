class_name NameTag
extends Control
## Etiqueta con el nombre de un personaje (panel inclinado del color del personaje).

var text := "":
	set(value):
		text = value
		_resize()
		queue_redraw()
var color := UIStyle.LIME:
	set(value):
		color = value
		queue_redraw()

const FONT_SIZE := 30


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resize()


func _resize() -> void:
	var w := UIStyle.FONT_HEAVY_ITALIC.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	size = Vector2(w + 70, 52)


func _draw() -> void:
	var shape := UIStyle.slanted_rect(Rect2(Vector2.ZERO, size), 16)
	draw_colored_polygon(UIStyle.slanted_rect(Rect2(Vector2(5, 5), size), 16), Color(color, 0.8))
	draw_colored_polygon(shape, Color(UIStyle.INK, 0.92))
	UIStyle.draw_outline(self, shape, color, 2.0)
	draw_string(UIStyle.FONT_HEAVY_ITALIC, Vector2(32, 37), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, UIStyle.WHITE)
