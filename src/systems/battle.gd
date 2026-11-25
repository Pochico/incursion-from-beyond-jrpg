class_name Battle
extends RefCounted
## Lógica de un combate del grupo contra uno a tres rivales. No sabe nada de la
## interfaz: cada acción modifica el estado y devuelve una lista de eventos que la
## vista (CombatView) anima en orden.
##
## El grupo es el protagonista ("player") y, opcionalmente, un compañero ("ally").
## Los rivales son "enemy", "enemy2" y "enemy3" (FOES). Cada ronda actúan los
## miembros del grupo en pie, en orden, y después cada rival en pie (`enemy_turn`
## de cada uno y `end_round`). Se gana cuando caen todos los rivales.
##
## Tiers de las criaturas (CharacterDB.ENEMY_TIERS): multiplican los PV y suman a
## los atributos; las habilidades de su ficha son de su tier o menos. Un jefe
## (`boss`) lleva además BOSS_PV_MULT.
## Antes de que actúe alguien, la vista llama a `start_turn` (puede perder el
## turno o tener que hacer una acción al azar).
##
## Fórmulas, habilidades y estados: SkillDB (docs/diseno/habilidades_tiers.md y
## habilidades_1.md). PV y PM máximos salen del nivel y los atributos.
##
## Orden al usar una habilidad: validar (vivo, recarga, PM, objetivo,
## compatibilidad) → pagar PM y costes propios → potenciadores (con límites) →
## daño/curación con defensa y redondeo → estados (compatibilidad antes que
## probabilidad) → fin de turno (estados periódicos, recargas) → eventos.
##
## Eventos:
##   {type: "damage", source, target, move, amount, guarded, skill, [immune], [shared]}
##   {type: "miss", source, target, move}
##   {type: "heal", target, item, amount, pm}         — objeto (PV y PM recuperados)
##   {type: "skill", source, skill, cost}             — anuncio; gasta PM
##   {type: "restore", target, skill, amount}         — curación de habilidad
##   {type: "pm_restore", target, skill, amount}
##   {type: "self_damage", target, skill, amount}     — coste en PV o calor
##   {type: "status", source, target, status, applied, chance, turns, [immune]}
##   {type: "tick", target, status, amount}           — daño periódico
##   {type: "regen", target, status, amount}          — curación periódica
##   {type: "status_end", target, status}
##   {type: "cleanse", target, statuses}
##   {type: "skip", target, status}                   — pierde el turno
##   {type: "random", target}                         — actúa al azar
##   {type: "wait", target}                           — no puede hacer nada
##   {type: "defend", target}
##   {type: "analyze"}
##   {type: "surrender", target}
## `source` y `target` son "player", "ally" o uno de FOES. `skill` vacío = ataque básico.

const PLAYER := "player"
const ALLY := "ally"
const ENEMY := "enemy"
## Puestos de los rivales, en orden de turno (el primero es el líder).
const FOES: Array[String] = ["enemy", "enemy2", "enemy3"]
const MAX_FOES := 3
const LOW_HP_RATIO := 0.35   ## Por debajo de esto, el rival intenta curarse.
## Probabilidad de que el rival use una habilidad disponible en vez del ataque básico.
const ENEMY_SKILL_CHANCE := 0.45
## Recompensa por victoria: ¥ por nivel de la criatura...
const REWARD_PER_LEVEL := 120
## ...y ±este porcentaje por cada nivel que la criatura esté por encima (o por debajo) de Ren.
const REWARD_LEVEL_STEP := 0.15
const REWARD_MIN_FACTOR := 0.1

var fighters := {}           ## "player"/"ally"/"enemy"... -> Dictionary con el estado del luchador
var party: Array[String] = [PLAYER]
var foes: Array[String] = []  ## rivales de este combate (puestos de FOES)
var analyzed := false        ## El jugador ha analizado al rival (se muestran sus PV)
var tension := 0.0           ## 0..1, solo visual por ahora
var surrendered := false
var rng := RandomNumberGenerator.new()
var _acting := ""            ## quien está actuando (sus estados nuevos no cuentan este turno)


## `enemy_ids`: un id o una lista de hasta tres (el primero, el líder). `ally_id`
## vacío = combate en solitario. `ally_skills` sustituye las habilidades del
## compañero (si está vacío, usa las suyas de CharacterDB). `enemy_level` > 0 fija
## el nivel de las criaturas (según dónde aparecen; ver ProgressionDB). `boss`:
## el líder es el jefe de la zona.
func _init(player_id: String, enemy_ids: Variant, ally_id: String = "", ally_skills: Array = [],
		enemy_level: int = 0, boss: bool = false) -> void:
	rng.randomize()
	fighters[PLAYER] = _make_fighter(player_id)
	var ids: Array = enemy_ids if enemy_ids is Array else [enemy_ids]
	for i in mini(ids.size(), MAX_FOES):
		fighters[FOES[i]] = _make_fighter(ids[i], enemy_level, boss and i == 0)
		foes.append(FOES[i])
	# Daño según el tier; en grupo, cada criatura (menos el jefe) tiene menos PV y pega menos.
	var scale: Dictionary = CharacterDB.GROUP_SCALE.get(foes.size(), {})
	for who in foes:
		var f: Dictionary = fighters[who]
		f.dmg_scale = float(CharacterDB.ENEMY_TIERS.get(f.tier, {}).get("dmg", 1.0))
		if f.boss or scale.is_empty():
			continue
		f.pv_max = maxi(roundi(f.pv_max * float(scale.pv)), 1)
		f.pv = f.pv_max
		f.dmg_scale *= float(scale.dmg)
	if ally_id != "":
		fighters[ALLY] = _make_fighter(ally_id)
		if not ally_skills.is_empty():
			fighters[ALLY].skills = ally_skills.duplicate()
		party.append(ALLY)


## PV y PM máximos por fórmula (nivel y atributos). Los enemigos pueden llevar
## `pv_mult` (luchan solos contra un grupo). Nivel: el que se pida (`level`), o
## el de la partida (GameState.level_of; las criaturas, el de su ficha). Los
## atributos de la ficha son los de nivel 1 y crecen con ProgressionDB.stats_at.
func _make_fighter(id: String, level: int = 0, boss: bool = false) -> Dictionary:
	var data := CharacterDB.get_character(id)
	var c: Dictionary = data.get("combat", {})
	if level <= 0:
		level = maxi(c.get("level", 1), 1) if data.get("enemy", false) else GameState.level_of(id)
	level = clampi(level, 1, ProgressionDB.MAX_LEVEL)
	var stats := ProgressionDB.stats_at(c.get("stats", {}), level)
	var pv_mult := float(c.get("pv_mult", 1.0))
	var tier := 0
	if data.get("enemy", false):
		tier = CharacterDB.enemy_tier(id)
		var t: Dictionary = CharacterDB.ENEMY_TIERS.get(tier, {})
		pv_mult *= float(t.get("pv_mult", 1.0)) * (CharacterDB.BOSS_PV_MULT if boss else 1.0)
		for attr: String in stats:
			stats[attr] += int(t.get("stat_bonus", 0)) + (CharacterDB.BOSS_STAT_BONUS if boss else 0)
	var pv := roundi(SkillDB.pv_max(level, stats.get("RES", 10)) * pv_mult)
	var pm := SkillDB.pm_max(level, stats.get("INT", 10), stats.get("VOL", 10))
	var nature: String = data.get("nature", "")
	return {
		"id": id,
		"name": CharacterDB.display_name(id),
		"nature": nature,
		"tags": SkillDB.tags_for(c, nature),
		"level": level,
		"pv": pv, "pv_max": pv,
		"pm": pm, "pm_max": pm,
		"attack": c.get("attack", "Ataque"),
		"stats": stats,
		"skills": (c.get("skills", []) as Array).duplicate(),
		"cooldowns": {},     ## skill_id -> turnos propios que faltan para poder usarla
		"statuses": {},      ## status_id -> {turns, fresh, source, ...valores}
		"items": (c.get("items", {}) as Dictionary).duplicate(),
		"defending": false,
		"tier": tier,
		"boss": boss,
	}


func player() -> Dictionary:
	return fighters[PLAYER]


## El primer rival en pie (o el líder, si ya no queda ninguno).
func enemy() -> Dictionary:
	var alive := alive_foes()
	return fighters[alive[0] if not alive.is_empty() else ENEMY]


static func is_enemy(who: String) -> bool:
	return who.begins_with(ENEMY)


## Rivales que siguen en pie, en orden de turno.
func alive_foes() -> Array[String]:
	var out: Array[String] = []
	for who in foes:
		if is_alive(who):
			out.append(who)
	return out


func fighter(who: String) -> Dictionary:
	return fighters[who]


func is_alive(who: String) -> bool:
	return fighters.has(who) and fighters[who].pv > 0


## Miembros del grupo que siguen en pie, en orden de turno.
func alive_party() -> Array[String]:
	var out: Array[String] = []
	for who in party:
		if is_alive(who):
			out.append(who)
	return out


func is_over() -> bool:
	return surrendered or alive_foes().is_empty() or alive_party().is_empty()


func player_won() -> bool:
	return not surrendered and alive_foes().is_empty() and not alive_party().is_empty()


## Dinero que se gana al vencer: proporcional al nivel de la criatura (cuanto más
## lejos de 0, más) y corregido por la diferencia de nivel con Ren: más si la
## criatura está por encima, menos si es Ren quien está por encima.
## EXP que da la victoria a cada miembro del grupo (0 si no se ha ganado).
func xp_reward() -> int:
	if not player_won():
		return 0
	var total := 0
	for who in party:
		total += fighters[who].level
	var party_level := roundi(float(total) / party.size())
	var xp := 0
	for who in foes:
		var e: Dictionary = fighters[who]
		var data := CharacterDB.get_character(e.id)
		xp += ProgressionDB.battle_xp(e.level, party_level, e.boss or data.get("combat", {}).get("boss", false),
				not data.get("enemy", false))
	return xp


## Ids de personaje del grupo (para repartir la EXP).
func party_ids() -> Array:
	return party.map(func(w: String) -> String: return fighters[w].id)


func reward() -> int:
	if not player_won():
		return 0
	var total := 0
	for who in foes:
		var e: Dictionary = fighters[who]
		var diff: int = e.level - player().level
		var factor := maxf(1.0 + diff * REWARD_LEVEL_STEP, REWARD_MIN_FACTOR)
		total += maxi(int(round(absi(e.level) * REWARD_PER_LEVEL * factor * (1.0 + (e.tier - 1) * 0.5))), 1)
	return total


# --- Consultas para la interfaz ----------------------------------------------------------

func skill_cost(who: String, skill_id: String) -> int:
	var base := SkillDB.cost(skill_id, fighters[who].level)
	var mult := 1.0
	for st: Dictionary in fighters[who].statuses.values():
		mult *= float(st.get("cost_mult", 1.0))
	return ceili(base * mult - 0.0001)


func skill_cooldown(who: String, skill_id: String) -> int:
	return fighters[who].cooldowns.get(skill_id, 0)


func can_use_skill(who: String, skill_id: String) -> bool:
	return skill_problem(who, skill_id) == ""


## Por qué `who` no puede usar la habilidad ahora ("" si puede).
func skill_problem(who: String, skill_id: String) -> String:
	var f: Dictionary = fighters[who]
	var skill := SkillDB.get_skill(skill_id)
	if skill.is_empty() or not skill_id in f.skills:
		return "No conoce esa habilidad."
	if skill_cooldown(who, skill_id) > 0:
		var cd := skill_cooldown(who, skill_id)
		return "Recargando: disponible en %d turno%s." % [cd, "" if cd == 1 else "s"]
	if f.pm < skill_cost(who, skill_id):
		return "No hay PM suficientes."
	if not SkillDB.compatible(f.tags, skill.get("caster_requires", [])):
		return "%s no tiene con qué usarla." % f.name
	if not skill.get("caster_natures", []).is_empty() and not f.nature in skill.caster_natures:
		return "Solo la puede usar alguien de tipo %s." % " o ".join(
				skill.caster_natures.map(func(n: String) -> String: return SkillDB.NATURE_NAMES.get(n, n)))
	if _has_flag(f, "psy_only") and skill.nature != "psychic":
		return "Fuera del cuerpo solo valen las habilidades psíquicas."
	if _has_flag(f, "no_physical") and SkillDB.is_physical(skill_id):
		return "Inmovilizado: no puede dar golpes físicos."
	for st: String in skill.get("exclusive", []):
		if f.statuses.has(st):
			return "No se puede combinar con %s." % SkillDB.STATUS_NAMES.get(st, st)
	if _targets(who, skill_id).is_empty():
		return "No hay un objetivo válido." if skill.target != "link" else "Necesita a dos miembros del grupo en pie."
	return ""


## ¿Puede usar objetos? (No, fuera del cuerpo.)
func can_use_items(who: String) -> bool:
	return not _has_flag(fighters[who], "psy_only")


## ¿Puede dar el ataque básico? (No, inmovilizado o fuera del cuerpo.)
func can_attack(who: String) -> bool:
	var f: Dictionary = fighters[who]
	return not _has_flag(f, "no_physical") and not _has_flag(f, "psy_only")


## Daño aproximado del ataque básico de `who` contra su rival (sin estados del momento).
func attack_preview(who: String) -> int:
	var f: Dictionary = fighters[who]
	var dst: Dictionary = fighters[_preview_target(who)]
	var b := SkillDB.BASIC_ATTACK
	return SkillDB.round_half_up(b.mult * SkillDB.base_damage(f.level, _stat(f, b.attr), _stat(dst, b.defense)))


## Resumen corto del efecto principal de una habilidad para `who` (p. ej. «~41»,
## «+17 PV/turno ×3», «+17 PM»). Para la interfaz; sin aleatoriedad.
func skill_summary(who: String, skill_id: String) -> String:
	var f: Dictionary = fighters[who]
	var skill := SkillDB.get_skill(skill_id)
	var dst: Dictionary = fighters[_preview_target(who)]
	for op: Dictionary in skill.get("ops", []):
		match op.op:
			"damage":
				return "~%d" % SkillDB.round_half_up(op.mult * SkillDB.base_damage(f.level, _stat(f, op.attr), _stat(dst, op.defense)))
			"heal":
				return "+%d PV" % SkillDB.round_half_up(op.mult * SkillDB.base_restore(f.level, _stat(f, op.attr)))
			"recover_pm":
				return "+%d PM" % SkillDB.pm_recovery(op, f.level, _stat(f, op.attr))
			"status":
				if op.has("regen"):
					var r: Dictionary = op.regen
					return "+%d PV/turno ×%d" % [SkillDB.round_half_up(r.mult * SkillDB.base_restore(f.level, _stat(f, r.attr))), op.turns]
				return "%s · %d t." % [SkillDB.STATUS_NAMES.get(op.status, op.status), _turns_for(op, f.level)]
			"cleanse":
				return "Limpia %d" % SkillDB.by_level(op.count, op.get("count_from", {}), f.level)
	return "—"


func _preview_target(who: String) -> String:
	if not is_enemy(who):
		return enemy_target()
	var alive := alive_party()
	return alive[0] if not alive.is_empty() else PLAYER


# --- Turnos -------------------------------------------------------------------------------

## Antes de que actúe `who`. Devuelve {events, skip, forced}:
##  - skip: pierde el turno (aturdido, desactivado, excorporado...); ya se ha
##    cerrado su turno (estados periódicos incluidos).
##  - forced: acción que tiene que hacer («attack», «defend», «skill:<id>»), por
##    Adivinación. La vista la ejecuta como si la hubiera elegido.
func start_turn(who: String) -> Dictionary:
	var f: Dictionary = fighters[who]
	_acting = who
	for id: String in f.statuses:
		if SkillDB.status(id).get("skip_turn", false) and not f.statuses[id].get("fresh", false):
			var events: Array = [{"type": "skip", "target": who, "status": id}]
			return {"events": events + _end_turn(who), "skip": true, "forced": ""}
	if f.statuses.has("adivinacion") and not f.statuses.adivinacion.get("fresh", false):
		var options := _valid_actions(who)
		if not options.is_empty():
			return {"events": [{"type": "random", "target": who}], "skip": false,
					"forced": options[rng.randi_range(0, options.size() - 1)]}
	if _valid_actions(who).is_empty():
		var events: Array = [{"type": "wait", "target": who}]
		return {"events": events + _end_turn(who), "skip": true, "forced": ""}
	return {"events": [], "skip": false, "forced": ""}


## Acciones que puede hacer ahora: «attack», «defend» y «skill:<id>».
func _valid_actions(who: String) -> Array[String]:
	var out: Array[String] = []
	if can_attack(who):
		out.append("attack")
	if not is_enemy(who):
		out.append("defend")
	for id: String in fighters[who].skills:
		if can_use_skill(who, id):
			out.append("skill:" + id)
	return out


## Ejecuta una acción en forma de texto (la de `start_turn.forced`, por ejemplo).
func do_action(who: String, action: String) -> Array:
	if action == "attack":
		return attack(who)
	if action == "defend":
		return defend(who)
	if action.begins_with("skill:"):
		return use_skill(who, action.substr(6))
	return []


# --- Acciones del grupo (`who` = "player" o "ally"; también las usa el rival) ----------------

func attack(who: String, target: String = "") -> Array:
	_acting = who
	if not can_attack(who):
		return []
	var t := target if target != "" else _opponent_of(who)
	var b := SkillDB.BASIC_ATTACK
	var events := _break_camouflage(who)
	events += _hit(who, t, b.mult, b.attr, b.defense, fighters[who].attack, "", false, 1.0)
	return events + _end_turn(who)


func use_skill(who: String, skill_id: String, target: String = "") -> Array:
	_acting = who
	if not can_use_skill(who, skill_id):
		return []
	var events := _use_skill(who, skill_id, target)
	return events + _end_turn(who)


## Usa un objeto del inventario del grupo (GameState) sobre `target` (vacío =
## sobre quien actúa; tiene que seguir en pie). Los de ataque van al rival.
func use_item(who: String, item_id: String, target: String = "") -> Array:
	_acting = who
	if ItemDB.is_attack(item_id):
		target = target if is_enemy(target) and is_alive(target) else enemy_target()
	elif target == "":
		target = who
	if not can_use_items(who) or not is_alive(target) or not GameState.use_item(item_id):
		return []
	var events: Array = []
	if is_enemy(target):
		var dmg := roundi(ItemDB.get_item(item_id).damage * _in_mult(target))
		events = _apply_damage(who, target, dmg, ItemDB.display_name(item_id), "")
	else:
		var ev := _heal(target, item_id)
		ev.source = who
		events = [ev]
	return events + _end_turn(who)


# --- Fuera del combate (exploración) ------------------------------------------------------

## PV y PM del grupo por id de personaje, para llevarlos de un combate a otro.
func party_vitals() -> Dictionary:
	var out := {}
	for who in party:
		var f: Dictionary = fighters[who]
		out[f.id] = {"pv": f.pv, "pm": f.pm}
	return out


## Pone los PV y PM guardados con `party_vitals` (los que falten, al máximo).
## Con `min_pv`, nadie se queda por debajo (p. ej. 1 tras caer en combate).
func set_party_vitals(vitals: Dictionary, min_pv: int = 0) -> void:
	for who in party:
		var f: Dictionary = fighters[who]
		var v: Dictionary = vitals.get(f.id, {})
		f.pv = clampi(v.get("pv", f.pv_max), mini(min_pv, f.pv_max), f.pv_max)
		f.pm = clampi(v.get("pm", f.pm_max), 0, f.pm_max)


## ¿Sirve `skill_id` fuera del combate? Las que curan o recuperan PM sin atacar.
static func is_field_skill(skill_id: String) -> bool:
	if SkillDB.is_offensive(skill_id):
		return false
	for op: Dictionary in SkillDB.get_skill(skill_id).get("ops", []):
		if op.op in ["heal", "recover_pm"]:
			return true
	return false


## Usa una habilidad fuera del combate: gasta PM y aplica sus efectos, pero sin
## turno, recarga ni estados que duren (no hay combate en el que contarlos).
func field_use_skill(who: String, skill_id: String, target: String = "") -> Array:
	if not is_field_skill(skill_id) or not can_use_skill(who, skill_id):
		return []
	_acting = who
	var events := _use_skill(who, skill_id, target)
	for w in fighters:
		fighters[w].statuses.clear()
		fighters[w].cooldowns.clear()
	return events


## Usa un objeto fuera del combate sobre `target` (sin turno). Solo los que curan.
func field_use_item(target: String, item_id: String) -> Array:
	if not ItemDB.restores(item_id) or not is_alive(target) or not GameState.use_item(item_id):
		return []
	return [_heal(target, item_id)]


func defend(who: String) -> Array:
	_acting = who
	fighters[who].defending = true
	var events: Array = [{"type": "defend", "target": who}]
	return events + _end_turn(who)


## No consume el turno.
func analyze() -> Array:
	analyzed = true
	return [{"type": "analyze"}]


func surrender() -> Array:
	surrendered = true
	return [{"type": "surrender", "target": PLAYER}]


## Primer rival en pie (objetivo por defecto del grupo).
func enemy_target() -> String:
	var alive := alive_foes()
	return alive[0] if not alive.is_empty() else ENEMY


# --- Turno de los rivales ------------------------------------------------------------------

## Turno del rival `who` (si sigue en pie). Al acabar los de todos, `end_round`.
func enemy_turn(who: String = ENEMY) -> Array:
	if not is_alive(who) or is_over():
		return []
	var pre := start_turn(who)
	var events: Array = pre.events
	if not pre.skip:
		if pre.forced != "":
			events += do_action(who, pre.forced)
		else:
			events += _enemy_choice(who)
	if foes.size() == 1:
		end_round()
	return events


## Fin de la ronda: la guardia del grupo dura hasta que han actuado todos los rivales.
func end_round() -> void:
	for who in party:
		fighters[who].defending = false


func _enemy_choice(who: String) -> Array:
	var e: Dictionary = fighters[who]
	var low: bool = float(e.pv) / e.pv_max < LOW_HP_RATIO
	var heal := _first_skill(who, "heal")
	if low and heal != "":
		return use_skill(who, heal)
	if low and e.items.get("pochicola", 0) > 0:
		_acting = who
		e.items["pochicola"] -= 1
		var events: Array = [_heal(who, "pochicola")]
		return events + _end_turn(who)
	var target := _pick_target()
	var skill := _pick_enemy_skill(who, target)
	if skill != "":
		return use_skill(who, skill, target)
	if can_attack(who):
		return attack(who, target)
	# Sin golpes físicos ni habilidades útiles: cualquier habilidad que pueda usar.
	for id: String in e.skills:
		if can_use_skill(who, id):
			return use_skill(who, id, target)
	_acting = who
	var wait: Array = [{"type": "wait", "target": who}]
	return wait + _end_turn(who)


func _pick_target() -> String:
	var alive := alive_party()
	return alive[rng.randi_range(0, alive.size() - 1)] if not alive.is_empty() else PLAYER


## Habilidad que usará el rival ("" = ataque básico). No repite potenciadores
## que ya tiene ni estados que el objetivo ya sufre, y prefiere aplicar estados nuevos.
func _pick_enemy_skill(who: String, target: String) -> String:
	var options: Array[String] = []
	var fresh_status: Array[String] = []
	var me: Dictionary = fighters[who]
	for id: String in me.skills:
		var skill := SkillDB.get_skill(id)
		if skill.role == "heal" or not can_use_skill(who, id):
			continue
		var st := _main_status(id)
		if skill.role == "buff" and st != "" and me.statuses.has(st):
			continue
		if skill.role == "debuff" and st != "" and fighters[target].statuses.has(st):
			continue
		options.append(id)
		if skill.role in ["attack", "debuff"] and st != "" and not fighters[target].statuses.has(st):
			fresh_status.append(id)
	var forced := not can_attack(who)
	if options.is_empty() or (not forced and rng.randf() >= ENEMY_SKILL_CHANCE):
		return ""
	if not fresh_status.is_empty():
		return fresh_status[rng.randi_range(0, fresh_status.size() - 1)]
	return options[rng.randi_range(0, options.size() - 1)]


func _first_skill(who: String, role: String) -> String:
	for id: String in fighters[who].skills:
		if SkillDB.get_skill(id).role == role and can_use_skill(who, id):
			return id
	return ""


func _main_status(skill_id: String) -> String:
	for op: Dictionary in SkillDB.get_skill(skill_id).ops:
		if op.op == "status":
			return op.status
	return ""


# --- Internos: objetivos y atributos ----------------------------------------------------------

func _opponent_of(who: String) -> String:
	return _pick_target() if is_enemy(who) else enemy_target()


func _same_side(a: String, b: String) -> bool:
	return is_enemy(a) == is_enemy(b)


## Objetivos de una habilidad (vacío = no hay ninguno válido). `preferred` es el
## que haya elegido la IA para las de un solo objetivo.
func _targets(who: String, skill_id: String, preferred: String = "") -> Array[String]:
	var skill := SkillDB.get_skill(skill_id)
	var party_side := alive_party()
	var enemy_side := alive_foes()
	var others := enemy_side if not is_enemy(who) else party_side
	var friends := party_side if not is_enemy(who) else enemy_side
	var candidates: Array[String] = []
	match skill.target:
		"self":
			candidates.append(who)
		"enemy":
			candidates.assign([preferred] if preferred in others else others)
		"enemies":
			candidates.assign(others)
		"ally":
			candidates.append(who)
			for other in friends:
				if other != who:
					candidates[0] = other
		"allies", "link":
			candidates.assign(friends)
	var required: Array = skill.get("requires", [])
	var out: Array[String] = []
	for t in candidates:
		if is_alive(t) and SkillDB.compatible(fighters[t].tags, required):
			out.append(t)
	if skill.target == "link" and out.size() < 2:
		out.clear()
	if skill.target == "enemy" and out.size() > 1:
		var pick := out[rng.randi_range(0, out.size() - 1)]
		out.assign([pick])
	return out


## Atributo efectivo: base + sumas de estados, por multiplicadores de estados.
## "ARQ" = max(INT, VOL).
func _stat(f: Dictionary, attr: String) -> float:
	if attr == "ARQ":
		return maxf(_stat(f, "INT"), _stat(f, "VOL"))
	var value := float(f.stats.get(attr, 10))
	var mult := 1.0
	for st: Dictionary in f.statuses.values():
		value += float(st.get("stat_add", {}).get(attr, 0))
		mult *= float(st.get("stat_mult", {}).get(attr, 1.0))
	return value * mult


func _has_flag(f: Dictionary, flag: String) -> bool:
	for id: String in f.statuses:
		if SkillDB.status(id).get(flag, false):
			return true
	return false


func _sum(f: Dictionary, key: String) -> float:
	var total := 0.0
	for st: Dictionary in f.statuses.values():
		total += float(st.get(key, 0.0))
	return total


func _turns_for(op: Dictionary, level: int) -> int:
	return SkillDB.by_level(op.turns, op.get("turns_from", {}), level)


# --- Internos: resolución --------------------------------------------------------------------

## `target` vacío = el que corresponda (uno mismo, el rival o un miembro del grupo).
func _use_skill(who: String, skill_id: String, target: String = "") -> Array:
	var skill := SkillDB.get_skill(skill_id)
	var f: Dictionary = fighters[who]
	var targets := _targets(who, skill_id, target)
	var cost := skill_cost(who, skill_id)
	f.pm -= cost
	# +1 porque _end_turn descuenta uno al terminar este mismo turno.
	if skill.cd > 0:
		f.cooldowns[skill_id] = skill.cd + 1
	var events: Array = [{"type": "skill", "source": who, "skill": skill_id, "cost": cost}]
	var area: bool = skill.target == "enemies"
	if SkillDB.is_offensive(skill_id):
		events += _break_camouflage(who)
	# Potenciadores de un solo uso: se gastan con esta habilidad.
	var bonus := _consume_bonus(who, skill_id, targets, events)
	for op: Dictionary in skill.ops:
		match op.op:
			"damage":
				for t in targets:
					if is_alive(t):
						events += _hit(who, t, op.mult, op.attr, op.defense, skill.name, skill_id, area, bonus)
			"heal":
				for t in targets:
					if is_alive(t):
						var amount := SkillDB.round_half_up(op.mult * SkillDB.base_restore(f.level, _stat(f, op.attr)) * (1.0 + bonus / 100.0))
						events.append(_restore(t, amount, skill_id))
			"status":
				if skill.target == "link":
					events += _apply_link(who, targets, op)
				else:
					var on: Array[String] = targets
					if op.get("on", "") == "self":
						on = [who]
					for t in on:
						if is_alive(t):
							events.append(_apply_status(who, t, op))
			"self_damage":
				events += _self_damage(who, ceili(op.pct / 100.0 * f.pv_max), skill_id)
			"recover_pm":
				var before: int = f.pm
				f.pm = mini(f.pm + SkillDB.pm_recovery(op, f.level, _stat(f, op.attr)), f.pm_max)
				events.append({"type": "pm_restore", "target": who, "skill": skill_id, "amount": f.pm - before})
			"cleanse":
				for t in targets:
					events += _cleanse(t, SkillDB.by_level(op.count, op.get("count_from", {}), f.level), op.get("origin", ""))
			"reveal":
				if not is_enemy(who):
					analyzed = true
					events.append({"type": "analyze"})
	return events


## Suma (en %) de Manifestar, Sacrificio y Datos expuestos que se gastan con esta habilidad.
func _consume_bonus(who: String, skill_id: String, targets: Array[String], events: Array) -> float:
	var f: Dictionary = fighters[who]
	var bonus := 0.0
	for id: String in f.statuses.keys():
		var consume: String = SkillDB.status(id).get("consume", "")
		if (consume == "any" and SkillDB.is_damage_or_heal(skill_id)) \
				or (consume == "offensive" and SkillDB.is_offensive(skill_id)):
			bonus += float(f.statuses[id].get("bonus", 0.0))
			f.statuses.erase(id)
			events.append({"type": "status_end", "target": who, "status": id})
	if SkillDB.is_offensive(skill_id):
		for t in targets:
			if fighters[t].statuses.has("expuesto"):
				bonus += float(fighters[t].statuses.expuesto.get("bonus", 0.0))
				fighters[t].statuses.erase("expuesto")
				events.append({"type": "status_end", "target": t, "status": "expuesto"})
	return bonus


## Un golpe de `src` a `dst`: precisión → daño base → potenciadores → reducciones.
func _hit(src: String, dst: String, mult: float, attr: String, defense: String, move: String,
		skill_id: String, area: bool, bonus: float) -> Array:
	var a: Dictionary = fighters[src]
	var d: Dictionary = fighters[dst]
	var chance := _hit_chance(src, dst, area)
	if chance < 100.0 and rng.randf() * 100.0 >= chance:
		return [{"type": "miss", "source": src, "target": dst, "move": move, "skill": skill_id}]
	var raw := mult * SkillDB.base_damage(a.level, _stat(a, attr), _stat(d, defense))
	raw *= _out_mult(src, skill_id, bonus) * float(a.get("dmg_scale", 1.0))
	return _apply_damage(src, dst, SkillDB.round_half_up(raw * _in_mult(dst)), move, skill_id)


## Probabilidad de acertar (%). Sin efectos, siempre acierta. La esquiva solo
## cuenta contra ataques de un objetivo de quien ve.
func _hit_chance(src: String, dst: String, area: bool) -> float:
	var acc := _sum(fighters[src], "acc")
	var eva := 0.0
	if not area and "vision" in fighters[src].tags:
		eva = minf(_sum(fighters[dst], "eva"), SkillDB.MAX_EVASION)
	return clampf(100.0 + acc - eva, 5.0, 100.0)


## Potencia de daño de `src` (×1 sin efectos; máximo ×2,5 combinado).
func _out_mult(src: String, skill_id: String, bonus: float) -> float:
	var f: Dictionary = fighters[src]
	var pct := _sum(f, "dmg_out") + bonus
	if skill_id != "" and SkillDB.get_skill(skill_id).nature == "mechanical":
		pct += _sum(f, "mech_out")
	# Dominio: el del propio bando potencia, el del contrario debilita.
	for who: String in fighters:
		if is_alive(who) and fighters[who].statuses.has("dominio"):
			var dom: Dictionary = fighters[who].statuses.dominio
			pct += float(dom.field_out) if _same_side(who, src) else -float(dom.field_in)
	var m := clampf(1.0 + pct / 100.0, 0.1, SkillDB.MAX_DAMAGE_MULT)
	# Proyección astral: las habilidades psíquicas salen al 60 %.
	if skill_id != "" and SkillDB.get_skill(skill_id).nature == "psychic":
		for st: Dictionary in f.statuses.values():
			m *= float(st.get("psy_mult", 1.0))
	return m


## Multiplicador del daño recibido por `dst` (reducción combinada máxima del 70 %).
func _in_mult(dst: String) -> float:
	var d: Dictionary = fighters[dst]
	var red := _sum(d, "dmg_in") + (SkillDB.GUARD_REDUCTION if d.defending else 0.0)
	return 1.0 - minf(red, SkillDB.MAX_DAMAGE_REDUCTION) / 100.0


## Aplica daño ya calculado. Intangible = 0. Con Empatía, se reparte a medias
## con el vinculado (el daño compartido no se vuelve a repartir).
func _apply_damage(source: String, target: String, amount: int, move: String, skill_id: String,
		shared: bool = false) -> Array:
	var t: Dictionary = fighters[target]
	var base := {"type": "damage", "source": source, "target": target, "move": move,
			"guarded": t.defending, "skill": skill_id, "shared": shared}
	if _has_flag(t, "immune"):
		base.amount = 0
		base.immune = true
		return [base]
	amount = maxi(amount, 1)
	var events: Array = []
	var partner: String = t.statuses.get("empatia", {}).get("partner", "")
	var split := not shared and partner != "" and is_alive(partner) and amount > 1
	var mine := SkillDB.round_half_up(amount / 2.0) if split else amount
	t.pv = maxi(t.pv - mine, 0)
	tension = clampf(tension + float(mine) / t.pv_max * 0.6, 0.0, 1.0)
	base.amount = mine
	events.append(base)
	if split:
		events += _apply_damage(source, partner, amount - mine, move, skill_id, true)
	return events


func _restore(target: String, amount: int, skill_id: String) -> Dictionary:
	var t: Dictionary = fighters[target]
	var before: int = t.pv
	t.pv = mini(t.pv + amount, t.pv_max)
	return {"type": "restore", "target": target, "skill": skill_id, "amount": t.pv - before}


## Coste en PV propio: nunca deja a nadie por debajo de 1 PV.
func _self_damage(who: String, amount: int, skill_id: String) -> Array:
	var f: Dictionary = fighters[who]
	var real := mini(amount, f.pv - 1)
	if real <= 0:
		return []
	f.pv -= real
	return [{"type": "self_damage", "target": who, "skill": skill_id, "amount": real}]


## Aplica (o renueva) un estado. Primero la compatibilidad; después la probabilidad.
func _apply_status(src: String, dst: String, op: Dictionary) -> Dictionary:
	var a: Dictionary = fighters[src]
	var d: Dictionary = fighters[dst]
	var turns := _turns_for(op, a.level)
	var ev := {"type": "status", "source": src, "target": dst, "status": op.status, "turns": turns,
			"applied": false, "chance": 100.0}
	if not SkillDB.compatible(d.tags, op.get("requires", [])):
		ev.chance = 0.0
		ev.immune = true
		return ev
	if op.has("chance"):
		ev.chance = SkillDB.status_chance(op.chance, _stat(a, op.attr), _stat(d, op.resist), _sum(d, "status_res"))
		if rng.randf() * 100.0 >= ev.chance:
			return ev
	var st := {"turns": turns, "fresh": dst == _acting, "source": src}
	for key in ["dmg_out", "dmg_in", "mech_out", "acc", "eva", "status_res", "bonus",
			"field_out", "field_in", "cost_mult", "psy_mult", "end_self_pct"]:
		if op.has(key):
			st[key] = SkillDB.scaled(op[key], a.level)
	for key in ["stat_mult", "stat_add"]:
		if op.has(key):
			st[key] = op[key]
	if op.has("tick"):
		# Se guarda el atacante (nivel y atributo); la defensa se aplica en cada tick.
		st.tick_src = {"mult": op.tick.mult, "level": a.level, "attr": _stat(a, op.tick.attr), "defense": op.tick.defense}
		st.tick = _tick_amount(d, st.tick_src)
	if op.has("regen"):
		st.regen = SkillDB.round_half_up(op.regen.mult * SkillDB.base_restore(a.level, _stat(a, op.regen.attr)))
	if op.status == "dominio":
		# Solo un Dominio por bando: el nuevo sustituye al anterior.
		for who: String in fighters:
			if who != dst and _same_side(who, dst):
				fighters[who].statuses.erase("dominio")
	d.statuses[op.status] = st
	ev.applied = true
	return ev


## Empatía: vincula a los dos objetivos entre sí.
func _apply_link(src: String, targets: Array[String], op: Dictionary) -> Array:
	var events: Array = []
	for i in targets.size():
		var ev := _apply_status(src, targets[i], op)
		if ev.applied:
			fighters[targets[i]].statuses[op.status].partner = targets[1 - i]
		events.append(ev)
	return events


func _tick_amount(d: Dictionary, src: Dictionary) -> int:
	return SkillDB.round_half_up(src.mult * SkillDB.base_damage(src.level, src.attr, _stat(d, src.defense)))


## Quita hasta `count` estados negativos (de `origin`, si se da).
func _cleanse(who: String, count: int, origin: String) -> Array:
	var f: Dictionary = fighters[who]
	var removed: Array = []
	for id: String in f.statuses.keys():
		var info := SkillDB.status(id)
		if removed.size() >= count:
			break
		if info.get("debuff", false) and (origin == "" or info.get("origin", "") == origin):
			f.statuses.erase(id)
			removed.append(id)
	return [{"type": "cleanse", "target": who, "statuses": removed}]


## Atacar rompe el camuflaje óptico.
func _break_camouflage(who: String) -> Array:
	if fighters[who].statuses.erase("camuflaje"):
		return [{"type": "status_end", "target": who, "status": "camuflaje"}]
	return []


## Fin del turno de `who`: recargas y estados (los recién puestos en este turno
## no cuentan). Daño y curación periódicos; al acabar Sobrecarga, el calor.
func _end_turn(who: String) -> Array:
	var f: Dictionary = fighters[who]
	var events: Array = []
	for skill_id: String in f.cooldowns.keys():
		f.cooldowns[skill_id] = maxi(f.cooldowns[skill_id] - 1, 0)
	_acting = ""
	if is_over() or f.pv <= 0:
		return events
	for id: String in f.statuses.keys():
		if not f.statuses.has(id):
			continue
		var st: Dictionary = f.statuses[id]
		if st.get("fresh", false):
			st.fresh = false
			continue
		st.turns -= 1
		if st.has("tick_src"):
			var amount := 0 if _has_flag(f, "immune") else mini(_tick_amount(f, st.tick_src), f.pv)
			f.pv -= amount
			events.append({"type": "tick", "target": who, "status": id, "amount": amount})
		if st.get("regen", 0) > 0:
			var ev := _restore(who, st.regen, "")
			events.append({"type": "regen", "target": who, "status": id, "amount": ev.amount})
		if st.turns <= 0:
			f.statuses.erase(id)
			events.append({"type": "status_end", "target": who, "status": id})
			if st.has("end_self_pct"):
				events += _self_damage(who, ceili(st.end_self_pct / 100.0 * f.pv_max), "")
		if f.pv <= 0:
			break
	return events


## Objeto que cura: `amount` = PV recuperados, `pm` = PM recuperados.
func _heal(target: String, item_id: String) -> Dictionary:
	var t: Dictionary = fighters[target]
	var item := ItemDB.get_item(item_id)
	var before: int = t.pv
	var before_pm: int = t.pm
	t.pv = mini(t.pv + int(item.get("heal", 0)), t.pv_max)
	t.pm = mini(t.pm + int(item.get("pm", 0)), t.pm_max)
	return {"type": "heal", "target": target, "item": item_id, "amount": t.pv - before, "pm": t.pm - before_pm}
