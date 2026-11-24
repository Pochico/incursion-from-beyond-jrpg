class_name Lies
extends RefCounted
## Mentiras y secretos. Sin interfaz: ConversationView avisa de las mentiras y los
## diálogos cuentan el resultado. Diseño en docs/diseno/personajes_y_relaciones.md
## («Mentiras y secretos»). Valores provisionales.
##
## - Mentir: una opción de Ren con [#miente=TEMA] es una mentira al interlocutor.
##   TEMA dice qué verdad se tapa (ver `truth_events`):
##     cita        las citas de Ren con otra persona que el engañado no sabe
##     ayer        dónde estuvo Ren ayer (fuera de casa)
##     dia_N       dónde estuvo Ren el día N (dia_2 = martes)
##   Lo que sabe cada personaje sale del registro de acontecimientos (quién lo
##   presenció o a quién se lo contaron).
## - Testigos: los presentes que saben la verdad. Si alguno siente más por el
##   engañado que por Ren (`affinity`), le delata; si no, el que más aprecia a
##   Ren le cubre. Sin testigos, cuela. En el diálogo:
##     if Story.lie_result() == "delatado" / "cubierto" / "creido"
##     {{Story.lie_witness()}}: ...   (quien delata o cubre)
## - Secretos: una mentira que cuela (o una cita a espaldas de la pareja) queda
##   pendiente en GameState.secrets. Cada mañana, quien lo sabe y prefiere al
##   engañado por al menos GOSSIP_MARGIN se lo cuenta. Si Ren había mentido, peor;
##   quien le cubrió también pierde la confianza del engañado.

const TAG := "miente"
const PROTAGONIST := "ren"
const TRUTH_KINDS: Array[String] = ["visit", "talk", "flirt", "fight", "date", "plan"]

## Delata a la cara si prefiere al engañado (diferencia > 0); se va de la lengua
## después solo si la diferencia es de al menos esto.
const GOSSIP_MARGIN := 10.0
## Pillado en la mentira delante de todos.
const EXPOSED_COST := {"confianza": -15.0, "resentimiento": 10.0, "afecto": -5.0}
## Se entera después de que le mintió.
const DISCOVERED_LIE_COST := {"confianza": -20.0, "resentimiento": 15.0, "afecto": -5.0}
## Se entera después de algo que Ren calló (sin mentir).
const DISCOVERED_SECRET_COST := {"confianza": -8.0, "resentimiento": 5.0}
## Lo que pierde con el engañado quien cubrió a Ren.
const ACCOMPLICE_COST := {"confianza": -10.0, "resentimiento": 5.0}
## Lo que gana con el engañado quien le cuenta la verdad.
const HONEST_GAIN := {"confianza": 5.0, "afecto": 2.0}
const DISCOVERED_TEXT := "Me ha contado %s lo que no me contaste tú. Gracias por nada, Ren."
const DISCOVERED_LIE_TEXT := "Me ha contado %s la verdad. Me mentiste a la cara, Ren."

## Última mentira de la conversación en curso: {result, witness, target, topic}.
static var last := {}


## Cuánto aprecia `from` a `to`, para decidir a quién es leal.
static func affinity(from: String, to: String) -> float:
	var r := Social.relation(from, to)
	return r.afecto + 0.5 * r.confianza + 0.3 * r.respeto - r.resentimiento - r.asco


## Ids de los acontecimientos que la mentira tapa y que `target` no sabe.
static func truth_events(topic: String, target: String) -> Array[String]:
	var out: Array[String] = []
	var day := -1
	if topic == "ayer":
		day = GameState.day_number() - 1
	elif topic.begins_with("dia_") and topic.substr(4).is_valid_int():
		day = int(topic.substr(4))
	for ev in GameState.events.find({"actor": PROTAGONIST}):
		if GameState.events.knows(target, ev.id):
			continue
		if topic == "cita":
			if ev.kind == "date" and ev.target != target and ev.data.get("result", "") == "ok":
				out.append(ev.id)
		elif day > 0 and ev.kind in TRUTH_KINDS and ev.location != LocationDB.HOME \
				and _day_of(ev.date) == day and ev.target != target:
			out.append(ev.id)
	return out


## Quién (con ficha, sin Ren ni el engañado) sabe alguno de `ids`.
static func knowers(ids: Array, target: String) -> Array[String]:
	var out: Array[String] = []
	for who in CharacterDB.with_profile():
		if who == PROTAGONIST or who == target:
			continue
		for id: String in ids:
			if GameState.events.knows(who, id):
				out.append(who)
				break
	return out


## Ren miente a `target` sobre `topic`. Devuelve "delatado", "cubierto" o "creido"
## y aplica los efectos.
static func tell(target: String, topic: String) -> String:
	var ids := truth_events(topic, target)
	var present := Social.present()
	var delator := ""
	var cover := ""
	var best_delate := 0.0
	var best_cover := -INF
	for who in knowers(ids, target):
		if not who in present:
			continue
		var pref := affinity(who, target) - affinity(who, PROTAGONIST)
		if pref > best_delate:
			best_delate = pref
			delator = who
		elif pref <= 0.0 and -pref > best_cover:
			best_cover = -pref
			cover = who
	var result := "creido"
	if delator != "":
		result = "delatado"
		Social.change(target, PROTAGONIST, EXPOSED_COST)
		Social.change(target, delator, HONEST_GAIN)
		Social.set_mood(target, "irritado", 70.0)
		_reveal(target, ids)
	elif cover != "":
		result = "cubierto"
	if result != "delatado" and not ids.is_empty():
		_keep_secret(target, ids, true, [cover] if cover != "" else [])
	var witness := delator if delator != "" else cover
	last = {"result": result, "witness": witness, "target": target, "topic": topic}
	GameState.record("lie", PROTAGONIST, target, {"topic": topic, "result": result, "witness": witness}, present)
	return result


## Ren calla algo (sin mentir todavía): queda como secreto para `target`.
static func keep_quiet(target: String, ids: Array[String]) -> void:
	_keep_secret(target, ids, false, [])


## Ren lo confiesa: `target` se entera de todo lo pendiente, sin el castigo de
## la mentira descubierta.
static func confess(target: String) -> void:
	for s: Dictionary in GameState.secrets.duplicate():
		if s.target == target:
			GameState.secrets.erase(s)
			_reveal(target, s.events)
	GameState.record("confess", PROTAGONIST, target, {}, Social.present())


## Cada mañana: quien sabe un secreto y prefiere al engañado se lo cuenta.
## Devuelve [{target, by, lied}] con lo que se ha descubierto.
static func morning() -> Array:
	var found := []
	for s: Dictionary in GameState.secrets.duplicate():
		var by := ""
		var best := GOSSIP_MARGIN
		for who in knowers(s.events, s.target):
			if who in s.accomplices:
				continue
			var pref := affinity(who, s.target) - affinity(who, PROTAGONIST)
			if pref >= best:
				best = pref
				by = who
		if by == "":
			continue
		GameState.secrets.erase(s)
		var lied: bool = s.lied
		Social.change(s.target, PROTAGONIST, DISCOVERED_LIE_COST if lied else DISCOVERED_SECRET_COST)
		Social.change(s.target, by, HONEST_GAIN)
		for acc: String in s.accomplices:
			Social.change(s.target, acc, ACCOMPLICE_COST)
		_reveal(s.target, s.events)
		# Para los diálogos: «# cuando: hablar, flag pillado_rika» (el cue lo apaga).
		GameState.set_flag("pillado_" + s.target)
		GameState.set_flag("pillado_mentira_" + s.target, lied)
		GameState.set_flag("chivato_" + s.target, by)
		GameState.add_message(s.target, s.target, (DISCOVERED_LIE_TEXT if lied else DISCOVERED_TEXT) % CharacterDB.display_name(by))
		GameState.record("discovered", by, s.target, {"lied": lied}, [by, s.target])
		found.append({"target": s.target, "by": by, "lied": lied})
	return found


## ¿Tiene Ren algo pendiente con `target`?
static func has_secret(target: String) -> bool:
	for s: Dictionary in GameState.secrets:
		if s.target == target:
			return true
	return false


# --- Internos ----------------------------------------------------------------------

## `target` se entera de `ids`; si era una cita a espaldas de su pareja, cuernos.
static func _reveal(target: String, ids: Array) -> void:
	# Lo que ya sabe deja de ser secreto.
	for s: Dictionary in GameState.secrets.duplicate():
		if s.target == target:
			s.events = s.events.filter(func(e: String) -> bool: return not e in ids)
			if s.events.is_empty():
				GameState.secrets.erase(s)
	for id: String in ids:
		GameState.events.tell(target, id)
		var ev := GameState.events.get_event(id)
		if ev.get("kind", "") == "date" and Romance.ren_partner() == target and ev.target != target:
			Romance.cheat_discovered(target, ev.target)


static func _keep_secret(target: String, ids: Array, lied: bool, accomplices: Array) -> void:
	for s: Dictionary in GameState.secrets:
		if s.target == target:
			for id: String in ids:
				if not id in s.events:
					s.events.append(id)
			s.lied = s.lied or lied
			for a: String in accomplices:
				if not a in s.accomplices:
					s.accomplices.append(a)
			return
	GameState.secrets.append({"target": target, "events": Array(ids), "lied": lied, "accomplices": Array(accomplices)})


static func _day_of(date: Dictionary) -> int:
	var start := GameState.START_DATE
	var a := Time.get_unix_time_from_datetime_dict({"year": start.year, "month": start.month, "day": start.day, "hour": 12})
	var b := Time.get_unix_time_from_datetime_dict({"year": date.year, "month": date.month, "day": date.day, "hour": 12})
	return roundi((b - a) / 86400.0) + 1
