class_name Romance
extends RefCounted
## Citas, parejas y rupturas. Sin interfaz: world_screen pregunta y los diálogos
## cuentan el resultado. Diseño en docs/diseno/personajes_y_relaciones.md («Citas y
## parejas»). Valores provisionales.
##
## - Pedir una cita (acción «date» del menú): el personaje acepta o no según lo que
##   siente por Ren, su ánimo, si el sitio le gusta (`citas.lugares` de su ficha) y
##   si tiene pareja. Resultado → moment «cita_responde» con resultado =
##   acepta | rompe | pareja | animo | gustos | afecto | no.
## - Parejas: GameState.partners (id -> id, en los dos sentidos). Kenji y Yuna
##   empiezan juntos. Si uno de los dos siente por Ren bastante más que por su
##   pareja, acepta la cita y la deja («rompe»).
## - Al final de una cita, Ren puede pedir salir en serio (Story.can_be_partner).
## - Con pareja: cada mañana `morning()` mira el día anterior. Sin verse ni
##   escribirse, plantarle un plan o salir con otra persona baja lo que siente; si
##   cae demasiado, deja a Ren. Mientras dure, propone una cita cada mañana
##   (indicador «cita_propuesta:N»): si ese día Ren no queda con ella, cuenta.
## - Ligar con otra persona delante de la pareja, o quedar con otra, son cuernos
##   (lo segundo, cuando se entera: ver Lies).

const PROTAGONIST := "ren"
## Quién empieza saliendo con quién.
const START_PARTNERS := {"kenji": "yuna", "yuna": "kenji"}
## Sitios a los que se puede invitar (id de ubicación).
const DATE_PLACES: Array[String] = ["galeria", "parque", "plaza", "campus", "cloacas"]

## Puntuación para aceptar: 0,4·afecto + 0,6·atracción + 0,2·confianza
## − 0,5·(resentimiento + asco) + gusto por el sitio + ánimo (+ pareja de Ren).
const ACCEPT_SCORE := 30.0
const MOOD_BONUS := {"alegre": 10.0, "curioso": 5.0, "tranquilo": 0.0, "ansioso": -10.0, "triste": -15.0, "irritado": -20.0}
const PARTNER_BONUS := 30.0
## Dejar a su pareja por Ren: afecto por Ren ≥ BREAK_AFFECTION y atracción por Ren
## ≥ atracción por su pareja − BREAK_MARGIN.
const BREAK_AFFECTION := 50.0
const BREAK_MARGIN := 15.0
## Salir en serio con Ren (al final de una cita).
const PARTNER_MIN := {"afecto": 45.0, "atraccion": 40.0, "confianza": 25.0}
## Descuido: días seguidos sin verse ni escribirse.
const NEGLECT_DUMP := 3
const NEGLECT_COST := {"afecto": -4.0, "confianza": -2.0}
const MISSED_DATE_COST := {"afecto": -6.0, "resentimiento": 5.0}
const MISSED_PLAN_COST := {"afecto": -2.0}
const CHEAT_COST := {"afecto": -10.0, "confianza": -15.0, "resentimiento": 15.0}
const DATE_GAIN := {"afecto": 5.0, "confianza": 3.0, "atraccion": 3.0}
## Deja a Ren si: afecto < DUMP_AFFECTION, confianza < 0 o resentimiento ≥ DUMP_RESENTMENT.
const DUMP_AFFECTION := 25.0
const DUMP_RESENTMENT := 40.0
const NEGLECT_FLAG := "pareja_descuido"
const PROPOSAL_FLAG := "cita_propuesta:"
const PLACE_FLAG := "cita_lugar"
## Mensajes de la pareja (propuesta de cada mañana) y de quien se entera de algo.
const PROPOSALS: Array[String] = [
	"¿Hoy nos vemos? Aunque sea un rato. Dime sitio.",
	"Tengo ganas de verte. Pídeme una cita como dios manda, anda.",
	"Hoy me debes una cita. No es una pregunta.",
]
const FLIRT_TEXT := "Muy bonito lo de antes con %s. Delante de mí, Ren."
const LEFT_TEXT := "No me escribas. En serio. Ahora no."
const INTERACTION_KINDS: Array[String] = ["talk", "flirt", "fight", "date", "message", "plan"]


static func partner_of(id: String) -> String:
	return GameState.partners.get(id, "")


static func ren_partner() -> String:
	return partner_of(PROTAGONIST)


## Gusto de `who` por el sitio (`citas.lugares` de su ficha; 0 si no dice nada).
static func place_taste(who: String, place: String) -> float:
	return float(CharacterDB.profile(who).get("citas", {}).get("lugares", {}).get(place, 0))


static func _score(who: String, place: String) -> float:
	var v := func(dim: String) -> float: return Social.value(who, PROTAGONIST, dim)
	var s: float = 0.4 * v.call("afecto") + 0.6 * v.call("atraccion") + 0.2 * v.call("confianza") \
			- 0.5 * (v.call("resentimiento") + v.call("asco"))
	s += place_taste(who, place)
	var m := Social.mood(who)
	s += MOOD_BONUS.get(m.id, 0.0) * m.intensity / 50.0
	if partner_of(who) == PROTAGONIST:
		s += PARTNER_BONUS
	return s


## ¿Dejaría `who` a su pareja por Ren?
static func would_leave_partner(who: String) -> bool:
	var p := partner_of(who)
	if p == "" or p == PROTAGONIST:
		return false
	return Social.value(who, PROTAGONIST, "afecto") >= BREAK_AFFECTION \
			and Social.value(who, PROTAGONIST, "atraccion") >= Social.value(who, p, "atraccion") - BREAK_MARGIN


## Respuesta a una cita en `place`: "acepta", "rompe" (acepta y deja a su pareja),
## o el motivo del no: "no" (adultos), "pareja", "animo", "gustos", "afecto".
static func answer(who: String, place: String) -> String:
	if CharacterDB.profile(who).get("identity", {}).get("generation", "joven") != "joven":
		return "no"
	var p := partner_of(who)
	if p != "" and p != PROTAGONIST and not would_leave_partner(who):
		return "pareja"
	var s := _score(who, place)
	if s >= ACCEPT_SCORE:
		return "rompe" if p != "" and p != PROTAGONIST else "acepta"
	var m := Social.mood(who)
	var mood_part: float = MOOD_BONUS.get(m.id, 0.0) * m.intensity / 50.0
	if mood_part < 0.0 and s - mood_part >= ACCEPT_SCORE:
		return "animo"
	if place_taste(who, place) < 0.0 and s - place_taste(who, place) >= ACCEPT_SCORE:
		return "gustos"
	return "afecto"


## Cita aceptada: ruptura si toca y registro. Los presentes os ven quedar (lo
## saben). Si Ren tiene otra pareja: si está delante, se entera ya; si no, queda
## como secreto (Lies) y sospecha (`flag sospecha_<id>`): se enterará si alguien
## se lo cuenta, si pilla a Ren mintiendo o si Ren confiesa.
static func start_date(who: String, place: String, result: String) -> void:
	if result == "rompe":
		break_up(who, partner_of(who), "por_ren")
	var mine := ren_partner()
	GameState.set_flag(PLACE_FLAG, place)
	var id := GameState.record("date", PROTAGONIST, who, {"place": place, "result": "ok"}, Social.present())
	if mine != "" and mine != who:
		if mine in Social.present():
			cheat_discovered(mine, who)
		else:
			Lies.keep_quiet(mine, [id])
			GameState.set_flag("sospecha_" + mine)


## La pareja de Ren se entera de que ha quedado con `who`.
static func cheat_discovered(mine: String, who: String) -> void:
	Social.change(mine, PROTAGONIST, CHEAT_COST)
	GameState.set_flag("infiel_" + mine, int(GameState.get_flag("infiel_" + mine, 0)) + 1)
	GameState.set_flag("sospecha_" + mine, false)
	Social.set_mood(mine, "triste", 70.0)


## Cita rechazada: queda registrada (cuenta como interacción, sin efectos).
static func refused(who: String, place: String, result: String) -> void:
	GameState.set_flag(PLACE_FLAG, place)
	GameState.record("date", PROTAGONIST, who, {"place": place, "result": result}, Social.present())


## ¿Ya ha habido cita hoy (con quien sea)?
static func dated_today() -> bool:
	for ev in GameState.events.find({"kind": "date", "actor": PROTAGONIST, "date": GameState.date}):
		if ev.data.get("result", "") == "ok":
			return true
	return false


## Ren liga con `target`: si su pareja está delante (y no es `target`), le sienta fatal.
static func on_flirt(target: String) -> void:
	var mine := ren_partner()
	if mine == "" or mine == target or not mine in Social.present():
		return
	Social.change(mine, PROTAGONIST, CHEAT_COST, 0.5)
	Social.set_mood(mine, "irritado", 70.0)
	GameState.add_message(mine, mine, FLIRT_TEXT % CharacterDB.display_name(target))


## Fin de una cita (escena jugada): sube lo que siente.
static func finish_date(who: String) -> void:
	Social.change(who, PROTAGONIST, DATE_GAIN)
	if partner_of(who) == PROTAGONIST:
		GameState.set_flag(NEGLECT_FLAG, 0)


static func dates_with(who: String) -> int:
	return GameState.events.count({"kind": "date", "actor": PROTAGONIST, "target": who})


## ¿Saldría en serio con Ren ahora? (tras al menos una cita)
static func can_be_partner(who: String) -> bool:
	var p := partner_of(who)
	if (p != "" and p != PROTAGONIST) or dates_with(who) < 1:
		return false
	for dim: String in PARTNER_MIN:
		if Social.value(who, PROTAGONIST, dim) < PARTNER_MIN[dim]:
			return false
	return true


static func become_partner(who: String) -> void:
	var old := ren_partner()
	if old != "" and old != who:
		break_up(PROTAGONIST, old, "ren_deja")
	GameState.partners[PROTAGONIST] = who
	GameState.partners[who] = PROTAGONIST
	GameState.set_flag("pareja_" + who)
	GameState.set_flag(NEGLECT_FLAG, 0)
	GameState.flags.erase("ex_" + who)
	GameState.record("couple", PROTAGONIST, who, {}, [PROTAGONIST, who])


## Rompen `a` y `b`. `why`: por_ren (uno deja al otro por Ren), descuido,
## infiel, frio (dejan a Ren) o ren_deja.
static func break_up(a: String, b: String, why: String) -> void:
	GameState.partners.erase(a)
	GameState.partners.erase(b)
	GameState.record("breakup", a, b, {"why": why}, [a, b])
	if PROTAGONIST in [a, b]:
		var other := b if a == PROTAGONIST else a
		GameState.flags.erase("pareja_" + other)
		GameState.set_flag("ex_" + other)
		Social.change(other, PROTAGONIST, {"afecto": -15.0, "resentimiento": 15.0})
		Social.set_mood(other, "triste", 75.0)
		return
	# Una pareja del grupo rompe por Ren: el dejado se lo toma fatal (con Ren y con su ex).
	var left := b
	var pair := [a, b]
	pair.sort()
	GameState.set_flag("%s_%s_rotos" % pair)   # kenji_yuna_rotos
	GameState.set_flag("dejado_por_ren_" + left)   # dejado_por_ren_kenji: Yuna dejó a Kenji
	Social.change(left, PROTAGONIST, {"afecto": -30.0, "confianza": -30.0, "resentimiento": 40.0})
	Social.change(left, a, {"afecto": -25.0, "confianza": -30.0, "resentimiento": 30.0})
	Social.set_mood(left, "triste", 85.0)
	GameState.add_message(left, left, LEFT_TEXT)


# --- Cada mañana -------------------------------------------------------------------

## Revisa el día anterior con la pareja de Ren. Devuelve el motivo si le deja
## ("descuido", "infiel", "frio") o "" si siguen.
static func morning() -> String:
	var p := ren_partner()
	if p == "":
		return ""
	var yesterday := _yesterday()
	var seen := false
	for ev in GameState.events.find({"actor": PROTAGONIST, "target": p, "date": yesterday}):
		if ev.kind in INTERACTION_KINDS and ev.data.get("result", Social.OK) == Social.OK:
			seen = true
	var neglect := int(GameState.get_flag(NEGLECT_FLAG, 0))
	if seen:
		neglect = maxi(neglect - 1, 0)
	else:
		neglect += 1
		Social.change(p, PROTAGONIST, NEGLECT_COST)
	# Planes que propuso y a los que Ren no fue.
	for id: String in ChapterDB.PLANS:
		if ChapterDB.plan(id).get("invite", {}).get("from", "") == p and int(ChapterDB.plan(id).get("day", 0)) == GameState.day_number() - 1 \
				and GameState.get_flag(ChapterDB.PLAN_INVITED + id) and not GameState.get_flag(ChapterDB.PLAN_DONE + id):
			Social.change(p, PROTAGONIST, MISSED_PLAN_COST)
	# La cita que pidió ayer.
	if GameState.get_flag(PROPOSAL_FLAG + str(GameState.day_number() - 1)):
		var dated := false
		for ev in GameState.events.find({"kind": "date", "actor": PROTAGONIST, "target": p, "date": yesterday}):
			dated = dated or ev.data.get("result", "") == "ok"
		if not dated:
			Social.change(p, PROTAGONIST, MISSED_DATE_COST)
	GameState.set_flag(NEGLECT_FLAG, neglect)
	var why := ""
	if int(GameState.get_flag("infiel_" + p, 0)) >= 2 or Social.value(p, PROTAGONIST, "confianza") < 0.0:
		why = "infiel" if int(GameState.get_flag("infiel_" + p, 0)) > 0 else "frio"
	elif neglect >= NEGLECT_DUMP:
		why = "descuido"
	elif Social.value(p, PROTAGONIST, "afecto") < DUMP_AFFECTION or Social.value(p, PROTAGONIST, "resentimiento") >= DUMP_RESENTMENT:
		why = "frio"
	if why != "":
		break_up(p, PROTAGONIST, why)
		GameState.flags.erase("infiel_" + p)
		GameState.set_flag("deja_a_ren_motivo", why)
		return why
	# Sigue: hoy también quiere verte.
	GameState.set_flag(PROPOSAL_FLAG + str(GameState.day_number()))
	GameState.add_message(p, p, PROPOSALS[GameState.day_number() % PROPOSALS.size()])
	return ""


## Sitio favorito de `who` para una cita (el que más le gusta).
static func favourite_place(who: String) -> String:
	var best := DATE_PLACES[0]
	for place in DATE_PLACES:
		if place_taste(who, place) > place_taste(who, best):
			best = place
	return best


static func _yesterday() -> Dictionary:
	var unix := Time.get_unix_time_from_datetime_dict({"year": GameState.date.year, "month": GameState.date.month,
			"day": GameState.date.day, "hour": 12, "minute": 0, "second": 0}) - 86400
	var d := Time.get_datetime_dict_from_unix_time(unix)
	return {"year": d.year, "month": d.month, "day": d.day}
