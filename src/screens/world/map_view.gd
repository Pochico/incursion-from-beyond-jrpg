class_name MapView
extends Control
## Mapa de la zona: el modelo 3D de Leganés (CityMap, ajustado con el editor del
## mapa) con las ubicaciones encima, seleccionables con teclado, mando o ratón.
## La iluminación sigue la franja del día (GameState.slot_hour) cada vez que se abre.
## Sale siempre recto y entero; con la rueda, el pellizco o +/− se acerca hacia
## el ratón, y arrastrando se mueve. Al abrirlo relee la configuración si se ha
## guardado de nuevo desde el editor.

signal location_focused(location: Dictionary)
signal location_selected(location: Dictionary)

## Calles y río del mapa provisional: los usa todavía el minimapa del combate.
const ROADS := [
	[Vector2(0.0, 0.40), Vector2(0.30, 0.38), Vector2(0.55, 0.48), Vector2(1.0, 0.50)],
	[Vector2(0.46, 0.0), Vector2(0.46, 0.46), Vector2(0.40, 1.0)],
	[Vector2(0.10, 0.0), Vector2(0.24, 0.30), Vector2(0.30, 0.55), Vector2(0.26, 1.0)],
	[Vector2(0.70, 0.0), Vector2(0.70, 0.24), Vector2(0.66, 0.66), Vector2(0.75, 1.0)],
	[Vector2(0.46, 0.46), Vector2(0.66, 0.66)],
	[Vector2(0.70, 0.24), Vector2(0.86, 0.48)],
]
const RIVER := [Vector2(0.0, 0.86), Vector2(0.18, 0.80), Vector2(0.36, 0.88), Vector2(0.58, 0.84), Vector2(0.80, 0.92), Vector2(1.0, 0.88)]

const LABEL_FONT_SIZE := 24
const MAX_ZOOM := 5.0
const ZOOM_STEP := 1.15
const DRAG_THRESHOLD := 8.0

## Ubicaciones del mapa (Dictionary de LocationDB + "id"), en orden de navegación.
var locations: Array[Dictionary] = []

## Ubicación donde está el jugador (se marca con «AQUÍ»).
var current_id := "":
	set(value):
		current_id = value
		_redraw()

var selected := 0:
	set(value):
		selected = wrapi(value, 0, locations.size())
		_redraw()
		location_focused.emit(locations[selected])
		if not _mouse_selecting:
			_keep_visible(selected)

var _time := 0.0
var _zoom := 1.0
var _press_pos := Vector2.ZERO
var _pressed := false
var _dragging := false
var _mouse_selecting := false
var _city: CityMap
var _layer: Control          ## Rombos y etiquetas, por encima del 3D.


func _init() -> void:
	_load_locations()


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true   # Con zoom, nada se sale del marco.
	resized.connect(_reframe)
	var view := SubViewportContainer.new()
	view.stretch = true
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	view.add_child(vp)
	_city = CityMap.new()
	_city.show_markers = false
	vp.add_child(_city)
	_layer = Control.new()
	_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.draw.connect(_draw_layer)
	add_child(_layer)


## Al abrir: configuración al día (por si se ha guardado desde el editor), luz
## de la hora actual y el mapa entero.
func refresh() -> void:
	MapConfig.reload_if_changed()
	_load_locations()
	if _city:
		_city.apply(MapConfig.current())
		_city.set_hour(GameState.slot_hour())
	_reframe()


func _reframe() -> void:
	if _city == null or _city.camera == null:
		return
	_zoom = 1.0
	_city.frame_all()
	_redraw()


# --- Zoom y desplazamiento ---------------------------------------------------------------

## Acerca (factor > 1) o aleja manteniendo fijo el punto del suelo bajo `screen_pos`.
func _zoom_at(factor: float, screen_pos: Vector2) -> void:
	var before = _city.ground_point(screen_pos)
	_zoom = clampf(_zoom * factor, 1.0, MAX_ZOOM)
	_city.distance = _city.fit_distance / _zoom
	_city.update_camera()
	var after = _city.ground_point(screen_pos)
	if before != null and after != null:
		_city.target += Vector2(before.x - after.x, before.z - after.z)
	_clamp_target()


func _pan(relative: Vector2) -> void:
	var c := size * 0.5
	var a = _city.ground_point(c)
	var b = _city.ground_point(c + relative)
	if a == null or b == null:
		return
	_city.target += Vector2(a.x - b.x, a.z - b.z)
	_clamp_target()


## Con zoom se puede mover por todo el mapa; sin zoom, vuelve al encuadre completo.
func _clamp_target() -> void:
	var reach := _city.map_size * 0.5 * (1.0 - 1.0 / _zoom)
	var off := (_city.target - _city.fit_target).clamp(-reach, reach)
	_city.target = _city.fit_target + off
	_city.update_camera()
	_redraw()


## Con zoom, si la ubicación elegida con el teclado queda fuera, el mapa la sigue.
func _keep_visible(i: int) -> void:
	if _city == null or _zoom <= 1.0:
		return
	var p := _to_local(i)
	if Rect2(Vector2.ZERO, size).grow(-80).has_point(p):
		return
	_city.target = _city.point_of(locations[i].id)
	_clamp_target()


func _load_locations() -> void:
	locations.clear()
	for id in LocationDB.map_ids():
		var loc := LocationDB.get_location(id)
		loc["id"] = id
		locations.append(loc)


## Selecciona la ubicación con ese id (si está en el mapa).
func select_id(id: String) -> void:
	for i in locations.size():
		if locations[i].id == id:
			selected = i
			return
	selected = 0


func _redraw() -> void:
	if _layer:
		_layer.queue_redraw()


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_time += delta
		_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var k := (event as InputEventKey).keycode
		if k in [KEY_PLUS, KEY_EQUAL, KEY_KP_ADD]:
			_zoom_at(ZOOM_STEP, size * 0.5)
			accept_event()
			return
		if k in [KEY_MINUS, KEY_KP_SUBTRACT]:
			_zoom_at(1.0 / ZOOM_STEP, size * 0.5)
			accept_event()
			return
	if event is InputEventMagnifyGesture:
		_zoom_at((event as InputEventMagnifyGesture).factor, event.position)
		accept_event()
		return
	if event is InputEventPanGesture:
		_pan(-(event as InputEventPanGesture).delta * 12.0)
		accept_event()
		return
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
		var mm := event as InputEventMouseMotion
		var held := mm.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE) != 0
		if held and _pressed and (_dragging or mm.position.distance_to(_press_pos) > DRAG_THRESHOLD):
			_dragging = true
			_pan(mm.relative)
			mouse_default_cursor_shape = Control.CURSOR_DRAG
			return
		var hit := _location_at(mm.position)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hit >= 0 else Control.CURSOR_ARROW
		if hit >= 0 and hit != selected:
			_mouse_selecting = true
			selected = hit
			_mouse_selecting = false
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(ZOOM_STEP, mb.position)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(1.0 / ZOOM_STEP, mb.position)
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if mb.pressed:
				_pressed = true
				_dragging = false
				_press_pos = mb.position
			else:
				# Clic (sin arrastrar) sobre una ubicación: viajar.
				var was_drag := _dragging
				_pressed = false
				_dragging = false
				if not was_drag and mb.button_index == MOUSE_BUTTON_LEFT:
					var hit := _location_at(mb.position)
					if hit >= 0:
						_mouse_selecting = true
						selected = hit
						_mouse_selecting = false
						location_selected.emit(locations[selected])
		accept_event()


## Ubicación bajo el punto: vale tanto el rombo como la etiqueta con su nombre.
func _location_at(point: Vector2) -> int:
	for i in locations.size():
		if point.distance_to(_to_local(i)) < 34.0 or _label_rect(i).has_point(point):
			return i
	return -1


## Caja de la etiqueta de la ubicación `i` (la misma que se dibuja).
func _label_rect(i: int) -> Rect2:
	var p := _to_local(i)
	var tw := UIStyle.FONT_BOLD_ITALIC.get_string_size(locations[i].name, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE).x
	var lp := p + Vector2(26, -14)
	return Rect2(lp - Vector2(10, 26), Vector2(tw + 34, 36))


func _to_local(i: int) -> Vector2:
	if _city == null or _city.camera == null:
		return size * 0.5
	return _city.screen_point(locations[i].id)


func _draw_layer() -> void:
	var c := _layer
	var font := UIStyle.FONT_BOLD_ITALIC
	for i in locations.size():
		var loc: Dictionary = locations[i]
		var p := _to_local(i)
		var is_sel := i == selected
		var accent: Color = UIStyle.MAGENTA if loc.get("dungeon", false) else UIStyle.LIME

		if is_sel:
			var pulse := 0.5 + 0.5 * sin(_time * 4.0)
			c.draw_arc(p, 30.0 + pulse * 8.0, 0, TAU, 40, Color(accent, 0.6 - pulse * 0.4), 2.0, true)

		var r := 16.0 if is_sel else 12.0
		var diamond := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)])
		c.draw_colored_polygon(diamond, accent if is_sel else UIStyle.INK)
		UIStyle.draw_outline(c, diamond, accent, 2.0)

		# Etiqueta.
		var lp := p + Vector2(26, -14)
		var box := UIStyle.slanted_rect(_label_rect(i), 10)
		c.draw_colored_polygon(box, accent if is_sel else Color(UIStyle.INK, 0.85))
		if not is_sel:
			UIStyle.draw_outline(c, box, Color(UIStyle.WHITE, 0.5), 1.0)
		c.draw_string(font, lp + Vector2(8, 0), loc.name, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE,
				UIStyle.INK if is_sel else UIStyle.WHITE)

		# Marca de posición actual.
		if loc.id == current_id:
			var tri := PackedVector2Array([p + Vector2(0, 22), p + Vector2(-14, 46), p + Vector2(14, 46)])
			c.draw_colored_polygon(tri, UIStyle.LIME)
			c.draw_string(UIStyle.FONT_BOLD, p + Vector2(-26, 70), "AQUÍ", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIStyle.LIME)

	# Atribución de los datos del mapa (licencia ODbL).
	var credit := "© colaboradores de OpenStreetMap"
	var cw := UIStyle.FONT_MEDIUM.get_string_size(credit, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	c.draw_rect(Rect2(size.x - cw - 20, size.y - 28, cw + 20, 28), Color(UIStyle.INK, 0.6))
	c.draw_string(UIStyle.FONT_MEDIUM, Vector2(size.x - cw - 10, size.y - 9), credit, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 15, Color(UIStyle.WHITE, 0.6))
