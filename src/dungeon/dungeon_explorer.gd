class_name DungeonExplorer
extends Node3D
## Exploración en primera persona de un DungeonMap: casillas y giros de 90°.
##
## No lee el teclado: quien lo usa llama a `act()` (el editor en «Probar mapa» y
## la pantalla de mazmorra del juego). Si llega una acción mientras se anima
## otra, se guarda una en cola.
##
## Acciones: forward, back, left, right (girar), strafe_left, strafe_right, interact.
##
## Interacción: solo con lo que hay justo delante (`front()`): la puerta del
## borde de delante o la cosa de la casilla de delante (enemigo, objeto,
## interruptor). Escaleras: al entrar en su casilla se pasa a la otra planta.
## Enemigos: al chocar con uno (o interactuar) se emite `encounter`; quien lo usa
## lanza el combate y, si se gana, llama a `defeat()`.
##
## Estado de la partida (`state`, se puede guardar tal cual en JSON):
##   doors     planta -> {clave de borde: abierta}
##   defeated  "planta|x,y" -> true
##   taken     "planta|x,y" -> true
##   visited   planta -> {"x,y": true}   (para el automapa)
##   detected  "planta|clave de borde" -> 1..5: paredes secretas que ha hecho
##             brillar el pulso del resonador (5 = detectada desde muy cerca)
##
## Resonador (`pulse()`): un anillo rosado sale de la cámara y recorre
## PULSE_RANGE casillas (efecto en pulse.gdshader, sobre toda la geometría de
## la planta). Las paredes secretas sin abrir a su alcance brillan más cuanto
## más cerca estaba el grupo y desde entonces se pueden inspeccionar. Las
## ocultas (`hidden`) solo así; las demás también al empujarlas a ciegas.
## (las plantas van como texto, para que sobrevivan al JSON).

signal message(text: String)
signal moved(cell: Vector2i, dir: int)
signal encounter(enemy_id: String, cell: Vector2i)
signal level_changed(level: int)
signal item_taken(item_id: String, count: int)
## Se ha cogido una caja (ya está en el inventario): la pantalla ofrece abrirla o guardarla.
signal box_found(item_id: String, count: int)
## Algo que el grupo puede comentar: "secret_found", "locked", "switch", "bump".
signal noticed(kind: String)
## Fin del pulso del resonador: cuántas paredes ha hecho brillar.
signal pulse_finished(found: int)
## El grupo usa un punto de guardado (lo resuelve quien usa el explorador).
signal save_point_used(cell: Vector2i)

const EYE_H := 1.55
const STEP_TIME := 0.2
const TURN_TIME := 0.16
const BUMP := 0.18
const PULSE_RANGE := 5            ## casillas
const PULSE_TIME := 1.8           ## s que tarda el frente en llegar al final
const PULSE_SHADER := preload("res://src/dungeon/pulse.gdshader")
const SECRET_GLOW := 0.5          ## brillo del borde de una pared detectada desde 1 casilla

var map: DungeonMap
var cell := Vector2i.ZERO
var dir := DungeonMap.N
var state: Dictionary = {}
## Puertas de la planta actual: clave del borde -> abierta.
var open_doors: Dictionary = {}

var _camera: Camera3D
var _lights_cell := Vector2i(1 << 30, 0)   ## casilla con la que se eligieron las luces encendidas
## Entorno de la vista (niebla, brillo): lo ajusta el estilo visual (DungeonLook).
var environment: Environment
var _model: Node3D
var _yaw := 0.0
var _busy := false
var _queued := ""
var _pulse_mat: ShaderMaterial      ## capa del pulso sobre la planta
var _secret_mats := {}              ## clave de pared secreta -> su capa (pulso + brillo)
var _pulse_t := -1.0                ## s desde que empezó el pulso (-1 = ninguno)
var _pulse_pending := {}            ## clave -> {dist (m), level} aún no alcanzadas
var _pulse_found := 0


## `state` vacío = partida nueva en este mapa. `at` = {level, cell, dir} para
## no empezar en el inicio del mapa.
func setup(dungeon: DungeonMap, game_state: Dictionary = {}, at: Dictionary = {}) -> void:
	map = dungeon
	state = game_state
	for k in ["doors", "defeated", "taken", "visited", "detected"]:
		if not state.has(k):
			state[k] = {}
	for ch in get_children():
		ch.queue_free()
	_model = null
	map.set_level(at.get("level", map.start_level))
	_build_level()

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = UIStyle.INK
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("5a5f8a")
	e.ambient_light_energy = 0.35
	e.fog_enabled = true
	e.fog_light_color = UIStyle.INK
	e.fog_density = 0.09
	env.environment = e
	environment = e
	add_child(env)

	_camera = Camera3D.new()
	_camera.fov = 72
	_camera.near = 0.05
	add_child(_camera)
	# Luz del grupo (linterna o móvil): va con la cámara.
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("fff1dc")
	lamp.light_energy = 1.6
	lamp.omni_range = 11.0
	lamp.omni_attenuation = 1.2
	lamp.position = Vector3(0.25, -0.2, 0.1)
	_camera.add_child(lamp)

	place(at.get("cell", map.start), at.get("dir", map.start_dir))


func _lk() -> String:
	return str(map.level)


func _ck(c: Vector2i) -> String:
	return "%s|%d,%d" % [_lk(), c.x, c.y]


## (Re)construye la planta activa con el estado de sus puertas, enemigos y objetos.
func _build_level() -> void:
	if _model:
		_model.queue_free()
	if not state.doors.has(_lk()):
		state.doors[_lk()] = {}
	open_doors = state.doors[_lk()]
	_model = DungeonBuilder.build(map)
	add_child(_model)
	for door: Node3D in _model.get_node("Puertas").get_children():
		var k: String = door.get_meta("key")
		if open_doors.has(k):
			DungeonBuilder.set_door_open(door, open_doors[k], false)
	update_door_locks()
	_lights_cell = Vector2i(1 << 30, 0)
	for enemy: Node3D in _model.get_node("Enemigos").get_children():
		enemy.visible = not state.defeated.has("%s|%s" % [_lk(), enemy.name])
	for item: Node3D in _model.get_node("Objetos").get_children():
		item.visible = not state.taken.has("%s|%s" % [_lk(), item.name])
	for sw: Node3D in _model.get_node("Interruptores").get_children():
		var doors: Array = map.thing(_cell_of(sw.name)).get("doors", [])
		if not doors.is_empty():
			DungeonBuilder.set_switch_on(sw, door_open(doors[0]), false)
	_setup_pulse_layer()


# --- Resonador -------------------------------------------------------------------------------

## Pone la capa del pulso a la geometría de la planta (no a criaturas ni objetos).
## Las paredes secretas llevan su propia copia, para poder brillar solas.
func _setup_pulse_layer() -> void:
	_pulse_mat = ShaderMaterial.new()
	_pulse_mat.shader = PULSE_SHADER
	_pulse_mat.set_shader_parameter("max_radius", PULSE_RANGE * DungeonBuilder.tile())
	_secret_mats.clear()
	_pulse_t = -1.0
	for child in _model.get_children():
		if child.name in ["Enemigos", "Objetos", "Extraccion", "Puertas", "Luces"]:
			continue
		for mi: MeshInstance3D in child.find_children("*", "MeshInstance3D", true, false) + ([child] if child is MeshInstance3D else []):
			mi.material_overlay = _pulse_mat
	for door: Node3D in _model.get_node("Puertas").get_children():
		var k: String = door.get_meta("key")
		var mat := _pulse_mat
		if door.has_meta("secret"):
			mat = _pulse_mat.duplicate()
			_secret_mats[k] = mat
			mat.set_shader_parameter("glow", _glow_for(detection(k)) if not door_open(k) else 0.0)
			# Caja de la pared cerrada, para que brille por los bordes.
			var box := _local_aabb(door.get_node("Hoja"))
			box.position.y = 0.0
			box.position += door.position
			mat.set_shader_parameter("box_center", box.get_center())
			mat.set_shader_parameter("box_half", box.size * 0.5)
			mat.set_shader_parameter("box_axes", Vector3(0, 1, 1) if k.ends_with("W") else Vector3(1, 1, 0))
		for mi: MeshInstance3D in door.find_children("*", "MeshInstance3D", true, false):
			if mi.name != "Hueco":
				mi.material_overlay = mat


## Caja de las mallas de `node` en el espacio de su padre (sin animación de apertura).
static func _local_aabb(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = mi.transform * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


## Más brillo cuanto más cerca (nivel 5); el nivel 1 sigue viéndose.
static func _glow_for(level: int) -> float:
	if level <= 0:
		return 0.0
	return SECRET_GLOW * (0.3 + 0.7 * level / float(PULSE_RANGE))


## 1..5 si el pulso ha hecho brillar la pared secreta `key` de esta planta (0 = no).
func detection(key: String) -> int:
	return int(state.detected.get("%s|%s" % [_lk(), key], 0))


func is_pulsing() -> bool:
	return _pulse_t >= 0.0


## Lanza el pulso desde la posición del grupo. Al acabar emite `pulse_finished`.
func pulse() -> void:
	if is_pulsing() or _pulse_mat == null:
		return
	var origin := _camera.global_position
	_pulse_t = 0.0
	_pulse_found = 0
	_pulse_pending.clear()
	# Distancia (en casillas) del centro de la casilla al centro de cada pared secreta.
	for k: String in _secret_mats:
		if door_open(k):
			continue
		var cs := DungeonMap.key_cells(k)
		var mid := (DungeonBuilder.cell_center(cs[0]) + DungeonBuilder.cell_center(cs[1])) * 0.5
		var dist := Vector2(mid.x - origin.x, mid.z - origin.z).length()
		var cells := dist / DungeonBuilder.tile()
		var level := PULSE_RANGE + 1 - ceili(cells - 0.001)
		if level >= 1:
			_pulse_pending[k] = {"dist": dist, "level": mini(level, PULSE_RANGE)}
	for m: ShaderMaterial in [_pulse_mat] + _secret_mats.values():
		m.set_shader_parameter("origin", origin)


## Luces del mapa encendidas a la vez (las más cercanas): en GL Compatibility cada
## malla recibe como mucho 8 luces (project.godot, max_lights_per_object), y la
## planta va en pocas mallas grandes; la linterna del grupo es una más.
const MAX_MAP_LIGHTS := 6


## Enciende solo las MAX_MAP_LIGHTS luces del mapa más cercanas que lleguen a la casilla.
func _update_lights() -> void:
	_lights_cell = cell
	var holder := _model.get_node_or_null("Luces")
	if holder == null:
		return
	var here := DungeonBuilder.cell_center(cell)
	var near: Array = []
	for n: Node3D in holder.get_children():
		var omni: OmniLight3D = n.get_node("Luz")
		var dist := Vector2(n.position.x - here.x, n.position.z - here.z).length()
		omni.visible = false
		# Alcance más un margen: se ve el resplandor de las que hay al fondo del pasillo.
		if dist <= omni.omni_range + DungeonBuilder.tile() * 3.0:
			near.append([dist, omni])
	near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for i in mini(near.size(), MAX_MAP_LIGHTS):
		near[i][1].visible = true


func _process(delta: float) -> void:
	if _model and cell != _lights_cell:
		_update_lights()
	if _pulse_t < 0.0:
		return
	_pulse_t += delta
	var k_t := clampf(_pulse_t / PULSE_TIME, 0.0, 1.0)
	var radius := ease(k_t, 0.6) * PULSE_RANGE * DungeonBuilder.tile()
	var strength := 1.0 - k_t * k_t
	for m: ShaderMaterial in [_pulse_mat] + _secret_mats.values():
		m.set_shader_parameter("radius", radius)
		m.set_shader_parameter("strength", strength)
	# Al llegar el frente a una pared secreta: destello y se queda brillando.
	for k: String in _pulse_pending.keys():
		var p: Dictionary = _pulse_pending[k]
		if radius >= p.dist:
			_pulse_pending.erase(k)
			_reveal(k, p.level)
	if k_t >= 1.0:
		_pulse_t = -1.0
		for m: ShaderMaterial in [_pulse_mat] + _secret_mats.values():
			m.set_shader_parameter("strength", 0.0)
		pulse_finished.emit(_pulse_found)


func _reveal(k: String, level: int) -> void:
	_pulse_found += 1
	var key := "%s|%s" % [_lk(), k]
	state.detected[key] = maxi(detection(k), level)
	var mat: ShaderMaterial = _secret_mats[k]
	var final := _glow_for(detection(k))
	# Destello al llegar el pulso, que se queda en su brillo según la distancia.
	mat.set_shader_parameter("glow", final + 0.6)
	create_tween().tween_method(func(v: float) -> void: mat.set_shader_parameter("glow", v), final + 0.6, final, 1.2)


static func _cell_of(n: String) -> Vector2i:
	var p := n.split(",")
	return Vector2i(int(p[0]), int(p[1]))


## Paredes falsas sin descubrir alrededor de la casilla actual (claves de borde).
## Las ocultas no cuentan: esas solo las delata el resonador.
func secrets_near() -> Array[String]:
	var out: Array[String] = []
	for d in 4:
		var k := DungeonMap.edge_key(cell, d)
		if map.is_secret(k) and not map.is_hidden(k) and not door_open(k) and map.edge_type(cell, d) == DungeonMap.DOOR:
			out.append(k)
	return out


func door_open(key: String) -> bool:
	return open_doors.get(key, map.edges.get(key, {}).get("door", {}).get("open", false))


## Enemigo vivo en `c` (id) o "".
func enemy_at(c: Vector2i) -> String:
	var th := map.thing(c)
	if th.get("type", "") != DungeonMap.ENEMY or state.defeated.has(_ck(c)):
		return ""
	return th.enemy


func _item_at(c: Vector2i) -> Dictionary:
	var th := map.thing(c)
	if th.get("type", "") != DungeonMap.ITEM or state.taken.has(_ck(c)):
		return {}
	return th


## ¿Está el grupo en una zona de extracción segura (o en la entrada)?
func at_extraction() -> bool:
	return map != null and map.is_extraction(cell)


## Devuelve a su sitio los objetos cogidos (claves de `state.taken`) que no estén
## en `keep`: al salir sin extraer, lo conseguido se pierde y vuelve a la mazmorra.
func restore_items(keep: Dictionary) -> void:
	for k in state.taken.keys():
		if not keep.has(k):
			state.taken.erase(k)


## Devuelve a la vida las criaturas vencidas (fuera de `keep`) que soltaban algo:
## si lo soltado se pierde al salir sin extraer, hay que poder volver a ganarlo.
func restore_drops(keep: Dictionary) -> void:
	for k: String in state.defeated.keys():
		if keep.has(k):
			continue
		var parts := k.split("|")
		var lvl := int(parts[0])
		if lvl < 0 or lvl >= map.floors.size():
			continue
		var xy := parts[1].split(",")
		var th: Dictionary = map.floors[lvl].things.get(Vector2i(int(xy[0]), int(xy[1])), {})
		if th.get("drop", "") != "":
			state.defeated.erase(k)


## Lo que suelta la criatura de `c` al caer ("" = nada).
func drop_at(c: Vector2i) -> String:
	return map.thing(c).get("drop", "")


## ¿Algo en `c` impide entrar? (enemigo vivo, interruptor o punto de guardado)
func _blocked(c: Vector2i) -> bool:
	return enemy_at(c) != "" or map.thing(c).get("type", "") in [DungeonMap.SWITCH, DungeonMap.SAVE]


## Lo que hay justo delante y se puede usar: {kind (door, enemy, item, switch),
## cell, name, verb, node} o vacío.
func front() -> Dictionary:
	if map == null:
		return {}
	var ahead := cell + DungeonMap.DIRS[dir]
	# Una pared falsa no se distingue de las demás (ni cerrada ni ya abierta),
	# salvo que el resonador la haya hecho brillar.
	var front_key := DungeonMap.edge_key(cell, dir)
	if map.edge_type(cell, dir) == DungeonMap.DOOR and map.is_secret(front_key) \
			and not door_open(front_key) and detection(front_key) > 0:
		return {"kind": "secret", "cell": ahead, "key": front_key, "name": "Pared que resuena", "verb": "Inspeccionar",
				"node": _model.get_node("Puertas").get_node_or_null(front_key)}
	if map.edge_type(cell, dir) == DungeonMap.DOOR and not map.is_secret(DungeonMap.edge_key(cell, dir)):
		var k := DungeonMap.edge_key(cell, dir)
		var open := door_open(k)
		var door: Node3D = _model.get_node("Puertas").get_node_or_null(k)
		var t := {"kind": "door", "cell": ahead, "key": k, "name": "Puerta %s" % ("abierta" if open else "cerrada"),
				"verb": "Cerrar" if open else "Abrir", "node": door.get_node("Hueco") if door else null}
		# La consola de este lado (la más cercana): se puede señalar aparte.
		if door:
			var here := DungeonBuilder.cell_center(cell)
			var pads: Array = [door.get_node("ConsolaA"), door.get_node("ConsolaB")]
			pads.sort_custom(func(p: Node3D, q: Node3D) -> bool:
				return p.global_position.distance_to(here) < q.global_position.distance_to(here))
			t.console = pads[0]
		return t
	if not map.can_cross(cell, dir, open_doors):
		return {}
	var nk := "%d,%d" % [ahead.x, ahead.y]
	var foe := enemy_at(ahead)
	if foe != "":
		return {"kind": "enemy", "cell": ahead, "enemy": foe, "name": CharacterDB.display_name(foe), "verb": "Luchar",
				"node": _model.get_node("Enemigos").get_node_or_null(nk)}
	var item := _item_at(ahead)
	if not item.is_empty():
		var n: int = item.get("count", 1)
		var iname: String = ItemDB.get_item(item.item).get("name", item.item)
		return {"kind": "item", "cell": ahead, "name": iname + (" ×%d" % n if n > 1 else ""), "verb": "Coger",
				"node": _model.get_node("Objetos").get_node_or_null(nk)}
	if map.thing(ahead).get("type", "") == DungeonMap.SWITCH:
		return {"kind": "switch", "cell": ahead, "name": "Palanca", "verb": "Accionar",
				"node": _model.get_node("Interruptores").get_node_or_null(nk)}
	if map.thing(ahead).get("type", "") == DungeonMap.SAVE:
		return {"kind": "save", "cell": ahead, "name": "Punto de guardado", "verb": "Guardar",
				"node": _model.get_node("Guardado").get_node_or_null(nk)}
	return {}


## Rectángulo en pantalla (coordenadas del viewport 3D) de lo que hay delante.
func front_rect(target: Dictionary) -> Rect2:
	var node: Node3D = target.get("node")
	if node == null or not is_instance_valid(node):
		return Rect2()
	var out := Rect2()
	var first := true
	for vi in node.find_children("*", "VisualInstance3D", true, false) + ([node] if node is VisualInstance3D else []):
		var v := vi as VisualInstance3D
		if not v.is_visible_in_tree():
			continue
		var box := v.global_transform * v.get_aabb()
		for i in 8:
			var p := box.get_endpoint(i)
			if _camera.is_position_behind(p):
				continue
			var sp := _camera.unproject_position(p)
			if first:
				out = Rect2(sp, Vector2.ZERO)
				first = false
			else:
				out = out.expand(sp)
	return out


## Marca como vencido el enemigo de `c` y lo hace desaparecer.
func defeat(c: Vector2i) -> void:
	state.defeated[_ck(c)] = true
	var node: Node3D = _model.get_node("Enemigos").get_node_or_null("%d,%d" % [c.x, c.y])
	if node:
		var tw := create_tween()
		tw.tween_property(node, "scale", Vector3(1.0, 0.01, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(node.hide)


func place(at: Vector2i, facing: int) -> void:
	cell = at
	dir = facing
	_yaw = DungeonBuilder.dir_yaw(dir)
	_camera.position = DungeonBuilder.cell_center(cell) + Vector3.UP * EYE_H
	_camera.rotation = Vector3(0, _yaw, 0)
	_busy = false
	_queued = ""
	_visit()
	moved.emit(cell, dir)


func _visit() -> void:
	if not state.visited.has(_lk()):
		state.visited[_lk()] = {}
	state.visited[_lk()]["%d,%d" % [cell.x, cell.y]] = true


func is_visited(level: int, c: Vector2i) -> bool:
	return state.visited.get(str(level), {}).has("%d,%d" % [c.x, c.y])


func camera() -> Camera3D:
	return _camera


func is_busy() -> bool:
	return _busy


func act(action: String) -> void:
	if _busy:
		_queued = action
		return
	_busy = true
	match action:
		"forward": await _step(dir)
		"back": await _step((dir + 2) % 4)
		"strafe_left": await _step((dir + 3) % 4)
		"strafe_right": await _step((dir + 1) % 4)
		"left": await _turn(-1)
		"right": await _turn(1)
		"interact": await _interact()
	_busy = false
	if _queued != "":
		var next := _queued
		_queued = ""
		act(next)


func _step(d: int) -> void:
	var from := _camera.position
	var offset := Vector3(DungeonMap.DIRS[d].x, 0, DungeonMap.DIRS[d].y)
	var target := cell + DungeonMap.DIRS[d]
	var can := map.can_cross(cell, d, open_doors)
	if not can or _blocked(target):
		# Choque: se acerca un poco y vuelve, para que se note la pulsación.
		var tw := create_tween().set_trans(Tween.TRANS_QUAD)
		tw.tween_property(_camera, "position", from + offset * BUMP, STEP_TIME * 0.4).set_ease(Tween.EASE_OUT)
		tw.tween_property(_camera, "position", from, STEP_TIME * 0.5).set_ease(Tween.EASE_IN)
		await tw.finished
		if can and enemy_at(target) != "":
			encounter.emit(enemy_at(target), target)
		return
	cell = target
	var exit := map.stairs_exit(cell)
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var to := DungeonBuilder.cell_center(cell) + Vector3.UP * EYE_H
	if not exit.is_empty():
		to += Vector3.UP * (1.0 if map.thing(cell).up else -1.0)
	tw.tween_property(_camera, "position", to, STEP_TIME * (2.0 if not exit.is_empty() else 1.0))
	await tw.finished
	if not exit.is_empty():
		_change_level(exit)
		return
	_visit()
	moved.emit(cell, dir)


## Pasa a la otra planta por una escalera.
func _change_level(exit: Dictionary) -> void:
	var up: bool = exit.level > map.level
	map.set_level(exit.level)
	_build_level()
	place(exit.cell, exit.dir)
	level_changed.emit(map.level)
	message.emit("%s · %s" % ["Subes" if up else "Bajas", map.level_name()])


func _turn(turn_dir: int) -> void:
	dir = (dir + turn_dir + 4) % 4
	_yaw -= turn_dir * PI * 0.5
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_camera, "rotation:y", _yaw, TURN_TIME)
	await tw.finished
	moved.emit(cell, dir)


## Usa lo que hay delante: abre o cierra la puerta, lucha, coge o acciona.
func _interact() -> void:
	var t := front()
	match t.get("kind", ""):
		"door":
			await _use_door(t.key)
		"enemy":
			encounter.emit(t.enemy, t.cell)
		"item":
			var th := map.thing(t.cell)
			var n: int = th.get("count", 1)
			state.taken[_ck(t.cell)] = true
			if ItemDB.is_box(th.item):
				# Caja: va al inventario; la pantalla pregunta si se abre ya o se guarda.
				GameState.add_item(th.item, n)
				item_taken.emit(th.item, n)
				box_found.emit(th.item, n)
			else:
				GameState.add_item(th.item, n)
				item_taken.emit(th.item, n)
				message.emit("Coges: %s" % t.name)
				update_door_locks()   # una tarjeta pone en verde sus puertas
			var node: Node3D = t.node
			if node:
				var tw := create_tween().set_parallel(true)
				tw.tween_property(node, "position:y", node.position.y + 0.6, 0.3)
				tw.tween_property(node, "scale", Vector3.ONE * 0.01, 0.3)
				await tw.finished
				node.hide()
		"switch":
			await _use_switch(t.cell, t.node)
		"save":
			save_point_used.emit(t.cell)
		"secret":
			message.emit("Inspeccionas la pared: suena hueca. La empujas… y cede. ¡Un pasadizo oculto!")
			noticed.emit("secret_found")
			await _open_secret(t.key)
		_:
			var k := DungeonMap.edge_key(cell, dir)
			if map.is_secret(k) and not map.is_hidden(k) and not door_open(k):
				message.emit("Empujas la pared… y cede. ¡Un pasadizo oculto!")
				noticed.emit("secret_found")
				await _open_secret(k)
			else:
				message.emit("No hay nada delante.")


func _open_secret(k: String) -> void:
	if _secret_mats.has(k):
		var mat: ShaderMaterial = _secret_mats[k]
		create_tween().tween_method(func(v: float) -> void: mat.set_shader_parameter("glow", v),
				float(mat.get_shader_parameter("glow")), 0.0, 0.5)
	await _set_door(k, true)


func _use_door(k: String) -> void:
	var cs := DungeonMap.key_cells(k)
	var info := map.door(cs[0], DungeonMap.N if k.ends_with("N") else DungeonMap.W)
	var is_open := door_open(k)
	var req: String = info.get("requires", "")
	if not is_open and req != "" and GameState.item_count(req) <= 0:
		message.emit("Está cerrada. Hace falta: %s" % ItemDB.get_item(req).get("name", req))
		noticed.emit("locked")
		return
	if not is_open and info.get("switch_only", false):
		message.emit("No se abre a mano. Habrá algún mecanismo.")
		noticed.emit("locked")
		return
	await _set_door(k, not is_open)


## Pone en verde o rojo las consolas de las puertas de seguridad de la planta:
## verde si está abierta o se puede abrir ya (sin tarjeta que falte ni mecanismo).
func update_door_locks() -> void:
	if _model == null:
		return
	for door: Node3D in _model.get_node("Puertas").get_children():
		if door.has_meta("secret"):
			continue
		var k: String = door.get_meta("key")
		var info: Dictionary = map.edges.get(k, {}).get("door", {})
		var req: String = info.get("requires", "")
		DungeonBuilder.set_door_lock(door, door_open(k) or (not info.get("switch_only", false)
				and (req == "" or GameState.item_count(req) > 0)))


func _set_door(k: String, open: bool) -> void:
	open_doors[k] = open
	update_door_locks()
	var node: Node3D = _model.get_node("Puertas").get_node_or_null(k)
	if node:
		await DungeonBuilder.set_door_open(node, open).finished


func _use_switch(c: Vector2i, node: Node3D) -> void:
	var doors: Array = []
	for k: String in map.thing(c).get("doors", []):
		if map.edges.get(k, {}).get("type", "") == DungeonMap.DOOR:
			doors.append(k)
	if doors.is_empty():
		if node:
			DungeonBuilder.set_switch_on(node, true)
		message.emit("La palanca baja con un chasquido. No pasa nada.")
		return
	var open := not door_open(doors[0])
	if node:
		DungeonBuilder.set_switch_on(node, open)
	message.emit("Se oye un mecanismo: %s." % ("algo se abre" if open else "algo se cierra"))
	noticed.emit("switch")
	for k: String in doors:
		_set_door(k, open)
	await get_tree().create_timer(0.45).timeout
