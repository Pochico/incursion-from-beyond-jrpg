class_name Invites
extends RefCounted
## Invitaciones a planes: las que recibe Ren (ChapterDB.PLANS) y las que hace él
## (ChapterDB.REN_ACTIVITIES, guardadas en GameState.ren_plans).
##
## Las que recibe:
## - Por mensaje (`invite.via` = "mensaje", por defecto): llega al móvil por la
##   mañana o al empezar la franja `invite.at`. Se contesta desde el chat.
## - En persona (`invite.via` = "persona"): queda «por proponer» y se lo propone
##   cuando Ren habla con él (regla `flag por_proponer:<plan>` en su .dialogue) o
##   dentro de otra escena. Si no se ha visto a tiempo (al empezar la franja del
##   plan o `invite.at`), llega por mensaje.
## - Respuestas: «sí», «no» o «ya he quedado para X» (si X es otro plan aceptado
##   que coincide en alguna franja). Ninguna es excluyente: se puede decir que sí
##   a dos planes a la misma hora; luego habrá que elegir.
##
## Las que hace Ren («Quedar» en el menú del personaje o «Proponer plan» en el
## móvil): elige actividad y franja (hoy o mañana) y el otro contesta según lo que
## siente por él, el sitio y su ánimo, o dice que ya ha quedado si tiene otro plan
## a esa hora. Se puede invitar a varios al mismo plan.
##
## Plantones: si Ren dijo que sí (o propuso él el plan y alguien aceptó) y la franja
## pasa sin ir, baja la relación, llega un reproche al móvil y queda pendiente. Si
## Ren contesta al mensaje, se cierra ahí; si no, se lo dicen en persona
## (`reproach_cue`).
##
## Flags de GameState (las reglas `# cuando:` los leen):
##   plan_invitado:<id>  ya se lo han propuesto       plan_hecho:<id>  ha ido
##   por_proponer:<id>   lo propondrá en persona      plan_si / plan_no / plan_otro:<id>
##   plan_plantado:<id>  dijo que sí y no fue         reproche:<id>    reproche sin contestar
##   reproche:<id>@<quien>  reproche de un invitado de Ren

const SAID_YES := "plan_si:"
const SAID_NO := "plan_no:"
const SAID_OTHER := "plan_otro:"
const PENDING := "por_proponer:"
const MISSED := "plan_plantado:"
const REPROACH := "reproche:"
const REN_PREFIX := "ren:"

## Lo que pasa con la relación de quien invita (valores provisionales).
const ACCEPT_GAIN := {"afecto": 1.0}
const MISSED_COST := {"afecto": -5.0, "confianza": -4.0, "resentimiento": 3.0}
## Contestar al reproche por mensaje suaviza el golpe.
const REPLY_EFFECT := {
	"perdon": {"resentimiento": -2.0, "afecto": 1.0},
	"otro": {"resentimiento": -1.0, "confianza": 1.0},
	"olvido": {"resentimiento": 1.0},
}
## Cuando Ren propone: acepta si 0,5·afecto + 0,3·confianza − 0,5·resentimiento
## + gusto por el sitio + ánimo ≥ REN_ACCEPT (quien es «talk_only», la familia,
## siempre que esté libre).
const REN_ACCEPT := 8.0
const SLOT_PHRASES := {"manana": "por la mañana", "dia": "a mediodía", "tarde": "por la tarde", "noche": "por la noche"}

## Contexto de la respuesta que se está reproduciendo (lo leen Story.plan_*).
static var current_plan := ""
static var current_reply := ""
static var other_plan := ""
## Plan propuesto al que nadie ha dicho que sí (no se guarda; solo para el diálogo).
static var _draft_plan := {}
const DRAFT := "ren:borrador"


# --- Estado ------------------------------------------------------------------------------

static func inviter(plan_id: String) -> String:
	return ChapterDB.plan(plan_id).get("invite", {}).get("from", "")


static func invited(plan_id: String) -> bool:
	return GameState.get_flag(ChapterDB.PLAN_INVITED + plan_id)


static func answered(plan_id: String) -> bool:
	return GameState.get_flag(SAID_YES + plan_id) or GameState.get_flag(SAID_NO + plan_id) \
			or GameState.get_flag(SAID_OTHER + plan_id)


## ¿Va Ren a ir? (dijo que sí, o es un plan suyo y alguien ha aceptado)
static func said_yes(plan_id: String) -> bool:
	if is_ren(plan_id):
		return not ChapterDB.plan(plan_id).get("cast", []).is_empty()
	return GameState.get_flag(SAID_YES + plan_id)


static func done(plan_id: String) -> bool:
	return GameState.get_flag(ChapterDB.PLAN_DONE + plan_id)


static func is_ren(plan_id: String) -> bool:
	return plan_id.begins_with(REN_PREFIX)


static func _slot_index(slot: String) -> int:
	for i in GameState.TIME_SLOTS.size():
		if GameState.TIME_SLOTS[i].id == slot:
			return i
	return -1


## Franjas del plan como índices (sin `slots`: todas menos la noche).
static func _slots(plan_id: String) -> Array[int]:
	var out: Array[int] = []
	var slots: Array = ChapterDB.plan(plan_id).get("slots", [])
	if slots.is_empty():
		for i in GameState.TIME_SLOTS.size() - 1:
			out.append(i)
	else:
		for s: String in slots:
			out.append(_slot_index(s))
	return out


## ¿Coinciden dos planes del mismo día en alguna franja?
static func overlap(a: String, b: String) -> bool:
	if int(ChapterDB.plan(a).get("day", -1)) != int(ChapterDB.plan(b).get("day", -2)):
		return false
	for s in _slots(a):
		if s in _slots(b):
			return true
	return false


## Planes a los que Ren va a ir que coinciden con `plan_id` (para «ya he quedado»).
static func conflicts(plan_id: String) -> Array[String]:
	var out: Array[String] = []
	for id in ChapterDB.all_ids():
		if id != plan_id and said_yes(id) and not done(id) and overlap(id, plan_id):
			out.append(id)
	return out


## ¿Se le puede contestar todavía? (sigue disponible hoy)
static func _still_open(plan_id: String) -> bool:
	if not ChapterDB.plan_available(plan_id):
		return false
	var last: int = _slots(plan_id).max()
	return GameState.time_slot <= last


# --- Propuestas que recibe Ren -------------------------------------------------------------

## Entrega lo que toca a esta hora: invitaciones por mensaje cuya franja `at` ya ha
## llegado, las de «en persona» que nadie ha propuesto a tiempo y los mensajes
## sueltos del día. Devuelve quién ha escrito (para avisar).
static func deliver_due() -> Array[String]:
	var senders: Array[String] = []
	for id: String in ChapterDB.plans_today():
		var invite: Dictionary = ChapterDB.plan(id).get("invite", {})
		if invite.is_empty() or invited(id):
			continue
		var at := _slot_index(invite.get("at", ""))
		if invite.get("via", "mensaje") == "persona":
			if not GameState.get_flag(PENDING + id):
				GameState.set_flag(PENDING + id)
			# Si no se ha visto en persona antes de su franja, lo manda por mensaje.
			var deadline: int = at if at >= 0 else _slots(id).min()
			if GameState.time_slot < deadline:
				continue
		elif at > GameState.time_slot:
			continue
		GameState.flags.erase(PENDING + id)
		GameState.set_flag(ChapterDB.PLAN_INVITED + id)
		# `text_late`: el mensaje de quien pensaba decírtelo en persona.
		GameState.add_message(invite.from, invite.from, invite.get("text_late", invite.text))
		if not senders.has(invite.from):
			senders.append(invite.from)
	# Mensajes sueltos del día (ChapterDB.MESSAGES).
	for i in ChapterDB.MESSAGES.size():
		var m: Dictionary = ChapterDB.MESSAGES[i]
		var key := "mensaje_dia:%d" % i
		# `day` = día de la partida; o `phase` + `phase_day` = días después de empezar esa fase.
		var day := int(m.get("day", -1))
		if m.has("phase_day"):
			day = -1 if not GameState.phase_at_least(m.phase) else \
					int(GameState.get_flag(GameState.PHASE_DAY + m.phase, 0)) + int(m.phase_day)
		if GameState.get_flag(key) or day != GameState.day_number() or _slot_index(m.slot) > GameState.time_slot:
			continue
		if (m.has("if") and not GameState.get_flag(m["if"])) or (m.has("unless") and GameState.get_flag(m.unless)):
			continue
		if not Acquaintance.is_friend(m.from):
			continue
		GameState.set_flag(key)
		GameState.add_message(m.from, m.from, m.text)
		if not senders.has(m.from):
			senders.append(m.from)
	return senders


## Ren contesta a una invitación (en persona, desde el diálogo, o por el móvil).
## `kind`: "si" | "no" | "otro" (ya ha quedado para otro plan, `other`).
static func answer(plan_id: String, kind: String, other: String = "") -> void:
	var who := inviter(plan_id)
	GameState.flags.erase(PENDING + plan_id)
	GameState.set_flag(ChapterDB.PLAN_INVITED + plan_id)
	for f in [SAID_YES, SAID_NO, SAID_OTHER]:
		GameState.flags.erase(f + plan_id)
	match kind:
		"si":
			GameState.set_flag(SAID_YES + plan_id)
			Social.change(who, CharacterDB.PROTAGONIST, ACCEPT_GAIN, 1.0, "plan_aceptado")
		"no":
			GameState.set_flag(SAID_NO + plan_id)
		"otro":
			GameState.set_flag(SAID_OTHER + plan_id, other if other != "" else true)
	GameState.record("plan_respuesta", CharacterDB.PROTAGONIST, who, {"plan": plan_id, "result": kind})


# --- Planes que propone Ren ----------------------------------------------------------------

## Plan de Ren con el formato de ChapterDB.PLANS (lo usa ChapterDB.plan).
static func ren_plan(id: String) -> Dictionary:
	var p: Dictionary = _draft_plan if id == DRAFT else GameState.ren_plans.get(id, {})
	if p.is_empty():
		return {}
	var act: Dictionary = ChapterDB.REN_ACTIVITIES.get(p.activity, {})
	var cast: Array = []
	for who: String in p.guests:
		if p.guests[who] == "si":
			cast.append(who)
	var scenes: Array = []
	if not cast.is_empty():
		scenes.append({"cue": "quedada_" + p.activity, "npc": cast[0]})
		for who: String in cast:
			scenes.append({"cue": who + "_quedada" if Story.has_cue(who + "_quedada") else "quedada_generica", "npc": who})
	return {"title": act.get("title", p.activity), "day": p.day, "slots": [p.slot], "target": act.get("target", ""),
		"cast": cast, "scenes": scenes, "advance_time": p.slot != "noche", "ren": true, "activity": p.activity}


## Franjas que Ren puede proponer para `activity`: las que quedan hoy (después de
## la actual) y, si son pocas, las de mañana. [{day, slot, label}]
static func proposal_slots(activity: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var allowed: Array = ChapterDB.REN_ACTIVITIES.get(activity, {}).get("slots", [])
	var today := GameState.day_number()
	for i in range(GameState.time_slot + 1, GameState.TIME_SLOTS.size()):
		var s: String = GameState.TIME_SLOTS[i].id
		if s in allowed:
			out.append({"day": today, "slot": s, "label": "Hoy " + SLOT_PHRASES[s]})
	if out.size() < 2:
		for s: String in allowed:
			if out.size() >= 3:
				break
			out.append({"day": today + 1, "slot": s, "label": "Mañana " + SLOT_PHRASES[s]})
	return out


## «hoy por la tarde», «mañana a mediodía», «el sábado por la noche».
static func when_phrase(day: int, slot: String) -> String:
	var today := GameState.day_number()
	var d := "hoy" if day == today else ("mañana" if day == today + 1 else "el día %d" % day)
	if slot == "manana" and day == today + 1:
		return "mañana por la mañana"
	return "%s %s" % [d, SLOT_PHRASES.get(slot, slot)]


## ¿Tiene `who` otro plan a esa hora? Devuelve el id del plan o "".
static func busy_with(who: String, day: int, slot: String, except: String = "") -> String:
	var idx := _slot_index(slot)
	for id in ChapterDB.all_ids():
		if id == except or done(id):
			continue
		var p := ChapterDB.plan(id)
		if int(p.get("day", -1)) != day or not (idx in _slots(id)):
			continue
		if who in p.get("cast", []) and (not p.has("phase") or GameState.phase_at_least(p.phase)) \
				and (not p.has("before_phase") or not GameState.phase_at_least(p.before_phase)):
			return id
	return ""


## Ren propone `activity` a `who` para (`day`, `slot`). Si ya hay un plan suyo igual,
## se suma a él. Devuelve la conversación que lo cuenta (`<who>_quedar` o la de
## general) con el contexto puesto: Story.plan_reply() = "si" | "no" | "ocupado" | "ya".
static func ren_invite(who: String, activity: String, day: int, slot: String) -> Dictionary:
	var id := ""
	for pid: String in GameState.ren_plans:
		var p: Dictionary = GameState.ren_plans[pid]
		if p.activity == activity and int(p.day) == day and p.slot == slot:
			id = pid
	var guests: Dictionary = GameState.ren_plans[id].guests if id != "" else {}
	other_plan = ""
	if guests.get(who, "") == "si":
		current_reply = "ya"
	else:
		other_plan = busy_with(who, day, slot, id)
		if other_plan != "":
			current_reply = "ocupado"
		elif _accepts(who, ChapterDB.REN_ACTIVITIES[activity].target):
			current_reply = "si"
			Social.change(who, CharacterDB.PROTAGONIST, ACCEPT_GAIN, 1.0, "plan_aceptado")
		else:
			current_reply = "no"
		# El plan solo se crea cuando alguien dice que sí.
		if id == "" and current_reply == "si":
			var n := int(GameState.get_flag("planes_ren_creados", 0)) + 1
			GameState.set_flag("planes_ren_creados", n)
			id = "%s%d" % [REN_PREFIX, n]
			GameState.ren_plans[id] = {"activity": activity, "day": day, "slot": slot, "guests": guests}
		guests[who] = current_reply
	# Sin plan (nadie ha dicho que sí): el contexto lleva lo propuesto para el diálogo.
	current_plan = id if id != "" else _draft(activity, day, slot)
	GameState.record("plan_propuesto", CharacterDB.PROTAGONIST, who, {"plan": id, "result": current_reply})
	var own := who + "_quedar"
	return Story.cue(own if Story.has_cue(own) else "quedar")


static func _draft(activity: String, day: int, slot: String) -> String:
	_draft_plan = {"activity": activity, "day": day, "slot": slot, "guests": {}}
	return DRAFT


static func _accepts(who: String, place: String) -> bool:
	if CharacterDB.get_character(who).get("talk_only", false):
		return true
	var v := func(dim: String) -> float: return Social.value(who, CharacterDB.PROTAGONIST, dim)
	var s: float = 0.5 * v.call("afecto") + 0.3 * v.call("confianza") - 0.5 * v.call("resentimiento")
	s += Romance.place_taste(who, place)
	var m := Social.mood(who)
	s += Romance.MOOD_BONUS.get(m.id, 0.0) * m.intensity / 50.0
	return s >= REN_ACCEPT


## Quién ha dicho que sí a un plan de Ren («Kenji y Rika»).
static func guest_names(plan_id: String) -> String:
	var names: Array = ChapterDB.plan(plan_id).get("cast", []).map(func(w: String) -> String: return CharacterDB.display_name(w))
	if names.size() <= 1:
		return "".join(names)
	return ", ".join(names.slice(0, -1)) + " y " + names.back()


# --- Plantones ------------------------------------------------------------------------------

## Planes a los que Ren iba a ir cuya franja ya ha pasado: baja la relación, llega
## el reproche al móvil y queda pendiente. Llamar al pasar de franja y cada mañana.
## Devuelve quién ha escrito.
static func check_missed() -> Array[String]:
	var senders: Array[String] = []
	var today := GameState.day_number()
	for id in ChapterDB.all_ids():
		var p := ChapterDB.plan(id)
		if not p.has("day") or not said_yes(id) or done(id) or GameState.get_flag(MISSED + id):
			continue
		var day := int(p.day)
		if day > today or (day == today and GameState.time_slot <= int(_slots(id).max())):
			continue
		GameState.set_flag(MISSED + id)
		var hurt: Array = p.cast if is_ren(id) else [inviter(id)]
		for who: String in hurt:
			GameState.set_flag(_reproach_key(id, who))
			Social.change(who, CharacterDB.PROTAGONIST, MISSED_COST, 1.0, "plan_plantado")
			GameState.record("plan_plantado", CharacterDB.PROTAGONIST, who, {"plan": id})
			var text: String = p.get("missed_text", "")
			if is_ren(id):
				text = ChapterDB.REN_MISSED_TEXT.get(who, "Te he esperado en %s.") % Story.lower_first(p.title)
			if text != "":
				GameState.add_message(who, who, text)
				if not senders.has(who):
					senders.append(who)
	return senders


static func _reproach_key(plan_id: String, who: String) -> String:
	return REPROACH + plan_id + ("@" + who if is_ren(plan_id) else "")


## Plan por el que `who` tiene un reproche pendiente a Ren, o "".
static func reproach_for(who: String) -> String:
	for id in ChapterDB.all_ids():
		if is_ren(id):
			if GameState.get_flag(_reproach_key(id, who)):
				return id
		elif inviter(id) == who and GameState.get_flag(REPROACH + id):
			return id
	return ""


static func clear_reproach(plan_id: String, who: String) -> void:
	GameState.flags.erase(_reproach_key(plan_id, who))


## Ren contesta por el móvil al reproche: "perdon" | "otro" (estaba en otro plan) | "olvido".
static func reply_reproach(plan_id: String, kind: String, who: String) -> void:
	clear_reproach(plan_id, who)
	Social.change(who, CharacterDB.PROTAGONIST, REPLY_EFFECT.get(kind, {}), 1.0, "plan_plantado")


## Conversación para el reproche en persona si `who` tiene uno pendiente: la propia
## del plan (`<who>_hablar_plantado_<plan>`, con su regla) la elige el selector; si
## no la hay, esta devuelve `<who>_hablar_plantado` (o la de general) y cierra el
## reproche. {} si no hay nada pendiente.
static func reproach_cue(who: String, picked: String) -> Dictionary:
	var id := reproach_for(who)
	if id == "" or picked.contains("plantad"):
		return {}
	current_plan = id
	other_plan = done_instead(id)
	current_reply = ""
	clear_reproach(id, who)
	var own := who + "_hablar_plantado"
	return Story.cue(own if Story.has_cue(own) else "hablar_plantado")


## Plan que Ren hizo en vez de `plan_id` (coincidían de hora), o "".
static func done_instead(plan_id: String) -> String:
	for id in ChapterDB.all_ids():
		if id != plan_id and done(id) and overlap(id, plan_id):
			return id
	return ""


# --- Móvil --------------------------------------------------------------------------------

## Lo que `contact` espera que Ren conteste por el móvil: {kind: "invite"|"reproche", plan}
## o {} si nada. Primero los reproches.
static func pending_question(contact: String) -> Dictionary:
	var r := reproach_for(contact)
	if r != "":
		return {"kind": "reproche", "plan": r}
	for id: String in ChapterDB.PLANS:
		if inviter(id) == contact and invited(id) and not answered(id) and _still_open(id):
			return {"kind": "invite", "plan": id}
	return {}


## Botones de respuesta del chat: [{label, reply, other}].
static func replies(contact: String) -> Array[Dictionary]:
	var q := pending_question(contact)
	var out: Array[Dictionary] = []
	if q.is_empty():
		return out
	if q.kind == "invite":
		out.append({"label": "Me apunto", "reply": "si", "other": ""})
		for other in conflicts(q.plan):
			out.append({"label": "Ya he quedado: %s" % ChapterDB.plan(other).title, "reply": "otro", "other": other})
		out.append({"label": "Esta vez paso", "reply": "no", "other": ""})
	else:
		out.append({"label": "Perdona, lo siento", "reply": "perdon", "other": ""})
		var instead := done_instead(q.plan)
		if instead != "":
			out.append({"label": "Estaba en: %s" % ChapterDB.plan(instead).title, "reply": "otro", "other": instead})
		out.append({"label": "Se me olvidó", "reply": "olvido", "other": ""})
	return out


## Aplica la respuesta elegida en el chat y devuelve la conversación que la cuenta
## (`<contacto>_movil_plan` o `_movil_plantado`; si no la tiene, la de general).
static func choose_reply(contact: String, option: Dictionary) -> Dictionary:
	var q := pending_question(contact)
	if q.is_empty():
		return {}
	current_plan = q.plan
	current_reply = option.reply
	other_plan = option.other
	var cue_kind := "plan"
	if q.kind == "invite":
		answer(q.plan, option.reply, option.other)
	else:
		cue_kind = "plantado"
		reply_reproach(q.plan, option.reply, contact)
	var own := "%s_movil_%s" % [contact, cue_kind]
	return Story.cue(own if Story.has_cue(own) else "movil_" + cue_kind)


## Avisos de los planes de hoy para el toast: los propuestos que siguen en pie.
static func agenda() -> Array[String]:
	var out: Array[String] = []
	for id in ChapterDB.plans_today():
		var p := ChapterDB.plan(id)
		if p.has("invite") and not invited(id):
			continue
		if GameState.get_flag(SAID_NO + id) or GameState.get_flag(SAID_OTHER + id):
			continue
		var label := ChapterDB.plan_label(id)
		if is_ren(id):
			label = "Tu plan con %s · %s" % [guest_names(id), label]
		elif said_yes(id):
			label = "Has quedado · " + label
		elif p.has("invite"):
			label = "Sin contestar · " + label
		out.append(label)
	return out
