class_name Social
extends RefCounted
## Motor de reglas sociales: cómo les sienta a los personajes lo que hace Ren.
## Diseño en docs/diseno/personajes_y_relaciones.md.
##
## Todo va por detrás: nada de esto se muestra al jugador. Lo que cambia se nota
## después en cómo le hablan y le reciben.
##
## - Relaciones: GameState.relations[de][a][dimensión]. Tienen dirección.
## - Ánimo: GameState.moods[id] = {id, intensity}.
## - Reacciones: en la ficha de cada personaje (`reactions`). Cada entrada es un
##   diccionario de cambios ({"afecto": 2}) o, si depende del ánimo, uno por
##   ánimo con "default" como respaldo ({"default": {...}, "triste": {...}}).
## - Cansancio: se cuenta en el registro de acontecimientos cuántas veces ha
##   pasado lo mismo hoy con la misma persona.
## Los personajes sin ficha todavía no reaccionan.

const DIMENSIONS := {
	"afecto": Vector2(-100, 100), "confianza": Vector2(-100, 100), "respeto": Vector2(-100, 100),
	"atraccion": Vector2(0, 100), "miedo": Vector2(0, 100), "asco": Vector2(0, 100),
	"resentimiento": Vector2(0, 100),
}
## Dimensiones en las que subir es bueno para Ren (en las demás, lo malo es subir).
const GOOD_DIMENSIONS: Array[String] = ["afecto", "confianza", "respeto", "atraccion"]
const MOODS: Array[String] = ["alegre", "tranquilo", "curioso", "irritado", "ansioso", "triste"]
const NEGATIVE_MOODS: Array[String] = ["irritado", "ansioso", "triste"]

## Interacciones del menú (Hablar / Ligar / Luchar).
const INTERACTIONS: Array[String] = ["talk", "flirt", "fight"]
## Con un ánimo negativo de esta intensidad o más, no quiere hablar ni que le tiren los tejos.
const REFUSE_INTENSITY := 70
const REFUSABLE: Array[String] = ["talk", "flirt"]
## Rendimiento de la 1.ª, 2.ª y 3.ª interacción del día con la misma persona.
const REPEAT_FACTORS: Array[float] = [1.0, 0.5, 0.0]
## Las reacciones de quien solo está delante pesan menos.
const OBSERVER_WEIGHT := 0.5
## Intentos extra que se aguantan según la acción (hablar cansa menos que ligar).
const TOLERANCE_BONUS := {"talk": 1}

## Etiqueta de las opciones que mencionan a alguien: [#alude=rika].
const MENTION_TAG := "alude"
## Etiqueta de las opciones «por persona»: la opción se repite una vez por cada
## personaje que cumpla los filtros, con {persona} sustituido por su nombre.
##   - Tuve una cita con {persona}. [#persona, #afecto>=25, #genero=mujer, #joven, #bromista]
## Filtros (todos opcionales; nunca salen Ren ni quien acaba de hablar ni el interlocutor):
##   afecto>=25 (cualquier dimensión de lo que siente por Ren; =, !=, <, >, <=, >=)
##   tramo>=cercana · genero=mujer|hombre · joven · adulto · edad<=45 (identity.age;
##   quien no tiene edad en la ficha no cumple) · entre=rika|akane
##   presente · ausente
const PERSON_TAG := "persona"
const PERSON_WORDS: Array[String] = ["joven", "adulto", "presente", "ausente"]
const PERSON_KEYS: Array[String] = ["genero", "entre", "tramo", "edad"]

const OK := "ok"
const TIRED := "tired"        ## Se ha hartado: «bueno, ya, ¿no?»
const REFUSED := "refused"    ## Mal día: no quiere hablar


# --- Estado inicial -----------------------------------------------------------------

static func initial_relations() -> Dictionary:
	var rel := {}
	for id in CharacterDB.with_profile():
		rel[id] = {}
		var start: Dictionary = CharacterDB.profile(id).get("relationships", {})
		for other: String in start:
			rel[id][other] = _with_defaults(start[other])
	return rel


static func initial_moods() -> Dictionary:
	var moods := {}
	for id in CharacterDB.with_profile():
		var m: Dictionary = CharacterDB.profile(id).get("mood", {}).get("initial", {})
		moods[id] = {"id": m.get("id", "tranquilo"), "intensity": m.get("intensity", 30)}
	return moods


# --- Consultas ---------------------------------------------------------------------

## Lo que `from` siente por `to` (todas las dimensiones).
static func relation(from: String, to: String) -> Dictionary:
	return _with_defaults(GameState.relations.get(from, {}).get(to, {}))


static func value(from: String, to: String, dim: String) -> float:
	return relation(from, to).get(dim, 0.0)


## Tramo de la relación, para que los diálogos no lean números:
## "hostil", "fria", "neutral", "cercana" o "intima".
static func tier(from: String, to: String) -> String:
	var r := relation(from, to)
	var score: float = r.afecto - r.resentimiento - r.asco * 0.5
	if score < -40:
		return "hostil"
	if score < -10:
		return "fria"
	if score < 25:
		return "neutral"
	if score < 55:
		return "cercana"
	return "intima"


static func mood(id: String) -> Dictionary:
	return GameState.moods.get(id, {"id": "tranquilo", "intensity": 30})


static func set_mood(id: String, mood_id: String, intensity: float) -> void:
	GameState.moods[id] = {"id": mood_id, "intensity": clampf(intensity, 0.0, 100.0)}


## Quién está en la escena ahora mismo (Ren incluido).
static func present() -> Array:
	# Durante el guion y los planes, los presentes son los de la escena (ver ChapterDB).
	if not GameState.scene_cast.is_empty():
		return [CharacterDB.PROTAGONIST] + GameState.scene_cast
	if GameState.story_step != "":
		var step := ChapterDB.step(GameState.story_step)
		var here: bool = step.get("target", "") == GameState.location_id
		return [CharacterDB.PROTAGONIST] + (step.get("cast", []) if here else [])
	return [CharacterDB.PROTAGONIST] + LocationDB.cast(GameState.location_id)


## Cuántas interacciones aceptadas lleva hoy Ren con `target`.
static func interactions_today(target: String) -> int:
	var n := 0
	for ev in GameState.events.find({"actor": CharacterDB.PROTAGONIST, "target": target, "date": GameState.date}):
		if ev.kind in INTERACTIONS and ev.data.get("result", OK) == OK:
			n += 1
	return n


## Cuántas veces aguanta `id` la misma acción en un día antes de hartarse.
static func tolerance(id: String, action: String) -> int:
	var patience: float = CharacterDB.profile(id).get("traits", {}).get("paciencia", 50)
	var t: float = 0.5 + patience / 40.0 + TOLERANCE_BONUS.get(action, 0)
	t += -1.0 if mood(id).id in NEGATIVE_MOODS else 1.0
	return maxi(roundi(t), 0)


# --- Reglas ------------------------------------------------------------------------

## Ren inicia una interacción del menú con `target`. Decide si el personaje la
## acepta, se ha hartado o no quiere hablar, la registra y aplica sus efectos.
## `force` la acepta siempre (escenas de guion).
static func begin_interaction(target: String, action: String, force: bool = false) -> String:
	var p := CharacterDB.profile(target)
	var m := mood(target)
	var same_today := GameState.events.count({"kind": action, "actor": CharacterDB.PROTAGONIST,
			"target": target, "date": GameState.date})
	var result := OK
	if not force and not p.is_empty():
		if action in REFUSABLE and m.id in NEGATIVE_MOODS and m.intensity >= REFUSE_INTENSITY:
			result = REFUSED
		elif same_today >= tolerance(target, action):
			result = TIRED
	var factor := _repeat_factor(interactions_today(target))
	GameState.record(action, CharacterDB.PROTAGONIST, target, {"result": result}, present())
	if p.is_empty():
		return result

	var reactions: Dictionary = p.get("reactions", {})
	match result:
		OK:
			_apply(target, _for_mood(reactions.get("actions", {}).get(action, {}), m.id), factor, action)
		TIRED:
			var fed_up: Dictionary = reactions.get("fed_up", {})
			# Cuanto más se insiste, peor: 1 la primera vez que se harta hoy, 2 la siguiente...
			var excess := 0
			for ev in GameState.events.find({"kind": action, "target": target, "date": GameState.date}):
				if ev.data.get("result", OK) == TIRED:
					excess += 1
			_apply(target, fed_up.get(action, {}), float(excess), "harto de " + action)
			set_mood(target, fed_up.get("mood", "irritado"), maxf(m.intensity, 40.0) + 15.0 * excess)
		REFUSED:
			# Insistir en un mal día lo empeora.
			set_mood(target, m.id, m.intensity + 10.0)
	return result


## Ren elige una opción de diálogo hablando con `target`. Reaccionan todos los
## presentes con ficha: el interlocutor del todo; el resto, a medias.
## Los mencionados (`mentions`) que están presentes se dan por aludidos y
## reaccionan del todo, como el interlocutor. Si no están, no se enteran.
## Opción: {styles: ["franco", ...], stance: {tema: postura}, mentions: ["rika"]}.
static func on_choice(target: String, choice: Dictionary) -> Dictionary:
	var out := {}
	var styles: Array = choice.get("styles", [])
	var stance: Dictionary = choice.get("stance", {})
	var mentions: Array = choice.get("mentions", [])
	if styles.is_empty() and stance.is_empty() and mentions.is_empty():
		return out
	GameState.record("choice", CharacterDB.PROTAGONIST, target,
			{"styles": styles, "stance": stance, "mentions": mentions, "persona": choice.get("persona", ""),
			"text": choice.get("text", "")}, present())
	# Ya está registrada la interacción en curso: las anteriores de hoy son una menos.
	var factor := _repeat_factor(interactions_today(target) - 1)
	for who: String in present():
		var p := CharacterDB.profile(who)
		if who == CharacterDB.PROTAGONIST or p.is_empty():
			continue
		var reactions: Dictionary = p.get("reactions", {})
		var mood_id: String = mood(who).id
		var deltas := {}
		for style: String in styles:
			_add(deltas, _for_mood(reactions.get("styles", {}).get(style, {}), mood_id))
		for topic: String in stance:
			_add(deltas, _for_mood(reactions.get("stances", {}).get(topic, {}).get(stance[topic], {}), mood_id))
		var weight := factor if who == target else (1.0 if who in mentions else OBSERVER_WEIGHT)
		var final := _apply(who, deltas, weight, "opción «%s»" % choice.get("text", ""))
		if not final.is_empty():
			out[who] = final
	return out


## Cuánto le ha sentado mal algo a alguien (0 = nada), a partir de los cambios
## que devuelve on_choice: lo que baja de afecto, confianza, respeto o atracción
## más lo que sube de resentimiento, asco o miedo.
static func displeasure(deltas: Dictionary) -> float:
	var bad := 0.0
	for dim: String in deltas:
		var d: float = deltas[dim]
		bad += maxf(-d, 0.0) if dim in GOOD_DIMENSIONS else maxf(d, 0.0)
	return bad


## ¿Es `tag` un filtro de una opción «por persona»?
static func is_person_filter(tag: String) -> bool:
	if tag in PERSON_WORDS:
		return true
	for op in [">=", "<=", "!=", "=", ">", "<"]:
		var i := tag.find(op)
		if i > 0:
			var key := tag.substr(0, i)
			return key in PERSON_KEYS or DIMENSIONS.has(key)
	return false


## Personajes con ficha que cumplen todos los `filters`, de más a menos afecto
## por Ren. `exclude`: ids que no pueden salir (además de Ren).
static func person_candidates(filters: Array, exclude: Array = []) -> Array[String]:
	var out: Array[String] = []
	for id: String in CharacterDB.with_profile():
		if id == CharacterDB.PROTAGONIST or id in exclude:
			continue
		var ok := true
		for f: String in filters:
			if not _person_matches(id, f):
				ok = false
				break
		if ok:
			out.append(id)
	out.sort_custom(func(a: String, b: String) -> bool:
		return value(a, CharacterDB.PROTAGONIST, "afecto") > value(b, CharacterDB.PROTAGONIST, "afecto"))
	return out


static func _person_matches(id: String, f: String) -> bool:
	var identity: Dictionary = CharacterDB.profile(id).get("identity", {})
	match f:
		"joven", "adulto":
			return identity.get("generation", "") == f
		"presente":
			return id in present()
		"ausente":
			return not id in present()
	for op in [">=", "<=", "!=", "=", ">", "<"]:
		var i := f.find(op)
		if i <= 0:
			continue
		var key := f.substr(0, i)
		var arg := f.substr(i + op.length())
		match key:
			"genero":
				return identity.get("gender", "") in arg.split("|") if op != "!=" else not identity.get("gender", "") in arg.split("|")
			"entre":
				return id in arg.split("|") if op != "!=" else not id in arg.split("|")
			"edad":
				return identity.has("age") and _cmp(float(identity.age), op, float(arg))
			"tramo":
				var tiers := ["hostil", "fria", "neutral", "cercana", "intima"]
				return _cmp(tiers.find(tier(id, CharacterDB.PROTAGONIST)), op, tiers.find(arg))
		if DIMENSIONS.has(key):
			return _cmp(value(id, CharacterDB.PROTAGONIST, key), op, float(arg))
		break
	push_warning("Social: filtro de persona desconocido '%s'" % f)
	return true


static func _cmp(a: float, op: String, b: float) -> bool:
	match op:
		">=": return a >= b
		"<=": return a <= b
		">": return a > b
		"<": return a < b
		"!=": return a != b
	return a == b


## Cambia lo que `from` siente por `to`. Valores fuera de rango se recortan.
static func change(from: String, to: String, deltas: Dictionary, weight: float = 1.0) -> void:
	if deltas.is_empty() or weight == 0.0:
		return
	if not GameState.relations.has(from):
		GameState.relations[from] = {}
	var r := relation(from, to)
	for dim: String in deltas:
		if not DIMENSIONS.has(dim):
			push_warning("Social: dimensión desconocida '%s'" % dim)
			continue
		var range_: Vector2 = DIMENSIONS[dim]
		r[dim] = snappedf(clampf(r[dim] + deltas[dim] * weight, range_.x, range_.y), 0.01)
	GameState.relations[from][to] = r


# --- Internos ----------------------------------------------------------------------

## Lo que siente `who` por Ren cambia según `deltas`, modulado por su ánimo:
## con un ánimo negativo lo malo pesa más (según su sensibilidad) y lo bueno menos.
## Devuelve los cambios aplicados (ya multiplicados por `weight`).
static func _apply(who: String, deltas: Dictionary, weight: float, reason: String) -> Dictionary:
	if deltas.is_empty() or weight == 0.0:
		return {}
	var m := mood(who)
	var sensitivity: float = CharacterDB.profile(who).get("traits", {}).get("sensibilidad", 50)
	var negative: bool = m.id in NEGATIVE_MOODS
	var k: float = m.intensity / 100.0
	var final := {}
	for dim: String in deltas:
		var d: float = deltas[dim]
		var bad := d < 0.0 if dim in GOOD_DIMENSIONS else d > 0.0
		if negative:
			d *= (1.0 + sensitivity / 100.0 * k) if bad else (1.0 - 0.5 * k)
		final[dim] = d
	change(who, CharacterDB.PROTAGONIST, final, weight)
	if OS.is_debug_build():
		print("[Social] %s → ren (%s, %s %d, ×%.2f): %s" % [who, reason, m.id, m.intensity, weight, final])
	var applied := {}
	for dim: String in final:
		applied[dim] = final[dim] * weight
	return applied


## Si la entrada depende del ánimo, la variante de ese ánimo o "default".
static func _for_mood(entry: Dictionary, mood_id: String) -> Dictionary:
	if entry.has("default") or MOODS.any(func(mo: String) -> bool: return entry.has(mo)):
		return entry.get(mood_id, entry.get("default", {}))
	return entry


static func _repeat_factor(previous: int) -> float:
	return REPEAT_FACTORS[clampi(previous, 0, REPEAT_FACTORS.size() - 1)]


static func _add(into: Dictionary, deltas: Dictionary) -> void:
	for dim: String in deltas:
		into[dim] = into.get(dim, 0.0) + deltas[dim]


static func _with_defaults(values: Dictionary) -> Dictionary:
	var out := {}
	for dim: String in DIMENSIONS:
		out[dim] = float(values.get(dim, 0.0))
	return out
