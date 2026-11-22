class_name CityMap
extends Node3D
## El mapa 3D de Leganés con su cámara, su luz según la hora y (en el editor)
## marcadores 3D de las ubicaciones. `apply(cfg)` aplica una configuración de
## MapConfig; `set_hour(h)` cambia la iluminación. El fondo es transparente:
## se ve lo que haya detrás del SubViewport.

const MARKER_HEIGHT := 60.0

## Marcadores 3D con nombre (el editor). El juego dibuja los suyos en 2D.
@export var show_markers := true

var cfg: Dictionary
var hour := 13.0
## Cámara orbital: mira a `target` (x, z en metros) desde `distance`, con `yaw`
## (giro, 0 = norte arriba) y `pitch` (inclinación, de cfg.camera).
var yaw := 0.0
var pitch := 50.0
var distance := 2300.0
var target := Vector2.ZERO
## Encuadre con el mapa entero (lo calcula `frame_all`).
var fit_distance := 2300.0
var fit_target := Vector2.ZERO
var city: Node3D
var camera: Camera3D
var sun: DirectionalLight3D
var env: Environment
var map_size := Vector2.ONE
var _markers := {}           ## id -> Node3D
var _highlight := ""


func _ready() -> void:
	var data := CityBuilder.load_data()
	map_size = CityBuilder.map_size(data)
	city = CityBuilder.build(data)
	add_child(city)
	sun = DirectionalLight3D.new()
	sun.shadow_bias = 0.04
	add_child(sun)
	env = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	camera = Camera3D.new()
	camera.far = 12000.0
	camera.near = 2.0
	add_child(camera)
	camera.make_current()
	apply(cfg if not cfg.is_empty() else MapConfig.current())


func apply(new_cfg: Dictionary) -> void:
	cfg = new_cfg
	if city == null:
		return   # Aún no está en el árbol: se aplica en _ready.
	pitch = cfg.camera.pitch
	camera.fov = cfg.camera.fov
	update_camera()
	apply_light()
	var veil: Dictionary = cfg.veil
	for layer: String in CityBuilder.LAYERS:
		if layer == "windows":
			continue
		var c := Color(cfg.colors[layer]).lerp(Color(veil.color), veil.amount)
		CityBuilder.set_layer_color(city, layer, c)
	_sync_markers()


func set_hour(h: float) -> void:
	hour = fposmod(h, 24.0)
	if city:
		apply_light()


func apply_light() -> void:
	var l := MapConfig.light_at(cfg, hour)
	sun.rotation_degrees = Vector3(-l.elevation, 180.0 - l.azimuth, 0.0)
	sun.light_color = l.color
	sun.light_energy = l.energy
	sun.shadow_enabled = cfg.lighting.shadows
	env.ambient_light_color = l.ambient
	env.ambient_light_energy = l.ambient_energy
	var w := Color(cfg.colors.windows)
	w.a = clampf(l.windows, 0.0, 1.0)
	CityBuilder.set_layer_color(city, "windows", w)
	(city.get_node("windows") as Node3D).visible = l.windows > 0.01


func update_camera() -> void:
	var t := Vector3(target.x, 0.0, target.y)
	var y := deg_to_rad(yaw)
	var p := deg_to_rad(pitch)
	# yaw 0: la cámara está al sur mirando al norte (−Z).
	var offset := Vector3(sin(y) * cos(p), sin(p), cos(y) * cos(p)) * distance
	camera.look_at_from_position(t + offset, t)
	sun.directional_shadow_max_distance = distance * 2.0
	for m: Node3D in _markers.values():
		_scale_marker(m)


## Encuadra el mapa entero, recto (norte arriba), con un margen alrededor.
## Guarda el resultado en fit_distance / fit_target y deja la cámara ahí.
func frame_all(margin := 0.04) -> void:
	var vs := camera.get_viewport().get_visible_rect().size
	if vs.x < 2.0 or vs.y < 2.0:
		return
	yaw = 0.0
	target = Vector2.ZERO
	var room := vs * (1.0 - margin * 2.0)
	for pass_ in 4:
		# Distancia mínima a la que la maqueta cabe (búsqueda binaria).
		var lo := 50.0
		var hi := 40000.0
		for i in 32:
			distance = (lo + hi) * 0.5
			update_camera()
			var b := _model_screen_rect()
			if b.size.x <= room.x and b.size.y <= room.y:
				hi = distance
			else:
				lo = distance
		distance = hi
		update_camera()
		# Centrar: mover el objetivo para que la maqueta quede en medio.
		var b := _model_screen_rect()
		var a = ground_point(b.get_center())
		var c = ground_point(vs * 0.5)
		if a == null or c == null:
			break
		target += Vector2((a as Vector3).x - (c as Vector3).x, (a as Vector3).z - (c as Vector3).z)
	update_camera()
	fit_distance = distance
	fit_target = target


## Rectángulo en pantalla que ocupa la maqueta (con la base y algo de altura).
func _model_screen_rect() -> Rect2:
	var h := map_size * 0.5
	var r := Rect2()
	var first := true
	for x: float in [-h.x, h.x]:
		for z: float in [-h.y, h.y]:
			for y: float in [-CityBuilder.BASE_DEPTH, 40.0]:
				var p := camera.unproject_position(Vector3(x, y, z))
				if first:
					r = Rect2(p, Vector2.ZERO)
					first = false
				else:
					r = r.expand(p)
	return r


## Dónde está una ubicación (x, z en metros). Si aún no se ha colocado en el
## editor, una posición provisional a partir de la del mapa antiguo.
func point_of(id: String) -> Vector2:
	if cfg.points.has(id):
		return Vector2(cfg.points[id][0], cfg.points[id][1])
	var pos: Vector2 = LocationDB.get_location(id).get("pos", Vector2(0.5, 0.5))
	return (pos - Vector2(0.5, 0.5)) * map_size * 0.85


## Posición en pantalla (del viewport) de una ubicación.
func screen_point(id: String) -> Vector2:
	var p := point_of(id)
	return camera.unproject_position(Vector3(p.x, 0.0, p.y))


## Punto del suelo (y = 0) bajo una posición de pantalla del viewport.
func ground_point(screen_pos: Vector2) -> Variant:
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	return Plane(Vector3.UP, 0.0).intersects_ray(from, dir)


## La ubicación cuyo marcador está más cerca de `screen_pos` (a menos de `radius` px).
func marker_at(screen_pos: Vector2, radius := 28.0) -> String:
	var best := ""
	var best_d := radius
	for id: String in _markers:
		var base: Vector3 = (_markers[id] as Node3D).position
		for p: Vector3 in [base, base + Vector3(0, MARKER_HEIGHT * _marker_scale(), 0)]:
			if camera.is_position_behind(p):
				continue
			var d := camera.unproject_position(p).distance_to(screen_pos)
			if d < best_d:
				best_d = d
				best = id
	return best


func set_highlight(id: String) -> void:
	_highlight = id
	_sync_markers()


func _sync_markers() -> void:
	var ids: Array = LocationDB.map_ids() if show_markers else []
	for id: String in _markers.keys():
		if not ids.has(id):
			_markers[id].queue_free()
			_markers.erase(id)
	for id: String in ids:
		if not _markers.has(id):
			_markers[id] = _make_marker(id)
			add_child(_markers[id])
			_scale_marker(_markers[id])
		var m: Node3D = _markers[id]
		var p := point_of(id)
		m.position = Vector3(p.x, 0.0, p.y)
		var placed: bool = cfg.points.has(id)
		var col := UIStyle.MAGENTA if id == _highlight else (UIStyle.LIME if placed else Color(UIStyle.WHITE, 0.6))
		((m.get_node("Pin") as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = col
		var label := m.get_node("Nombre") as Label3D
		label.text = LocationDB.display_name(id) + ("" if placed else " (?)")
		label.modulate = col.lightened(0.5)


## Los pines crecen con la distancia para verse siempre del mismo tamaño (el
## nombre ya es de tamaño fijo en pantalla).
func _marker_scale() -> float:
	return maxf(distance / 1200.0, 0.4)


func _scale_marker(m: Node3D) -> void:
	var s := _marker_scale()
	var pin := m.get_node("Pin") as Node3D
	pin.scale = Vector3.ONE * s
	pin.position.y = MARKER_HEIGHT * 0.5 * s
	(m.get_node("Nombre") as Node3D).position.y = (MARKER_HEIGHT + 12.0) * s


func _make_marker(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = id
	var pin := MeshInstance3D.new()
	pin.name = "Pin"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 14.0
	mesh.bottom_radius = 1.0
	mesh.height = MARKER_HEIGHT
	pin.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pin.material_override = mat
	root.add_child(pin)
	var label := Label3D.new()
	label.name = "Nombre"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.pixel_size = 0.0008
	label.font_size = 26
	label.outline_size = 10
	label.outline_modulate = Color(UIStyle.INK, 0.9)
	label.no_depth_test = true
	root.add_child(label)
	return root
