class_name DungeonMap
extends RefCounted
## Mapa de una mazmorra: casillas y bordes. Lo usan el editor, el generador 3D
## y el movimiento, así que las reglas de paso están solo aquí.
##
## Casillas: posición Vector2i (x = este, y = sur). Pintar una casilla crea su
## suelo y su techo. Bordes: cada casilla es dueña de sus bordes norte y oeste;
## el borde este de (x, y) es el oeste de (x + 1, y). Clave: "x,y,N" o "x,y,W".
## Cada borde tiene dos caras: «a» mira a la casilla dueña y «b» a la vecina.
##
## Tipo efectivo de un borde:
##  - una de las dos casillas no existe → pared (se deduce, no se guarda);
##  - las dos existen → paso libre, salvo que se marque como muro o puerta.
##
## Texturas: nombre del PNG dentro de assets/textures/<tema>/<superficie>/
## (ver DungeonTextures). Vacío = la predeterminada del tema.
##
## Plantas: el mapa tiene varias (`floors`); `cells`, `edges` y `things` son
## siempre los de la planta activa (`set_level`). `ground` es el índice de la
## planta 0 (las de debajo salen como −1, −2…).
##
## Cosas (una por casilla, `things`):
##  - {type: "enemy", enemy: <id de CharacterDB>}: bloquea el paso; al chocar, combate.
##  - {type: "item", item: <id de ItemDB>, count}: en el suelo; se coge desde la casilla de al lado.
##  - {type: "switch", doors: [claves de borde]}: palanca; bloquea el paso y abre o
##    cierra las puertas vinculadas (de la misma planta).
##  - {type: "extraction"}: zona de extracción segura: saliendo desde ella te
##    llevas lo conseguido en la incursión (la casilla de inicio también lo es).
##  - {type: "stairs", up: bool, dir}: escalera. Se entra andando hacia `dir` y
##    se sale en la planta de arriba/abajo, en la casilla siguiente en esa
##    dirección. Va en pareja: la de la otra planta está en la misma casilla,
##    con el sentido contrario (las crea y borra `place_stairs` / `erase_stairs`).
##
## Se guarda en JSON: src/data/mazmorras/<id>.json.

const DIR := "res://src/data/mazmorras"
const VERSION := 2

## Norte, este, sur, oeste (en el plano: arriba, derecha, abajo, izquierda).
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const DIR_NAMES := ["Norte", "Este", "Sur", "Oeste"]
enum { N, E, S, W }

const OPEN := "open"
const WALL := "wall"
const DOOR := "door"
const NONE := "none"

const ENEMY := "enemy"
const STAIRS := "stairs"
const ITEM := "item"
const SWITCH := "switch"
const EXTRACTION := "extraction"
## Punto de guardado: terminal que guarda la partida y asegura lo conseguido.
const SAVE := "save"

var id := "mazmorra"
var theme := "pruebas"
var start := Vector2i.ZERO
var start_dir := N
var start_level := 0
## Plantas, de abajo arriba: {cells, edges, things}.
var floors: Array[Dictionary] = []
var level := 0
var ground := 0
## Vector2i -> {floor, ceiling} (texturas; vacío = del tema), floor_rot opcional.
var cells: Dictionary = {}
## "x,y,N|W" -> {type (wall/door; sin type = automático), a, b (texturas de cada cara),
## door: {open (estado inicial), requires (id de objeto necesario), switch_only,
## secret (parece pared hasta que se examina; una vez abierta no se cierra)}}
var edges: Dictionary = {}
## Vector2i -> cosa (enemigo o escalera).
var things: Dictionary = {}


func _init() -> void:
	floors.append(_empty_floor())
	set_level(0)


static func _empty_floor() -> Dictionary:
	return {"cells": {}, "edges": {}, "things": {}}


# --- Plantas ----------------------------------------------------------------------------

func set_level(i: int) -> void:
	level = clampi(i, 0, floors.size() - 1)
	cells = floors[level].cells
	edges = floors[level].edges
	things = floors[level].things


## Número visible de una planta (0 = la de `ground`).
## Nivel de las criaturas de la planta `i` (ver ProgressionDB.floor_creature_level).
func creature_level(i: int = level) -> int:
	return ProgressionDB.floor_creature_level(i - ground)


func level_name(i: int = level) -> String:
	return "Planta %d" % (i - ground)


## Añade una planta vacía encima (`above`) o debajo de todas. Devuelve su índice.
func add_level(above: bool) -> int:
	if above:
		floors.append(_empty_floor())
		return floors.size() - 1
	floors.insert(0, _empty_floor())
	ground += 1
	start_level += 1
	set_level(level + 1)
	return 0


## Solo se pueden borrar la de arriba o la de abajo (las escaleras van por parejas
## entre plantas contiguas). Se quitan las escaleras que llevaban a ella.
func can_remove_level(i: int) -> bool:
	return floors.size() > 1 and (i == 0 or i == floors.size() - 1)


func remove_level(i: int) -> bool:
	if not can_remove_level(i):
		return false
	var cur := level
	var nb := 1 if i == 0 else i - 1
	set_level(nb)
	for c: Vector2i in things.keys():
		if things[c].type == STAIRS and (things[c].up == (i > nb)):
			things.erase(c)
	floors.remove_at(i)
	if i == 0:
		ground = maxi(ground - 1, 0)
		start_level = maxi(start_level - 1, 0)
		cur -= 1
	start_level = mini(start_level, floors.size() - 1)
	set_level(clampi(cur, 0, floors.size() - 1))
	return true


# --- Cosas ------------------------------------------------------------------------------

func thing(c: Vector2i) -> Dictionary:
	return things.get(c, {})


func set_enemy(c: Vector2i, enemy_id: String, drop: String = "") -> bool:
	if not has_cell(c) or thing(c).get("type", "") == STAIRS \
			or (thing(c).get("enemy", "") == enemy_id and thing(c).get("drop", "") == drop):
		return false
	things[c] = {"type": ENEMY, "enemy": enemy_id}
	if drop != "":
		things[c]["drop"] = drop
	return true


func erase_enemy(c: Vector2i) -> bool:
	if thing(c).get("type", "") != ENEMY:
		return false
	things.erase(c)
	return true


## Quita lo que haya en `c` salvo escaleras (enemigo, objeto o interruptor).
func erase_thing(c: Vector2i) -> bool:
	if not things.has(c) or thing(c).type == STAIRS:
		return false
	things.erase(c)
	return true


func set_item(c: Vector2i, item_id: String, count: int = 1) -> bool:
	if not has_cell(c) or thing(c).get("type", "") == STAIRS:
		return false
	var t := thing(c)
	if t.get("item", "") == item_id and int(t.get("count", 1)) == count:
		return false
	things[c] = {"type": ITEM, "item": item_id, "count": count}
	return true


func set_extraction(c: Vector2i) -> bool:
	if not has_cell(c) or thing(c).get("type", "") != "":
		return false
	things[c] = {"type": EXTRACTION}
	return true


## ¿Se puede salir sin perder nada desde `c` (planta activa)? Zonas de
## extracción y la casilla de inicio.
func is_extraction(c: Vector2i) -> bool:
	return thing(c).get("type", "") == EXTRACTION or (level == start_level and c == start)


func set_save_point(c: Vector2i) -> bool:
	if not has_cell(c) or thing(c).get("type", "") != "":
		return false
	things[c] = {"type": SAVE}
	return true


func set_switch(c: Vector2i) -> bool:
	if not has_cell(c) or thing(c).get("type", "") in [STAIRS, SWITCH]:
		return false
	things[c] = {"type": SWITCH, "doors": []}
	return true


## Vincula o desvincula la puerta `key` al interruptor de `c`. Devuelve si queda vinculada.
func toggle_switch_door(c: Vector2i, key: String) -> bool:
	var doors: Array = thing(c).get("doors", [])
	if key in doors:
		doors.erase(key)
		return false
	doors.append(key)
	return true


func count_of(type: String) -> int:
	var n := 0
	for f in floors:
		for c: Vector2i in f.things:
			if f.things[c].type == type:
				n += 1
	return n


func enemy_count() -> int:
	return count_of(ENEMY)


## Planta a la que lleva una escalera de esta planta.
func stairs_target(c: Vector2i) -> int:
	return level + (1 if thing(c).get("up", false) else -1)


## Pone una escalera (y su pareja en la otra planta, que se crea si no existe).
## Prepara las casillas necesarias: la de la escalera y la de salida en la otra
## planta, y la de llegada en esta. Devuelve el índice de la otra planta.
func place_stairs(c: Vector2i, up: bool, d: int) -> int:
	erase_stairs(c)
	set_cell(c)
	set_cell(c - DIRS[d])
	things[c] = {"type": STAIRS, "up": up, "dir": d}
	var here := level
	if up and level == floors.size() - 1:
		add_level(true)
	elif not up and level == 0:
		add_level(false)
		here = level
	var other := here + (1 if up else -1)
	set_level(other)
	set_cell(c)
	set_cell(c + DIRS[d])
	things[c] = {"type": STAIRS, "up": not up, "dir": (d + 2) % 4}
	set_level(here)
	return other


## Quita la escalera de `c` y su pareja.
func erase_stairs(c: Vector2i) -> bool:
	if thing(c).get("type", "") != STAIRS:
		return false
	var here := level
	var other := stairs_target(c)
	things.erase(c)
	if other >= 0 and other < floors.size():
		set_level(other)
		if thing(c).get("type", "") == STAIRS:
			things.erase(c)
		set_level(here)
	return true


## Adónde lleva la escalera de `c`: {level, cell, dir} (vacío si no hay).
func stairs_exit(c: Vector2i) -> Dictionary:
	var t := thing(c)
	if t.get("type", "") != STAIRS:
		return {}
	var other := stairs_target(c)
	if other < 0 or other >= floors.size():
		return {}
	var d: int = t.dir
	var out := c + DIRS[d]
	if not floors[other].cells.has(out):
		out = c
	return {"level": other, "cell": out, "dir": d}


# --- Casillas ---------------------------------------------------------------------------

func has_cell(c: Vector2i) -> bool:
	return cells.has(c)


func set_cell(c: Vector2i) -> bool:
	if cells.has(c):
		return false
	cells[c] = {"floor": "", "ceiling": ""}
	return true


func erase_cell(c: Vector2i) -> bool:
	if not cells.has(c):
		return false
	if not erase_stairs(c):
		things.erase(c)
	cells.erase(c)
	# Los bordes que ya no tocan ninguna casilla sobran.
	for d in 4:
		var k := edge_key(c, d)
		if edges.has(k) and not has_cell(c) and not has_cell(c + DIRS[d]):
			edges.erase(k)
	return true


## Textura de suelo o techo de una casilla ("floor" / "ceiling"); vacío = del tema.
func cell_texture(c: Vector2i, surface: String) -> String:
	return cells.get(c, {}).get(surface, "")


func set_cell_texture(c: Vector2i, surface: String, tex: String) -> void:
	if cells.has(c):
		cells[c][surface] = tex


## Giro de la textura del suelo de una casilla, en cuartos de vuelta: 0 = lo de
## arriba de la imagen mira al norte, 1 = al este, 2 = al sur, 3 = al oeste
## (igual que las direcciones N, E, S, O). Sirve para orientar flechas.
func cell_rot(c: Vector2i) -> int:
	return int(cells.get(c, {}).get("floor_rot", 0))


func set_cell_rot(c: Vector2i, rot: int) -> void:
	if not cells.has(c):
		return
	rot = posmod(rot, 4)
	if rot == 0:
		cells[c].erase("floor_rot")
	else:
		cells[c]["floor_rot"] = rot


# --- Bordes -----------------------------------------------------------------------------

static func edge_key(c: Vector2i, dir: int) -> String:
	match dir:
		N: return "%d,%d,N" % [c.x, c.y]
		W: return "%d,%d,W" % [c.x, c.y]
		S: return "%d,%d,N" % [c.x, c.y + 1]
		_: return "%d,%d,W" % [c.x + 1, c.y]


## Cara del borde que mira a la casilla `c`: «a» si `c` es la dueña.
static func face_of(dir: int) -> String:
	return "a" if dir == N or dir == W else "b"


## Las dos casillas de un borde a partir de su clave: [dueña, vecina].
static func key_cells(key: String) -> Array[Vector2i]:
	var p := key.split(",")
	var owner := Vector2i(int(p[0]), int(p[1]))
	return [owner, owner + (Vector2i(0, -1) if p[2] == "N" else Vector2i(-1, 0))]


func edge(c: Vector2i, dir: int) -> Dictionary:
	return edges.get(edge_key(c, dir), {})


## Tipo efectivo: none (sin casillas), wall, door u open.
func edge_type(c: Vector2i, dir: int) -> String:
	var a := has_cell(c)
	var b := has_cell(c + DIRS[dir])
	if not a and not b:
		return NONE
	if not a or not b:
		return WALL
	return edge(c, dir).get("type", OPEN)


## Borde interior (entre dos casillas): solo estos se pueden marcar a mano.
func is_inner_edge(c: Vector2i, dir: int) -> bool:
	return has_cell(c) and has_cell(c + DIRS[dir])


## Marca un borde interior como open (automático), wall o door.
func set_edge_type(c: Vector2i, dir: int, type: String) -> void:
	var k := edge_key(c, dir)
	var e: Dictionary = edges.get(k, {})
	if type == OPEN:
		e.erase("type")
		e.erase("door")
	else:
		e["type"] = type
		if type == DOOR and not e.has("door"):
			e["door"] = {"open": false, "requires": ""}
		elif type != DOOR:
			e.erase("door")
	_store_edge(k, e)


## Textura de la cara del borde `dir` vista desde la casilla `c`.
func face_texture(c: Vector2i, dir: int) -> String:
	return edge(c, dir).get(face_of(dir), "")


func set_face_texture(c: Vector2i, dir: int, tex: String) -> void:
	var k := edge_key(c, dir)
	var e: Dictionary = edges.get(k, {})
	if tex == "":
		e.erase(face_of(dir))
	else:
		e[face_of(dir)] = tex
	_store_edge(k, e)


func door(c: Vector2i, dir: int) -> Dictionary:
	return edge(c, dir).get("door", {})


## ¿El borde es una puerta secreta (pared falsa)?
func is_secret(key: String) -> bool:
	var e: Dictionary = edges.get(key, {})
	return e.get("type", "") == DOOR and e.get("door", {}).get("secret", false)


## ¿Es una pared secreta oculta (`hidden`)? Solo se puede inspeccionar después
## de detectarla con el pulso del resonador.
func is_hidden(key: String) -> bool:
	return is_secret(key) and edges[key].door.get("hidden", false)


func set_door(c: Vector2i, dir: int, field: String, value: Variant) -> void:
	var e := edge(c, dir)
	if e.has("door"):
		e.door[field] = value


func _store_edge(k: String, e: Dictionary) -> void:
	if e.is_empty():
		edges.erase(k)
	else:
		edges[k] = e


## ¿Se puede pasar de `c` hacia `dir`? `open_doors`: clave -> abierta (estado de
## la partida); si una puerta no está ahí, vale su estado inicial.
func can_cross(c: Vector2i, dir: int, open_doors: Dictionary = {}) -> bool:
	match edge_type(c, dir):
		OPEN:
			return true
		DOOR:
			return open_doors.get(edge_key(c, dir), door(c, dir).get("open", false))
	return false


# --- Utilidades -------------------------------------------------------------------------

func bounds() -> Rect2i:
	if cells.is_empty():
		return Rect2i(0, 0, 1, 1)
	var r := Rect2i(cells.keys()[0], Vector2i.ONE)
	for c: Vector2i in cells:
		r = r.merge(Rect2i(c, Vector2i.ONE))
	return r


func door_count() -> int:
	var n := 0
	for f in floors:
		for k: String in f.edges:
			if f.edges[k].get("type", "") == DOOR:
				var cs := key_cells(k)
				if f.cells.has(cs[0]) and f.cells.has(cs[1]):
					n += 1
	return n


static func _key(p: Vector2i) -> String:
	return "%d,%d" % [p.x, p.y]


static func _cell_of(k: String) -> Vector2i:
	var p := k.split(",")
	return Vector2i(int(p[0]), int(p[1]))


# --- Guardado ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var fl := []
	for f in floors:
		var c := {}
		for p: Vector2i in f.cells:
			c[_key(p)] = f.cells[p].duplicate()
		var th := {}
		for p: Vector2i in f.things:
			th[_key(p)] = f.things[p].duplicate()
		fl.append({"cells": c, "edges": f.edges.duplicate(true), "things": th})
	return {
		"version": VERSION, "id": id, "theme": theme,
		"start": {"x": start.x, "y": start.y, "dir": start_dir, "level": start_level},
		"ground": ground, "level": level, "floors": fl,
	}


static func from_dict(d: Dictionary) -> DungeonMap:
	var m := DungeonMap.new()
	m.id = d.get("id", "mazmorra")
	m.theme = d.get("theme", "pruebas")
	var s: Dictionary = d.get("start", {})
	m.start = Vector2i(int(s.get("x", 0)), int(s.get("y", 0)))
	m.start_dir = int(s.get("dir", N))
	m.start_level = int(s.get("level", 0))
	m.ground = int(d.get("ground", 0))
	# Versión 1: una sola planta, con cells y edges en la raíz.
	var raw: Array = d.get("floors", [{"cells": d.get("cells", {}), "edges": d.get("edges", {})}])
	m.floors.clear()
	for f: Dictionary in raw:
		var fl := _empty_floor()
		for k: String in f.get("cells", {}):
			var v: Dictionary = f.cells[k]
			fl.cells[_cell_of(k)] = {"floor": v.get("floor", ""), "ceiling": v.get("ceiling", "")}
			if int(v.get("floor_rot", 0)) != 0:
				fl.cells[_cell_of(k)]["floor_rot"] = int(v.floor_rot)
		fl.edges = f.get("edges", {}).duplicate(true)
		for k: String in f.get("things", {}):
			var t: Dictionary = f.things[k].duplicate()
			if t.has("dir"):
				t.dir = int(t.dir)
			if t.has("count"):
				t.count = int(t.count)
			fl.things[_cell_of(k)] = t
		m.floors.append(fl)
	if m.floors.is_empty():
		m.floors.append(_empty_floor())
	m.start_level = clampi(m.start_level, 0, m.floors.size() - 1)
	m.set_level(int(d.get("level", m.start_level)))
	return m


static func path_for(map_id: String) -> String:
	return "%s/%s.json" % [DIR, map_id]


func save() -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var f := FileAccess.open(path_for(id), FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_dict(), "\t"))
	return OK


static func load_map(map_id: String) -> DungeonMap:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path_for(map_id)))
	return from_dict(data) if data is Dictionary else null


## Ids de los mapas guardados, en orden alfabético.
static func list_maps() -> Array[String]:
	var out: Array[String] = []
	if not DirAccess.dir_exists_absolute(DIR):
		return out
	for f in DirAccess.get_files_at(DIR):
		if f.ends_with(".json"):
			out.append(f.get_basename())
	out.sort()
	return out
