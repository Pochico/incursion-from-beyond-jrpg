class_name LocationBanner
extends Control
## Cartel de llegada: «/// PLAZA MAYOR» que entra, se mantiene y se va.

var _title := ""
var _subtitle := ""
var _progress := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func play(title: String, subtitle: String) -> void:
	_title = title.to_upper()
	_subtitle = subtitle
	visible = true
	var t := create_tween()
	t.tween_method(_set_progress, 0.0, 1.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_interval(1.4)
	t.tween_method(_set_progress, 1.0, 0.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await t.finished
	visible = false


func _set_progress(v: float) -> void:
	_progress = v
	queue_redraw()


func _draw() -> void:
	var p := _progress
	var y := size.y * 0.42
	var font := UIStyle.FONT_HEAVY_ITALIC
	var tw := font.get_string_size(_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 84).x
	var band_w := (tw + 260.0) * p
	var band := UIStyle.slanted_rect(Rect2(Vector2(-40, y - 90), Vector2(band_w, 150)), 40)
	draw_colored_polygon(band, Color(UIStyle.INK, 0.85 * p))
	draw_rect(Rect2(Vector2(-40, y + 60), Vector2(band_w, 6)), Color(UIStyle.LIME, p))
	var a := clampf(p * 1.5 - 0.3, 0.0, 1.0)
	draw_string(font, Vector2(120 - (1.0 - p) * 80, y + 20), _title, HORIZONTAL_ALIGNMENT_LEFT, -1, 84, Color(UIStyle.WHITE, a))
	UIStyle.draw_spaced(self, UIStyle.FONT_BOLD_ITALIC, Vector2(126, y - 54), _subtitle.to_upper(), 20, 4.0, Color(UIStyle.LIME, a))
