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
##                  (en las de seguridad, «Izq» y «Der»), su «Hueco» (el vano, invisible,
##                  para el recuadro del objetivo) y sus consolas «ConsolaA»/«ConsolaB»
##     Escaleras    peldaños (la de subir deja el techo abierto; la de bajar, un hueco)
##     Enemigos     un Node3D por enemigo (nombre = "x,y")
##     Objetos      un Node3D por objeto del suelo (nombre = "x,y")
##     Interruptores  un Node3D por palanca (nombre = "x,y") con su «Palanca»
##
## Construye la planta activa del mapa (`map.set_level`).

## Grosor de muros y tabiques (m). Cada cara se mete la mitad en su casilla y en
## cada esquina o extremo hay un pilar, así que un tabique suelto en mitad de una
## sala se ve como un bloque y no como una lámina.
const WALL_THICK := 0.3
const DOOR_W := 1.2
const DOOR_H := 2.1
const DOOR_THICK := 0.12
const DOOR_COLOR := Color("2c3530")
## Puerta de seguridad: dos hojas con la imagen (assets/mazmorra/puerta_hoja_*)
## que se abren del centro hacia los lados, y a la derecha (vista de frente, por
## cada cara) una consola con pantalla: roja si no se puede pasar, verde si sí.
const DOOR_LEAF_TEX := ["res://assets/mazmorra/puerta_hoja_izq.png", "res://assets/mazmorra/puerta_hoja_der.png"]
const DOOR_PAD_TEX := "res://assets/mazmorra/puerta_teclado.png"
const PAD_SIZE := Vector2(0.2, 0.29)       ## consola (m), proporción de su imagen (160×232)
const PAD_X := 0.73                        ## centro de la consola desde el centro de la puerta
const PAD_Y := 1.3
const SCREEN_RECT := Rect2(22, 33, 114, 33)   ## pantalla dentro de la imagen de la consola (px)
const LOCK_RED := Color("ff2f24")
const LOCK_GREEN := Color("37ff6a")
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
			if type == DungeonMap.DOOR and map.is_secret(DungeonMap.edge_key(c, d)):
				continue   # la pared falsa va aparte (se hunde al descubrirla)
			var tex_w := DungeonTextures.resolve(map.theme, "wall", map.face_texture(c, d))
			_wall_face(_st(structure, tex_w), c, d, type == DungeonMap.DOOR)
	_posts(map, _st(structure, DungeonTextures.resolve(map.theme, "wall", "")))

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
		if map.is_secret(k):
			doors.add_child(_secret_door(map, k, map.edges[k].door.get("open", false)))
		else:
			var info: Dictionary = map.edges[k].door
			var door := _door(k, info.get("open", false))
			set_door_lock(door, info.get("open", false) or (info.get("requires", "") == "" and not info.get("switch_only", false)))
			doors.add_child(door)

	var lights := Node3D.new()
	lights.name = "Luces"
	root.add_child(lights)
	for c: Vector2i in map.lights:
		lights.add_child(light_point(c, map.lights[c]))

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
	var saves := Node3D.new()
	saves.name = "Guardado"
	root.add_child(saves)
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
			items.add_child(_item(c, th.item))
		elif th.type == DungeonMap.SWITCH:
			switches.add_child(_switch(c, _switch_on(map, th)))
		elif th.type == DungeonMap.SAVE:
			saves.add_child(_save_point(c))
	# Zonas de extracción (y la entrada): un círculo cian en el suelo.
	var exits := Node3D.new()
	exits.name = "Extraccion"
	root.add_child(exits)
	for c: Vector2i in map.cells:
		if map.is_extraction(c):
			exits.add_child(_extraction(c))
	return root


static func _extraction(c: Vector2i) -> Node3D:
	var node := Node3D.new()
	node.name = "%d,%d" % [c.x, c.y]
	node.position = cell_center(c)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.72
	torus.outer_radius = 0.8
	torus.rings = 48
	ring.mesh = torus
	ring.material_override = _glow_material(UIStyle.CYAN, 1.2)
	ring.scale = Vector3(1, 0.05, 1)
	ring.position.y = 0.012
	node.add_child(ring)
	var pad := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.72
	disc.bottom_radius = 0.72
	disc.height = 0.01
	pad.mesh = disc
	var pm := _glow_material(Color(UIStyle.CYAN, 0.16), 0.4)
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pad.material_override = pm
	pad.position.y = 0.008
	node.add_child(pad)
	var light := OmniLight3D.new()
	light.light_color = UIStyle.CYAN
	light.light_energy = 0.6
	light.omni_range = 2.4
	light.position.y = 0.4
	node.add_child(light)
	return node


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


## Objeto sobre una losa que brilla, a media altura (para que se vea desde la
## casilla de al lado), girando: su modelo 3D (ItemDB.model_path), si no su
## imagen y, sin nada, una caja pequeña con franja lima.
static func _item(c: Vector2i, item_id: String = "") -> Node3D:
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
	var light := OmniLight3D.new()
	light.light_color = UIStyle.LIME
	light.light_energy = 0.6
	light.omni_range = 1.6
	light.position.y = 0.5
	node.add_child(light)
	var spin := ItemSpin.new()
	spin.name = "Objeto"
	spin.position.y = 0.7
	node.add_child(spin)
	var model := ItemDB.model_path(item_id)
	var image: String = ItemDB.get_item(item_id).get("image", "")
	if model != "":
		spin.add_child((load(model) as PackedScene).instantiate())
	elif image != "" and ResourceLoader.exists(image):
		# Imagen plana (la tarjeta): por las dos caras.
		var tex: Texture2D = load(image)
		var sprite := Sprite3D.new()
		sprite.texture = tex
		sprite.pixel_size = 0.55 / tex.get_width()
		sprite.double_sided = true
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.position.y = 0.15
		spin.add_child(sprite)
	else:
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.42, 0.32, 0.32)
		box.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("2b2740")
		mat.roughness = 0.5
		box.material_override = mat
		box.position.y = 0.1
		spin.add_child(box)
		var band := MeshInstance3D.new()
		var bb := BoxMesh.new()
		bb.size = Vector3(0.44, 0.06, 0.34)
		band.mesh = bb
		band.material_override = _glow_material(UIStyle.LIME)
		band.position.y = 0.13
		spin.add_child(band)
	return node


## Punto de guardado: terminal con pantalla cian sobre un pedestal, en el
## centro de la casilla (se usa desde la de al lado, como una palanca).
static func _save_point(c: Vector2i) -> Node3D:
	var node := Node3D.new()
	node.name = "%d,%d" % [c.x, c.y]
	node.position = cell_center(c)
	var base := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.32
	cyl.bottom_radius = 0.42
	cyl.height = 1.0
	cyl.radial_segments = 6
	base.mesh = cyl
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("24222e")
	m.metallic = 0.6
	m.roughness = 0.35
	base.material_override = m
	base.position.y = 0.5
	node.add_child(base)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.33
	torus.outer_radius = 0.37
	torus.rings = 32
	ring.mesh = torus
	ring.material_override = _glow_material(UIStyle.CYAN, 1.4)
	ring.position.y = 0.72
	node.add_child(ring)
	# Cristal flotante que gira: lo que se ve desde lejos.
	var gem := MeshInstance3D.new()
	var diamond := SphereMesh.new()   # 4 lados y 2 anillos: un rombo
	diamond.radius = 0.2
	diamond.height = 0.62
	diamond.radial_segments = 4
	diamond.rings = 1
	gem.mesh = diamond
	var gmat := _glow_material(Color(UIStyle.CYAN, 0.8), 1.6)
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gem.material_override = gmat
	var spin := ItemSpin.new()
	spin.name = "Cristal"
	spin.position.y = 1.4
	spin.add_child(gem)
	node.add_child(spin)
	var light := OmniLight3D.new()
	light.light_color = UIStyle.CYAN
	light.light_energy = 1.0
	light.omni_range = 3.2
	light.position.y = 1.4
	node.add_child(light)
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


## Enemigo de pie en la casilla, mirando siempre a la cámara: su modelo 3D si
## existe (EnemyModel), si no su retrato plano y, sin retrato, una cápsula.
## Las voladoras (CharacterDB.hover) flotan y dejan una sombra en el suelo.
static func _enemy(c: Vector2i, enemy_id: String) -> Node3D:
	var node := Node3D.new()
	node.name = "%d,%d" % [c.x, c.y]
	node.position = cell_center(c)
	var model := EnemyModel.create(enemy_id)
	var tex := CharacterDB.portrait(enemy_id)
	if model != null:
		node.add_child(model)
	elif tex != null:
		var sprite := Sprite3D.new()
		sprite.texture = tex
		sprite.pixel_size = ENEMY_H / tex.get_height()
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.position.y = ENEMY_H * 0.5 + CharacterDB.hover(enemy_id)
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
		body.position.y = ENEMY_H * 0.5 + CharacterDB.hover(enemy_id)
		node.add_child(body)
	if CharacterDB.hover(enemy_id) > 0.0:
		node.add_child(_hover_shadow())
	return node


## Mancha oscura y difusa en el suelo bajo una criatura que vuela.
static func _hover_shadow() -> MeshInstance3D:
	var shadow := MeshInstance3D.new()
	shadow.name = "Sombra"
	var quad := PlaneMesh.new()
	quad.size = Vector2(1.3, 1.3)
	shadow.mesh = quad
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.55))
	g.set_color(1, Color(0, 0, 0, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	shadow.material_override = m
	shadow.position.y = 0.02
	return shadow


## Una cara de pared del borde `d` de la casilla `c`, mirando hacia dentro de `c`.
## Con puerta, deja el hueco (dos laterales y el dintel).
## Cara del muro del borde `d` vista desde la casilla `c`: metida medio grosor en
## la casilla y sin los extremos (los cubren los pilares de `_posts`). Con puerta,
## deja el hueco y pone su mitad de jambas y dintel.
static func _wall_face(st: SurfaceTool, c: Vector2i, d: int, with_door: bool) -> void:
	var t := tile()
	var h := wall_h()
	var k := WALL_THICK * 0.5
	var center := cell_center(c)
	var out := Vector3(DungeonMap.DIRS[d].x, 0, DungeonMap.DIRS[d].y)   # hacia el borde
	var n := -out                                                    # normal: hacia la casilla
	var right := out.cross(Vector3.UP)                               # derecha vista de frente
	var line := center + out * t * 0.5                               # eje del muro
	var mid := line - out * k                                        # su cara
	var wall_uv := func(p: Vector3) -> Vector2: return Vector2(p.dot(right) / t, 1.0 - p.y / h)
	var a0 := -t * 0.5 + k
	var a1 := t * 0.5 - k
	var spans := [[a0, a1, 0.0, h]]
	if with_door:
		var hw := DOOR_W * 0.5
		spans = [[a0, -hw, 0.0, h], [hw, a1, 0.0, h], [-hw, hw, DOOR_H, h]]
		# Jambas y dintel: del eje del muro hasta la cara, por este lado.
		var depth_uv := func(p: Vector3) -> Vector2: return Vector2(p.dot(out) / t, 1.0 - p.y / h)
		for side: float in [-1.0, 1.0]:
			var x := right * hw * side
			_quad(st, [line + x, mid + x, mid + x + Vector3.UP * DOOR_H, line + x + Vector3.UP * DOOR_H],
					right * -side, depth_uv)
		var top := Vector3.UP * DOOR_H
		_quad(st, [line - right * hw + top, line + right * hw + top, mid + right * hw + top, mid - right * hw + top],
				Vector3.DOWN, func(p: Vector3) -> Vector2: return Vector2(p.dot(right) / t, p.dot(out) / t))
	for s: Array in spans:
		var a: Vector3 = mid + right * s[0] + Vector3.UP * s[2]
		var b: Vector3 = mid + right * s[1] + Vector3.UP * s[2]
		var cc: Vector3 = mid + right * s[1] + Vector3.UP * s[3]
		var dd: Vector3 = mid + right * s[0] + Vector3.UP * s[3]
		_quad(st, [a, b, cc, dd], n, wall_uv)


## Pilares de las esquinas: en cada vértice de la cuadrícula al que llega algún
## muro o puerta, un prisma de WALL_THICK de lado. Solo se dibujan sus caras libres
## (las que no tapan un muro) y que dan a alguna casilla: así se cierran los
## extremos de los tabiques y las esquinas.
static func _posts(map: DungeonMap, st: SurfaceTool) -> void:
	var t := tile()
	var h := wall_h()
	var k := WALL_THICK * 0.5
	var attached := {}   # vértice -> máscara de direcciones con muro
	# Extremos de cada borde: [vértice, dirección del muro desde él] por lado de la casilla.
	var ends := [
		[[Vector2i(0, 0), DungeonMap.E], [Vector2i(1, 0), DungeonMap.W]],   # N
		[[Vector2i(1, 0), DungeonMap.S], [Vector2i(1, 1), DungeonMap.N]],   # E
		[[Vector2i(0, 1), DungeonMap.E], [Vector2i(1, 1), DungeonMap.W]],   # S
		[[Vector2i(0, 0), DungeonMap.S], [Vector2i(0, 1), DungeonMap.N]],   # W
	]
	for c: Vector2i in map.cells:
		for d in 4:
			var type := map.edge_type(c, d)
			if type == DungeonMap.OPEN or type == DungeonMap.NONE:
				continue
			# La pared falsa no cuenta: al hundirse, el pilar cierra la esquina.
			if type == DungeonMap.DOOR and map.is_secret(DungeonMap.edge_key(c, d)):
				continue
			for e: Array in ends[d]:
				var v: Vector2i = c + e[0]
				attached[v] = attached.get(v, 0) | (1 << int(e[1]))
	# Casillas a los dos lados del medio borde que sale de un vértice hacia cada dirección.
	var sides := [
		[Vector2i(0, -1), Vector2i(-1, -1)],   # N
		[Vector2i(0, 0), Vector2i(0, -1)],     # E
		[Vector2i(0, 0), Vector2i(-1, 0)],     # S
		[Vector2i(-1, 0), Vector2i(-1, -1)],   # W
	]
	for v: Vector2i in attached:
		var base := Vector3(v.x * t, 0.0, v.y * t)
		for d in 4:
			if attached[v] & (1 << d):
				continue
			if not (map.has_cell(v + sides[d][0]) or map.has_cell(v + sides[d][1])):
				continue
			var n := Vector3(DungeonMap.DIRS[d].x, 0, DungeonMap.DIRS[d].y)
			var across := n.cross(Vector3.UP)
			var mid := base + n * k
			_quad(st, [mid - across * k, mid + across * k, mid + across * k + Vector3.UP * h, mid - across * k + Vector3.UP * h],
					n, func(p: Vector3) -> Vector2: return Vector2(p.dot(across) / t, 1.0 - p.y / h))


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
		var st: SurfaceTool = groups[tex]
		st.generate_tangents()   # para el relieve (parallax y normal map)
		mi.mesh = st.commit()
		mi.material_override = material(tex)
		node.add_child(mi)
	return node


## Filtrado de las texturas de suelo, techo y paredes (lo cambia el estilo
## visual de la mazmorra, DungeonLook).
static var texture_filter := BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC


## Material de una textura; si tiene relieve (DungeonTextures.relief_for), con
## parallax y normal map.
static func material(tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 0.95
	m.texture_filter = texture_filter
	var relief := DungeonTextures.relief_for(tex)
	if not relief.is_empty():
		apply_relief(m, relief)
	return m


static func apply_relief(m: StandardMaterial3D, relief: Dictionary) -> void:
	m.heightmap_enabled = true
	m.heightmap_texture = relief.height
	m.heightmap_scale = relief.depth
	m.heightmap_deep_parallax = true
	m.heightmap_min_layers = 8
	m.heightmap_max_layers = 24
	m.normal_enabled = true
	m.normal_texture = relief.normal
	m.normal_scale = 1.0


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
	var hw := DOOR_W * 0.5
	var leaves := Node3D.new()
	leaves.name = "Hoja"
	node.add_child(leaves)
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = DOOR_COLOR
	core_mat.roughness = 0.6
	for i in 2:
		var leaf := Node3D.new()
		leaf.name = "Izq" if i == 0 else "Der"
		leaf.position = Vector3(_leaf_x(i, open), DOOR_H * 0.5, 0.0)
		var core := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(hw, DOOR_H, DOOR_THICK)
		core.mesh = box
		core.material_override = core_mat
		leaf.add_child(core)
		# Cara de delante (+Z) y de detrás: por detrás esta hoja queda al otro
		# lado, así que lleva la imagen de la otra.
		for face in 2:
			var q := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(hw, DOOR_H)
			q.mesh = qm
			q.material_override = _door_mat(DOOR_LEAF_TEX[i if face == 0 else 1 - i])
			q.position.z = (DOOR_THICK * 0.5 + 0.002) * (1.0 if face == 0 else -1.0)
			q.rotation.y = 0.0 if face == 0 else PI
			leaf.add_child(q)
		leaves.add_child(leaf)
	# El vano, invisible: da el recuadro del objetivo abierta o cerrada.
	var gap := MeshInstance3D.new()
	gap.name = "Hueco"
	var gm := QuadMesh.new()
	gm.size = Vector2(DOOR_W, DOOR_H)
	gap.mesh = gm
	var clear := StandardMaterial3D.new()
	clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	clear.albedo_color = Color(0, 0, 0, 0)
	clear.cull_mode = BaseMaterial3D.CULL_DISABLED
	gap.material_override = clear
	gap.position.y = DOOR_H * 0.5
	node.add_child(gap)
	# Consolas, una por cara, a la derecha de quien mira, y luz sobre el dintel.
	for face in 2:
		var sgn := 1.0 if face == 0 else -1.0
		var pad := Node3D.new()
		pad.name = "Consola" + ("A" if face == 0 else "B")
		pad.position = Vector3(sgn * PAD_X, PAD_Y, sgn * (WALL_THICK * 0.5 + 0.015))
		pad.rotation.y = 0.0 if face == 0 else PI
		var plate := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(PAD_SIZE.x, PAD_SIZE.y, 0.03)
		plate.mesh = pb
		plate.material_override = core_mat
		pad.add_child(plate)
		var front := MeshInstance3D.new()
		var fm := QuadMesh.new()
		fm.size = PAD_SIZE
		front.mesh = fm
		front.material_override = _door_mat(DOOR_PAD_TEX)
		front.position.z = 0.016
		pad.add_child(front)
		# Pantalla: encima de la de la imagen, con su color y su texto.
		var px := PAD_SIZE.x / 160.0
		var screen := MeshInstance3D.new()
		screen.name = "Pantalla"
		var sm := QuadMesh.new()
		sm.size = SCREEN_RECT.size * px
		screen.mesh = sm
		screen.position = Vector3((SCREEN_RECT.get_center().x - 80.0) * px, (116.0 - SCREEN_RECT.get_center().y) * px, 0.018)
		pad.add_child(screen)
		var text := Label3D.new()
		text.name = "Texto"
		text.font = UIStyle.FONT_SEMIBOLD
		text.font_size = 48
		text.pixel_size = 0.00038
		text.outline_size = 0
		text.position = screen.position + Vector3(0, 0, 0.002)
		pad.add_child(text)
		node.add_child(pad)
		var lamp := MeshInstance3D.new()
		lamp.name = "Luz" + ("A" if face == 0 else "B")
		var lb := BoxMesh.new()
		lb.size = Vector3(0.26, 0.05, 0.03)
		lamp.mesh = lb
		lamp.position = Vector3(0.0, DOOR_H + 0.14, sgn * (WALL_THICK * 0.5 + 0.015))
		node.add_child(lamp)
	return node


## Posición X de la hoja `i` (0 izquierda, 1 derecha): juntas en el centro o
## metidas en el muro.
static func _leaf_x(i: int, open: bool) -> float:
	var sgn := -1.0 if i == 0 else 1.0
	return sgn * DOOR_W * (0.75 if open else 0.25)


static var _door_mats := {}

static func _door_mat(path: String) -> StandardMaterial3D:
	if not _door_mats.has(path):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(path)
		m.roughness = 0.75
		m.metallic = 0.3
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_door_mats[path] = m
	return _door_mats[path]


## Pantallas y luz de una puerta de seguridad: verde si se puede pasar, roja si no.
static func set_door_lock(door_node: Node3D, can_pass: bool) -> void:
	var col := LOCK_GREEN if can_pass else LOCK_RED
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col.darkened(0.72)
	var lamp_m := StandardMaterial3D.new()
	lamp_m.albedo_color = col
	lamp_m.emission_enabled = true
	lamp_m.emission = col
	lamp_m.emission_energy_multiplier = 1.6
	for face in ["A", "B"]:
		var pad := door_node.get_node_or_null("Consola" + face)
		if pad == null:
			return
		(pad.get_node("Pantalla") as MeshInstance3D).material_override = m
		var text: Label3D = pad.get_node("Texto")
		text.text = "> ACCESO" if can_pass else "> BLOQUEADA"
		text.modulate = col
		(door_node.get_node("Luz" + face) as MeshInstance3D).material_override = lamp_m


## Punto de luz de una casilla (DungeonMap.lights): una OmniLight3D sin sombras
## y una bombilla pequeña que brilla con su color.
static func light_point(c: Vector2i, data: Dictionary) -> Node3D:
	var node := Node3D.new()
	node.name = "%d,%d" % [c.x, c.y]
	node.position = cell_center(c) + Vector3.UP * float(data.get("height", 2.2))
	var col := Color(String(data.get("color", "ffc98a")))
	var omni := OmniLight3D.new()
	omni.name = "Luz"
	omni.light_color = col
	omni.light_energy = float(data.get("energy", 1.5))
	omni.omni_range = float(data.get("range", 5.0))
	omni.omni_attenuation = float(data.get("decay", 1.0))
	omni.shadow_enabled = false
	node.add_child(omni)
	var bulb := MeshInstance3D.new()
	bulb.name = "Bombilla"
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	sm.radial_segments = 12
	sm.rings = 6
	bulb.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col.lerp(Color.WHITE, 0.4)
	bulb.material_override = m
	node.add_child(bulb)
	return node


## Puerta secreta: un tramo de pared entero, con las texturas de sus dos caras,
## que se hunde en el suelo al descubrirlo.
static func _secret_door(map: DungeonMap, key: String, open: bool) -> Node3D:
	var node := Node3D.new()
	node.name = key
	node.set_meta("key", key)
	node.set_meta("secret", true)
	var cs := DungeonMap.key_cells(key)
	var d := DungeonMap.N if key.ends_with("N") else DungeonMap.W
	var groups := {}
	for side: Array in [[cs[0], d], [cs[1], (d + 2) % 4]]:
		var tex := DungeonTextures.resolve(map.theme, "wall", map.face_texture(side[0], side[1]))
		_wall_face(_st(groups, tex), side[0], side[1], false)
	var leaf := _meshes(groups)
	leaf.name = "Hoja"
	leaf.position.y = -wall_h() if open else 0.0
	node.add_child(leaf)
	return node


## Mueve la hoja de una puerta (las de seguridad se separan desde el centro; la
## pared falsa se hunde).
static func set_door_open(door_node: Node3D, open: bool, animate: bool = true) -> Tween:
	var leaf: Node3D = door_node.get_node("Hoja")
	if not door_node.has_meta("secret"):
		# Puerta de seguridad: las dos hojas se separan desde el centro.
		if not animate:
			for i in 2:
				(leaf.get_child(i) as Node3D).position.x = _leaf_x(i, open)
			return null
		var dt := door_node.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		for i in 2:
			dt.tween_property(leaf.get_child(i), "position:x", _leaf_x(i, open), 0.6)
		return dt
	var y := -wall_h() if open else 0.0
	if not animate:
		leaf.position.y = y
		return null
	var tw := door_node.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(leaf, "position:y", y, 1.1)
	return tw
