class_name ChapterDB
extends RefCounted
## Guion del capítulo 1: los pasos del primer día y los planes de los siguientes.
##
## Cada paso tiene un objetivo (se avisa con un toast), un destino y las escenas
## que se reproducen al llegar. Mientras hay un paso activo
## (`GameState.story_step`), solo se puede viajar al destino, no aparecen
## personajes sueltos por el mapa y no hay combates.
##
## Escenas: {cue, npc} = conversación con `npc` a la derecha (y quien hable se
## turna en ese retrato); {cue, black = true} = narración sobre negro.
## `cast` = quién está en la escena: son los que reaccionan a las opciones de Ren.
## `advance_time` = al terminar pasa a la franja siguiente del día (es una actividad).
## `end_day` = al terminar, Ren se duerme y empieza el día siguiente.

## Cue con el que despierta Ren el primer día (en vez de la intro de rutina).
const START_CUE := "dia1_despertar"
const FIRST_STEP := "dia1_instituto"

const STEPS := {
	"dia1_instituto": {
		"objective": "Ve al instituto",
		"target": "instituto",
		"cast": ["kenji", "yuna", "rika", "shiori"],
		"scenes": [
			{"cue": "dia1_clase", "npc": "kenji"},
			{"cue": "dia1_clase_fundido", "black": true},
			{"cue": "dia1_clase_salida", "npc": "rika"},
		],
		"next": "dia1_parquesur",
		"advance_time": true,   # clase: mañana → día
	},
	"dia1_parquesur": {
		"objective": "Ve a Westfield Parquesur con el grupo",
		"target": "galeria",
		"cast": ["kenji", "yuna", "rika", "shiori"],
		"scenes": [
			{"cue": "dia1_camas", "npc": "kenji"},
			{"cue": "dia1_camas_fundido", "black": true},
			{"cue": "dia1_despedida", "npc": "kenji"},
		],
		"next": "dia1_casa",
		"advance_time": true,   # camas elásticas: día → tarde
	},
	"dia1_casa": {
		"objective": "Vuelve a casa",
		"target": "casa",
		"cast": ["madre_ren"],
		"scenes": [
			{"cue": "dia1_casa", "npc": ""},
		],
		"next": "",
		"end_day": true,
	},
}


static func step(id: String) -> Dictionary:
	return STEPS.get(id, {})


# --- Planes (no obligatorios) ------------------------------------------------------------
#
# Después del día 1 el juego es libre. Cada día hay planes que alguien propone
# (mensaje al móvil por la mañana y aviso «Planes de hoy»). Ninguno es
# obligatorio: si Ren va a `target` en una de las franjas `slots` (sin `slots`,
# cualquiera menos la noche) el día `day` (sin `day`, cualquiera), se juegan sus
# escenas, como en los pasos del guion. Cada plan se hace una vez.
#   phase / before_phase  solo desde esa fase / antes de esa fase
#   invite                quién lo propone y cómo (ver Invites):
#                           from, text  mensaje que lo propone
#                           via         "mensaje" (por defecto) o "persona": te lo
#                                       propone al hablar con él o en otra escena
#                           at          franja en la que llega el mensaje (sin `at`, por
#                                       la mañana); en persona, la última para proponerlo
#                                       en persona (sin `at`, la franja del plan)
#                           text_late   mensaje si iba a decírtelo en persona y no os visteis
#   missed_text           mensaje de quien invitó si Ren dijo que sí y no fue
#   cast                  quién está en la escena (reaccionan a las opciones)
#   advance_time          al terminar pasa a la franja siguiente (es una actividad)
#   sets_phase            al terminar, la historia avanza a esa fase

const PLANS := {
	# --- Día 2 (martes) ---
	"clase_martes": {
		"title": "Matemáticas II", "day": 2, "slots": ["manana"], "target": "instituto",
		"cast": ["kenji", "yuna", "rika", "shiori"],
		"scenes": [
			{"cue": "dia2_clase", "npc": "rika"},
			{"cue": "dia2_clase_fundido", "black": true},
		],
		"invite": {"from": "rika", "text": "¿Vienes a mates? Necesito que alguien me sople lo de las derivadas. Del uno al quince, Ren. DEL UNO AL QUINCE."},
		"missed_text": "¿Me dices que vienes y no vienes? Me ha sacado a la pizarra, Ren. A MÍ. Delante de todos.",
		"advance_time": true,
	},
	"charla_shiori": {
		"title": "Charla de leyendas urbanas", "day": 2, "slots": ["dia"], "target": "campus",
		"cast": ["shiori"],
		"scenes": [{"cue": "dia2_charla", "npc": "shiori"}],
		"invite": {"from": "shiori", "text": "Hoy a mediodía hay una charla en Egaleo: «Leyendas del sur de Madrid». Quedan sillas libres. No es una invitación. Es información."},
		"missed_text": "Dijiste que vendrías. He guardado la silla de al lado hasta que empezó. Luego se ha sentado un señor que olía a sopa.",
		"advance_time": true,
	},
	"bowls": {
		"title": "Patinar en Bowls", "day": 2, "slots": ["tarde"], "target": "parque",
		"cast": ["kenji", "yuna", "akane"],
		"scenes": [{"cue": "dia2_bowls", "npc": "kenji"}],
		"invite": {"from": "kenji", "text": "Esta tarde, Bowls. Traigo el patín y el altavoz. Viene Yuna. No acepto un no por respuesta."},
		"missed_text": "Loco, ¿dónde estás? Te hemos guardado un bocadillo. Bueno, ya no. Pero te lo guardamos.",
		"advance_time": true,
	},
	# --- Día 3 (miércoles) ---
	"clase_miercoles": {
		"title": "Clase (dicen que hay examen sorpresa)", "day": 3, "slots": ["manana"], "target": "instituto",
		"cast": ["kenji", "yuna", "rika", "shiori"],
		"scenes": [{"cue": "dia3_clase", "npc": "shiori"}],
		"invite": {"from": "shiori", "text": "Hoy hay examen sorpresa en mates. Lo sé porque la profesora lleva dos días sin sonreír. Tú verás."},
		"missed_text": "El examen no contaba, pero tu silla vacía sí la ha visto todo el mundo. Te dije que había examen.",
		"advance_time": true,
	},
	"voley_colinas": {
		"title": "Vóley en Colinas", "day": 3, "slots": ["dia"], "target": "plaza",
		"cast": ["rika", "yuna", "kenji"],
		"scenes": [{"cue": "dia3_voley", "npc": "rika"}],
		"invite": {"from": "rika", "text": "Vóley en Colinas a la hora de comer. Nos falta uno. Adivina quién es ese uno."},
		"missed_text": "Hemos jugado dos contra uno. Ha ganado Kenji. KENJI, Ren. No te lo perdono en la vida. Bueno, hasta el viernes.",
		"advance_time": true,
	},
	"recreativas": {
		"title": "Recreativas con Akane", "day": 3, "slots": ["tarde"], "target": "galeria",
		"cast": ["akane"],
		"scenes": [{"cue": "dia3_recreativas", "npc": "akane"}],
		"invite": {"from": "akane", "text": "Esta tarde estoy en las recres. Si vienes, la primera partida va por mí. Las demás no."},
		"missed_text": "La ficha sigue en el mostrador. Tú no has venido. Vale.",
		"advance_time": true,
	},
	# --- Día 4 (jueves): hay que elegir. A mediodía, por la tarde y por la noche
	# coinciden dos planes; se puede decir que sí a los dos, pero solo se va a uno.
	"clase_jueves": {
		"title": "Clase de Historia", "day": 4, "slots": ["manana"], "target": "instituto",
		"cast": ["kenji", "yuna", "rika", "shiori"],
		"scenes": [
			{"cue": "dia4_clase", "npc": "shiori"},
			{"cue": "dia4_clase_fundido", "black": true},
		],
		"invite": {"from": "rika", "text": "Hoy Historia a primera. Si no vienes, me toca sentarme con Shiori y me corrige hasta cómo cojo el boli."},
		"missed_text": "Me he sentado con Shiori. Me ha corregido cómo cojo el boli. Esto es culpa tuya, cielo.",
		"advance_time": true,
	},
	"hemeroteca_shiori": {
		"title": "Hemeroteca con Shiori", "day": 4, "slots": ["dia"], "target": "campus",
		"cast": ["shiori"],
		"scenes": [{"cue": "dia4_hemeroteca", "npc": "shiori"}],
		"invite": {"from": "shiori", "via": "persona",
			"text": "A mediodía estoy en la hemeroteca del campus. Hay algo que quiero enseñarte. A ti.",
			"text_late": "Iba a decírtelo en clase, pero no has venido. A mediodía estoy en la hemeroteca del campus. Quiero enseñarte una cosa. A ti, concretamente."},
		"missed_text": "Te he guardado sitio hasta las dos y cuarto. Luego he dejado de guardarlo. Lo he apuntado.",
		"advance_time": true,
	},
	"lago_yuna": {
		"title": "Comer en Westlake con Yuna", "day": 4, "slots": ["dia"], "target": "lago",
		"cast": ["yuna"],
		"scenes": [{"cue": "dia4_lago", "npc": "yuna"}],
		"invite": {"from": "yuna", "text": "¿Comemos hoy en Westlake? He hecho tortilla para dos y Kenji está con su abuela. Quiero hablar contigo de una cosa. Nada malo."},
		"missed_text": "Me he comido la tortilla entera. Sola. Mirando el lago. No pasa nada. Bueno, un poco sí.",
		"advance_time": true,
	},
	"parque_kenji": {
		"title": "Parque sin móvil con Kenji", "day": 4, "slots": ["tarde"], "target": "parque",
		"cast": ["kenji"],
		"scenes": [{"cue": "dia4_parque", "npc": "kenji"}],
		"invite": {"from": "kenji", "via": "persona", "at": "dia",
			"text": "Esta tarde, parque de la Ribera. Sin móviles. Como cuando éramos críos.",
			"text_late": "Socio, te lo iba a decir en clase. Esta tarde, parque de la Ribera. Sin móviles, como cuando éramos críos. Ven, que hace falta."},
		"missed_text": "Te he esperado en el parque. Sin móvil, como dijimos. Por eso no te escribo hasta ahora. Hora y media, Ren.",
		"advance_time": true,
	},
	"tiendas_rika": {
		"title": "Tarde de tiendas con Rika", "day": 4, "slots": ["tarde"], "target": "galeria",
		"cast": ["rika"],
		"scenes": [{"cue": "dia4_tiendas", "npc": "rika"}],
		"invite": {"from": "rika", "at": "dia", "text": "EMERGENCIA. Necesito una opinión sincera sobre un vestido. Esta tarde, Parquesur. Tú eres sincero. Demasiado a veces. Perfecto."},
		"missed_text": "Me he comprado el vestido sin opinión sincera. Si es horroroso, la culpa es tuya. Y te he esperado en la puerta como una tonta.",
		"advance_time": true,
	},
	"concierto_akane": {
		"title": "Concierto de Akane", "day": 4, "slots": ["noche"], "target": "estacion",
		"cast": ["akane"],
		"scenes": [{"cue": "dia4_concierto", "npc": "akane"}],
		"invite": {"from": "akane", "via": "persona", "at": "tarde",
			"text": "Esta noche tocamos en el garito de debajo de la estación de Zarzaquemada.",
			"text_late": "Esta noche tocamos en el garito de debajo de la estación. A las diez. No te estoy invitando. Te estoy informando."},
		"missed_text": "Te he buscado entre la gente. Tres canciones. Luego he dejado de buscar.",
	},
	"cena_mama": {
		"title": "Cena con mamá", "day": 4, "slots": ["noche"], "target": "casa",
		"cast": ["madre_ren"],
		"scenes": [{"cue": "dia4_cena", "npc": "madre_ren"}],
		"invite": {"from": "madre_ren", "via": "persona", "at": "tarde",
			"text": "Esta noche cenamos juntos, ¿vale? Hago la tortilla de papá.",
			"text_late": "Cariño, esta noche cenamos juntos, ¿te parece? Hago la tortilla de papá. La de cebolla."},
		"missed_text": "Te he dejado la tortilla tapada en la nevera. Ya la cenamos otro día, cariño. No pasa nada.",
	},
	# --- Tras la primera incursión (cualquier día) ---
	"reunion_cloacas": {
		"title": "Reunión en las Cloacas", "target": "cloacas",
		"phase": "incursion_1", "before_phase": "reunion",
		"cast": ["kenji", "yuna", "rika", "shiori", "akane"],
		"scenes": [
			{"cue": "reunion_cloacas", "npc": "kenji"},
			{"cue": "reunion_cloacas_fin", "black": true},
		],
		"invite": {"from": "kenji", "text": "Reunión. En las Cloacas, donde la cascada. Rika está avisando a todo el mundo. Ven cuando puedas, pero ven."},
		"advance_time": true,
		"sets_phase": "reunion",
	},
}

## Escena extra de la mañana de algunos días, después del despertar (`intro`).
const MORNINGS := {
	4: {"cue": "dia4_desayuno", "npc": "madre_ren"},
}

## Mensajes sueltos que llegan un día a una franja (una vez). `if` / `unless`:
## solo si ese flag está (o no está) puesto.
const MESSAGES := [
	{"day": 4, "slot": "dia", "from": "madre_ren",
		"text": "¿Has comido? Y no me digas que un Chocopolvo, que la madre de Kenji ya me ha contado lo de su hijo."},
	{"day": 4, "slot": "tarde", "from": "madre_ren", "if": "plan_si:cena_mama",
		"text": "Si llegas antes que yo, pela tres patatas. Tres, Ren. No una y media."},
	{"day": 4, "slot": "tarde", "from": "madre_ren", "unless": "plan_si:cena_mama",
		"text": "Pásalo bien esta noche, cariño. Yo me pongo la serie de los médicos y me quedo frita en el sofá. Lo normal."},
]

const PLAN_DONE := "plan_hecho:"
const PLAN_INVITED := "plan_invitado:"


static func plan(id: String) -> Dictionary:
	return PLANS.get(id, {})


## ¿Se puede hacer hoy el plan `id`? (día, fase y que no esté hecho; la franja aparte)
static func plan_available(id: String) -> bool:
	var p := plan(id)
	if p.is_empty() or GameState.get_flag(PLAN_DONE + id) or GameState.story_step != "":
		return false
	if p.has("day") and GameState.day_number() != int(p.day):
		return false
	if p.has("phase") and not GameState.phase_at_least(p.phase):
		return false
	if p.has("before_phase") and GameState.phase_at_least(p.before_phase):
		return false
	return true


static func plan_in_slot(id: String, slot: String) -> bool:
	var slots: Array = plan(id).get("slots", [])
	return slot in slots if not slots.is_empty() else slot != "noche"


## Planes que quedan hoy (aún se puede llegar a su franja).
static func plans_today() -> Array[String]:
	var out: Array[String] = []
	for id: String in PLANS:
		if not plan_available(id):
			continue
		var slots: Array = plan(id).get("slots", [])
		var later := slots.is_empty()
		for s: String in slots:
			if GameState.TIME_SLOTS.map(func(t: Dictionary) -> String: return t.id).find(s) >= GameState.time_slot:
				later = true
		if later:
			out.append(id)
	return out


## Plan que empieza al llegar ahora a `location_id` ("" si no hay).
static func plan_at(location_id: String) -> String:
	for id: String in PLANS:
		if plan(id).target == location_id and plan_available(id) and plan_in_slot(id, GameState.slot_id()):
			return id
	return ""


## «Bowls (tarde)»: para el aviso de planes del día.
static func plan_label(id: String) -> String:
	var p := plan(id)
	var slots: Array = p.get("slots", [])
	var names: Array = slots.map(func(s: String) -> String:
		for t: Dictionary in GameState.TIME_SLOTS:
			if t.id == s:
				return String(t.name).to_lower()
		return s)
	var where := LocationDB.display_name(p.target)
	return "%s · %s%s" % [p.title, where, (" (%s)" % ", ".join(names)) if not names.is_empty() else ""]
