extends Control
## Decoración de la pantalla de título: cortes diagonales lima y violeta,
## líneas finas y una línea de escaneo que recorre la pantalla.

var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y

	# Cortes diagonales grandes a la derecha (como en la ficha de personaje).
	var sway := sin(_time * 0.6) * 6.0
	_slash(Vector2(w * 0.70 + sway, h), Vector2(w * 0.86 + sway, 0), 34.0, Color(UIStyle.LIME, 0.92))
	_slash(Vector2(w * 0.755 - sway, h), Vector2(w * 0.915 - sway, 0), 12.0, Color(UIStyle.VIOLET, 0.85))
	_slash(Vector2(w * 0.80, h), Vector2(w * 0.96, 0), 3.0, Color(UIStyle.WHITE, 0.35))

	# Marco fino superior con «///».
	draw_line(Vector2(48, 48), Vector2(w * 0.42, 48), Color(UIStyle.WHITE, 0.25), 1.0)
	UIStyle.draw_stripes(self, Vector2(w * 0.42 + 12, 56), 3, Vector2(10, 14), 5, Color(UIStyle.WHITE, 0.4))

	# Línea inferior del pie.
	var fy := h - 96.0
	draw_line(Vector2(48, fy), Vector2(w - 48, fy), Color(UIStyle.WHITE, 0.35), 1.0)
	UIStyle.draw_stripes(self, Vector2(w - 48 - 66, fy - 8), 3, Vector2(14, 10), 6, Color(UIStyle.WHITE, 0.6),
			[Color(UIStyle.WHITE, 0.6), UIStyle.LIME, UIStyle.LIME])

	# Línea de escaneo horizontal muy sutil.
	var scan_y := fmod(_time * 90.0, h + 200.0) - 100.0
	draw_rect(Rect2(0, scan_y, w, 2), Color(UIStyle.LIME, 0.05))


func _slash(bottom: Vector2, top: Vector2, width: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		bottom, top, top + Vector2(width, 0), bottom + Vector2(width, 0),
	]), color)
