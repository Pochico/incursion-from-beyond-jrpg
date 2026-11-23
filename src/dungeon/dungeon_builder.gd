class_name DungeonBuilder
extends RefCounted
## Genera el escenario 3D de un DungeonMap: suelo, techo y paredes como planos
## con textura (una malla por textura) y una escena por puerta.
##
## Medidas en TextureFormats (casilla de 2 m, pared de 2,5 m). Las UV salen de
## la posición en el mundo: una textura del Estudio ocupa exactamente una
## casilla (suelo, techo) o un tramo de pared, y las juntas casan entre casillas.
##
## Resultado:
##   Mazmorra
##     Estructura   suelos y paredes
##     Techos       aparte, para poder ocultarlos en la vista del editor
##     Puertas      un Node3D por puerta (nombre = clave del borde) con su «Hoja»
##     Escaleras    peldaños (la de subir deja el techo abierto; la de bajar, un hueco)
##     Enemigos     un Node3D por enemigo (nombre = "x,y")
##     Objetos      un Node3D por objeto del suelo (nombre = "x,y")
##     Interruptores  un Node3D por palanca (nombre = "x,y") con su «Palanca»
##
## Construye la planta activa del mapa (`map.set_level`).

const DOOR_W := 1.2
const DOOR_H := 2.1
const DOOR_THICK := 0.12
const DOOR_COLOR := Color("3b344d")
const STEPS := 7
const ENEMY_H := 1.9


static func tile() -> float:
	return TextureFormats.TILE_SIZE_M


static func wall_h() -> float:
	return TextureFormats.WALL_HEIGHT_M


## Centro de una casilla en el mundo (a ras de suelo).
static func cell_center(c: Vector2i) -> Vector3:
	var t := tile()
	return Vector3((c.x + 0.5) * t, 0.0, (c.y + 0.5) * t)


## Giro en Y para mirar hacia `dir` (N = −Z).
static func dir_yaw(dir: int) -> float:
	return -dir * PI * 0.5


static func build(map: DungeonMap) -> Node3D:
	var root := Node3D.new()
	root.name = "Mazmorra"
	var structure := {}   # Texture2D -> SurfaceTool
	var ceilings := {}
	var t := tile()
	var h := wall_h()

	for c: Vector2i in map.cells:
		var x0 := c.x * t
		var z0 := c.y * t
		var tex_f := DungeonTextures.resolve(map.theme, "floor", map.cell_texture(c, "floor"))
		var tex_c := DungeonTextures.resolve(map.theme, "ceiling", map.cell_texture(c, "ceiling"))
		var th := map.thing(c)
		var stairs: bool = th.get("type", "") == DungeonMap.STAIRS
		if not (stairs and not th.up):
			var rot := map.cell_rot(c)
			_quad(_st(structure, tex_f), [Vector3(x0, 0, z0 + t), Vector3(x0 + t, 0, z0 + t), Vector3(x0 + t, 0, z0), Vector3(x0, 0, z0)],
					Vector3.UP, _flat_uv if rot == 0 else _rotated_uv.bind(c, rot))
		if not (stairs and th.up):
			_quad(_st(ceilings, tex_c), [Vector3(x0, h, z0), Vector3(x0 + t, h, z0), Vector3(x0 + t, h, z0 + t), Vector3(x0, h, z0 + t)],
					Vector3.DOWN, _flat_uv)
		for d in 4:
			var type := map.edge_type(c, d)
			if type == DungeonMap.OPEN:
				continue
			var tex_w := DungeonTextures.resolve(map.theme, "wall", map.face_texture(c, d))
			_wall_face(_st(structure, tex_w), c, d, type == DungeonMap.DOOR)

	var structure_node := _meshes(structure)
	structure_node.name = "Estructura"
	root.add_child(structure_node)
	var ceiling_node := _meshes(ceilings)
	ceiling_node.name = "Techos"
	root.add_child(ceiling_node)

	var doors := Node3D.new()
	doors.name = "Puertas"
	root.add_child(doors)
	for k: String in map.edges:
		var cs := DungeonMap.key_cells(k)
		if map.edges[k].get("type", "") != DungeonMap.DOOR or not map.has_cell(cs[0]) or not map.has_cell(cs[1]):
			continue
		doors.add_child(_door(k, map.edges[k].door.get("open", false)))

	var stairs_node := Node3D.new()
	stairs_node.name = "Escaleras"
	root.add_child(stairs_node)
	var enemies := Node3D.new()
	enemies.name = "Enemigos"
	root.add_child(enemies)
	var items := Node3D.new()
	items.name = "Objetos"
	root.add_child(items)
	var switches := Node3D.new()
	switches.name = "Interruptores"
	root.add_child(switches)
	for c: Vector2i in map.things:
		if not map.has_cell(c):
			continue
		var th: Dictionary = map.things[c]
		if th.type == DungeonMap.STAIRS:
			var tex := DungeonTextures.resolve(map.theme, "floor", map.cell_texture(c, "floor"))
			stairs_node.add_child(_stairs(c, th.up, th.dir, tex))
		elif th.type == DungeonMap.ENEMY:
			enemies.add_child(_enemy(c, th.enemy))
		elif th.type == DungeonMap.ITEM:
			items.add_child(_item(c))
		elif th.type == DungeonMap.SWITCH:
			switches.add_child(_switch(c, _switch_on(map, th)))
	return root


## Una palanca está «activada» si la primera de sus puertas está abierta al empezar.
static func _switch_on(map: DungeonMap, th: Dictionary) -> bool:
	for k: String in th.get("doors", []):
		if map.edges.get(k, {}).get("type", "") == DungeonMap.DOOR:
			return map.edges[k].door.get("open", false)
	return false


static func _glow_material(col: Color, energy: float = 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m


## Objeto: una caja pequeña con franja lima flotando sobre una losa que brilla
## (a media altura, para que se vea desde la casilla de al lado).
static func _item(c: Vector2i) -> Node3D:
	var node := Node3D.new()
	node.name = "%d,%d" % [c.x, c.y]
	node.position = cell_center(c)
	var glow := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.45
	disc.bottom_radius = 0.45
	disc.height = 0.02
	glow.mesh = disc
	var gm := _glow_material(Color(UIStyle.LIME, 0.35), 0.5)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.material_override = gm
	glow.position.y = 0.01
	node.add_child(glow)
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.42, 0.32, 0.32)
	box.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("2b2740")
	mat.roughness = 0.5
	box.material_override = mat
	box.position.y = 0.8
	box.rotation.y = 0.5
	node.add_child(box)
	var band := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(0.44, 0.06, 0.34)
	band.mesh = bb
	band.material_override = _glow_material(UIStyle.LIME)
	band.position.y = 0.83
	band.rotation.y = 0.5
	var light := OmniLight3D.new()
	light.light_color = UIStyle.LIME
	light.light_energy = 0.6
	light.omni_range = 1.6
	light.position.y = 0.5
	node.add_child(light)
	node.add_child(band)
	return node


## Palanca sobre un poste en el centro de la casilla.
static func _switch(c: Vector2i, on: bool) -> Node3D:
	var node := Node3D.new()
	node.name = "%d,%d" % [c.x, c.y]
	node.position = cell_center(c)
	var post := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.36, 1.0, 0.36)
	post.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("3b344d")
	mat.roughness = 0.6
	post.material_override = mat
	post.position.y = 0.5
	node.add_child(post)
	var panel := MeshInstance3D.new()
	var plm := BoxMesh.new()
	plm.size = Vector3(0.4, 0.06, 0.4)
	panel.mesh = plm
	panel.material_override = _glow_material(UIStyle.VIOLET, 0.6)
	panel.position.y = 1.0
	node.add_child(panel)
	var pivot := Node3D.new()
	pivot.name = "Palanca"
	pivot.position.y = 1.03
	node.add_child(pivot)
	var arm := MeshInstance3D.new()
	var am := CylinderMesh.new()
	am.top_radius = 0.035
	am.bottom_radius = 0.035
	am.height = 0.5
	arm.mesh = am
	arm.material_override = mat
	arm.position.y = 0.25
	pivot.add_child(arm)
	var knob := MeshInstance3D.new()
	var km := SphereMesh.new()
	km.radius = 0.08
	km.height = 0.16
	knob.mesh = km
	knob.material_override = _glow_material(UIStyle.LIME)
	knob.position.y = 0.52
	pivot.add_child(knob)
	set_switch_on(node, on, false)
	return node


## Inclina la palanca: a un lado apagada, al otro encendida.
static func set_switch_on(switch_node: Node3D, on: bool, animate: bool = true) -> void:
	var pivot: Node3D = switch_node.get_node("Palanca")
	var z := deg_to_rad(-40.0 if on else 40.0)
	if not animate:
		pivot.rotation.z = z
		return
	var tw := switch_node.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(pivot, "rotation:z", z, 0.3)


## Peldaños de una escalera que se sube (o baja) andando hacia `d`.
static func _stairs(c: Vector2i, up: bool, d: int, tex: Texture2D) -> Node3D:
	var t := tile()
	var h := wall_h()
	var node := Node3D.new()
	node.name = "%d,%d" % [c.x, c.y]
	var fwd := Vector3(DungeonMap.DIRS[d].x, 0, DungeonMap.DIRS[d].y)
	var center := cell_center(c)
	var mat := material(tex)
	var rise := h / STEPS
	var run := t / STEPS
	for i in STEPS:
		var top := (i + 1) * rise if up else -(i + 1) * rise
		var bottom := 0.0 if up else -h - 0.3
		var step := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(t * 0.98, top - bottom, run)
		step.mesh = box
		step.material_override = mat
		step.position = center + fwd * (-t * 0.5 + (i + 0.5) * run) + Vector3.UP * (bottom + top) * 0.5
		step.rotation.y = dir_yaw(d)
		node.add_child(step)
	if not up:
		# Paredes del hueco, oscuras.
		var dark := StandardMaterial3D.new()
		dark.albedo_color = Color("101018")
		var pit := MeshInstance3D.new()
		var pbox := BoxMesh.new()
		pbox.size = Vector3(t, h, t)
		pbox.flip_faces = true
		pit.mesh = pbox
		pit.material_override = dark
		pit.position = center + Vector3.DOWN * (h * 0.5 + 0.01)
		node.add_child(pit)
	return node


## Enemigo de pie en la casilla: su retrato mirando siempre a la cámara.
static func _enemy(c: Vector2i, enemy_id: String) -> Node3D:
	var node := Node3D.new()
	node.name = "%d,%d" % [c.x, c.y]
	node.position = cell_center(c)
	var tex := CharacterDB.portrait(enemy_id)
	if tex != null:
		var sprite := Sprite3D.new()
		sprite.texture = tex
		sprite.pixel_size = ENEMY_H / tex.get_height()
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.position.y = ENEMY_H * 0.5
		node.add_child(sprite)
	else:
		var body := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.4
		cap.height = ENEMY_H
		body.mesh = cap
		var m := StandardMaterial3D.new()
		m.albedo_color = CharacterDB.color(enemy_id)
		body.material_override = m
		body.position.y = ENEMY_H * 0.5
		node.add_child(body)
	return node


## Una cara de pared del borde `d` de la casilla `c`, mirando hacia dentro de `c`.
## Con puerta, deja el hueco (dos laterales y el dintel).
static func _wall_face(st: SurfaceTool, c: Vector2i, d: int, with_door: bool) -> void:
	var t := tile()
	var h := wall_h()
	var center := cell_center(c)
	var out := Vector3(DungeonMap.DIRS[d].x, 0, DungeonMap.DIRS[d].y)   # hacia el borde
	var n := -out                                                    # normal: hacia la casilla
	var right := out.cross(Vector3.UP)                               # derecha vista de frente
	var mid := center + out * t * 0.5
	var spans := [[-t * 0.5, t * 0.5, 0.0, h]]
	if with_door:
		var hw := DOOR_W * 0.5
		spans = [[-t * 0.5, -hw, 0.0, h], [hw, t * 0.5, 0.0, h], [-hw, hw, DOOR_H, h]]
	for s: Array in spans:
		var a: Vector3 = mid + right * s[0] + Vector3.UP * s[2]
		var b: Vector3 = mid + right * s[1] + Vector3.UP * s[2]
		var cc: Vector3 = mid + right * s[1] + Vector3.UP * s[3]
		var dd: Vector3 = mid + right * s[0] + Vector3.UP * s[3]
		_quad(st, [a, b, cc, dd], n, func(p: Vector3) -> Vector2:
			return Vector2(p.dot(right) / t, 1.0 - p.y / h))


static func _flat_uv(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z) / tile()


## UV del suelo de la casilla `c` girado `rot` cuartos de vuelta (en sentido
## horario visto desde arriba: con 1, lo de arriba de la imagen mira al este).
static func _rotated_uv(p: Vector3, c: Vector2i, rot: int) -> Vector2:
	var f := Vector2(p.x, p.z) / tile() - Vector2(c)    # 0..1 dentro de la casilla
	for i in rot:
		f = Vector2(f.y, 1.0 - f.x)
	return f


## Cuadrilátero a-b-c-d con normal `n`. Godot dibuja la cara delantera en sentido
## horario, así que se orienta cada triángulo según la normal.
static func _quad(st: SurfaceTool, pts: Array, n: Vector3, uv: Callable) -> void:
	for tri: Array in [[0, 1, 2], [0, 2, 3]]:
		var a: Vector3 = pts[tri[0]]
		var b: Vector3 = pts[tri[1]]
		var c: Vector3 = pts[tri[2]]
		if (b - a).cross(c - a).dot(n) > 0.0:
			var tmp := b
			b = c
			c = tmp
		for p: Vector3 in [a, b, c]:
			st.set_normal(n)
			st.set_uv(uv.call(p))
			st.add_vertex(p)


static func _st(groups: Dictionary, tex: Texture2D) -> SurfaceTool:
	if not groups.has(tex):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		groups[tex] = st
	return groups[tex]


static func _meshes(groups: Dictionary) -> Node3D:
	var node := Node3D.new()
	for tex: Texture2D in groups:
		var mi := MeshInstance3D.new()
		mi.mesh = groups[tex].commit()
		mi.material_override = material(tex)
		node.add_child(mi)
	return node


static func material(tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 0.95
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


static func _door(key: String, open: bool) -> Node3D:
	var cs := DungeonMap.key_cells(key)
	var a := cell_center(cs[0])
	var b := cell_center(cs[1])
	var node := Node3D.new()
	node.name = key
	node.set_meta("key", key)
	node.position = (a + b) * 0.5
	# Las puertas de bordes norte van a lo largo de X; las de bordes oeste, de Z.
	if key.ends_with("W"):
		node.rotation.y = PI * 0.5
	var leaf := MeshInstance3D.new()
	leaf.name = "Hoja"
	var box := BoxMesh.new()
	box.size = Vector3(DOOR_W, DOOR_H, DOOR_THICK)
	leaf.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = DOOR_COLOR
	mat.roughness = 0.6
	leaf.material_override = mat
	leaf.position.y = DOOR_H * 0.5 + (DOOR_H if open else 0.0)
	node.add_child(leaf)
	# Franja lima a la altura de los ojos, para distinguir la puerta de la pared.
	var stripe := MeshInstance3D.new()
	var sbox := BoxMesh.new()
	sbox.size = Vector3(DOOR_W * 0.9, 0.06, DOOR_THICK + 0.02)
	stripe.mesh = sbox
	var smat := StandardMaterial3D.new()
	smat.albedo_color = UIStyle.LIME
	smat.emission_enabled = true
	smat.emission = UIStyle.LIME
	smat.emission_energy_multiplier = 0.6
	stripe.material_override = smat
	stripe.position.y = 0.45
	leaf.add_child(stripe)
	return node


## Mueve la hoja de una puerta (sube al abrirse).
static func set_door_open(door_node: Node3D, open: bool, animate: bool = true) -> Tween:
	var leaf: Node3D = door_node.get_node("Hoja")
	var y := DOOR_H * 0.5 + (DOOR_H if open else 0.0)
	if not animate:
		leaf.position.y = y
		return null
	var tw := door_node.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(leaf, "position:y", y, 0.45)
	return tw
