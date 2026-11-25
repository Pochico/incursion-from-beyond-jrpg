class_name CombatView
extends Control
## Interfaz de combate (ver docs/ui/referencias/02_combate.webp).
##
## Composición (base 1920×1080):
##  - Cabecera roja con el nombre del combate; fecha y dinero arriba a la derecha.
##  - Visor grande: fondo de la ubicación, el rival con su silueta de color,
##    su placa de PV y el medidor de Tensión.
##  - Columna derecha: minimapa y fichas del grupo.
##  - Fila de comandos (Atacar, Habilidad, Objeto, Defender, Analizar, Huir).
##  - Fila de opciones del comando seleccionado + descripción / registro.
##  - Pantalla de estado (StatusPanel): clic en una ficha del grupo o Tab.
##
## La lógica está en Battle; esta vista solo traduce sus eventos en animaciones.
##
## Uso:
##   combat.setup("kenji")         # mientras la transición tapa la pantalla
##   combat.begin()               # tras descubrirla
##   var won: bool = await combat.finished

signal finished(player_won: bool)

enum State { IDLE, COMMAND, OPTION, ANIMATING, RESULT, STATUS }

const VIEWPORT_RECT := Rect2(10, 96, 1418, 782)
const COMMAND_Y := 898.0
const OPTION_ROW := Rect2(30, 990, 1864, 70)
const RIGHT_X := 1440.0

const COMMANDS := [
	{"id": "attack", "label": "Atacar", "icon": "swords", "desc": "Ataque básico con lo que tengas a mano."},
	{"id": "skill", "label": "Habilidad", "icon": "sparkle", "desc": "Técnicas de quien actúa. Gastan PM."},
	{"id": "item", "label": "Objeto", "icon": "flask", "desc": "Usar un objeto del inventario."},
	{"id": "defend", "label": "Defender", "icon": "shield", "desc": "Cubrirte para reducir el próximo golpe."},
	{"id": "analyze", "label": "Analizar", "icon": "antenna", "desc": "Estudiar al rival. No gasta el turno."},
	{"id": "flee", "label": "Huir", "icon": "run", "desc": "Abandonar el combate."},
]

var _battle: Battle
## Fondo del visor en lugar del de la ubicación (p. ej. dentro de una mazmorra). null = el de la ubicación.
var backdrop_override: Texture2D
var _actor := Battle.PLAYER       # miembro del grupo al que le toca elegir
var _state := State.IDLE
var _enemy_id := ""
var _pending_item := ""       ## objeto elegido mientras se escoge sobre quién usarlo
var _current_command := 0
var _info_text := ""
var _log_text := ""             # última acción del combate (registro)
var _result_text := ""
var _result_sub := ""       ## Línea bajo VICTORIA (dinero y EXP ganados)
var _result_levels := ""    ## Subidas de nivel, debajo
var _result_color := UIStyle.LIME
var _result_t := 0.0

var _viewport: Control
var _backdrop: LocationBackdrop
var _enemy: CharacterSprite
var _plate: EnemyPlate
var _fx: Control                 # capa de efectos dentro del visor (tajos, popups)
var _minimap: MiniMap
var _cards: Array[CombatantCard] = []
var _commands: Array[SlantButton] = []
var _options: HBoxContainer
var _info: Control
var _status: StatusPanel
var _tension_shown := 0.0
var _banner_text := ""           # nombre de la habilidad en curso
var _banner_color := UIStyle.WHITE
var _banner_t := 0.0


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


# --- Construcción ----------------------------------------------------------------------

func _build() -> void:
	# Visor
	_viewport = Control.new()
	_viewport.position = VIEWPORT_RECT.position + Vector2(2, 2)
	_viewport.size = VIEWPORT_RECT.size - Vector2(4, 4)
	_viewport.clip_contents = true
	_viewport.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_viewport)

	_backdrop = LocationBackdrop.new()
	_backdrop.size = _viewport.size
	_viewport.add_child(_backdrop)

	var shade := ColorRect.new()
	shade.color = Color(UIStyle.INK, 0.25)
	shade.size = _viewport.size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(shade)

	_enemy = CharacterSprite.new()
	_enemy.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_enemy.size = Vector2(560, 600)
	_enemy.position = Vector2(_viewport.size.x * 0.56 - 280, _viewport.size.y - 600)
	_enemy.pivot_offset = Vector2(280, 600)
	_viewport.add_child(_enemy)

	_plate = EnemyPlate.new()
	_plate.position = Vector2(26, 22)
	_viewport.add_child(_plate)

	_fx = Control.new()
	_fx.size = _viewport.size
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.draw.connect(_draw_fx)
	_viewport.add_child(_fx)

	# Columna derecha
	_minimap = MiniMap.new()
	_minimap.position = Vector2(RIGHT_X, 62)
	_minimap.size = Vector2(1908 - RIGHT_X, 238)
	add_child(_minimap)
	for i in 4:
		var card := CombatantCard.new()
		card.position = Vector2(RIGHT_X, 310 + i * 102)
		card.size = Vector2(1908 - RIGHT_X, 94)
		card.pressed.connect(_open_status.bind(i))
		add_child(card)
		_cards.append(card)

	# Comandos
	var x := 74.0
	var w := 296.0
	for i in COMMANDS.size():
		var b := SlantButton.new()
		b.label = COMMANDS[i].label
		b.icon_name = COMMANDS[i].icon
		b.description = COMMANDS[i].desc
		b.hover_focus = false   # El comando se elige con clic; el hover solo afecta a las opciones.
		b.font_size = 30
		b.slant = 26
		b.position = Vector2(x + i * (w + 8), COMMAND_Y)
		b.size = Vector2(w, 72)
		b.custom_minimum_size = Vector2(w, 72)
		b.focus_entered.connect(_on_command_focused.bind(i))
		b.pressed.connect(_on_command_pressed.bind(i))
		add_child(b)
		_commands.append(b)

	# Fila de opciones + descripción
	_info = Control.new()
	_info.position = OPTION_ROW.position
	_info.size = OPTION_ROW.size
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.draw.connect(_draw_info)
	add_child(_info)

	_options = HBoxContainer.new()
	_options.position = OPTION_ROW.position + Vector2(18, 10)
	_options.size = Vector2(900, 50)
	_options.add_theme_constant_override("separation", 18)
	add_child(_options)

	# Pantalla de estado, por encima de todo.
	_status = StatusPanel.new()
	_status.size = Vector2(1920, 1080)
	_status.closed.connect(_on_status_closed)
	add_child(_status)


# --- API ---------------------------------------------------------------------------------

const DEFAULT_ENEMY_SIZE := Vector2(560, 600)


## Prepara el combate contra `enemy_id` y lo hace visible (sin dar el control).
## Con `ally_id`, un compañero lucha junto al protagonista; `ally_skills`
## sustituye sus habilidades. `vitals` (Battle.party_vitals) = PV y PM con los
## que empieza el grupo (vacío = al máximo); al acabar, `party_vitals()`.
## `enemy_level` > 0 fija el nivel de la criatura (ver ProgressionDB).
func setup(enemy_id: String, ally_id: String = "", ally_skills: Array = [], vitals: Dictionary = {},
		enemy_level: int = 0) -> void:
	_enemy_id = enemy_id
	_battle = Battle.new(CharacterDB.PROTAGONIST, enemy_id, ally_id, ally_skills, enemy_level)
	_battle.set_party_vitals(vitals, 1)
	_actor = Battle.PLAYER
	_state = State.IDLE
	_tension_shown = 0.0
	_result_text = ""
	_result_sub = ""
	_result_levels = ""
	_result_t = 0.0
	_banner_text = ""
	_log_text = ""

	_backdrop.set_location(GameState.location_id)
	if backdrop_override != null:
		_backdrop.set_texture(backdrop_override)
	_minimap.location_id = GameState.location_id
	_minimap.queue_redraw()

	var vs := _viewport.size
	var default_rect := Rect2(Vector2(vs.x * 0.56 - DEFAULT_ENEMY_SIZE.x * 0.5, vs.y - DEFAULT_ENEMY_SIZE.y), DEFAULT_ENEMY_SIZE)
	var rect: Rect2 = CharacterDB.get_character(enemy_id).get("battle_rect", default_rect)
	_enemy.position = rect.position
	_enemy.size = rect.size
	_enemy.pivot_offset = Vector2(rect.size.x * 0.5, rect.size.y)
	_enemy.texture = CharacterDB.portrait(enemy_id)
	_enemy.glow_color = CharacterDB.color(enemy_id)
	_enemy.glow_idle = 0.9
	_enemy.modulate = Color.WHITE
	_enemy.scale = Vector2.ONE
	_plate.setup(_battle.enemy())
	_plate.analyzed = false
	_plate.statuses = []

	for i in _cards.size():
		_cards[i].guarding = false
		_cards[i].status_text = ""
		_cards[i].statuses = []
		_cards[i].active = false
		if i < _battle.party.size():
			var f := _battle.fighter(_battle.party[i])
			_cards[i].setup(f.id, i + 1, f)
		else:
			_cards[i].setup("", i + 1)

	_build_options(0)
	if ally_id != "":
		_log("¡%s te cierra el paso! %s lucha a tu lado." % [_battle.enemy().name, CharacterDB.display_name(ally_id)])
	elif CharacterDB.is_enemy(enemy_id):
		_log("¡%s te cierra el paso!" % _battle.enemy().name)
	else:
		_log("¡%s acepta el duelo!" % _battle.enemy().name)
	visible = true
	queue_redraw()
	_fx.queue_redraw()


## PV y PM del grupo al terminar (ver `setup`).
func party_vitals() -> Dictionary:
	return _battle.party_vitals() if _battle else {}


## Da el control al jugador. El resultado llega por la señal `finished(player_won)`.
func begin() -> void:
	# Pequeño margen para que las pulsaciones de Enter con las que se avanzaba
	# el diálogo previo no ejecuten una acción sin querer.
	await get_tree().create_timer(0.3).timeout
	_current_command = 0
	await _prompt()


# --- Estados y entrada ---------------------------------------------------------------------

func _enter_command_state(index: int) -> void:
	for i in _battle.party.size():
		_cards[i].active = _battle.party.size() > 1 and _battle.party[i] == _actor
	_state = State.COMMAND
	_set_commands_enabled(true)
	_commands[index].grab_focus()
	_on_command_focused(index)


func _set_commands_enabled(on: bool) -> void:
	for b in _commands:
		b.focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	for c in _options.get_children():
		(c as Control).mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE


func _on_command_focused(index: int) -> void:
	if _state != State.COMMAND and _state != State.OPTION:
		return
	# Volver a la fila de comandos (con ↑ o el ratón) sale de la de opciones.
	_state = State.COMMAND
	_current_command = index
	for i in _commands.size():
		_commands[i].active = i == index
	_build_options(index)
	_set_info(COMMANDS[index].desc)


func _on_command_pressed(index: int) -> void:
	if _state != State.COMMAND:
		return
	_current_command = index
	var first := _first_enabled_option()
	if first:
		_state = State.OPTION
		first.grab_focus()


func _first_enabled_option() -> PillButton:
	for c in _options.get_children():
		if c is PillButton and not c.disabled:
			return c
	return null


## Opciones de cada comando.
func _options_for(command_id: String) -> Array:
	var p := _battle.fighter(_actor)
	match command_id:
		"attack":
			var can := _battle.can_attack(_actor)
			return [{"label": p.attack, "icon": "slash", "action": "attack", "disabled": not can,
				"desc": ("Ataque básico: golpe físico (FUE contra RES). Daño estimado: ~%d." % _battle.attack_preview(_actor))
					if can else "Ahora no puede dar golpes físicos."}]
		"skill":
			var opts := []
			for id: String in p.skills:
				opts.append(_skill_option(id))
			if opts.is_empty():
				opts.append({"label": "Ninguna", "icon": "lock", "disabled": true,
					"desc": "%s no tiene habilidades." % p.name})
			return opts
		"item":
			var opts := []
			var can_use := _battle.can_use_items(_actor)
			for id: String in GameState.inventory:
				var n := GameState.item_count(id)
				if n <= 0 or not ItemDB.usable_in_combat(id):
					continue
				opts.append({"label": "%s  ×%d" % [ItemDB.display_name(id), n], "icon": ItemDB.get_item(id).get("icon", "can"),
					"action": "item:%s" % id, "disabled": not can_use,
					"desc": ItemDB.description(id) if can_use else "Fuera del cuerpo no puede coger nada."})
			if opts.is_empty():
				opts.append({"label": "Nada", "icon": "can", "disabled": true,
					"desc": "No llevas nada que sirva en combate."})
			return opts
		"item_target":
			# Tras elegir objeto: sobre quién del grupo (en pie) se usa.
			var item_id := _pending_item
			var opts := []
			for who in _battle.alive_party():
				var f := _battle.fighter(who)
				var pm_item: bool = ItemDB.get_item(item_id).get("heal", 0) <= 0
				opts.append({"label": f.name, "icon": ItemDB.get_item(item_id).get("icon", "can"), "action": "item:%s:%s" % [item_id, who],
					"desc": "Usar %s con %s (%s)." % [ItemDB.display_name(item_id), f.name,
						("%d/%d PM" % [f.pm, f.pm_max]) if pm_item else ("%d/%d PV" % [f.pv, f.pv_max])]})
			return opts
		"defend":
			return [{"label": "Guardia", "icon": "shield", "action": "defend",
				"desc": "Te cubres: el próximo golpe del rival te hará la mitad de daño."}]
		"analyze":
			return [{"label": "Escanear", "icon": "antenna", "action": "analyze",
				"desc": "Revela los PV y el ataque del rival. No gasta el turno."}]
		"flee":
			if CharacterDB.is_enemy(_enemy_id):
				return [{"label": "Huir", "icon": "run", "action": "flee",
					"desc": "Intentas escapar de la criatura. Cuenta como derrota."}]
			return [{"label": "Rendirse", "icon": "run", "action": "flee",
				"desc": "Abandonas el duelo. Cuenta como derrota."}]
	return []


## Cambia las opciones del comando Objeto por los miembros del grupo.
func _show_item_targets() -> void:
	for c in _options.get_children():
		c.queue_free()
	for opt in _options_for("item_target"):
		var b := PillButton.new()
		b.label = opt.label
		b.icon_name = opt.icon
		b.selectable = true
		b.description = opt.desc
		b.font_size = 24
		b.custom_minimum_size = Vector2(250, 50)
		b.focus_entered.connect(func() -> void: _set_info(b.description))
		b.pressed.connect(_execute.bind(opt.action))
		_options.add_child(b)
	_log("¿A quién?")
	_state = State.OPTION
	(_options.get_child(_options.get_child_count() - 1) as Control).grab_focus.call_deferred()


func _skill_option(id: String) -> Dictionary:
	var skill := SkillDB.get_skill(id)
	var cost := _battle.skill_cost(_actor, id)
	var tier: String = (" Tier %d." % skill.tier) if skill.get("tier", 0) > 0 else ""
	var desc := "%s Efecto: %s. Coste: %d PM.%s" % [skill.desc, _battle.skill_summary(_actor, id), cost, tier]
	if skill.cd > 0:
		desc += " Recarga: %d turnos." % skill.cd
	var problem := _battle.skill_problem(_actor, id)
	var disabled := problem != ""
	if disabled:
		desc = "%s %s" % [problem, desc]
	return {"label": "%s  %d PM" % [skill.name, cost], "icon": skill.get("icon", "sparkle"),
		"action": "skill:" + id, "disabled": disabled, "desc": desc}


func _build_options(index: int) -> void:
	for c in _options.get_children():
		c.queue_free()
	for opt in _options_for(COMMANDS[index].id):
		var b := PillButton.new()
		b.label = opt.label
		b.icon_name = opt.icon
		b.selectable = true
		b.description = opt.desc
		b.disabled = opt.get("disabled", false)
		b.font_size = 24
		b.custom_minimum_size = Vector2(250, 50)
		if b.disabled:
			b.modulate.a = 0.45
		b.focus_entered.connect(func() -> void: _set_info(b.description))
		if opt.has("action"):
			b.pressed.connect(_execute.bind(opt.action))
		_options.add_child(b)


## Abre la pantalla de estado del miembro del grupo de la ficha `slot`.
## Solo mientras el jugador está eligiendo acción.
func _open_status(slot: int) -> void:
	if _state != State.COMMAND and _state != State.OPTION:
		return
	if slot >= _battle.party.size():
		return
	_state = State.STATUS
	get_viewport().gui_release_focus()
	_set_commands_enabled(false)
	_status.open(_battle, _battle.party[slot])


func _on_status_closed() -> void:
	_enter_command_state(_current_command)


func _input(event: InputEvent) -> void:
	# Tab: estado de quien está eligiendo. En _input porque, si no, Tab lo
	# gasta antes el sistema de foco de los botones.
	if visible and (_state == State.COMMAND or _state == State.OPTION) and event.is_action_pressed("ui_focus_next"):
		_open_status(_battle.party.find(_actor))
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _state == State.OPTION and event.is_action_pressed("ui_cancel"):
		_enter_command_state(_current_command)
		get_viewport().set_input_as_handled()
	elif _state == State.RESULT and (event.is_action_pressed("ui_accept") or
			(event is InputEventMouseButton and event.pressed)):
		_state = State.IDLE
		get_viewport().set_input_as_handled()
		finished.emit(_battle.player_won())


func _gui_input(event: InputEvent) -> void:
	if _state == State.RESULT and event is InputEventMouseButton and event.pressed:
		_state = State.IDLE
		accept_event()
		finished.emit(_battle.player_won())


# --- Ejecución de turnos ---------------------------------------------------------------------

func _execute(action: String) -> void:
	if _state != State.COMMAND and _state != State.OPTION:
		return
	# Objeto con más de uno en el grupo: antes, elegir sobre quién.
	var parts := action.split(":")
	if parts[0] == "item" and parts.size() == 2 and _battle.alive_party().size() > 1 and not ItemDB.is_attack(parts[1]):
		_pending_item = parts[1]
		_show_item_targets()
		return
	await _run_action(action)
	await _prompt()


## Da el turno a `_actor`: si pierde el turno (aturdido, desactivado...) o tiene
## que actuar al azar (Adivinación), lo resuelve solo y pasa al siguiente.
func _prompt() -> void:
	while not _battle.is_over():
		var pre := _battle.start_turn(_actor)
		await _play_events(pre.events)
		if _battle.is_over():
			break
		if pre.skip:
			await _advance()
		elif pre.forced != "":
			await _run_action(pre.forced)
		else:
			if _battle.party.size() > 1:
				_log("Turno de %s." % _fighter_name(_actor))
			_enter_command_state(_current_command)
			return
	await _show_result()


## Ejecuta la acción de `_actor` y, si gasta el turno, pasa al siguiente.
func _run_action(action: String) -> void:
	_state = State.ANIMATING
	get_viewport().gui_release_focus()
	_set_commands_enabled(false)

	var events: Array = []
	var uses_turn := true
	match action:
		"attack":
			events = _battle.attack(_actor)
		"defend":
			events = _battle.defend(_actor)
		"analyze":
			events = _battle.analyze()
			uses_turn = false
		"flee":
			events = _battle.surrender()
		_:
			if action.begins_with("item:"):
				var parts := action.split(":")
				events = _battle.use_item(_actor, parts[1], parts[2] if parts.size() > 2 else "")
			elif action.begins_with("skill:"):
				events = _battle.use_skill(_actor, action.substr(6))
	await _play_events(events)
	if not _battle.is_over() and uses_turn:
		await _advance()


## Le toca al siguiente del grupo en pie; si no queda nadie, al rival.
func _advance() -> void:
	var next := _next_actor(_actor)
	if next != "":
		_actor = next
		return
	await get_tree().create_timer(0.35).timeout
	await _play_events(_battle.enemy_turn())
	var alive := _battle.alive_party()
	if not alive.is_empty():
		_actor = alive[0]


## Siguiente miembro del grupo en pie después de `who` en esta ronda ("" si no hay).
func _next_actor(who: String) -> String:
	var i := _battle.party.find(who)
	for j in range(i + 1, _battle.party.size()):
		if _battle.is_alive(_battle.party[j]):
			return _battle.party[j]
	return ""


func _card(who: String) -> CombatantCard:
	return _cards[maxi(_battle.party.find(who), 0)]


func _play_events(events: Array) -> void:
	for ev: Dictionary in events:
		match ev.type:
			"damage":
				if ev.get("immune", false):
					await _anim_immune(ev)
				elif ev.get("shared", false):
					await _anim_shared(ev)
				elif ev.target == Battle.ENEMY:
					await _anim_player_hits(ev)
				else:
					await _anim_enemy_hits(ev)
			"miss":
				_log("%s falla: %s no alcanza a %s." % [_fighter_name(ev.source), ev.move, _fighter_name(ev.target)])
				_popup(ev.target, "FALLO", UIStyle.GRAY)
				await get_tree().create_timer(0.7).timeout
			"self_damage":
				var why := SkillDB.display_name(ev.skill) if ev.skill != "" else "El calor de la sobrecarga"
				_log("%s: %s pierde %d PV." % [why, _fighter_name(ev.target), ev.amount])
				_refresh_pv(ev.target)
				_popup(ev.target, str(ev.amount), Color("ff6b7d"))
				await get_tree().create_timer(0.7).timeout
			"pm_restore":
				_log("%s: %s recupera %d PM." % [SkillDB.display_name(ev.skill), _fighter_name(ev.target), ev.amount])
				if ev.target != Battle.ENEMY:
					_card(ev.target).animate_pm(_battle.fighter(ev.target).pm)
				_popup(ev.target, "+%d PM" % ev.amount, CombatantCard.PM_COLOR)
				await get_tree().create_timer(0.7).timeout
			"regen":
				_log("%s: %s recupera %d PV." % [SkillDB.STATUS_NAMES.get(ev.status, ev.status), _fighter_name(ev.target), ev.amount])
				_refresh_pv(ev.target)
				_popup(ev.target, "+%d" % ev.amount, UIStyle.LIME)
				await get_tree().create_timer(0.6).timeout
			"cleanse":
				var names: Array = ev.statuses.map(func(s: String) -> String: return SkillDB.STATUS_NAMES.get(s, s).to_lower())
				_log("%s se libra de %s." % [_fighter_name(ev.target), ", ".join(names)] if not names.is_empty()
						else "%s no tenía nada que quitarse." % _fighter_name(ev.target))
				_update_status_tags()
				await get_tree().create_timer(0.6).timeout
			"skip":
				_log("%s pierde el turno (%s)." % [_fighter_name(ev.target), SkillDB.STATUS_NAMES.get(ev.status, ev.status).to_lower()])
				await get_tree().create_timer(0.8).timeout
			"random":
				_log("%s se deja llevar por la intuición..." % _fighter_name(ev.target))
				await get_tree().create_timer(0.7).timeout
			"wait":
				_log("%s no puede hacer nada." % _fighter_name(ev.target))
				await get_tree().create_timer(0.7).timeout
			"heal":
				await _anim_heal(ev)
			"skill":
				await _anim_skill(ev)
			"restore":
				await _anim_restore(ev)
			"status":
				await _anim_status(ev)
			"tick":
				await _anim_tick(ev)
			"status_end":
				_log("%s: %s se disipa." % [_fighter_name(ev.target), SkillDB.STATUS_NAMES.get(ev.status, ev.status)])
				_update_status_tags()
				await get_tree().create_timer(0.6).timeout
			"defend":
				_card(ev.target).guarding = true
				_log("%s se pone en guardia." % _fighter_name(ev.target))
				await get_tree().create_timer(0.6).timeout
			"analyze":
				_plate.analyzed = true
				var e := _battle.enemy()
				var text := "Analizas a %s (nivel %d): %d / %d PV. Ataque: %s (~%d de daño)." % [e.name, e.level, e.pv, e.pv_max, e.attack, _battle.attack_preview(Battle.ENEMY)]
				if e.nature != "":
					text += " Naturaleza: %s." % SkillDB.NATURE_NAMES.get(e.nature, e.nature)
				if not e.skills.is_empty():
					text += " Técnicas: %s." % ", ".join(e.skills.map(SkillDB.display_name))
				_log(text)
				await get_tree().create_timer(0.8).timeout
			"surrender":
				_log("%s levanta las manos. Se acabó el duelo." % _pname())
				await get_tree().create_timer(0.8).timeout
		for who in _battle.party:
			_card(who).guarding = _battle.fighter(who).defending
		_tween_tension()


func _anim_player_hits(ev: Dictionary) -> void:
	var e := _battle.enemy()
	if ev.skill != "":
		_log("%s recibe %d de daño." % [e.name, ev.amount])
	else:
		_log("%s usa %s. %s recibe %d de daño." % [_fighter_name(ev.source), ev.move, e.name, ev.amount])
	# Animación del tipo de golpe sobre el rival (ver AttackFx).
	var kind := AttackFx.kind_for(ev.skill)
	var fx := AttackFx.play(_fx, _enemy.position + Vector2(_enemy.size.x * 0.5, 260), kind)
	await get_tree().create_timer(AttackFx.DURATION[kind] * 0.6).timeout
	_flash_enemy()
	_shake(_enemy, 24.0 if kind == "mechanical" else 14.0)
	if is_instance_valid(fx):
		await fx.done
	_plate.animate_pv(e.pv)
	DamagePopup.spawn(_fx, _enemy.position + Vector2(_enemy.size.x * 0.5, 160), str(ev.amount), UIStyle.WHITE)
	await get_tree().create_timer(0.7).timeout


func _anim_enemy_hits(ev: Dictionary) -> void:
	var e := _battle.enemy()
	var extra := " (guardia)" if ev.get("guarded", false) else ""
	if ev.skill != "":
		_log("%s recibe %d de daño%s." % [_fighter_name(ev.target), ev.amount, extra])
	else:
		_log("%s usa %s. %s recibe %d de daño%s." % [e.name, ev.move, _fighter_name(ev.target), ev.amount, extra])
	# El rival se abalanza hacia la cámara.
	var t := create_tween()
	t.tween_property(_enemy, "scale", Vector2(1.12, 1.12), 0.12).set_trans(Tween.TRANS_QUAD)
	t.tween_property(_enemy, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD)
	await get_tree().create_timer(0.12).timeout
	# Animación del tipo de golpe sobre la ficha de quien lo recibe.
	var kind := AttackFx.kind_for(ev.skill, e.get("nature", ""))
	var card := _card(ev.target)
	AttackFx.play(self, card.position + card.size * 0.5, kind, 0.3)
	_shake(self, 16.0 if kind == "mechanical" else 10.0)
	_card(ev.target).flash(UIStyle.RED)
	_card(ev.target).animate_pv(_battle.fighter(ev.target).pv)
	DamagePopup.spawn(self, _card(ev.target).position + Vector2(_card(ev.target).size.x * 0.55, 30), str(ev.amount), Color("ff6b7d"), false)
	await get_tree().create_timer(0.75).timeout


func _anim_heal(ev: Dictionary) -> void:
	var item_name: String = ItemDB.get_item(ev.item).get("name", "objeto")
	var pm: int = ev.get("pm", 0)
	var gain := ("%d PM" % pm) if pm > 0 and ev.amount <= 0 else ("%d PV" % ev.amount)
	if ev.target != Battle.ENEMY:
		if ev.get("source", ev.target) != ev.target:
			_log("%s le da un %s a %s. Recupera %s." % [_fighter_name(ev.source), item_name, _fighter_name(ev.target), gain]
					if pm > 0 else "%s le da una %s a %s. Recupera %s." % [_fighter_name(ev.source), item_name, _fighter_name(ev.target), gain])
		else:
			_log("%s se toma %s. Recupera %s." % [_fighter_name(ev.target), item_name, gain])
		var col := CombatantCard.PM_COLOR if pm > 0 else UIStyle.LIME
		_card(ev.target).flash(col)
		_card(ev.target).animate_pv(_battle.fighter(ev.target).pv)
		_card(ev.target).animate_pm(_battle.fighter(ev.target).pm)
		DamagePopup.spawn(self, _card(ev.target).position + Vector2(_card(ev.target).size.x * 0.55, 30),
				("+%d PM" % pm) if pm > 0 and ev.amount <= 0 else "+%d" % ev.amount, col, false)
	else:
		var e := _battle.enemy()
		_log("%s bebe una %s. Recupera %d PV." % [e.name, item_name, ev.amount])
		_plate.animate_pv(e.pv)
		DamagePopup.spawn(_fx, _enemy.position + Vector2(_enemy.size.x * 0.5, 160), "+%d" % ev.amount, UIStyle.LIME)
	await get_tree().create_timer(0.8).timeout


## Anuncio de una habilidad: nombre, gasto de PM y destello del color de su naturaleza.
func _anim_skill(ev: Dictionary) -> void:
	var skill := SkillDB.get_skill(ev.skill)
	var color := SkillDB.nature_color(skill.nature)
	_log("%s usa %s." % [_fighter_name(ev.source), skill.name])
	if ev.source != Battle.ENEMY:
		_card(ev.source).animate_pm(_battle.fighter(ev.source).pm)
		_card(ev.source).flash(color)
		DamagePopup.spawn(self, _card(ev.source).position + Vector2(_card(ev.source).size.x * 0.3, 60), "−%d PM" % ev.cost, CombatantCard.PM_COLOR, false)
	else:
		var t := create_tween()
		_enemy.modulate = Color(color.r * 1.8, color.g * 1.8, color.b * 1.8)
		t.tween_property(_enemy, "modulate", Color.WHITE, 0.45)
	_skill_banner(skill.name, color)
	await get_tree().create_timer(0.6).timeout


func _anim_restore(ev: Dictionary) -> void:
	var skill_name := SkillDB.display_name(ev.skill)
	if ev.target != Battle.ENEMY:
		_log("%s: %s recupera %d PV." % [skill_name, _fighter_name(ev.target), ev.amount])
		_card(ev.target).flash(UIStyle.LIME)
		_card(ev.target).animate_pv(_battle.fighter(ev.target).pv)
		DamagePopup.spawn(self, _card(ev.target).position + Vector2(_card(ev.target).size.x * 0.55, 30), "+%d" % ev.amount, UIStyle.LIME, false)
	else:
		var e := _battle.enemy()
		_log("%s: %s recupera %d PV." % [skill_name, e.name, ev.amount])
		_plate.animate_pv(e.pv)
		DamagePopup.spawn(_fx, _enemy.position + Vector2(_enemy.size.x * 0.5, 160), "+%d" % ev.amount, UIStyle.LIME)
	await get_tree().create_timer(0.8).timeout


func _anim_status(ev: Dictionary) -> void:
	var status_name: String = SkillDB.STATUS_NAMES.get(ev.status, ev.status)
	var who := _fighter_name(ev.target)
	var debuff: bool = SkillDB.status(ev.status).get("debuff", false)
	var turns := "%d turno%s" % [ev.turns, "" if ev.turns == 1 else "s"]
	if ev.get("immune", false):
		_log("A %s no le afecta: %s." % [who, status_name.to_lower()])
	elif ev.applied and debuff:
		_log("¡%s sufre %s durante %s! (%d %%)" % [who, status_name.to_lower(), turns, roundi(ev.chance)])
		if ev.target != Battle.ENEMY:
			_card(ev.target).flash(UIStyle.VIOLET)
	elif ev.applied:
		_log("%s: %s durante %s." % [who, status_name, turns])
		if ev.target != Battle.ENEMY:
			_card(ev.target).flash(UIStyle.LIME)
	else:
		_log("%s resiste: %s. (%d %%)" % [who, status_name.to_lower(), roundi(ev.chance)])
	_update_status_tags()
	await get_tree().create_timer(0.8).timeout


func _anim_tick(ev: Dictionary) -> void:
	var status_name: String = SkillDB.STATUS_NAMES.get(ev.status, ev.status)
	_log("%s: %s pierde %d PV." % [status_name, _fighter_name(ev.target), ev.amount])
	if ev.target != Battle.ENEMY:
		_card(ev.target).flash(UIStyle.VIOLET)
		_card(ev.target).animate_pv(_battle.fighter(ev.target).pv)
		DamagePopup.spawn(self, _card(ev.target).position + Vector2(_card(ev.target).size.x * 0.55, 30), str(ev.amount), UIStyle.VIOLET, false)
	else:
		_plate.animate_pv(_battle.enemy().pv)
		DamagePopup.spawn(_fx, _enemy.position + Vector2(_enemy.size.x * 0.5, 160), str(ev.amount), UIStyle.VIOLET)
	_update_status_tags()
	await get_tree().create_timer(0.7).timeout


## Golpe sin efecto: el objetivo está fuera de su cuerpo.
func _anim_immune(ev: Dictionary) -> void:
	_log("%s atraviesa a %s sin hacerle nada." % [ev.move, _fighter_name(ev.target)])
	_popup(ev.target, "INMUNE", UIStyle.VIOLET)
	await get_tree().create_timer(0.7).timeout


## Parte del daño que llega por Empatía.
func _anim_shared(ev: Dictionary) -> void:
	_log("Empatía: %s comparte el golpe y recibe %d de daño." % [_fighter_name(ev.target), ev.amount])
	if ev.target != Battle.ENEMY:
		_card(ev.target).flash(UIStyle.RED)
	_refresh_pv(ev.target)
	_popup(ev.target, str(ev.amount), Color("ff6b7d"))
	await get_tree().create_timer(0.6).timeout


## Actualiza la barra de PV de `who` (ficha o placa del rival).
func _refresh_pv(who: String) -> void:
	if who == Battle.ENEMY:
		_plate.animate_pv(_battle.enemy().pv)
	else:
		_card(who).animate_pv(_battle.fighter(who).pv)


## Número flotante sobre `who`.
func _popup(who: String, text: String, color: Color) -> void:
	if who == Battle.ENEMY:
		DamagePopup.spawn(_fx, _enemy.position + Vector2(_enemy.size.x * 0.5, 160), text, color)
	else:
		DamagePopup.spawn(self, _card(who).position + Vector2(_card(who).size.x * 0.55, 30), text, color, false)


func _update_status_tags() -> void:
	for who in _battle.party:
		var parts := []
		var statuses: Dictionary = _battle.fighter(who).statuses
		for status: String in statuses:
			parts.append("%s %d" % [SkillDB.STATUS_NAMES.get(status, status).to_upper(), statuses[status].turns])
		_card(who).status_text = " · ".join(parts)
		_card(who).statuses = StatusBadges.from_fighter(_battle.fighter(who))
	_plate.statuses = StatusBadges.from_fighter(_battle.enemy())


func _pname() -> String:
	return _battle.player().name


func _fighter_name(who: String) -> String:
	return _battle.fighters[who].name


## Nombre de la habilidad en grande sobre el visor durante un momento.
func _skill_banner(text: String, color: Color) -> void:
	_banner_text = text
	_banner_color = color
	var t := create_tween()
	t.tween_method(func(v: float) -> void:
		_banner_t = v
		_fx.queue_redraw(), 0.0, 1.0, 1.1)
	t.tween_callback(func() -> void:
		_banner_text = ""
		_fx.queue_redraw())


func _show_result() -> void:
	var won := _battle.player_won()
	_result_text = "VICTORIA" if won else "DERROTA"
	_result_color = UIStyle.LIME if won else UIStyle.RED
	_result_sub = ""
	_result_levels = ""
	var gains: Array[String] = []
	var money := _battle.reward()
	if money > 0:
		GameState.add_money(money)
		gains.append("+ ¥ %s" % UIStyle.format_money(money))
		queue_redraw()   # La cabecera muestra el dinero.
	var xp := _battle.xp_reward()
	if xp > 0:
		var results := GameState.grant_xp(_battle.party_ids(), xp)
		gains.append("+ %d EXP" % xp)
		_result_levels = GameState.level_up_text(results)
		for i in _battle.party.size():
			var f := _battle.fighter(_battle.party[i])
			f.level = GameState.level_of(f.id)
			_cards[i].setup(f.id, i + 1, f)
	_result_sub = "   ·   ".join(gains)
	if won:
		var t := create_tween()
		t.tween_property(_enemy, "modulate", Color(0.35, 0.35, 0.4, 1.0), 0.5)
	_set_info("Pulsa Enter para continuar.")
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		_result_t = v
		_fx.queue_redraw(), 0.0, 1.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	_state = State.RESULT


# --- Efectos --------------------------------------------------------------------------------

func _flash_enemy() -> void:
	var t := create_tween()
	_enemy.modulate = Color(2.2, 2.2, 2.2)
	t.tween_property(_enemy, "modulate", Color.WHITE, 0.3)


func _shake(node: Control, strength: float) -> void:
	var origin := node.position
	var t := create_tween()
	for i in 6:
		var off := Vector2(randf_range(-1, 1), randf_range(-0.5, 0.5)) * strength * (1.0 - i / 6.0)
		t.tween_property(node, "position", origin + off, 0.035)
	t.tween_property(node, "position", origin, 0.04)


func _tween_tension() -> void:
	create_tween().tween_method(func(v: float) -> void:
		_tension_shown = v
		_fx.queue_redraw(), _tension_shown, _battle.tension, 0.4)


## Registro del combate: se muestra en el visor y también en la barra inferior.
func _log(text: String) -> void:
	_log_text = text
	_set_info(text)
	_fx.queue_redraw()


func _set_info(text: String) -> void:
	_info_text = text
	if _info:
		_info.queue_redraw()


# --- Dibujo ------------------------------------------------------------------------------------

func _draw() -> void:
	var w := size.x
	draw_rect(Rect2(Vector2.ZERO, size), UIStyle.INK)

	# Cabecera izquierda: barra roja, título y subtítulo.
	draw_rect(Rect2(28, 16, 12, 50), UIStyle.RED)
	var title := "Combate - %s" % (CharacterDB.display_name(_enemy_id) if _enemy_id != "" else "")
	draw_string(UIStyle.FONT_MEDIUM, Vector2(70, 46), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, UIStyle.WHITE)
	var sub := "%s / Zona: %s" % [GameState.region_name, LocationDB.display_name(GameState.location_id)]
	UIStyle.draw_spaced(self, UIStyle.FONT_REGULAR, Vector2(72, 74), sub, 18, 1.5, Color(UIStyle.WHITE, 0.9))

	# Línea de marco superior con quiebros (une cabecera y columna derecha).
	draw_polyline(PackedVector2Array([
		Vector2(0, 112), Vector2(24, 88), Vector2(500, 88), Vector2(522, 70),
		Vector2(1400, 70), Vector2(1430, 40), Vector2(1440, 40),
	]), UIStyle.LINE, 1.5, true)

	# Cabecera derecha: fecha y dinero.
	var hdr := PackedVector2Array([Vector2(1440, 40), Vector2(1470, 6), Vector2(1790, 6), Vector2(1760, 40)])
	draw_colored_polygon(hdr, Color(UIStyle.INK, 1.0))
	UIIcons.calendar(self, Vector2(1490, 26), 26, UIStyle.WHITE)
	draw_string(UIStyle.FONT_MEDIUM, Vector2(1516, 36), GameState.weekday_short().capitalize(), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UIStyle.WHITE)
	draw_line(Vector2(1592, 14), Vector2(1592, 40), UIStyle.WHITE, 1.5)
	draw_string(UIStyle.FONT_MEDIUM, Vector2(1608, 36), "¥ %s" % UIStyle.format_money(GameState.money), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UIStyle.WHITE)
	for i in 7:
		var sx := w - 120 + i * 14
		draw_line(Vector2(sx, 40), Vector2(sx + 16, 6), UIStyle.WHITE, 2.5, true)

	# Marco del visor.
	var vp := UIStyle.chamfer_rect(VIEWPORT_RECT, [0.0, 0.0, 22.0, 0.0])
	UIStyle.draw_outline(self, vp, UIStyle.LINE, 1.5)

	# Línea de guía a la izquierda de los comandos.
	draw_line(Vector2(0, COMMAND_Y + 40), Vector2(70, COMMAND_Y + 40), UIStyle.LINE, 1.5)



func _draw_info() -> void:
	var r := Rect2(Vector2.ZERO, _info.size)
	var shape := PackedVector2Array([
		Vector2(0, 16), Vector2(16, 0), Vector2(r.size.x - 22, 0), Vector2(r.size.x, 18),
		Vector2(r.size.x, r.size.y - 16), Vector2(r.size.x - 16, r.size.y), Vector2(0, r.size.y),
	])
	_info.draw_colored_polygon(shape, Color(UIStyle.INK, 0.9))
	UIStyle.draw_outline(_info, shape, UIStyle.LINE, 1.5)
	var div_x := 960.0
	_info.draw_line(Vector2(div_x, 14), Vector2(div_x, r.size.y - 14), Color(UIStyle.WHITE, 0.6), 1.5)
	_info.draw_colored_polygon(UIStyle.slanted_rect(Rect2(div_x + 34, 22, 9, 28), 7), UIStyle.LIME)
	_info.draw_string(UIStyle.FONT_REGULAR, Vector2(div_x + 60, 44), _info_text, HORIZONTAL_ALIGNMENT_LEFT,
			r.size.x - div_x - 80, 23, UIStyle.WHITE)


func _draw_fx() -> void:
	var vs := _fx.size
	# Medidor de Tensión (abajo a la izquierda del visor).
	var ty := vs.y - 50
	var tshape := PackedVector2Array([Vector2(0, ty), Vector2(460, ty), Vector2(508, vs.y), Vector2(0, vs.y)])
	_fx.draw_colored_polygon(tshape, Color(UIStyle.INK, 0.95))
	UIStyle.draw_outline(_fx, tshape, UIStyle.LINE, 1.5)
	_fx.draw_string(UIStyle.FONT_MEDIUM, Vector2(48, ty + 35), "Tensión", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UIStyle.WHITE)
	var filled := roundi(_tension_shown * 8.0)
	for i in 8:
		var col := UIStyle.MAGENTA if i < filled else Color(UIStyle.WHITE, 0.25)
		_fx.draw_colored_polygon(UIStyle.slanted_rect(Rect2(200 + i * 17, ty + 14, 12, 24), 7), col)
	_fx.draw_string(UIStyle.FONT_MEDIUM, Vector2(360, ty + 37), "%d %%" % roundi(_tension_shown * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UIStyle.WHITE)

	# Registro: última acción, a la derecha del medidor.
	if _log_text != "":
		var lx := 540.0
		var lshape := UIStyle.slanted_rect(Rect2(lx, ty + 6, vs.x - lx - 20, 40), 16)
		_fx.draw_colored_polygon(lshape, Color(UIStyle.INK, 0.7))
		_fx.draw_colored_polygon(UIStyle.slanted_rect(Rect2(lx + 26, ty + 14, 8, 24), 6), UIStyle.MAGENTA)
		_fx.draw_string(UIStyle.FONT_REGULAR_ITALIC, Vector2(lx + 48, ty + 34), _log_text, HORIZONTAL_ALIGNMENT_LEFT,
				vs.x - lx - 90, 21, UIStyle.WHITE)

	# Nombre de la habilidad: entra deslizándose, se mantiene y se desvanece.
	if _banner_text != "":
		var bt := _banner_t
		var a := clampf(bt * 6.0, 0.0, 1.0) * clampf((1.0 - bt) * 4.0, 0.0, 1.0)
		var bf := UIStyle.FONT_HEAVY_ITALIC
		var bw := bf.get_string_size(_banner_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 54).x
		var bx := vs.x - bw - 60 + (1.0 - clampf(bt * 6.0, 0.0, 1.0)) * 80
		var by := 190.0
		_fx.draw_colored_polygon(UIStyle.slanted_rect(Rect2(bx - 40, by - 50, bw + 80, 66), 22), Color(UIStyle.INK, 0.85 * a))
		_fx.draw_rect(Rect2(bx - 30, by + 16, bw + 60, 4), Color(_banner_color, a))
		_fx.draw_string(bf, Vector2(bx, by), _banner_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 54, Color(UIStyle.WHITE, a))
	# Banda de resultado.
	if _result_text != "":
		var p := _result_t
		var band_h := 150.0
		var y := vs.y * 0.42
		_fx.draw_rect(Rect2(0, y - band_h * 0.5 * p, vs.x, band_h * p), Color(UIStyle.INK, 0.85))
		_fx.draw_rect(Rect2(0, y + band_h * 0.5 * p, vs.x * p, 4), _result_color)
		_fx.draw_rect(Rect2(vs.x * (1.0 - p), y - band_h * 0.5 * p - 4, vs.x * p, 4), _result_color)
		var f := UIStyle.FONT_HEAVY_ITALIC
		var tw := f.get_string_size(_result_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 110).x
		_fx.draw_string(f, Vector2((vs.x - tw) * 0.5 + (1.0 - p) * 200, y + 40), _result_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 110, Color(_result_color, p))
		if _result_sub != "":
			var sf := UIStyle.FONT_SEMIBOLD
			var sw := sf.get_string_size(_result_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
			_fx.draw_string(sf, Vector2((vs.x - sw) * 0.5, y + band_h * 0.5 * p + 52), _result_sub,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(UIStyle.WHITE, p))
		if _result_levels != "":
			var lf := UIStyle.FONT_BOLD_ITALIC
			var lw := lf.get_string_size(_result_levels, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
			_fx.draw_string(lf, Vector2((vs.x - lw) * 0.5, y + band_h * 0.5 * p + 98), _result_levels,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(UIStyle.LIME, p))
