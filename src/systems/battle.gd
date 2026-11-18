class_name Battle
extends RefCounted
## Lógica de un combate 1 contra 1 (PROTOTIPO). No sabe nada de la interfaz:
## cada acción modifica el estado y devuelve una lista de eventos que la vista
## (CombatView) anima en orden.
##
## Eventos:
##   {type: "damage", source, target, move, amount}
##   {type: "heal",   target, item, amount}
##   {type: "defend", target}
##   {type: "analyze"}
##   {type: "surrender", target}
## `source` y `target` son "player" o "enemy".
##
## Valores de daño y PV: provisionales (CharacterDB.combat). No es balance final
## ni el sistema de naturalezas, que se diseñará aparte.

const PLAYER := "player"
const ENEMY := "enemy"
const LOW_HP_RATIO := 0.35   ## Por debajo de esto, el rival bebe su Pochicola si le queda.

var fighters := {}           ## "player"/"enemy" -> Dictionary con el estado del luchador
var analyzed := false        ## El jugador ha analizado al rival (se muestran sus PV)
var tension := 0.0           ## 0..1, solo visual por ahora
var surrendered := false
var rng := RandomNumberGenerator.new()


func _init(player_id: String, enemy_id: String) -> void:
	rng.randomize()
	fighters[PLAYER] = _make_fighter(player_id)
	fighters[ENEMY] = _make_fighter(enemy_id)


func _make_fighter(id: String) -> Dictionary:
	var c: Dictionary = CharacterDB.get_character(id).get("combat", {})
	var pv: int = c.get("pv", 100)
	var pm: int = c.get("pm", 0)
	return {
		"id": id,
		"name": CharacterDB.display_name(id),
		"level": c.get("level", 1),
		"pv": pv, "pv_max": pv,
		"pm": c.get("pm_now", pm), "pm_max": pm,
		"attack": c.get("attack", "Ataque"),
		"damage": c.get("damage", 10),
		"variance": c.get("variance", 0),
		"items": (c.get("items", {}) as Dictionary).duplicate(),
		"defending": false,
	}


func player() -> Dictionary:
	return fighters[PLAYER]


func enemy() -> Dictionary:
	return fighters[ENEMY]


func is_over() -> bool:
	return surrendered or player().pv <= 0 or enemy().pv <= 0


func player_won() -> bool:
	return not surrendered and enemy().pv <= 0 and player().pv > 0


# --- Acciones del jugador ------------------------------------------------------------

func player_attack() -> Array:
	return [_attack(PLAYER, ENEMY)]


## Usa un objeto del inventario del grupo (GameState) sobre el propio jugador.
func player_item(item_id: String) -> Array:
	if not GameState.use_item(item_id):
		return []
	return [_heal(PLAYER, item_id)]


func player_defend() -> Array:
	player().defending = true
	return [{"type": "defend", "target": PLAYER}]


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
	if low and e.items.get("pochicola", 0) > 0:
		e.items["pochicola"] -= 1
		events.append(_heal(ENEMY, "pochicola"))
	else:
		events.append(_attack(ENEMY, PLAYER))
	player().defending = false
	return events


# --- Internos ---------------------------------------------------------------------------

func _attack(source: String, target: String) -> Dictionary:
	var a: Dictionary = fighters[source]
	var t: Dictionary = fighters[target]
	var amount: int = a.damage + (rng.randi_range(-a.variance, a.variance) if a.variance > 0 else 0)
	if t.defending:
		amount = int(ceil(amount * 0.5))
	amount = maxi(amount, 1)
	t.pv = maxi(t.pv - amount, 0)
	tension = clampf(tension + float(amount) / t.pv_max * 0.6, 0.0, 1.0)
	return {"type": "damage", "source": source, "target": target, "move": a.attack, "amount": amount,
			"guarded": t.defending}


func _heal(target: String, item_id: String) -> Dictionary:
	var t: Dictionary = fighters[target]
	var heal: int = ItemDB.get_item(item_id).get("heal", 0)
	var before: int = t.pv
	t.pv = mini(t.pv + heal, t.pv_max)
	return {"type": "heal", "target": target, "item": item_id, "amount": t.pv - before}
