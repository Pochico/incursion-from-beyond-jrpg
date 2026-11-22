class_name Battle
extends RefCounted
## Lógica de un combate del grupo contra un rival (PROTOTIPO). No sabe nada de la
## interfaz: cada acción modifica el estado y devuelve una lista de eventos que la
## vista (CombatView) anima en orden.
##
## El grupo es el protagonista ("player") y, opcionalmente, un compañero ("ally").
## Cada ronda actúan los miembros del grupo en pie, en orden, y después el rival.
##
## Eventos:
##   {type: "damage", source, target, move, amount, guarded, skill}
##   {type: "heal",   target, item, amount}
##   {type: "skill",  source, skill, cost}            — anuncio; gasta PM
##   {type: "restore", target, skill, amount}
##   {type: "status", target, status, applied, chance, turns}
##   {type: "tick",   target, status, amount}
##   {type: "status_end", target, status}
##   {type: "defend", target}
##   {type: "analyze"}
##   {type: "surrender", target}
## `source` y `target` son "player", "ally" o "enemy". `skill` vacío = ataque básico.
##
## El ataque básico usa los valores provisionales de CharacterDB.combat; las
## habilidades, las fórmulas de SkillDB (docs/diseno/habilidades_1.md).
## La compatibilidad entre naturalezas (requirementTags) todavía no se comprueba.

const PLAYER := "player"
const ALLY := "ally"
const ENEMY := "enemy"
const LOW_HP_RATIO := 0.35   ## Por debajo de esto, el rival intenta curarse.
## Probabilidad de que el rival use una habilidad de ataque disponible en vez del básico.
const ENEMY_SKILL_CHANCE := 0.45
## Recompensa por victoria: ¥ por nivel de la criatura...
const REWARD_PER_LEVEL := 120
## ...y ±este porcentaje por cada nivel que la criatura esté por encima (o por debajo) de Ren.
const REWARD_LEVEL_STEP := 0.15
const REWARD_MIN_FACTOR := 0.1

var fighters := {}           ## "player"/"ally"/"enemy" -> Dictionary con el estado del luchador
var party: Array[String] = [PLAYER]
var analyzed := false        ## El jugador ha analizado al rival (se muestran sus PV)
var tension := 0.0           ## 0..1, solo visual por ahora
var surrendered := false
var rng := RandomNumberGenerator.new()


## `ally_id` vacío = combate en solitario. `ally_skills` sustituye las habilidades
## del compañero (si está vacío, usa las suyas de CharacterDB).
func _init(player_id: String, enemy_id: String, ally_id: String = "", ally_skills: Array = []) -> void:
	rng.randomize()
	fighters[PLAYER] = _make_fighter(player_id)
	fighters[ENEMY] = _make_fighter(enemy_id)
	if ally_id != "":
		fighters[ALLY] = _make_fighter(ally_id)
		if not ally_skills.is_empty():
			fighters[ALLY].skills = ally_skills.duplicate()
		party.append(ALLY)


func _make_fighter(id: String) -> Dictionary:
	var data := CharacterDB.get_character(id)
	var c: Dictionary = data.get("combat", {})
	var pv: int = c.get("pv", 100)
	var pm: int = c.get("pm", 0)
	return {
		"id": id,
		"name": CharacterDB.display_name(id),
		"nature": data.get("nature", ""),
		"level": c.get("level", 1),
		"pv": pv, "pv_max": pv,
		"pm": c.get("pm_now", pm), "pm_max": pm,
		"attack": c.get("attack", "Ataque"),
		"damage": c.get("damage", 10),
		"variance": c.get("variance", 0),
		"stats": (c.get("stats", {}) as Dictionary).duplicate(),
		"skills": (c.get("skills", []) as Array).duplicate(),
		"cooldowns": {},     ## skill_id -> turnos propios que faltan para poder usarla
		"statuses": {},      ## status_id -> {turns, tick}
		"items": (c.get("items", {}) as Dictionary).duplicate(),
		"defending": false,
	}


func player() -> Dictionary:
	return fighters[PLAYER]


func enemy() -> Dictionary:
	return fighters[ENEMY]


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
	return surrendered or enemy().pv <= 0 or alive_party().is_empty()


func player_won() -> bool:
	return not surrendered and enemy().pv <= 0 and not alive_party().is_empty()


## Dinero que se gana al vencer: proporcional al nivel de la criatura (cuanto más
## lejos de 0, más) y corregido por la diferencia de nivel con Ren: más si la
## criatura está por encima, menos si es Ren quien está por encima.
func reward() -> int:
	if not player_won():
		return 0
	var enemy_level: int = absi(enemy().level)
	var diff: int = enemy().level - player().level
	var factor := maxf(1.0 + diff * REWARD_LEVEL_STEP, REWARD_MIN_FACTOR)
	return maxi(int(round(enemy_level * REWARD_PER_LEVEL * factor)), 1)


# --- Habilidades: consultas ---------------------------------------------------------------

func skill_cost(who: String, skill_id: String) -> int:
	return SkillDB.cost(skill_id, fighters[who].level)


func skill_cooldown(who: String, skill_id: String) -> int:
	return fighters[who].cooldowns.get(skill_id, 0)


func can_use_skill(who: String, skill_id: String) -> bool:
	var f: Dictionary = fighters[who]
	return skill_id in f.skills and skill_cooldown(who, skill_id) <= 0 and f.pm >= skill_cost(who, skill_id)


## Resultado aproximado (sin variación) de la parte principal de una habilidad:
## daño contra el rival o PV restaurados. Para mostrar en la interfaz.
func skill_preview(who: String, skill_id: String) -> int:
	var f: Dictionary = fighters[who]
	var other: Dictionary = fighters[_opponent_of(who)]
	for fx: Dictionary in SkillDB.get_skill(skill_id).get("effects", []):
		match fx.kind:
			"damage":
				return _skill_damage(f, other, fx.mult, fx.attr, fx.defense)
			"restore":
				return SkillDB.round_half_up(fx.mult * SkillDB.base_restore(f.level, _stat(f, fx.attr)))
	return 0


# --- Acciones del grupo (`who` = "player" o "ally") ------------------------------------------

func attack(who: String) -> Array:
	var events: Array = [_attack(who, ENEMY)]
	return events + _end_turn(who)


func use_skill(who: String, skill_id: String) -> Array:
	if not can_use_skill(who, skill_id):
		return []
	var events := _use_skill(who, skill_id)
	return events + _end_turn(who)


## Usa un objeto del inventario del grupo (GameState) sobre quien actúa.
func use_item(who: String, item_id: String) -> Array:
	if not GameState.use_item(item_id):
		return []
	var events: Array = [_heal(who, item_id)]
	return events + _end_turn(who)


func defend(who: String) -> Array:
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


# --- Turno del rival --------------------------------------------------------------------

func enemy_turn() -> Array:
	var e := enemy()
	var events: Array = []
	var low: bool = float(e.pv) / e.pv_max < LOW_HP_RATIO
	var support := _first_skill(ENEMY, "support")
	var target := _pick_target()
	if low and support != "":
		events += _use_skill(ENEMY, support)
	elif low and e.items.get("pochicola", 0) > 0:
		e.items["pochicola"] -= 1
		events.append(_heal(ENEMY, "pochicola"))
	else:
		var skill := _pick_enemy_attack(target)
		if skill != "":
			events += _use_skill(ENEMY, skill, target)
		else:
			events.append(_attack(ENEMY, target))
	for who in party:
		fighters[who].defending = false
	return events + _end_turn(ENEMY)


func _pick_target() -> String:
	var alive := alive_party()
	return alive[rng.randi_range(0, alive.size() - 1)] if not alive.is_empty() else PLAYER


## Elige una habilidad de ataque disponible o "" para el ataque básico.
## Prefiere aplicar estados que el objetivo todavía no tiene.
func _pick_enemy_attack(target: String) -> String:
	var options: Array[String] = []
	for id: String in enemy().skills:
		if SkillDB.get_skill(id).role == "attack" and can_use_skill(ENEMY, id):
			options.append(id)
	if options.is_empty() or rng.randf() >= ENEMY_SKILL_CHANCE:
		return ""
	for id in options:
		var status := _status_of(id)
		if status != "" and not fighters[target].statuses.has(status):
			return id
	return options[rng.randi_range(0, options.size() - 1)]


func _first_skill(who: String, role: String) -> String:
	for id: String in fighters[who].skills:
		if SkillDB.get_skill(id).role == role and can_use_skill(who, id):
			return id
	return ""


func _status_of(skill_id: String) -> String:
	for fx: Dictionary in SkillDB.get_skill(skill_id).effects:
		if fx.kind == "status":
			return fx.status
	return ""


# --- Internos ---------------------------------------------------------------------------

func _opponent_of(who: String) -> String:
	return _pick_target() if who == ENEMY else ENEMY


func _stat(f: Dictionary, attr: String) -> float:
	var value := float(f.stats.get(attr, 10))
	for status: String in f.statuses:
		value *= SkillDB.STATUS_STAT_MODS.get(status, {}).get(attr, 1.0)
	return value


func _skill_damage(src: Dictionary, dst: Dictionary, mult: float, attr: String, defense: String) -> int:
	return SkillDB.round_half_up(mult * SkillDB.base_damage(src.level, _stat(src, attr), _stat(dst, defense)))


## `target` vacío = el que corresponda (uno mismo o el rival / un miembro del grupo).
func _use_skill(who: String, skill_id: String, target: String = "") -> Array:
	var skill := SkillDB.get_skill(skill_id)
	var f: Dictionary = fighters[who]
	var cost := skill_cost(who, skill_id)
	f.pm -= cost
	# +1 porque _end_turn descuenta uno al terminar este mismo turno.
	if skill.cd > 0:
		f.cooldowns[skill_id] = skill.cd + 1
	var events: Array = [{"type": "skill", "source": who, "skill": skill_id, "cost": cost}]
	var target_id := target
	if skill.target == "self":
		target_id = who
	elif target_id == "":
		target_id = _opponent_of(who)
	var t: Dictionary = fighters[target_id]
	for fx: Dictionary in skill.effects:
		match fx.kind:
			"damage":
				var amount := _skill_damage(f, t, fx.mult, fx.attr, fx.defense)
				events.append(_apply_damage(who, target_id, amount, skill.name, skill_id))
			"restore":
				var heal := SkillDB.round_half_up(fx.mult * SkillDB.base_restore(f.level, _stat(f, fx.attr)))
				var before: int = t.pv
				t.pv = mini(t.pv + heal, t.pv_max)
				events.append({"type": "restore", "target": target_id, "skill": skill_id, "amount": t.pv - before})
			"status":
				if t.pv <= 0:
					continue
				var chance := SkillDB.status_chance(fx.chance, _stat(f, fx.attr), _stat(t, fx.resist))
				var applied := rng.randf() * 100.0 < chance
				if applied:
					# No se acumula: reaplicar renueva la duración. El daño periódico
					# se calcula al aplicar y se conserva durante todo el estado.
					var tick := 0
					if fx.has("tick_mult"):
						tick = _skill_damage(f, t, fx.tick_mult, fx.tick_attr, fx.tick_defense)
					t.statuses[fx.status] = {"turns": fx.turns, "tick": tick}
				events.append({"type": "status", "target": target_id, "status": fx.status,
						"applied": applied, "chance": chance, "turns": fx.turns})
	return events


## Fin del turno de `who`: daño periódico de sus estados y enfriamientos.
func _end_turn(who: String) -> Array:
	var f: Dictionary = fighters[who]
	var events: Array = []
	for skill_id: String in f.cooldowns.keys():
		f.cooldowns[skill_id] = maxi(f.cooldowns[skill_id] - 1, 0)
	if is_over() or f.pv <= 0:
		return events
	for status: String in f.statuses.keys():
		var st: Dictionary = f.statuses[status]
		st.turns -= 1
		if st.tick > 0:
			var amount: int = mini(st.tick, f.pv)
			f.pv -= amount
			events.append({"type": "tick", "target": who, "status": status, "amount": amount})
		if st.turns <= 0:
			f.statuses.erase(status)
			events.append({"type": "status_end", "target": who, "status": status})
		if f.pv <= 0:
			break
	return events


func _attack(source: String, target: String) -> Dictionary:
	var a: Dictionary = fighters[source]
	var amount: int = a.damage + (rng.randi_range(-a.variance, a.variance) if a.variance > 0 else 0)
	return _apply_damage(source, target, amount, a.attack, "")


## La guardia reduce a la mitad tanto ataques básicos como habilidades.
func _apply_damage(source: String, target: String, amount: int, move: String, skill_id: String) -> Dictionary:
	var t: Dictionary = fighters[target]
	if t.defending:
		amount = int(ceil(amount * 0.5))
	amount = maxi(amount, 1)
	t.pv = maxi(t.pv - amount, 0)
	tension = clampf(tension + float(amount) / t.pv_max * 0.6, 0.0, 1.0)
	return {"type": "damage", "source": source, "target": target, "move": move, "amount": amount,
			"guarded": t.defending, "skill": skill_id}


func _heal(target: String, item_id: String) -> Dictionary:
	var t: Dictionary = fighters[target]
	var heal: int = ItemDB.get_item(item_id).get("heal", 0)
	var before: int = t.pv
	t.pv = mini(t.pv + heal, t.pv_max)
	return {"type": "heal", "target": target, "item": item_id, "amount": t.pv - before}
