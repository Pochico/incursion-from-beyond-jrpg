class_name CityBuilder
extends RefCounted
## Construye la ciudad 3D a partir de assets/map/leganes.json (ver tools/maps3d).
##
## Todo se recorta al rectángulo del mapa (nada asoma por los lados) y debajo
## lleva una base con grosor, como una maqueta. Cada capa es una malla con su
## propio material: su color se cambia al vuelo (`set_layer_color`) sin
## reconstruir. Los colores de vértice solo llevan el sombreado y se multiplican
## por el color de la capa. La capa `windows` son las ventanas encendidas de noche.

const DATA_PATH := "res://assets/map/leganes.json"

## Capas, en orden de dibujo.
const LAYERS := ["base", "ground", "green", "water", "paths", "roads", "rail", "buildings", "windows"]
const LAYER_Y := {"ground": 0.0, "green": 0.05, "water": 0.08, "paths": 0.12, "roads": 0.2, "rail": 0.18}
const MINOR_ROADS := ["footway", "cycleway", "path", "steps", "pedestrian", "track"]
const BASE_DEPTH := 40.0

const FLOOR_H := 3.2
## Luces de noche: tramos de fachada encendidos por planta (de lejos, una
## ventana suelta no llega a un píxel; un tramo de varias sí se ve).
const LIGHT_H := 2.2               ## alto de la franja de luz
const LIGHT_SPAN := 9.0            ## largo de cada tramo
const LIGHT_LIT := 0.38            ## proporción de tramos encendidos


static func load_data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))


## Tamaño del mapa en metros (x = este-oeste, y = norte-sur).
static func map_size(data: Dictionary) -> Vector2:
	return Vector2(data.size[0], data.size[1])


## Devuelve un Node3D con un MeshInstance3D por capa (con el nombre de la capa).
static func build(data: Dictionary) -> Node3D:
	var city := Node3D.new()
	city.name = "Ciudad"
	var half := map_size(data) * 0.5
	var bounds := Rect2(-half, half * 2.0)
	var rect := PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
	var surfaces := {}
	for layer: String in LAYERS:
		if layer == "windows":
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		surfaces[layer] = st

	_flat(surfaces.ground, rect, 0.0, Color.WHITE)
	_base(surfaces.base, rect)
	for g in data.green:
		for poly in _clip(g.p, rect):
			_flat(surfaces.green, poly, LAYER_Y.green, Color.WHITE)
	for w in data.water:
		for poly in _clip(w.p, rect):
			_flat(surfaces.water, poly, LAYER_Y.water, Color.WHITE)
	for r in data.roads:
		var layer := "paths" if r.k in MINOR_ROADS else "roads"
		_strip(surfaces[layer], r.p, r.w, LAYER_Y[layer], bounds)
	for r in data.rail:
		_strip(surfaces.rail, r.p, r.w, LAYER_Y.rail, bounds)
	var windows := {"v": PackedVector3Array(), "n": PackedVector3Array()}
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for b in data.buildings:
		for poly in _clip(b.p, rect):
			_building(surfaces.buildings, poly, b.h)
			_windows(windows, poly, b.h, rng)

	for layer: String in LAYERS:
		var mesh: ArrayMesh
		if layer == "windows":
			mesh = ArrayMesh.new()
			if not windows.v.is_empty():
				var arrays := []
				arrays.resize(Mesh.ARRAY_MAX)
				arrays[Mesh.ARRAY_VERTEX] = windows.v
				arrays[Mesh.ARRAY_NORMAL] = windows.n
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		else:
			mesh = (surfaces[layer] as SurfaceTool).commit()
		if mesh.get_surface_count() > 0:
			mesh.surface_set_material(0, _material(layer))
		var mi := MeshInstance3D.new()
		mi.name = layer
		mi.mesh = mesh
		if layer == "windows":
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		city.add_child(mi)
	return city


static func _material(layer: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if layer == "windows":
		# Luz propia: no le afecta la iluminación; su opacidad = cuánto están encendidas.
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		return m
	m.vertex_color_use_as_albedo = true
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 0.9
	return m


static func set_layer_color(city: Node3D, layer: String, color: Color) -> void:
	var mi := city.get_node_or_null(layer) as MeshInstance3D
	if mi and mi.mesh and mi.mesh.get_surface_count() > 0:
		(mi.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color = color


# --- Recorte -------------------------------------------------------------------------

## Polígonos resultantes de recortar `pts` al rectángulo del mapa.
static func _clip(pts: Array, rect: PackedVector2Array) -> Array:
	var poly := PackedVector2Array()
	for p in pts:
		poly.append(Vector2(p[0], p[1]))
	if poly.size() < 3:
		return []
	var inside := true
	for p in poly:
		if not Geometry2D.is_point_in_polygon(p, rect):
			inside = false
			break
	if inside:
		return [poly]
	return Geometry2D.intersect_polygons(poly, rect)


## Recorta el segmento a..b al rectángulo (Liang-Barsky). Vacío si queda fuera.
static func _clip_segment(a: Vector2, b: Vector2, r: Rect2) -> Array:
	var d := b - a
	var t0 := 0.0
	var t1 := 1.0
	for e in [[-d.x, a.x - r.position.x], [d.x, r.end.x - a.x], [-d.y, a.y - r.position.y], [d.y, r.end.y - a.y]]:
		var p: float = e[0]
		var q: float = e[1]
		if absf(p) < 1e-9:
			if q < 0:
				return []
		else:
			var t := q / p
			if p < 0:
				t0 = maxf(t0, t)
			else:
				t1 = minf(t1, t)
	if t0 > t1:
		return []
	return [a + d * t0, b - d * (1.0 - t1), t0 > 0.0, t1 < 1.0]


# --- Geometría -------------------------------------------------------------------------

static func _flat(st: SurfaceTool, poly: PackedVector2Array, y: float, c: Color) -> void:
	if poly.size() < 3:
		return
	var idx := Geometry2D.triangulate_polygon(poly)
	for i in range(0, idx.size(), 3):
		var tri := [Vector3(poly[idx[i]].x, y, poly[idx[i]].y), Vector3(poly[idx[i + 1]].x, y, poly[idx[i + 1]].y),
			Vector3(poly[idx[i + 2]].x, y, poly[idx[i + 2]].y)]
		# Godot toma como cara frontal la que se ve en sentido horario: que mire hacia arriba.
		if (tri[1] - tri[0]).cross(tri[2] - tri[0]).y > 0:
			tri = [tri[0], tri[2], tri[1]]
		for v: Vector3 in tri:
			st.set_color(c)
			st.set_normal(Vector3.UP)
			st.add_vertex(v)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c2: Vector3, d: Vector3, c: Color) -> void:
	var n := (b - a).cross(d - a).normalized()
	for v: Vector3 in [a, b, c2, a, c2, d]:
		st.set_color(c)
		st.set_normal(n)
		st.add_vertex(v)


## Los lados de la maqueta, de y = 0 hasta −BASE_DEPTH.
static func _base(st: SurfaceTool, rect: PackedVector2Array) -> void:
	for i in 4:
		var p0 := rect[i]
		var p1 := rect[(i + 1) % 4]
		_quad(st, Vector3(p0.x, -BASE_DEPTH, p0.y), Vector3(p1.x, -BASE_DEPTH, p1.y), Vector3(p1.x, 0, p1.y), Vector3(p0.x, 0, p0.y), Color.WHITE)


## Recorre las aristas de `poly` en el sentido en que sus paredes miran hacia fuera.
static func _outer_edges(poly: PackedVector2Array) -> Array:
	var area := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		area += a.x * b.y - b.x * a.y
	var edges := []
	for i in poly.size():
		var p0 := poly[i]
		var p1 := poly[(i + 1) % poly.size()]
		edges.append([p1, p0] if area < 0 else [p0, p1])
	return edges


static func _building(st: SurfaceTool, poly: PackedVector2Array, h: float) -> void:
	# Un poco más oscuro cuanto más bajo, para que se lean las alturas.
	var c := Color.WHITE.darkened(clampf(0.18 - h / 200.0, 0.0, 0.18))
	_flat(st, poly, h, c)
	var wall := c.darkened(0.06)
	for e in _outer_edges(poly):
		var p0: Vector2 = e[0]
		var p1: Vector2 = e[1]
		_quad(st, Vector3(p0.x, 0, p0.y), Vector3(p1.x, 0, p1.y), Vector3(p1.x, h, p1.y), Vector3(p0.x, h, p0.y), wall)


## Luces encendidas al azar (siempre las mismas) en las fachadas.
static func _windows(out: Dictionary, poly: PackedVector2Array, h: float, rng: RandomNumberGenerator) -> void:
	var floors := int((h - 1.0) / FLOOR_H)
	if floors < 1:
		return
	for e in _outer_edges(poly):
		var p0: Vector2 = e[0]
		var p1: Vector2 = e[1]
		var length := p0.distance_to(p1)
		if length < 3.0:
			continue
		var cols := maxi(int(length / LIGHT_SPAN), 1)
		var dir := (p1 - p0) / length
		var n2 := Vector2(dir.y, -dir.x)   # hacia fuera del edificio
		var normal := Vector3(n2.x, 0, n2.y)
		var off := n2 * 0.25
		var seg := length / cols
		for f in floors:
			var y0 := 0.6 + f * FLOOR_H
			for col in cols:
				if rng.randf() > LIGHT_LIT:
					continue
				var a := p0 + dir * (seg * col + seg * 0.12) + off
				var b := p0 + dir * (seg * (col + 1) - seg * 0.12) + off
				var y1 := y0 + LIGHT_H
				for v: Vector3 in [Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(b.x, y1, b.y),
						Vector3(a.x, y0, a.y), Vector3(b.x, y1, b.y), Vector3(a.x, y1, a.y)]:
					out.v.append(v)
					out.n.append(normal)


static func _strip(st: SurfaceTool, pts: Array, width: float, y: float, bounds: Rect2) -> void:
	var hw := width * 0.5
	# Recorte con margen de media anchura: así ninguna calle asoma por el borde.
	var r := bounds.grow(-hw)
	for i in pts.size() - 1:
		var seg := _clip_segment(Vector2(pts[i][0], pts[i][1]), Vector2(pts[i + 1][0], pts[i + 1][1]), r)
		if seg.is_empty():
			continue
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		if a.distance_to(b) < 0.01:
			continue
		var dir := (b - a).normalized()
		var n := dir.orthogonal() * hw
		# Se alarga un poco por los extremos para tapar las juntas (no donde se ha recortado).
		var a2 := a if seg[2] else a - dir * hw * 0.5
		var b2 := b if seg[3] else b + dir * hw * 0.5
		_quad(st, Vector3(a2.x + n.x, y, a2.y + n.y), Vector3(b2.x + n.x, y, b2.y + n.y),
			Vector3(b2.x - n.x, y, b2.y - n.y), Vector3(a2.x - n.x, y, a2.y - n.y), Color.WHITE)
