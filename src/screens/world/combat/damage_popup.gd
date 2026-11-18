class_name DamagePopup
extends Control
## Número flotante de daño/curación que sube y se desvanece.

var text := ""
var color := UIStyle.WHITE
var font_size := 72


static func spawn(parent: Control, at: Vector2, value_text: String, value_color: Color, big := true) -> void:
	var p := DamagePopup.new()
	p.text = value_text
	p.color = value_color
	p.font_size = 76 if big else 50
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	p.position = at
	p.scale = Vector2(0.6, 0.6)
	var t := p.create_tween().set_parallel(true)
	t.tween_property(p, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(p, "position:y", at.y - 70, 0.9).set_ease(Tween.EASE_OUT)
	t.tween_property(p, "modulate:a", 0.0, 0.35).set_delay(0.7)
	t.chain().tween_callback(p.queue_free)


func _draw() -> void:
	var f := UIStyle.FONT_HEAVY_ITALIC
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := Vector2(-w * 0.5, 0)
	draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 12, UIStyle.INK)
	draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
