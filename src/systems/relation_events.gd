class_name RelationEvents
extends RefCounted
## Sucesos de relación en el registro de acontecimientos (EventLog): parejas nuevas,
## rupturas y enfados graves. Solo registra y difunde; los diálogos reaccionan con
## las reglas de siempre.
##
## Ids fijos, para usarlos en las reglas `# cuando:` con `sabe`:
##   pareja_<a>_<b>     empiezan a salir (nombres en orden alfabético: pareja_kenji_yuna)
##   ruptura_<a>_<b>    lo dejan (ruptura_ren_yuna)
##   enfado_<quien>_<con>   enfado grave de `quien` con `con` (enfado_yuna_ren)
## Si se repite, lleva número: ruptura_kenji_yuna_2, enfado_yuna_ren_3...
##
## Quién lo sabe: los implicados y los presentes; cada mañana se cuenta (un salto por
## mañana) a quien tiene interés (afinidad con un implicado) y un amigo que ya lo sabe.
## Enfado grave: un solo cambio que, sumado, empeora la relación GRUDGE_POINTS o más
## (bajar afecto/confianza/respeto/atracción o subir miedo/asco/resentimiento).
## Mientras dura, el flag `enfadado_<quien>` (con Ren) está activo; se pasa con
## `reconcile` o al cabo de GRUDGE_DAYS días.
## Valores provisionales.

const PROTAGONIST := "ren"
const KINDS: Array[String] = ["couple", "breakup", "grudge"]
const PREFIX := {"couple": "pareja_", "breakup": "ruptura_", "grudge": "enfado_"}
const GRUDGE_POINTS := 25.0
const GRUDGE_DAYS := 7
## Afinidad (Lies.affinity) para interesarse por los implicados y para contárselo a alguien.
const GOSSIP_AFFINITY := 15.0
const ANGRY_FLAG := "enfadado_"


static func record_couple(a: String, b: String, witnesses: Array = []) -> String:
	return GameState.record("couple", a, b, {}, witnesses, _free_id(_pair_id("couple", a, b)))


static func record_breakup(a: String, b: String, why: String, witnesses: Array = []) -> String:
	return GameState.record("breakup", a, b, {"why": why}, witnesses, _free_id(_pair_id("breakup", a, b)))


## Tras un cambio de `from` hacia `to` (`delta` = lo que de verdad ha cambiado):
## si es grave, registra el enfado. `cause`: qué lo provocó («infiel», «mentira_delatada»,
## «opción «...»»...). Devuelve el id o "".
static func check_grudge(from: String, to: String, delta: Dictionary, cause: String) -> String:
	if from == PROTAGONIST or from == to or severity(delta) < GRUDGE_POINTS:
		return ""
	var here := Social.present()
	var witnesses: Array = here if from in here else []
	var id := GameState.record("grudge", from, to, {"cause": cause, "delta": delta, "day": GameState.day_number()},
			witnesses, _free_id(PREFIX.grudge + from + "_" + to))
	if to == PROTAGONIST:
		GameState.set_flag(ANGRY_FLAG + from)
	return id


## Cuánto empeora la relación un cambio (solo cuenta lo malo).
static func severity(delta: Dictionary) -> float:
	var bad := 0.0
	for dim: String in delta:
		var d: float = delta[dim]
		bad += maxf(-d, 0.0) if dim in Social.GOOD_DIMENSIONS else maxf(d, 0.0)
	return bad


## Último enfado de `from` con `to` que sigue en pie ({} si no hay).
static func grudge(from: String, to: String = PROTAGONIST) -> Dictionary:
	var g := GameState.events.last({"kind": "grudge", "actor": from, "target": to})
	if g.is_empty():
		return {}
	var peace := GameState.events.last({"kind": "reconcile", "actor": from, "target": to})
	if not peace.is_empty() and peace.seq > g.seq:
		return {}
	if GameState.day_number() - int(g.data.get("day", 0)) >= GRUDGE_DAYS:
		return {}
	return g


static func angry(from: String, to: String = PROTAGONIST) -> bool:
	return not grudge(from, to).is_empty()


## Hacen las paces (se registra; los presentes lo ven).
static func reconcile(from: String, to: String = PROTAGONIST) -> void:
	if not angry(from, to):
		return
	GameState.record("reconcile", from, to, {}, Social.present())
	if to == PROTAGONIST:
		GameState.flags.erase(ANGRY_FLAG + from)


## ¿Sabe `who` que `a` y `b` lo han dejado / están juntos (lo último que pasó entre ellos)?
static func knows_last(who: String, kind: String, a: String, b: String) -> bool:
	var ev := _last_between(kind, a, b)
	return not ev.is_empty() and GameState.events.knows(who, ev.id)


# --- Cada mañana -------------------------------------------------------------------

## Las noticias corren y los enfados viejos se pasan. Devuelve cuántas veces se ha
## contado algo.
static func morning() -> int:
	var told := 0
	var people := CharacterDB.with_profile().filter(func(id: String) -> bool: return id != PROTAGONIST)
	for ev: Dictionary in GameState.events.events:
		if not ev.kind in KINDS:
			continue
		var knowers := people.filter(func(id: String) -> bool: return GameState.events.knows(id, ev.id))
		for who: String in people:
			if who in knowers or not _cares(who, ev):
				continue
			for k: String in knowers:
				if Lies.affinity(k, who) >= GOSSIP_AFFINITY:
					GameState.events.tell(who, ev.id)
					told += 1
					break
	for id: String in GameState.flags.keys():
		if id.begins_with(ANGRY_FLAG) and not angry(id.substr(ANGRY_FLAG.length())):
			GameState.flags.erase(id)
	return told


static func _cares(who: String, ev: Dictionary) -> bool:
	for p: String in [ev.actor, ev.target]:
		if p != "" and p != who and Lies.affinity(who, p) >= GOSSIP_AFFINITY:
			return true
	return false


# --- Internos ----------------------------------------------------------------------

static func _pair_id(kind: String, a: String, b: String) -> String:
	var pair := [a, b]
	pair.sort()
	return PREFIX[kind] + "%s_%s" % pair


## `base` si está libre; si no, base_2, base_3...
static func _free_id(base: String) -> String:
	if not GameState.events.has(base):
		return base
	var n := 2
	while GameState.events.has("%s_%d" % [base, n]):
		n += 1
	return "%s_%d" % [base, n]


static func _last_between(kind: String, a: String, b: String) -> Dictionary:
	var found := {}
	for ev: Dictionary in GameState.events.find({"kind": kind}):
		if (ev.actor == a and ev.target == b) or (ev.actor == b and ev.target == a):
			found = ev
	return found
