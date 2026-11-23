extends Node
## Puente entre los diálogos (.dialogue, Dialogue Manager) y el estado del juego.
##
## 1. Funciones para usar dentro de los diálogos, en condiciones y mutaciones:
##      if Story.tier("rika") == "cercana"
##      $> Story.tell("shiori", "incursion_1")
## 2. Selector de conversaciones: elige qué cue suena para un personaje y un
##    momento ("hablar", "ligar"...) según las reglas escritas en los propios
##    .dialogue, justo debajo de cada cue:
##
##      ~ rika_hablar_tras_incursion
##      # cuando: hablar, fase >= incursion_1, sabe incursion_1, una vez
##
##    Gana la regla que cumple más condiciones (la más específica). «una vez»
##    pesa 3 y el ánimo 2 (ver CRITERION_WEIGHTS). Si empatan varias, una al azar. Criterios: ver docs/diseno/personajes_y_relaciones.md.

const DIALOGUE_DIR := "res://src/dialogue/"
const GENERAL := "general"
const TIERS: Array[String] = ["hostil", "fria", "neutral", "cercana", "intima"]
const SEEN_PREFIX := "visto:"
## Peso de cada condición al comparar reglas. Las escenas únicas («una vez»)
## ganan a las variantes de ánimo, y estas a las conversaciones genéricas.
const CRITERION_WEIGHTS := {"once": 3, "mood": 2}

## Acción del menú -> momento del selector.
const ACTION_MOMENTS := {"talk": "hablar", "flirt": "ligar", "fight": "luchar", "message": "movil"}
## Nombre del interlocutor actual, para las frases genéricas de general.dialogue:
##   {{Story.speaker}}: Ahora no me apetece hablar.
var speaker := ""

var _resources := {}     ## archivo -> DialogueResource
var _rules := {}         ## momento -> [{cue, file, criteria: Array[Dictionary]}]
var _cue_files := {}     ## cue -> archivo
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_load_rules()


# --- Consultas para los diálogos ---------------------------------------------------------

## Tramo de lo que `who` siente por Ren.
func tier(who: String) -> String:
	return Social.tier(who, CharacterDB.PROTAGONIST)


func mood(who: String) -> String:
	return Social.mood(who).id


func knows(who: String, event_id: String) -> bool:
	return GameState.events.knows(who, event_id)


## Ren le cuenta a `who` un acontecimiento.
func tell(who: String, event_id: String) -> void:
	GameState.events.tell(who, event_id)


func phase(id: String) -> bool:
	return GameState.phase_at_least(id)


func flag(id: String) -> bool:
	return bool(GameState.get_flag(id))


func set_flag(id: String, value: Variant = true) -> void:
	GameState.set_flag(id, value)


func present(who: String) -> bool:
	return who in Social.present()


## Interacciones aceptadas hoy con `who`, incluida la que está en curso.
func today(who: String) -> int:
	return Social.interactions_today(who)


func value(who: String, dim: String) -> float:
	return Social.value(who, CharacterDB.PROTAGONIST, dim)


## Cambio de guion en lo que `who` siente por Ren: $> Story.change("rika", "confianza", 3)
func change(who: String, dim: String, amount: float) -> void:
	Social.change(who, CharacterDB.PROTAGONIST, {dim: amount})


func set_mood(who: String, mood_id: String, intensity: float = 50.0) -> void:
	Social.set_mood(who, mood_id, intensity)


## Mensaje de `who` en el móvil de Ren (aparece en Mensajes).
func text(who: String, message: String) -> void:
	GameState.add_message(who, who, message)


func enemy_name() -> String:
	return CharacterDB.display_name(GameState.incursion_enemy)


func seen(cue: String) -> bool:
	return bool(GameState.get_flag(SEEN_PREFIX + cue))


# --- Selector ---------------------------------------------------------------------------

## Momento del selector para una acción del menú y el resultado de Social.
func moment_for(action: String, result: String = Social.OK) -> String:
	var base: String = ACTION_MOMENTS.get(action, action)
	if result == Social.REFUSED:
		return "no_quiere"
	if result == Social.TIRED:
		return "harto_" + base
	return base


## Elige el cue de `who` para `moment`. Devuelve {resource, cue} o {} si no hay.
## `context` añade datos del momento (p. ej. {"resultado": "gana"}).
func pick(who: String, moment: String, context: Dictionary = {}) -> Dictionary:
	var best: Array[Dictionary] = []
	for c: Dictionary in candidates(who, moment, context):
		if c.best:
			best.append(c.rule)
	if best.is_empty():
		return {}
	var chosen: Dictionary = best[_rng.randi_range(0, best.size() - 1)]
	speaker = CharacterDB.display_name(who)
	return {"resource": resource(chosen.file), "cue": chosen.cue}


## Todas las reglas que se consideran para `who` y `moment`, con su puntuación:
## [{rule, score, best}]. `score` es -1 si la regla no se cumple; `best` marca
## las ganadoras (si hay varias, `pick` elige una al azar).
## `state` permite evaluar con un estado simulado (pruebas, editor de diálogos):
## un objeto con los mismos métodos de consulta que Story (seen, knows, flag,
## present, phase_index, tier, mood, today, times_today, value). Por defecto,
## la partida actual.
func candidates(who: String, moment: String, context: Dictionary = {}, state: Object = null) -> Array[Dictionary]:
	var s: Object = state if state != null else self
	var out: Array[Dictionary] = []
	var best_score := -1
	for rule: Dictionary in _rules.get(moment, []):
		if rule.file != who and rule.file != GENERAL:
			continue
		# Las reglas genéricas (general.dialogue) solo si se refieren a cualquiera.
		var score := _score(rule, who, moment, context, s)
		if score >= 0:
			# A igualdad, lo del propio personaje gana a lo genérico.
			score = score * 2 + (1 if rule.file == who else 0)
			best_score = maxi(best_score, score)
		out.append({"rule": rule, "score": score, "best": false})
	for c: Dictionary in out:
		c.best = best_score >= 0 and c.score == best_score
	return out


## Índice de la fase actual en GameState.PHASES (para comparar fases).
func phase_index() -> int:
	return GameState.PHASES.find(GameState.phase)


## Recurso de un cue concreto (para escenas de guion que no pasan por el selector).
func cue(cue_name: String) -> Dictionary:
	if not _cue_files.has(cue_name):
		push_error("Story: cue desconocido '%s'" % cue_name)
		return {}
	return {"resource": resource(_cue_files[cue_name]), "cue": cue_name}


func mark_seen(cue_name: String) -> void:
	GameState.set_flag(SEEN_PREFIX + cue_name)


func resource(file: String) -> DialogueResource:
	if not _resources.has(file):
		_resources[file] = load(DIALOGUE_DIR + file + ".dialogue")
	return _resources[file]


## Peso de las condiciones que cumple la regla; -1 si falla alguna.
func _score(rule: Dictionary, who: String, moment: String, context: Dictionary, s: Object) -> int:
	var score := 0
	for c: Dictionary in rule.criteria:
		if not _check(c, rule.cue, who, moment, context, s):
			return -1
		score += CRITERION_WEIGHTS.get(c.kind, 1)
	return score


## Veces que Ren ha hecho hoy con `who` la acción de este momento (incluida la actual).
func times_today(who: String, moment: String) -> int:
	var action := ""
	for a: String in ACTION_MOMENTS:
		if moment.ends_with(ACTION_MOMENTS[a]):
			action = a
	if action == "":
		return 0
	return GameState.events.count({"kind": action, "actor": CharacterDB.PROTAGONIST,
			"target": who, "date": GameState.date})


## Si cambias estas reglas, cambia también el motor del editor de diálogos
## (docs/editor-dialogos/motor.js) y pasa la prueba de paridad (ver CLAUDE.md).
func _check(c: Dictionary, cue_name: String, who: String, moment: String, context: Dictionary, s: Object) -> bool:
	var ok := true
	match c.kind:
		"once":
			ok = not s.seen(cue_name)
		"seen":
			ok = s.seen(c.arg)
		"knows":
			ok = s.knows(who, c.arg)
		"flag":
			ok = s.flag(c.arg)
		"present":
			ok = s.present(c.arg)
		"phase":
			ok = _compare(s.phase_index(), c.op, GameState.PHASES.find(c.arg))
		"tier":
			ok = _compare(TIERS.find(s.tier(who)), c.op, TIERS.find(c.arg))
		"mood":
			ok = s.mood(who) in c.arg.split("|") if c.op == "=" else not s.mood(who) in c.arg.split("|")
		"today":
			ok = _compare(s.today(who), c.op, int(c.arg))
		"times":
			ok = _compare(s.times_today(who, moment), c.op, int(c.arg))
		"dim":
			ok = _compare(s.value(who, c.dim), c.op, float(c.arg))
		"context":
			ok = str(context.get(c.key, "")) in c.arg.split("|")
	return ok != c.negate


func _compare(a: float, op: String, b: float) -> bool:
	match op:
		">=": return a >= b
		"<=": return a <= b
		">": return a > b
		"<": return a < b
		"!=": return a != b
	return a == b


# --- Lectura de reglas ------------------------------------------------------------------

func _load_rules() -> void:
	var dir := DirAccess.open(DIALOGUE_DIR)
	if dir == null:
		push_error("Story: no existe %s" % DIALOGUE_DIR)
		return
	for f in dir.get_files():
		if f.get_extension() == "dialogue" and not f.begins_with("_"):
			_parse_file(f.get_basename(), FileAccess.get_file_as_string(DIALOGUE_DIR + f))


func _parse_file(file: String, text: String) -> void:
	var current := ""
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("~ "):
			current = line.substr(2).strip_edges()
			_cue_files[current] = file
		elif line.begins_with("# cuando:") and current != "":
			var parts := line.substr(9).split(",")
			var moment := parts[0].strip_edges()
			var criteria: Array[Dictionary] = []
			for i in range(1, parts.size()):
				var crit := _parse_criterion(parts[i].strip_edges())
				if crit.is_empty():
					push_error("Story: condición no válida «%s» en %s (%s)" % [parts[i], current, file])
				else:
					criteria.append(crit)
			if not _rules.has(moment):
				_rules[moment] = []
			_rules[moment].append({"cue": current, "file": file, "criteria": criteria})


## Criterios:
##   una vez | visto CUE | sabe EVENTO | flag NOMBRE | presente ID   (con «no» delante: negados)
##   fase >= X | tramo >= X | afecto >= N (cualquier dimensión)   (=, !=, <, >, <=, >=)
##   hoy >= N   (interacciones de cualquier tipo hoy con el personaje, incluida la actual)
##   veces >= N (veces que se ha hecho hoy esta misma acción, incluida la actual)
##   ánimo = a|b | ánimo != a|b
##   resultado = gana|pierde   (dato del momento)
func _parse_criterion(text: String) -> Dictionary:
	var negate := false
	if text.begins_with("no "):
		negate = true
		text = text.substr(3).strip_edges()
	if text == "una vez":
		return {"kind": "once", "negate": negate}
	for word in ["visto", "sabe", "flag", "presente"]:
		if text.begins_with(word + " "):
			var kinds := {"visto": "seen", "sabe": "knows", "flag": "flag", "presente": "present"}
			return {"kind": kinds[word], "arg": text.substr(word.length() + 1).strip_edges(), "negate": negate}
	for op in [">=", "<=", "!=", "=", ">", "<"]:
		var i := text.find(op)
		if i < 0:
			continue
		var key := text.substr(0, i).strip_edges()
		var arg := text.substr(i + op.length()).strip_edges()
		match key:
			"fase": return {"kind": "phase", "op": op, "arg": arg, "negate": negate}
			"tramo": return {"kind": "tier", "op": op, "arg": arg, "negate": negate}
			"hoy": return {"kind": "today", "op": op, "arg": arg, "negate": negate}
			"veces": return {"kind": "times", "op": op, "arg": arg, "negate": negate}
			"ánimo", "animo": return {"kind": "mood", "op": op, "arg": arg, "negate": negate}
			"resultado": return {"kind": "context", "key": "resultado", "arg": arg, "negate": negate}
		if Social.DIMENSIONS.has(key):
			return {"kind": "dim", "dim": key, "op": op, "arg": arg, "negate": negate}
		return {}
	return {}
