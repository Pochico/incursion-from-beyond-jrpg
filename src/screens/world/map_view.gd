class_name MapView
extends Control
## Mapa PROVISIONAL de la zona (lista de ubicaciones en LocationDB). Se sustituirá por el mapa definitivo.
##
## Dibuja calles, un río y distritos de forma procedural, y una lista de
## localizaciones seleccionables con teclado, mando o ratón.

signal location_focused(location: Dictionary)
signal location_selected(location: Dictionary)

const ROADS := [
	[Vector2(0.0, 0.40), Vector2(0.30, 0.38), Vector2(0.55, 0.48), Vector2(1.0, 0.50)],
	[Vector2(0.46, 0.0), Vector2(0.46, 0.46), Vector2(0.40, 1.0)],
	[Vector2(0.10, 0.0), Vector2(0.24, 0.30), Vector2(0.30, 0.55), Vector2(0.26, 1.0)],
	[Vector2(0.70, 0.0), Vector2(0.70, 0.24), Vector2(0.66, 0.66), Vector2(0.75, 1.0)],
	[Vector2(0.46, 0.46), Vector2(0.66, 0.66)],
	[Vector2(0.70, 0.24), Vector2(0.86, 0.48)],
]

const RIVER := [Vector2(0.0, 0.86), Vector2(0.18, 0.80), Vector2(0.36, 0.88), Vector2(0.58, 0.84), Vector2(0.80, 0.92), Vector2(1.0, 0.88)]

## Ubicaciones del mapa (Dictionary de LocationDB + "id"), en orden de navegación.
var locations: Array[Dictionary] = []

## Ubicación donde está el jugador (se marca con «AQUÍ»).
var current_id := "":
	set(value):
		current_id = value
		queue_redraw()

var selected := 0:
	set(value):
		selected = wrapi(value, 0, locations.size())
		queue_redraw()
		location_focused.emit(locations[selected])

var _time := 0.0


func _init() -> void:
	for id in LocationDB.map_ids():
		var loc := LocationDB.get_location(id).duplicate()
		loc["id"] = id
		locations.append(loc)


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP


## Selecciona la ubicación con ese id (si está en el mapa).
func select_id(id: String) -> void:
	for i in locations.size():
		if locations[i].id == id:
			selected = i
			return
	selected = 0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		selected += 1
		accept_event()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		selected -= 1
		accept_event()
	elif event.is_action_pressed("ui_accept"):
		location_selected.emit(locations[selected])
		accept_event()
	elif event is InputEventMouseMotion:
		var hit := _location_at(event.position)
		if hit >= 0 and hit != selected:
			selected = hit
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := _location_at(event.position)
		if hit >= 0:
			selected = hit
			location_selected.emit(locations[selected])
			accept_event()


func _location_at(point: Vector2) -> int:
	for i in locations.size():
		if point.distance_to(_to_local(locations[i].pos)) < 34.0:
			return i
	return -1


func _to_local(p: Vector2) -> Vector2:
	return p * size


func _draw() -> void:
	# Distritos (bloques de manzanas aproximados).
	var block := Color(UIStyle.WHITE, 0.05)
	var block_line := Color(UIStyle.WHITE, 0.14)
	for r: Rect2 in [Rect2(0.04, 0.06, 0.16, 0.20), Rect2(0.52, 0.06, 0.12, 0.30), Rect2(0.76, 0.06, 0.20, 0.30),
			Rect2(0.04, 0.46, 0.20, 0.24), Rect2(0.50, 0.54, 0.12, 0.24), Rect2(0.80, 0.60, 0.16, 0.20),
			Rect2(0.32, 0.56, 0.06, 0.20), Rect2(0.30, 0.08, 0.12, 0.24)]:
		var rect := Rect2(r.position * size, r.size * size)
		draw_rect(rect, block)
		draw_rect(rect, block_line, false, 1.0)

	# Río.
	draw_polyline(_scaled(RIVER), Color(UIStyle.VIOLET, 0.45), 26.0, true)
	draw_polyline(_scaled(RIVER), Color(UIStyle.VIOLET, 0.8), 2.0, true)

	# Calles.
	for road in ROADS:
		draw_polyline(_scaled(road), Color(UIStyle.WHITE, 0.10), 18.0, true)
		draw_polyline(_scaled(road), Color(UIStyle.WHITE, 0.35), 2.0, true)

	# Localizaciones.
	var font := UIStyle.FONT_BOLD_ITALIC
	for i in locations.size():
		var loc: Dictionary = locations[i]
		var p := _to_local(loc.pos)
		var is_sel := i == selected
		var accent: Color = UIStyle.MAGENTA if loc.get("dungeon", false) else UIStyle.LIME

		if is_sel:
			var pulse := 0.5 + 0.5 * sin(_time * 4.0)
			draw_arc(p, 30.0 + pulse * 8.0, 0, TAU, 40, Color(accent, 0.6 - pulse * 0.4), 2.0, true)

		var r := 16.0 if is_sel else 12.0
		var diamond := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)])
		draw_colored_polygon(diamond, accent if is_sel else UIStyle.INK)
		UIStyle.draw_outline(self, diamond, accent, 2.0)

		# Etiqueta.
		var label: String = loc.name
		var fs := 24
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var lp := p + Vector2(26, -14)
		var box := UIStyle.slanted_rect(Rect2(lp - Vector2(10, 26), Vector2(tw + 34, 36)), 10)
		draw_colored_polygon(box, accent if is_sel else Color(UIStyle.INK, 0.85))
		if not is_sel:
			UIStyle.draw_outline(self, box, Color(UIStyle.WHITE, 0.5), 1.0)
		draw_string(font, lp + Vector2(8, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				UIStyle.INK if is_sel else UIStyle.WHITE)

		# Marca de posición actual.
		if loc.id == current_id:
			var tri := PackedVector2Array([p + Vector2(0, 22), p + Vector2(-14, 46), p + Vector2(14, 46)])
			draw_colored_polygon(tri, UIStyle.LIME)
			draw_string(UIStyle.FONT_BOLD, p + Vector2(-26, 70), "AQUÍ", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIStyle.LIME)

	# Aviso de marcador de posición.
	draw_string(UIStyle.FONT_MEDIUM, Vector2(12, size.y - 12), "MAPA PROVISIONAL", HORIZONTAL_ALIGNMENT_LEFT,
			-1, 18, Color(UIStyle.WHITE, 0.25))


func _scaled(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(p * size)
	return out
