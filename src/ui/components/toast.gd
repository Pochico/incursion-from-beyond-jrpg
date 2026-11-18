class_name Toast
extends Control
## Aviso breve en un panel inclinado con barra de color. Se destruye solo.
##   Toast.show_in(parent, "Afinidad con Kael ↑", color)

var text := ""
var color := UIStyle.LIME
var _font := UIStyle.FONT_MEDIUM_ITALIC
const FONT_SIZE := 26


static func show_in(parent: Control, message: String, accent: Color = UIStyle.LIME,
		duration: float = 2.4, y: float = 170.0) -> Toast:
	var t := Toast.new()
	t.text = message
	t.color = accent
	parent.add_child(t)
	var w := t._font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x + 110
	t.size = Vector2(w, 56)
	t.position = Vector2(parent.size.x - w - 48, y)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.modulate.a = 0.0
	var tw := t.create_tween()
	tw.tween_property(t, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(t, "position:x", t.position.x, 0.25).from(t.position.x + 60)
	tw.tween_interval(duration)
	tw.tween_property(t, "modulate:a", 0.0, 0.3)
	tw.tween_callback(t.queue_free)
	return t


func _draw() -> void:
	var shape := UIStyle.chamfer_rect(Rect2(Vector2.ZERO, size), [16.0, 0.0, 16.0, 0.0])
	draw_colored_polygon(shape, Color(UIStyle.NIGHT, 0.92))
	UIStyle.draw_outline(self, shape, UIStyle.LINE, 1.5)
	draw_colored_polygon(UIStyle.slanted_rect(Rect2(Vector2(30, 13), Vector2(12, 30)), 7), color)
	draw_string(_font, Vector2(60, 37), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, UIStyle.WHITE)
	draw_line(Vector2(size.x - 60, size.y + 6), Vector2(size.x, size.y + 6), Color(color, 0.9), 3.0)
