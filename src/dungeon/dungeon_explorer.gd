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
## (las plantas van como texto, para que sobrevivan al JSON).

signal message(text: String)
signal moved(cell: Vector2i, dir: int)
signal encounter(enemy_id: String, cell: Vector2i)
signal level_changed(level: int)
signal item_taken(item_id: String, count: int)

const EYE_H := 1.55
const STEP_TIME := 0.2
const TURN_TIME := 0.16
const BUMP := 0.18

var map: DungeonMap
var cell := Vector2i.ZERO
var dir := DungeonMap.N
var state: Dictionary = {}
## Puertas de la planta actual: clave del borde -> abierta.
var open_doors: Dictionary = {}

var _camera: Camera3D
var _model: Node3D
var _yaw := 0.0
var _busy := false
var _queued := ""


## `state` vacío = partida nueva en este mapa. `at` = {level, cell, dir} para
## no empezar en el inicio del mapa.
func setup(dungeon: DungeonMap, game_state: Dictionary = {}, at: Dictionary = {}) -> void:
	map = dungeon
	state = game_state
	for k in ["doors", "defeated", "taken", "visited"]:
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
	for enemy: Node3D in _model.get_node("Enemigos").get_children():
		enemy.visible = not state.defeated.has("%s|%s" % [_lk(), enemy.name])
	for item: Node3D in _model.get_node("Objetos").get_children():
		item.visible = not state.taken.has("%s|%s" % [_lk(), item.name])
	for sw: Node3D in _model.get_node("Interruptores").get_children():
		var doors: Array = map.thing(_cell_of(sw.name)).get("doors", [])
		if not doors.is_empty():
			DungeonBuilder.set_switch_on(sw, door_open(doors[0]), false)


static func _cell_of(n: String) -> Vector2i:
	var p := n.split(",")
	return Vector2i(int(p[0]), int(p[1]))


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


## ¿Algo en `c` impide entrar? (enemigo vivo o interruptor)
func _blocked(c: Vector2i) -> bool:
	return enemy_at(c) != "" or map.thing(c).get("type", "") == DungeonMap.SWITCH


## Lo que hay justo delante y se puede usar: {kind (door, enemy, item, switch),
## cell, name, verb, node} o vacío.
func front() -> Dictionary:
	if map == null:
		return {}
	var ahead := cell + DungeonMap.DIRS[dir]
	if map.edge_type(cell, dir) == DungeonMap.DOOR:
		var k := DungeonMap.edge_key(cell, dir)
		var open := door_open(k)
		return {"kind": "door", "cell": ahead, "key": k, "name": "Puerta %s" % ("abierta" if open else "cerrada"),
				"verb": "Cerrar" if open else "Abrir", "node": _model.get_node("Puertas").get_node_or_null(k)}
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
	return {}


## Rectángulo en pantalla (coordenadas del viewport 3D) de lo que hay delante.
func front_rect(target: Dictionary) -> Rect2:
	var node: Node3D = target.get("node")
	if node == null or not is_instance_valid(node):
		return Rect2()
	var out := Rect2()
	var first := true
	for vi in node.find_children("*", "VisualInstance3D", true, false):
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
			GameState.add_item(th.item, n)
			item_taken.emit(th.item, n)
			message.emit("Coges: %s" % t.name)
			var node: Node3D = t.node
			if node:
				var tw := create_tween().set_parallel(true)
				tw.tween_property(node, "position:y", node.position.y + 0.6, 0.3)
				tw.tween_property(node, "scale", Vector3.ONE * 0.01, 0.3)
				await tw.finished
				node.hide()
		"switch":
			await _use_switch(t.cell, t.node)
		_:
			message.emit("No hay nada delante.")


func _use_door(k: String) -> void:
	var cs := DungeonMap.key_cells(k)
	var info := map.door(cs[0], DungeonMap.N if k.ends_with("N") else DungeonMap.W)
	var is_open := door_open(k)
	var req: String = info.get("requires", "")
	if not is_open and req != "" and GameState.item_count(req) <= 0:
		message.emit("Está cerrada. Hace falta: %s" % ItemDB.get_item(req).get("name", req))
		return
	if not is_open and info.get("switch_only", false):
		message.emit("No se abre a mano. Habrá algún mecanismo.")
		return
	await _set_door(k, not is_open)


func _set_door(k: String, open: bool) -> void:
	open_doors[k] = open
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
	for k: String in doors:
		_set_door(k, open)
	await get_tree().create_timer(0.45).timeout
