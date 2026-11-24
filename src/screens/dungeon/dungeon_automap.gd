class_name DungeonAutomap
extends Control
## Automapa de la mazmorra: las casillas ya visitadas de la planta actual, sus
## paredes y puertas, y el grupo como un triángulo lima. Ocupa el hueco del
## minimapa del combate; `big` = versión grande que tapa el visor (tecla M).

var explorer: DungeonExplorer
var big := false

const CHAMFER := 22.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := size
	var shape := UIStyle.chamfer_rect(Rect2(Vector2.ZERO, s), [0.0, CHAMFER, 0.0, CHAMFER])
	draw_colored_polygon(shape, Color(UIStyle.INK, 0.95 if big else 0.92))
	UIStyle.draw_outline(self, shape, UIStyle.LINE, 1.5)
	var title_size := 30 if big else 22
	var area := Rect2(Vector2(18, 18), s - Vector2(36, 36))
	if big:
		area = Rect2(Vector2(40, 80), s - Vector2(80, 120))
		draw_string(UIStyle.FONT_BOLD_ITALIC, Vector2(40, 54), "Automapa", HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, UIStyle.WHITE)
	draw_rect(area, Color(UIStyle.GRAPHITE, 0.5))
	if explorer == null or explorer.map == null:
		return
	var m := explorer.map
	var lvl := m.level
	if big:
		draw_string(UIStyle.FONT_MEDIUM, Vector2(220, 54), m.level_name() + "   ·   [M] Cerrar", HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
				Color(UIStyle.WHITE, 0.65))
	else:
		draw_string(UIStyle.FONT_MEDIUM, Vector2(s.x - 140, 40), m.level_name(), HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
				Color(UIStyle.WHITE, 0.75))

	# Escala: casillas fijas centradas en el grupo (pequeño) o todo lo visitado (grande).
	var px := 22.0
	var center := Vector2(explorer.cell) + Vector2(0.5, 0.5)
	if big:
		var vis := Rect2i()
		var first := true
		for c: Vector2i in m.cells:
			if explorer.is_visited(lvl, c):
				vis = Rect2i(c, Vector2i.ONE) if first else vis.merge(Rect2i(c, Vector2i.ONE))
				first = false
		if not first:
			px = clampf(minf(area.size.x / (vis.size.x + 2), area.size.y / (vis.size.y + 2)), 14.0, 64.0)
			center = Vector2(vis.position) + Vector2(vis.size) * 0.5
	var origin := area.get_center() - center * px
	var to_px := func(c: Vector2i) -> Rect2: return Rect2(origin + Vector2(c) * px, Vector2(px, px))

	var wall_w := maxf(2.0, px * 0.1)
	for c: Vector2i in m.cells:
		if not explorer.is_visited(lvl, c) and not _seen_save_point(m, lvl, c):
			continue
		var r: Rect2 = to_px.call(c)
		if not area.encloses(r):
			continue
		draw_rect(r.grow(-1), Color("a99ccf", 0.35))
		var th := m.thing(c)
		match th.get("type", ""):
			DungeonMap.STAIRS:
				draw_string(UIStyle.FONT_BOLD_ITALIC, r.position + Vector2(px * 0.2, px * 0.8), "▲" if th.up else "▼",
						HORIZONTAL_ALIGNMENT_LEFT, -1, int(px * 0.7), UIStyle.LIME if th.up else UIStyle.VIOLET)
			DungeonMap.SWITCH:
				draw_rect(r.grow(-px * 0.3), UIStyle.VIOLET)
			DungeonMap.SAVE:
				var k := px * 0.3
				var cc := r.get_center()
				draw_colored_polygon(PackedVector2Array([cc + Vector2(0, -k), cc + Vector2(k, 0), cc + Vector2(0, k), cc + Vector2(-k, 0)]), UIStyle.CYAN)
		if m.is_extraction(c):
			draw_arc(r.get_center(), px * 0.32, 0, TAU, 24, UIStyle.CYAN, maxf(1.5, px * 0.08), true)
		for d in 4:
			var t := m.edge_type(c, d)
			if t == DungeonMap.OPEN:
				continue
			var a: Vector2
			var b: Vector2
			match d:
				DungeonMap.N: a = r.position; b = Vector2(r.end.x, r.position.y)
				DungeonMap.E: a = Vector2(r.end.x, r.position.y); b = r.end
				DungeonMap.S: a = Vector2(r.position.x, r.end.y); b = r.end
				_: a = r.position; b = Vector2(r.position.x, r.end.y)
			var ek := DungeonMap.edge_key(c, d)
			if t == DungeonMap.DOOR and m.is_secret(ek):
				if explorer.door_open(ek):
					continue
				draw_line(a, b, UIStyle.WHITE, wall_w)
			elif t == DungeonMap.DOOR:
				var open := explorer.door_open(ek)
				draw_line(a, b, Color(UIStyle.LIME, 0.5 if open else 1.0), wall_w + 1.0)
			else:
				draw_line(a, b, UIStyle.WHITE, wall_w)

	# El grupo.
	var pr: Rect2 = to_px.call(explorer.cell)
	var pc := pr.get_center()
	var f := Vector2(DungeonMap.DIRS[explorer.dir])
	var side := f.orthogonal()
	var k := px * 0.42
	draw_colored_polygon(PackedVector2Array([pc + f * k, pc - f * k * 0.7 + side * k * 0.75, pc - f * k * 0.7 - side * k * 0.75]),
			UIStyle.LIME)


## Un punto de guardado no se pisa: sale en el mapa si se ha estado al lado.
func _seen_save_point(m: DungeonMap, lvl: int, c: Vector2i) -> bool:
	if m.thing(c).get("type", "") != DungeonMap.SAVE:
		return false
	for d in DungeonMap.DIRS:
		if explorer.is_visited(lvl, c + d):
			return true
	return false
