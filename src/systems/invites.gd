class_name Invites
extends RefCounted
## Invitaciones a planes (ChapterDB.PLANS): quién propone, cómo, qué contesta Ren
## y qué pasa si dice que sí y no aparece.
##
## - Por mensaje (`invite.via` = "mensaje", por defecto): llega al móvil por la
##   mañana o al empezar la franja `invite.at`. Se contesta desde el chat.
## - En persona (`invite.via` = "persona"): queda «por proponer» y se lo propone
##   cuando Ren habla con él (regla `flag por_proponer:<plan>` en su .dialogue) o
##   dentro de otra escena. Si no se ha visto a tiempo (al empezar la franja del
##   plan o `invite.at`), llega por mensaje.
## - Respuestas: «sí», «no» o «ya he quedado para X» (si X es otro plan aceptado
##   de hoy que coincide en alguna franja). Ninguna es excluyente: se puede decir
##   que sí a dos planes a la misma hora; luego habrá que elegir.
## - Plantón: si dijo que sí y la franja del plan pasa sin ir, baja la relación,
##   llega `missed_text` al móvil y queda un reproche pendiente. Si Ren contesta al
##   mensaje, se cierra ahí; si no, se lo dicen en persona (regla
##   `flag reproche:<plan>` en el .dialogue de quien invitó).
##
## Todo se guarda en flags de GameState (las reglas `# cuando:` los leen):
##   plan_invitado:<id>  ya se lo han propuesto       plan_hecho:<id>  ha ido
##   por_proponer:<id>   lo propondrá en persona      plan_si / plan_no / plan_otro:<id>
##   plan_plantado:<id>  dijo que sí y no fue         reproche:<id>    reproche sin contestar

const SAID_YES := "plan_si:"
const SAID_NO := "plan_no:"
const SAID_OTHER := "plan_otro:"
const PENDING := "por_proponer:"
const MISSED := "plan_plantado:"
const REPROACH := "reproche:"

## Lo que pasa con la relación de quien invita (valores provisionales).
const ACCEPT_GAIN := {"afecto": 1.0}
const MISSED_COST := {"afecto": -5.0, "confianza": -4.0, "resentimiento": 3.0}
## Contestar al reproche por mensaje suaviza el golpe.
const REPLY_EFFECT := {
	"perdon": {"resentimiento": -2.0, "afecto": 1.0},
	"otro": {"resentimiento": -1.0, "confianza": 1.0},
	"olvido": {"resentimiento": 1.0},
}

## Contexto de la respuesta que se está reproduciendo (lo leen Story.plan_*).
static var current_plan := ""
static var current_reply := ""
static var other_plan := ""


# --- Estado ------------------------------------------------------------------------------

static func inviter(plan_id: String) -> String:
	return ChapterDB.plan(plan_id).get("invite", {}).get("from", "")


static func invited(plan_id: String) -> bool:
	return GameState.get_flag(ChapterDB.PLAN_INVITED + plan_id)


static func answered(plan_id: String) -> bool:
	return GameState.get_flag(SAID_YES + plan_id) or GameState.get_flag(SAID_NO + plan_id) \
			or GameState.get_flag(SAID_OTHER + plan_id)


static func said_yes(plan_id: String) -> bool:
	return GameState.get_flag(SAID_YES + plan_id)


static func done(plan_id: String) -> bool:
	return GameState.get_flag(ChapterDB.PLAN_DONE + plan_id)


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


## Planes aceptados de hoy que coinciden con `plan_id` (para «ya he quedado»).
static func conflicts(plan_id: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in ChapterDB.PLANS:
		if id != plan_id and said_yes(id) and not done(id) and overlap(id, plan_id):
			out.append(id)
	return out


## ¿Se le puede contestar todavía? (sigue disponible hoy)
static func _still_open(plan_id: String) -> bool:
	if not ChapterDB.plan_available(plan_id):
		return false
	var last: int = _slots(plan_id).max()
	return GameState.time_slot <= last


# --- Propuestas ---------------------------------------------------------------------------

## Entrega lo que toca a esta hora: invitaciones por mensaje cuya franja `at` ya ha
## llegado y las de «en persona» que nadie ha propuesto a tiempo. Devuelve quién
## ha escrito (para avisar).
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
		if GameState.get_flag(key) or int(m.day) != GameState.day_number() or _slot_index(m.slot) > GameState.time_slot:
			continue
		if (m.has("if") and not GameState.get_flag(m["if"])) or (m.has("unless") and GameState.get_flag(m.unless)):
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


# --- Plantones ------------------------------------------------------------------------------

## Planes aceptados cuya franja ya ha pasado sin ir: baja la relación, llega el
## reproche al móvil y queda pendiente. Llamar al pasar de franja y cada mañana.
## Devuelve quién ha escrito.
static func check_missed() -> Array[String]:
	var senders: Array[String] = []
	var today := GameState.day_number()
	for id: String in ChapterDB.PLANS:
		var p := ChapterDB.plan(id)
		if not p.has("day") or not said_yes(id) or done(id) or GameState.get_flag(MISSED + id):
			continue
		var day := int(p.day)
		if day > today or (day == today and GameState.time_slot <= int(_slots(id).max())):
			continue
		var who := inviter(id)
		GameState.set_flag(MISSED + id)
		GameState.set_flag(REPROACH + id)
		Social.change(who, CharacterDB.PROTAGONIST, MISSED_COST, 1.0, "plan_plantado")
		GameState.record("plan_plantado", CharacterDB.PROTAGONIST, who, {"plan": id})
		var text: String = p.get("missed_text", "")
		if text != "":
			GameState.add_message(who, who, text)
			if not senders.has(who):
				senders.append(who)
	return senders


## Ren contesta por el móvil al reproche: "perdon" | "otro" (estaba en otro plan) | "olvido".
static func reply_reproach(plan_id: String, kind: String) -> void:
	GameState.flags.erase(REPROACH + plan_id)
	Social.change(inviter(plan_id), CharacterDB.PROTAGONIST, REPLY_EFFECT.get(kind, {}), 1.0, "plan_plantado")


## Plan de hoy que Ren hizo en vez de `plan_id` (coincidían de hora), o "".
static func done_instead(plan_id: String) -> String:
	for id: String in ChapterDB.PLANS:
		if id != plan_id and done(id) and overlap(id, plan_id):
			return id
	return ""


# --- Móvil --------------------------------------------------------------------------------

## Lo que `contact` espera que Ren conteste por el móvil: {kind: "invite"|"reproche", plan}
## o {} si nada. Primero los reproches.
static func pending_question(contact: String) -> Dictionary:
	for id: String in ChapterDB.PLANS:
		if inviter(id) == contact and GameState.get_flag(REPROACH + id):
			return {"kind": "reproche", "plan": id}
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
		reply_reproach(q.plan, option.reply)
	var own := "%s_movil_%s" % [contact, cue_kind]
	return Story.cue(own if Story.has_cue(own) else "movil_" + cue_kind)


## Avisos de los planes de hoy para el toast: los propuestos que siguen en pie.
static func agenda() -> Array[String]:
	var out: Array[String] = []
	for id in ChapterDB.plans_today():
		if ChapterDB.plan(id).has("invite") and not invited(id):
			continue
		if GameState.get_flag(SAID_NO + id) or GameState.get_flag(SAID_OTHER + id):
			continue
		var label := ChapterDB.plan_label(id)
		if said_yes(id):
			label = "Has quedado · " + label
		elif ChapterDB.plan(id).has("invite"):
			label = "Sin contestar · " + label
		out.append(label)
	return out
