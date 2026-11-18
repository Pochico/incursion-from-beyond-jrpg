class_name MiniMap
extends Control
## Minimapa del panel de combate: cuadrícula, calles del mapa provisional y la
## ubicación actual marcada con un triángulo lima.

var location_id := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := size
	var shape := UIStyle.chamfer_rect(Rect2(Vector2.ZERO, s), [0.0, 22.0, 0.0, 22.0])
	draw_colored_polygon(shape, Color(UIStyle.INK, 0.92))
	UIStyle.draw_outline(self, shape, UIStyle.LINE, 1.5)

	var area := Rect2(Vector2(18, 18), s - Vector2(110, 36))
	draw_rect(area, Color(UIStyle.GRAPHITE, 0.5))
	var step := 18.0
	var x := area.position.x
	while x < area.end.x:
		draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), Color(UIStyle.WHITE, 0.06), 1.0)
		x += step
	var y := area.position.y
	while y < area.end.y:
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color(UIStyle.WHITE, 0.06), 1.0)
		y += step

	var to_area := func(p: Vector2) -> Vector2: return area.position + p * area.size
	var river := PackedVector2Array()
	for p: Vector2 in MapView.RIVER:
		river.append(to_area.call(p))
	draw_polyline(river, Color(UIStyle.VIOLET, 0.6), 5.0, true)
	for road in MapView.ROADS:
		var pts := PackedVector2Array()
		for p: Vector2 in road:
			pts.append(to_area.call(p))
		draw_polyline(pts, Color("a99ccf", 0.75), 7.0, true)

	for id in LocationDB.map_ids():
		var loc := LocationDB.get_location(id)
		var p: Vector2 = to_area.call(loc.pos)
		if id == location_id:
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -14), p + Vector2(12, 9), p + Vector2(-12, 9)]), UIStyle.LIME)
		else:
			var c := UIStyle.MAGENTA if loc.get("dungeon", false) else Color(UIStyle.WHITE, 0.7)
			draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), c)

	# Pestaña «Mapa» y norte.
	var tab := Rect2(area.position + Vector2(-2, -2), Vector2(96, 36))
	draw_rect(tab, Color(UIStyle.INK, 0.95))
	draw_string(UIStyle.FONT_MEDIUM, tab.position + Vector2(12, 26), "Mapa", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UIStyle.WHITE)
	var n := Vector2(s.x - 46, 52)
	draw_string(UIStyle.FONT_MEDIUM, n + Vector2(-7, -14), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIStyle.WHITE)
	draw_colored_polygon(PackedVector2Array([n + Vector2(0, -8), n + Vector2(11, 18), n + Vector2(0, 11), n + Vector2(-11, 18)]), UIStyle.WHITE)
