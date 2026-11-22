class_name EventLog
extends RefCounted
## Registro de acontecimientos de la partida: qué ha pasado, cuándo, dónde, quién
## lo hizo y quién lo sabe. Solo se añaden entradas; nunca se modifican.
##
## Cada acontecimiento:
##   {id, seq, date, phase, location, kind, actor, target, data, witnesses}
## - `id`: los sucesos de guion llevan un id fijo ("incursion_1") y solo se
##   registran una vez. Los repetibles (hablar, regalar...) reciben uno automático.
## - `kind`: tipo de suceso ("talk", "fight", "flirt", "incursion", "examine"...).
## - `data`: detalles libres (resultado de un combate, objeto regalado...).
## - `witnesses`: quién estaba presente. Ellos lo saben desde el principio.
##
## El conocimiento es por personaje: un personaje solo puede reaccionar a lo que
## presenció o le han contado (`tell`). Los recuerdos son consultas a este registro.

var events: Array[Dictionary] = []
var _by_id := {}          ## id -> índice en `events`
var _knowledge := {}      ## personaje -> {id de acontecimiento: true}
var _seq := 0


## Registra un acontecimiento y devuelve su id. Si `id` ya existe no hace nada
## (devuelve "") para que un mismo suceso no aplique dos veces sus efectos.
func record(kind: String, actor: String, target: String = "", data: Dictionary = {},
		witnesses: Array = [], id: String = "") -> String:
	if id != "" and _by_id.has(id):
		return ""
	_seq += 1
	if id == "":
		id = "%s_%d" % [kind, _seq]
	var ev := {
		"id": id, "seq": _seq,
		"date": GameState.date.duplicate(), "phase": GameState.phase,
		"location": GameState.location_id,
		"kind": kind, "actor": actor, "target": target, "data": data.duplicate(true),
		"witnesses": _unique([actor, target] + witnesses),
	}
	_by_id[id] = events.size()
	events.append(ev)
	for who: String in ev.witnesses:
		_learn(who, id)
	return id


func has(id: String) -> bool:
	return _by_id.has(id)


func get_event(id: String) -> Dictionary:
	return events[_by_id[id]] if _by_id.has(id) else {}


## `who` se entera de un acontecimiento que no presenció.
func tell(who: String, id: String) -> void:
	if _by_id.has(id):
		_learn(who, id)


func knows(who: String, id: String) -> bool:
	return _knowledge.get(who, {}).has(id)


## Acontecimientos que cumplen el filtro, del más antiguo al más reciente.
## Claves del filtro: kind, actor, target, known_by, phase, date (todas opcionales).
func find(filter: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ev in events:
		if filter.has("kind") and ev.kind != filter.kind:
			continue
		if filter.has("actor") and ev.actor != filter.actor:
			continue
		if filter.has("target") and ev.target != filter.target:
			continue
		if filter.has("phase") and ev.phase != filter.phase:
			continue
		if filter.has("date") and ev.date != filter.date:
			continue
		if filter.has("known_by") and not knows(filter.known_by, ev.id):
			continue
		out.append(ev)
	return out


## Cuántas veces ha pasado algo (p. ej. intentos de ligar con alguien hoy).
func count(filter: Dictionary = {}) -> int:
	return find(filter).size()


func last(filter: Dictionary = {}) -> Dictionary:
	var found := find(filter)
	return found.back() if not found.is_empty() else {}


# --- Guardado ---------------------------------------------------------------------

func to_dict() -> Dictionary:
	var knowledge := {}
	for who: String in _knowledge:
		knowledge[who] = _knowledge[who].keys()
	return {"events": events, "knowledge": knowledge, "seq": _seq}


static func from_dict(d: Dictionary) -> EventLog:
	var result := EventLog.new()
	result._seq = int(d.get("seq", 0))
	for ev: Dictionary in d.get("events", []):
		ev.seq = int(ev.seq)
		for k: String in ev.date:
			ev.date[k] = int(ev.date[k])
		result._by_id[ev.id] = result.events.size()
		result.events.append(ev)
	for who: String in d.get("knowledge", {}):
		for id: String in d.knowledge[who]:
			result._learn(who, id)
	return result


func _learn(who: String, id: String) -> void:
	if who == "":
		return
	if not _knowledge.has(who):
		_knowledge[who] = {}
	_knowledge[who][id] = true


static func _unique(list: Array) -> Array:
	var out := []
	for x in list:
		if x != "" and x not in out:
			out.append(x)
	return out
