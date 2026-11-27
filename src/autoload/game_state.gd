extends Node
## Estado global de la partida en curso.
##
## Región, fecha, dinero, ubicación, punto de la historia, indicadores,
## registro de acontecimientos, relaciones y ánimo (ver Social). Se guarda en SAVE_PATH.
## Las mecánicas de naturalezas/asimilación (ver docs/diseno) vivirán en
## sistemas propios.

signal changed

const WEEKDAYS_SHORT := ["DOM", "LUN", "MAR", "MIÉ", "JUE", "VIE", "SÁB"]
const MONTHS_SHORT := ["ENE", "FEB", "MAR", "ABR", "MAY", "JUN", "JUL", "AGO", "SEP", "OCT", "NOV", "DIC"]

const START_REGION := "Leganés"
## Lunes: el capítulo 1 empieza con un día de clase.
const START_DATE := {"year": 2026, "month": 11, "day": 16}
const START_MONEY := 12460

var region_name: String = START_REGION
var date: Dictionary = START_DATE.duplicate()
var money: int = START_MONEY
## Franja del día actual (índice de TIME_SLOTS).
var time_slot := 0
## Ubicación actual (ver LocationDB). Empieza en casa.
var location_id: String = LocationDB.HOME
## Relaciones: de -> a -> dimensión -> valor. Las gestiona Social.
var relations: Dictionary = {}
## Ánimo de cada personaje: id -> {id, intensity}. Lo gestiona Social.
var moods: Dictionary = {}
## Inventario del grupo: id de objeto (ItemDB) -> cantidad.
var inventory: Dictionary = START_INVENTORY.duplicate()
## Conversaciones del móvil: id del contacto -> [{from, text, time, date}], de la más antigua
## a la más reciente. Un contacto aparece en Mensajes desde su primer mensaje.
var messages: Dictionary = {}
## Progreso en cada mazmorra: id del mapa -> estado de DungeonExplorer (puertas,
## enemigos vencidos, objetos cogidos, casillas visitadas).
var dungeons: Dictionary = {}
## Nivel y experiencia de Ren y los compañeros: id -> {level, xp} (xp = la que
## lleva dentro del nivel actual). Sin entrada = nivel de su ficha, 0 EXP.
var levels: Dictionary = {}
## Atributos entrenados con actividades: id -> {atributo: puntos} (fase de preparación).
var stat_bonus: Dictionary = {}
## Quiénes entran con Ren en la grieta (elegidos antes de entrar; ChapterDB.EXPEDITION).
## Vacío = mazmorra con un compañero al azar (La Torre).
var expedition: Array = []
## Planes que propone Ren (Invites): "ren:N" -> {activity, day, slot, guests: {id: "si"}}.
var ren_plans: Dictionary = {}

const START_INVENTORY := {"pochicola": 3}

## Puntos de la historia, en orden. Los diálogos comparan con `phase_at_least`.
const PHASES: Array[String] = [
	"rutina",         ## Día normal: nadie sabe nada de las criaturas.
	"incursion_1",    ## Tras la primera incursión.
	"reunion",        ## Tras la reunión del grupo en las Cloacas (ChapterDB.PLANS).
	# Resto del capítulo 1 (ver docs/diseno/capitulo_1_hoja_de_ruta.md); aún sin contenido.
	"incursion_2",    ## Tras la segunda incursión.
	"incursion_3",    ## Tras la tercera incursión.
	"grieta",         ## Han encontrado la grieta y se han asomado: preparación.
	"exploracion_1",  ## Tras la primera exploración (retirada forzada).
	"escaner",        ## Tienen el escáner; se abre el Pidl.
	"captura",        ## Tienen el dispositivo de captura.
	"jefe_1",         ## Jefe de la primera mazmorra vencido: fin del capítulo 1.
]

## Franjas del día. Las actividades (ir a clase, las camas elásticas, una
## siesta...) pasan a la siguiente; de noche a mañana cambia el día. `hour` es la
## hora con la que se ilumina el mapa (ver MapConfig.light_at).
const TIME_SLOTS := [
	{"id": "manana", "name": "Mañana", "hour": 8.0},
	{"id": "dia", "name": "Día", "hour": 13.0},
	{"id": "tarde", "name": "Tarde", "hour": 19.5},
	{"id": "noche", "name": "Noche", "hour": 23.0},
]
const WEEKDAYS_LONG := ["Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"]

const SAVE_PATH := "user://partida.json"
const SAVE_VERSION := 1

## Punto actual de la historia (uno de PHASES).
var phase: String = PHASES[0]
## Indicadores de historia: nombre -> valor (bool, número o texto).
var flags: Dictionary = {}
## Parejas: id -> id, en los dos sentidos (ver Romance). Kenji y Yuna empiezan juntos.
var partners: Dictionary = {}
## Secretos de Ren (ver Lies): [{target, events, lied, accomplices}].
var secrets: Array = []
## Qué ha pasado y quién lo sabe.
var events := EventLog.new()
## La introducción ya se ha visto (al continuar partida no se repite).
var intro_done := false
## Paso del guion en curso (ver ChapterDB). Vacío = juego libre.
var story_step := ""
## Quién está en la escena de un plan en curso (ChapterDB.PLANS), para que
## reaccionen a las opciones de Ren (Social.present). No se guarda.
var scene_cast: Array = []

## Primera incursión (suceso `incursion_1` de ChapterDB.BEATS): aparece una de
## estas criaturas, elegida al azar al empezar cada partida.
const INCURSION_ENEMIES: Array[String] = ["tiranosaurio", "oni"]

var incursion_enemy := ""
var incursion_done := false
## El primer combate contra una criatura se hace con un compañero.
var first_creature_fight_done := false
## Gente que Ren va conociendo: id -> "presentado" | "amigo" (ver Acquaintance).
var acquaintance: Dictionary = {}


func _ready() -> void:
	relations = Social.initial_relations()
	moods = Social.initial_moods()
	_reset_incursion()


func new_game() -> void:
	region_name = START_REGION
	date = START_DATE.duplicate()
	money = START_MONEY
	time_slot = 0
	location_id = LocationDB.HOME
	relations = Social.initial_relations()
	moods = Social.initial_moods()
	inventory = START_INVENTORY.duplicate()
	messages = {}
	dungeons = {}
	levels = {}
	stat_bonus = {}
	expedition = []
	ren_plans = {}
	phase = PHASES[0]
	flags = {}
	partners = Romance.START_PARTNERS.duplicate()
	secrets = []
	events = EventLog.new()
	# Kenji y Yuna ya salen al empezar: lo sabe todo el que los conoce.
	for a: String in partners:
		if a < partners[a]:
			RelationEvents.record_couple(a, partners[a], CharacterDB.with_profile())
	acquaintance = {}
	intro_done = false
	story_step = ChapterDB.FIRST_STEP
	_reset_incursion()
	changed.emit()


func _reset_incursion() -> void:
	incursion_enemy = INCURSION_ENEMIES.pick_random()
	incursion_done = false
	first_creature_fight_done = false


func set_location(id: String) -> void:
	location_id = id
	changed.emit()


func item_count(item_id: String) -> int:
	return inventory.get(item_id, 0)


func add_item(item_id: String, count: int = 1) -> void:
	inventory[item_id] = item_count(item_id) + count
	changed.emit()


# --- Niveles y experiencia (fórmulas en ProgressionDB) -------------------------------

## Quiénes suben de nivel: Ren y los compañeros que pueden luchar con él.
static func levelled_ids() -> Array[String]:
	var out: Array[String] = [CharacterDB.PROTAGONIST]
	out.append_array(CharacterDB.COMPANIONS)
	return out


func level_of(id: String) -> int:
	if levels.has(id):
		return levels[id].level
	return maxi(int(CharacterDB.get_character(id).get("combat", {}).get("level", 1)), 1)


func xp_of(id: String) -> int:
	return levels.get(id, {}).get("xp", 0)


## Suma EXP a `id` y sube los niveles que toque. Devuelve {id, xp, from, to}.
func add_xp(id: String, amount: int) -> Dictionary:
	var from := level_of(id)
	var lv := from
	var xp := xp_of(id) + maxi(amount, 0)
	var gains: Dictionary = levels.get(id, {}).get("gains", {})
	var random_growth: bool = str(CharacterDB.get_character(id).get("combat", {}).get("growth", "")) == ProgressionDB.RANDOM_GROWTH
	while lv < ProgressionDB.MAX_LEVEL and xp >= ProgressionDB.xp_to_next(lv):
		xp -= ProgressionDB.xp_to_next(lv)
		lv += 1
		if random_growth:
			_roll_gains(id, gains)
	if lv >= ProgressionDB.MAX_LEVEL:
		xp = 0
	levels[id] = {"level": lv, "xp": xp, "gains": gains}
	changed.emit()
	return {"id": id, "xp": amount, "from": from, "to": lv}


## Subida de nivel de quien crece al azar (Ren): RANDOM_GAINS_PER_LEVEL puntos
## en atributos distintos, elegidos al azar.
func _roll_gains(id: String, gains: Dictionary) -> void:
	var attrs: Array = CharacterDB.get_character(id).get("combat", {}).get("stats", {}).keys()
	attrs.shuffle()
	for attr: String in attrs.slice(0, ProgressionDB.RANDOM_GAINS_PER_LEVEL):
		gains[attr] = int(gains.get(attr, 0)) + 1


## Puntos de atributo que no salen de la fórmula: los de subir al azar y los entrenados.
func stat_extras(id: String) -> Dictionary:
	var out: Dictionary = levels.get(id, {}).get("gains", {}).duplicate()
	var trained: Dictionary = stat_bonus.get(id, {})
	for attr: String in trained:
		out[attr] = int(out.get(attr, 0)) + int(trained[attr])
	return out


## Sube a `id` justo al nivel siguiente (la primera incursión).
func level_up(id: String) -> Dictionary:
	return add_xp(id, ProgressionDB.xp_to_next(level_of(id)) - xp_of(id))


## Reparte `amount` a quienes participan (`ids`), FALLEN_SHARE a los que han
## caído (`fallen`) y a los que no estaban su parte según su afecto por Ren
## (ProgressionDB.bench_share). Devuelve los resultados (add_xp), participantes primero.
func grant_xp(ids: Array, amount: int, fallen: Array = []) -> Array:
	var out: Array = []
	for id: String in ids:
		if id in levelled_ids():
			out.append(add_xp(id, amount))
	for id: String in fallen:
		if id in levelled_ids():
			out.append(add_xp(id, roundi(amount * ProgressionDB.FALLEN_SHARE)))
	for id: String in levelled_ids():
		var share := roundi(amount * ProgressionDB.bench_share(id))
		if not id in ids and not id in fallen and share > 0:
			out.append(add_xp(id, share))
	return out


## Texto de las subidas de nivel de unos resultados de grant_xp ("" si no hay).
static func level_up_text(results: Array) -> String:
	var parts: Array[String] = []
	for r: Dictionary in results:
		if r.to > r.from:
			parts.append("¡%s sube al nivel %d!" % [CharacterDB.display_name(r.id), r.to])
	return "  ".join(parts)


## Estado guardado de la mazmorra `map_id` (se crea vacío; se modifica en sitio).
func dungeon_state(map_id: String) -> Dictionary:
	if not dungeons.has(map_id):
		dungeons[map_id] = {}
	return dungeons[map_id]


func use_item(item_id: String) -> bool:
	if item_count(item_id) <= 0:
		return false
	inventory[item_id] = item_count(item_id) - 1
	return true


## Abre una caja del inventario (ItemDB `loot`): se gasta y da lo que trae.
## Devuelve lo conseguido como texto («Batería del escáner, Pochicola ×2»),
## o "" si no había caja.
func open_box(item_id: String) -> String:
	if not ItemDB.is_box(item_id) or not use_item(item_id):
		return ""
	var got: Array[String] = []
	var contents: Array = ItemDB.get_item(item_id).get("loot_always", []).duplicate()
	var rolled := ItemDB.roll_loot(item_id)
	if not rolled.is_empty():
		contents.append([rolled.item, rolled.count])
	for e: Array in contents:
		var id: String = e[0]
		var n: int = e[1]
		if id == "money":
			add_money(n)
			got.append("¥ %d" % n)
		else:
			add_item(id, n)
			got.append(ItemDB.display_name(id) + (" ×%d" % n if n > 1 else ""))
	changed.emit()
	return ", ".join(got)


# --- Móvil ------------------------------------------------------------------------

## Añade un mensaje a la conversación con `contact` (`from` = quien lo escribe).
func add_money(amount: int) -> void:
	money += amount
	changed.emit()


func add_message(contact: String, from: String, text: String) -> void:
	# Quien no tiene el número de Ren no le escribe (ver Acquaintance).
	if not Acquaintance.is_friend(contact):
		return
	var t := Time.get_time_dict_from_system()
	if not messages.has(contact):
		messages[contact] = []
	messages[contact].append({"from": from, "text": text,
		"time": "%02d:%02d" % [t.hour, t.minute], "date": date.duplicate()})


## Contactos con conversación, de la más reciente a la más antigua.
func conversations() -> Array[String]:
	var out: Array[String] = []
	out.assign(messages.keys())
	out.sort_custom(func(a: String, b: String) -> bool:
		return _last_stamp(a) > _last_stamp(b))
	return out


func _last_stamp(contact: String) -> String:
	var list: Array = messages.get(contact, [])
	if list.is_empty():
		return ""
	var m: Dictionary = list.back()
	var d: Dictionary = m.date
	return "%04d%02d%02d%s" % [int(d.year), int(d.month), int(d.day), m.time]


# --- Historia ---------------------------------------------------------------------

func set_phase(id: String) -> void:
	assert(id in PHASES, "Fase desconocida: %s" % id)
	phase = id
	set_flag(PHASE_DAY + id, day_number())   # para los sucesos «N días después» (StoryBeats)
	changed.emit()


func phase_at_least(id: String) -> bool:
	return PHASES.find(phase) >= PHASES.find(id)


func set_flag(id: String, value: Variant = true) -> void:
	flags[id] = value


## `dia_N` no se guarda: es true si hoy es el día N de la partida (dia_1 = el
## primer lunes). Sirve en las reglas: «# cuando: hablar, flag dia_2». (Si hay
## un indicador guardado con ese nombre, manda él: así lo simula el editor web.)
func get_flag(id: String, default: Variant = false) -> Variant:
	if not flags.has(id) and id.begins_with(DAY_FLAG) and id.substr(DAY_FLAG.length()).is_valid_int():
		return day_number() == int(id.substr(DAY_FLAG.length()))
	return flags.get(id, default)


const DAY_FLAG := "dia_"
## Flag con el día en que empezó cada fase: «fase_dia:reunion» = 9.
const PHASE_DAY := "fase_dia:"


## Día de la partida: 1 el primer día (START_DATE), 2 el siguiente...
func day_number() -> int:
	return roundi((_date_to_unix(date) - _date_to_unix(START_DATE)) / 86400.0) + 1


## Atajo para registrar acontecimientos (ver EventLog.record).
func record(kind: String, actor: String, target: String = "", data: Dictionary = {},
		witnesses: Array = [], id: String = "") -> String:
	return events.record(kind, actor, target, data, witnesses, id)


# --- Guardado ---------------------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"region": region_name, "date": date, "time_slot": time_slot, "money": money,
		"location": location_id, "inventory": inventory, "messages": messages, "dungeons": dungeons,
		"levels": levels, "stat_bonus": stat_bonus, "expedition": expedition, "ren_plans": ren_plans,
		"relations": relations, "moods": moods,
		"phase": phase, "flags": flags, "partners": partners, "secrets": secrets, "events": events.to_dict(), "intro_done": intro_done,
		"story_step": story_step,
		"incursion": {"enemy": incursion_enemy, "done": incursion_done,
			"first_creature_fight_done": first_creature_fight_done},
		"acquaintance": acquaintance,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("No se pudo guardar la partida: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(data, "\t"))


func load_game() -> bool:
	if not has_save():
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not data is Dictionary:
		push_error("Partida guardada ilegible: %s" % SAVE_PATH)
		return false
	new_game()
	# JSON devuelve todos los números como float: se convierten a int.
	region_name = data.get("region", START_REGION)
	date = _ints(data.get("date", START_DATE))
	time_slot = int(data.get("time_slot", 0))
	money = int(data.get("money", START_MONEY))
	location_id = data.get("location", LocationDB.HOME)
	if LocationDB.get_location(location_id).is_empty():
		location_id = LocationDB.HOME   # ubicación borrada o renombrada en el editor del mapa
	relations = data.get("relations", relations)
	moods = data.get("moods", moods)
	inventory = _ints(data.get("inventory", START_INVENTORY))
	inventory.erase("resonador")   # partidas de antes del escáner (fase 6): se consigue en la grieta
	messages = data.get("messages", {})
	dungeons = data.get("dungeons", {})
	levels = {}
	for id: String in data.get("levels", {}):
		var v: Dictionary = data.levels[id]
		levels[id] = {"level": int(v.get("level", 1)), "xp": int(v.get("xp", 0)), "gains": _ints(v.get("gains", {}))}
	stat_bonus = {}
	for id: String in data.get("stat_bonus", {}):
		stat_bonus[id] = _ints(data.stat_bonus[id])
	expedition = data.get("expedition", [])
	ren_plans = {}
	var rp: Dictionary = data.get("ren_plans", {})
	for id: String in rp:
		var p: Dictionary = rp[id]
		ren_plans[id] = {"activity": p.activity, "day": int(p.day), "slot": p.slot, "guests": p.get("guests", {})}
	phase = data.get("phase", PHASES[0])
	flags = data.get("flags", {})
	partners = data.get("partners", partners)
	secrets = data.get("secrets", [])
	events = EventLog.from_dict(data.get("events", {}))
	intro_done = data.get("intro_done", false)
	story_step = data.get("story_step", "")
	var inc: Dictionary = data.get("incursion", {})
	incursion_enemy = inc.get("enemy", incursion_enemy)
	incursion_done = inc.get("done", false)
	first_creature_fight_done = inc.get("first_creature_fight_done", false)
	acquaintance = data.get("acquaintance", {})
	changed.emit()
	return true


static func _ints(d: Dictionary) -> Dictionary:
	var out := {}
	for k: String in d:
		out[k] = int(d[k])
	return out


func set_region(new_region: String) -> void:
	region_name = new_region
	changed.emit()


func advance_days(days: int = 1) -> void:
	var unix := _date_to_unix(date) + days * 86400
	var d := Time.get_datetime_dict_from_unix_time(unix)
	date = {"year": d.year, "month": d.month, "day": d.day}
	changed.emit()


# --- Franjas del día -------------------------------------------------------------------

func slot_id() -> String:
	return TIME_SLOTS[time_slot].id


func slot_name() -> String:
	return TIME_SLOTS[time_slot].name


func slot_hour() -> float:
	return TIME_SLOTS[time_slot].hour


## Pasa a la franja siguiente. Si era de noche, empieza la mañana del día
## siguiente: devuelve true en ese caso (para mostrar el cambio de día).
func advance_slot() -> bool:
	if time_slot == TIME_SLOTS.size() - 1:
		wake_up_next_day()
		return true
	time_slot += 1
	changed.emit()
	return false


## Mañana del día siguiente, sea la franja que sea.
func wake_up_next_day() -> void:
	time_slot = 0
	advance_days(1)


func weekday_long() -> String:
	var d := Time.get_datetime_dict_from_unix_time(_date_to_unix(date))
	return WEEKDAYS_LONG[d.weekday]


func weekday_short() -> String:
	var d := Time.get_datetime_dict_from_unix_time(_date_to_unix(date))
	return WEEKDAYS_SHORT[d.weekday]


func month_short() -> String:
	return MONTHS_SHORT[int(date.month) - 1]


func _date_to_unix(d: Dictionary) -> int:
	# Mediodía para evitar sorpresas en los límites del día.
	return Time.get_unix_time_from_datetime_dict({
		"year": d.year, "month": d.month, "day": d.day,
		"hour": 12, "minute": 0, "second": 0,
	})
