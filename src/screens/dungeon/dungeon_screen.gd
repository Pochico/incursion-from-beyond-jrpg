class_name DungeonScreen
extends Control
## Modo mazmorra: exploración en primera persona con la interfaz del combate.
##
## Composición (base 1920×1080, la misma que CombatView):
##  - Cabecera magenta «Mazmorra - <lugar>», planta; fecha y dinero arriba a la derecha.
##  - Visor grande: la vista 3D (DungeonExplorer). Lo que hay justo delante y se
##    puede usar (puerta, palanca, objeto, criatura) se recuadra; clic encima o
##    Espacio para usarlo.
##  - Columna derecha: automapa (en el hueco del minimapa) y fichas del grupo:
##    Ren y los que ha elegido para la grieta (GameState.expedition, hasta 3) o,
##    en La Torre, un compañero al azar (CharacterDB.COMPANIONS). Clic en una
##    ficha (o Tab) abre su pantalla de estado.
##  - Fila de comandos: Usar, Habilidades, Objetos, Mapa, Salir.
##  - Fila de opciones + descripción / registro.
##
## El mapa es `dungeon_map` de la ubicación actual (LocationDB). El progreso
## (puertas, enemigos vencidos, objetos cogidos, automapa) se guarda en
## GameState.dungeons; al volver se empieza otra vez en la entrada.
##
## Incursión: los PV y PM del grupo pasan de un combate a otro (se curan con
## objetos y habilidades, también explorando) y se recuperan al salir. Lo
## conseguido (objetos y dinero) solo se conserva saliendo desde una zona de
## extracción (o la entrada, ver DungeonMap.is_extraction); saliendo desde otro
## sitio se pierde y los objetos vuelven a su sitio. Por eso no se guarda la
## partida hasta salir.
##
## Escáner: cada incursión empieza con ItemDB.charges(ItemDB.SCANNER) cargas; cada
## pulso gasta una y las baterías (que traen las cajas) dan más. Al coger una caja
## se ofrece abrirla ya o guardarla (se abre luego desde Objetos o el móvil).
##
## La grieta (fase 6, GameState.expedition no vacío): el mapa es ChapterDB.RIFT_MAP
## (mientras no exista, RIFT_FALLBACK_MAP). Retirada forzada en combate y antes
## de empezar uno (Battle.should_retreat): se sale sin perder nada. Hasta tener
## el escáner se entra con lo puesto: sin objetos que curen. El escáner está en
## el mapa; si no lo traen de la primera, en la segunda lo encuentra alguien en
## la entrada. Al salir: fase `exploracion_1` (o `escaner`, si ya lo tienen).
## Perder un combate (caen todos) devuelve a la entrada y deshace todo lo
## ganado en la incursión.
##
## El compañero comenta de vez en cuando en el registro del visor (DungeonBanter):
## al andar, ante una criatura, junto a una pared falsa, al coger algo…

const WORLD_SCREEN := "res://src/screens/world/world_screen.tscn"
const VIEWPORT_RECT := Rect2(10, 96, 1418, 782)
const COMMAND_Y := 898.0
const OPTION_ROW := Rect2(30, 990, 1864, 70)
const RIGHT_X := 1440.0
const ACCENT := UIStyle.MAGENTA
const PULSE_PINK := Color("f0a8ff")   ## brillo del pulso del escáner (ver pulse.gdshader)

const COMMANDS := [
	{"id": "use", "label": "Usar", "icon": "sparkle", "desc": "Usar lo que hay justo delante: abrir, coger, accionar o luchar."},
	{"id": "skills", "label": "Habilidades", "icon": "heart", "desc": "Habilidades que sirven fuera del combate: curar o recuperar PM."},
	{"id": "items", "label": "Objetos", "icon": "flask", "desc": "Lo que llevas encima. Los que curan se usan sobre quien elijas; el escáner lanza un pulso que delata paredes secretas.  [F]"},
	{"id": "pulse", "label": "Escáner", "icon": "alert", "desc": "Lanza un pulso que delata paredes secretas. Gasta una carga.  [F]"},
	{"id": "map", "label": "Mapa", "icon": "calendar", "desc": "Automapa de la planta: lo que ya has recorrido.  [M]"},
	{"id": "look", "label": "Vista", "icon": "play", "desc": "Cambia el estilo visual: normal, PS2 o PS1.  [V]"},
	{"id": "exit", "label": "Salir", "icon": "run", "desc": "Volver a la calle. Desde una zona de extracción (círculo cian) te llevas lo conseguido."},
]
const EXIT_WARNING := "Si sales ahora perderás todo lo que hayas conseguido. Hay zonas de extracción segura. ¿Quieres salir?"

var _map: DungeonMap
var _map_id := ""
var _explorer: DungeonExplorer
var _view: SubViewportContainer
var _fx: Control
var _automap: DungeonAutomap
var _big_map: DungeonAutomap
var _cards: Array[CombatantCard] = []
var _commands: Array[SlantButton] = []
var _info: Control
var _options: HBoxContainer
var _combat: CombatView
var _info_text := ""
var _log_text := ""
var _target: Dictionary = {}
var _target_rect := Rect2()
var _hover_target := false
var _console_rect := Rect2()   ## consola junto a la puerta de delante (se puede señalar)
var _hover_console := false
var _busy := false          ## combate o salida en curso
var _status: StatusPanel

# Grupo: Ren y el compañero de esta visita.
var _companion := ""            ## quien habla en el registro (uno del grupo)
var _companion_skills: Array = []
var _party: Array = []          ## compañeros de Ren en esta incursión (ids)
var _rift := false              ## incursión en la grieta (con equipo elegido)
var _entry: Dictionary = {}     ## lo que había al entrar (perder vuelve aquí)
var _party_battle: Battle    ## PV/PM del grupo fuera del combate, fichas y pantalla de estado
var _vitals: Dictionary = {}  ## PV y PM del grupo en esta incursión (Battle.party_vitals)
var _run_start: Dictionary = {}  ## inventario, dinero y objetos cogidos al entrar
var _was_extraction := false
var _charges := 0              ## cargas del escáner en esta incursión

# Comentarios del compañero.
const IDLE_STEPS := Vector2i(9, 17)    ## pasos entre comentarios sueltos
const COMMENT_GAP := 3                 ## pasos mínimos entre comentarios
var _log_who := ""
var _extra := 0.0          ## ancho de más sobre 1920 (pantallas alargadas): lo gana el visor
var _pad: Control          ## cruceta táctil (solo en pantallas táctiles)
var _map_close: Button
var _steps := 0
var _next_idle := 0
var _last_comment := -99
var _comment_gen := 0
var _last_pos := Vector3i(0, 0, -999)    ## (x, y, planta) de la última casilla
var _remarked := {}                      ## criaturas y paredes falsas ya comentadas


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_map_id = LocationDB.get_location(GameState.location_id).get("dungeon_map", "torre")
	_rift = not GameState.expedition.is_empty()
	if _map_id == ChapterDB.RIFT_MAP and not FileAccess.file_exists(DungeonMap.path_for(_map_id)):
		_map_id = ChapterDB.RIFT_FALLBACK_MAP   # provisional, hasta que exista el mapa de la grieta
	_map = DungeonMap.load_map(_map_id)
	_build()
	resized.connect(_layout)
	_layout()
	if _map == null:
		_log("No se encuentra el mapa «%s» (src/data/mazmorras/)." % _map_id)
		return
	if _rift:
		_party = GameState.expedition.duplicate()
	else:
		_companion = CharacterDB.COMPANIONS.pick_random()
		_companion_skills = SkillDB.random_skills(2, CharacterDB.combat_tags(_companion), CharacterDB.get_character(_companion).get("nature", ""))
		_party = [_companion]
	_next_idle = randi_range(IDLE_STEPS.x, IDLE_STEPS.y)
	_explorer.setup(_map, GameState.dungeon_state(_map_id))
	DungeonLook.apply(_view, _explorer)
	_mark_run_start()
	_entry = _run_start.duplicate(true)
	_charges = ItemDB.charges(ItemDB.SCANNER)
	_was_extraction = _explorer.at_extraction()
	_refresh_party()
	_set_info(COMMANDS[0].desc)
	var names: Array = _party.map(func(w: String) -> String: return CharacterDB.display_name(w))
	_log("Entras en %s%s." % [_place_name(),
			(" con " + _group_name(_party)) if not names.is_empty() else " a solas"])
	if _rift and GameState.phase_at_least("exploracion_1") and GameState.item_count(ItemDB.SCANNER) <= 0:
		_find_scanner_at_entry()
	else:
		_comment("enter", 1.8, true)


## Segunda entrada sin el escáner: alguien del grupo lo encuentra en la entrada.
func _find_scanner_at_entry() -> void:
	await get_tree().create_timer(2.0).timeout
	GameState.add_item(ItemDB.SCANNER)
	_mark_run_start()
	_entry = _run_start.duplicate(true)
	_charges = ItemDB.charges(ItemDB.SCANNER)
	var who: String = _party.pick_random() if not _party.is_empty() else ""
	var line := DungeonBanter.line(who, "scanner") if who != "" else ""
	if line != "":
		_companion = who
		_say(line)
	else:
		_log("En la entrada, enganchado a la pared, hay un escáner. Te lo guardas.")
	await get_tree().create_timer(3.0).timeout
	if is_inside_tree() and not _busy:
		_log("Tienes el escáner: Analizar en combate y pulso en la mazmorra [F].")


# --- Construcción ----------------------------------------------------------------------

func _build() -> void:
	_view = SubViewportContainer.new()
	_view.stretch = true
	_view.position = VIEWPORT_RECT.position + Vector2(2, 2)
	_view.size = VIEWPORT_RECT.size - Vector2(4, 4)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X   # (el estilo visual lo cambia: DungeonLook)
	_view.add_child(vp)
	_explorer = DungeonExplorer.new()
	vp.add_child(_explorer)
	_explorer.moved.connect(func(_c: Vector2i, _d: int) -> void: _on_moved())
	_explorer.level_changed.connect(func(_l: int) -> void:
		queue_redraw()
		_on_moved()
		_first_visit_xp())
	_explorer.message.connect(_log)
	_explorer.pulse_finished.connect(_on_pulse_finished)
	_explorer.save_point_used.connect(func(_c: Vector2i) -> void: _use_save_point())
	_explorer.encounter.connect(_on_encounter)
	_explorer.item_taken.connect(func(id: String, _n: int) -> void:
		if not ItemDB.is_box(id):   # con la caja, la pregunta se queda a la vista
			_comment("item", 1.3))
	_explorer.box_found.connect(_offer_box)
	_explorer.noticed.connect(func(kind: String) -> void:
		_comment(kind, 1.6 if kind == "secret_found" else 1.3, kind == "secret_found")
		if kind == "secret_found":
			_explore_xp(ProgressionDB.secret_xp(_map.creature_level()), "Pasadizo descubierto"))

	# Capa sobre el visor: recuadro de lo de delante, registro y clics.
	_fx = Control.new()
	_fx.position = _view.position
	_fx.size = _view.size
	_fx.clip_contents = true
	_fx.mouse_filter = Control.MOUSE_FILTER_STOP
	_fx.draw.connect(_draw_fx)
	_fx.gui_input.connect(_on_view_input)
	add_child(_fx)

	_big_map = DungeonAutomap.new()
	_big_map.big = true
	_big_map.explorer = _explorer
	_big_map.position = _view.position + Vector2(60, 40)
	_big_map.size = _view.size - Vector2(120, 80)
	_big_map.visible = false
	add_child(_big_map)
	_map_close = _round_button("✕", 64, 34)
	_map_close.pressed.connect(_toggle_map)
	_big_map.add_child(_map_close)

	if App.is_touch():
		_build_touch_pad()

	# Columna derecha
	_automap = DungeonAutomap.new()
	_automap.explorer = _explorer
	_automap.position = Vector2(RIGHT_X, 62)
	_automap.size = Vector2(1908 - RIGHT_X, 238)
	add_child(_automap)
	for i in 4:
		var card := CombatantCard.new()
		card.position = Vector2(RIGHT_X, 310 + i * 102)
		card.size = Vector2(1908 - RIGHT_X, 94)
		card.pressed.connect(_open_status.bind(i))
		add_child(card)
		_cards.append(card)

	# Comandos (los reparte _layout a lo ancho)
	for i in COMMANDS.size():
		var b := SlantButton.new()
		b.label = COMMANDS[i].label
		b.icon_name = COMMANDS[i].icon
		b.description = COMMANDS[i].desc
		b.hover_focus = false
		b.focus_mode = Control.FOCUS_NONE   # las flechas son para andar
		b.font_size = 24
		b.slant = 22
		b.mouse_entered.connect(func() -> void: _set_info(COMMANDS[i].desc))
		b.pressed.connect(_on_command.bind(COMMANDS[i].id))
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
	_options.clip_contents = true
	_options.add_theme_constant_override("separation", 18)
	add_child(_options)

	_status = StatusPanel.new()
	_status.size = Vector2(1920, 1080)
	add_child(_status)

	# Combate, por encima de todo.
	_combat = CombatView.new()
	_combat.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg: String = LocationDB.get_location(GameState.location_id).get("battle_background", "")
	if bg != "" and ResourceLoader.exists(bg):
		_combat.backdrop_override = load(bg)
	add_child(_combat)


## Fichas de Ren y del compañero con sus datos de combate (los PV se recuperan
## al salir de cada combate). El combate «de mentira» sirve a la pantalla de estado.
func _refresh_party() -> void:
	var old_max := {}
	if _party_battle:
		for who in _party_battle.party:
			var f := _party_battle.fighter(who)
			old_max[f.id] = [f.pv_max, f.pm_max]
	_party_battle = Battle.new(CharacterDB.PROTAGONIST, "imp", _party, _companion_skills)
	# Al subir de nivel, lo que crecen PV y PM máximos se suma a los actuales.
	for who in _party_battle.party:
		var f := _party_battle.fighter(who)
		if old_max.has(f.id) and _vitals.has(f.id):
			_vitals[f.id].pv += maxi(f.pv_max - old_max[f.id][0], 0)
			_vitals[f.id].pm += maxi(f.pm_max - old_max[f.id][1], 0)
	_party_battle.set_party_vitals(_vitals, 1)
	_vitals = _party_battle.party_vitals()
	_update_cards()


func _update_cards() -> void:
	for i in _cards.size():
		if i < _party_battle.party.size():
			var f := _party_battle.fighter(_party_battle.party[i])
			_cards[i].setup(f.id, i + 1, f)
		else:
			_cards[i].setup("", i + 1)


## Pantalla de estado (la del combate) del miembro de la ficha `slot`.
func _open_status(slot: int) -> void:
	if _busy or _combat.visible or _status.visible or _party_battle == null:
		return
	if slot >= _party_battle.party.size():
		return
	_status.open(_party_battle, _party_battle.party[slot])


# --- Estado y entrada -------------------------------------------------------------------

func _on_moved() -> void:
	_target = _explorer.front()
	_hover_console = false
	var safe := _explorer.at_extraction()
	if safe and not _was_extraction:
		_log("Zona de extracción segura: desde aquí puedes salir sin perder nada.")
	_was_extraction = safe
	_banter_on_move()
	_automap.queue_redraw()
	_big_map.queue_redraw()
	queue_redraw()
	_fx.queue_redraw()


func _process(_delta: float) -> void:
	if _map == null:
		return
	# El recuadro sigue a la cámara mientras se anima (pasos, giros, puertas).
	var r := _explorer.front_rect(_target) if not _target.is_empty() else Rect2()
	var cr := _explorer.front_rect({"node": _target.console}) if _target.has("console") else Rect2()
	# La vista 3D puede ir a menos resolución (DungeonLook): a píxeles del visor.
	r = Rect2(r.position * _view.stretch_shrink, r.size * _view.stretch_shrink)
	cr = Rect2(cr.position * _view.stretch_shrink, cr.size * _view.stretch_shrink)
	if r != _target_rect or cr != _console_rect:
		_target_rect = r
		_console_rect = cr
		_fx.queue_redraw()


func _input(event: InputEvent) -> void:
	# Tab: estado del grupo (en _input, como en el combate, antes que el foco).
	if _map != null and not _busy and not _combat.visible and not _status.visible \
			and event.is_action_pressed("ui_focus_next"):
		_open_status(0)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _map == null or _busy or _combat.visible or _status.visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	var action := ""
	match key.physical_keycode:
		KEY_W, KEY_UP: action = "forward"
		KEY_S, KEY_DOWN: action = "back"
		KEY_A, KEY_LEFT: action = "left"
		KEY_D, KEY_RIGHT: action = "right"
		KEY_Q: action = "strafe_left"
		KEY_E: action = "strafe_right"
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			if not key.echo:
				_use()
		KEY_M:
			if not key.echo:
				_toggle_map()
		KEY_F:
			if not key.echo:
				_use_resonator()
		KEY_V:
			if not key.echo:
				_next_look()
		KEY_ESCAPE:
			if _big_map.visible:
				_toggle_map()
			elif _options.get_child_count() > 0:
				_clear_options()
			else:
				_on_command("exit")
		_:
			return
	if action != "":
		if _big_map.visible:
			_toggle_map()
		_clear_options()
		# Mantener pulsado: sigue andando (girar, solo una vez por pulsación).
		if not key.echo or action in ["forward", "back", "strafe_left", "strafe_right"]:
			_explorer.act(action)
	get_viewport().set_input_as_handled()


func _on_view_input(event: InputEvent) -> void:
	if _busy or _combat.visible or _status.visible:
		return
	if event is InputEventMouseMotion:
		var on_console := _console_rect.has_area() and _console_rect.grow(10).has_point(event.position)
		var inside := not on_console and _target_rect.has_area() and _target_rect.grow(12).has_point(event.position)
		if inside != _hover_target or on_console != _hover_console:
			_hover_target = inside
			_hover_console = on_console
			_fx.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if inside or on_console else Control.CURSOR_ARROW
			_fx.queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _console_rect.has_area() and _console_rect.grow(10).has_point(event.position):
			_log("Consola de acceso. Hace falta un dispositivo para hackearla.")
		elif _target_rect.has_area() and _target_rect.grow(12).has_point(event.position):
			_use()
		_fx.accept_event()


func _use() -> void:
	if _explorer.is_busy():
		return
	_clear_options()
	await _explorer.act("interact")
	_on_moved()


func _on_command(id: String) -> void:
	if _busy or _map == null:
		return
	_set_info(COMMANDS.filter(func(c: Dictionary) -> bool: return c.id == id)[0].desc)
	match id:
		"use":
			if _target.is_empty():
				_log("No hay nada delante que usar.")
			else:
				_use()
		"skills":
			_show_skills()
		"items":
			_show_items()
		"map":
			_toggle_map()
		"pulse":
			_use_resonator()
		"look":
			_next_look()
		"exit":
			_clear_options()
			if _explorer.at_extraction():
				_add_option("Salir con lo conseguido", _exit.bind(true))
				_add_option("Seguir explorando", _clear_options)
				_log("Zona de extracción segura: te llevas todo lo que has conseguido.")
			else:
				_ask_exit()


func _next_look() -> void:
	DungeonLook.next()
	DungeonLook.apply(_view, _explorer)
	_log("Estilo visual: %s" % DungeonLook.label(_view))


## Maqueta a lo ancho: la base es 1920×1080; en pantallas más alargadas el visor
## crece y la columna derecha y la cabecera se pegan al borde.
func _layout() -> void:
	_extra = maxf(size.x - 1920.0, 0.0)
	_view.size = Vector2(VIEWPORT_RECT.size.x - 4 + _extra, VIEWPORT_RECT.size.y - 4)
	_fx.size = _view.size
	_big_map.size = _view.size - Vector2(120, 80)
	_map_close.position = Vector2(_big_map.size.x - 84, 18)
	_automap.position.x = RIGHT_X + _extra
	for card in _cards:
		card.position.x = RIGHT_X + _extra
	var x0 := 74.0
	var gap := 8.0
	var w := (VIEWPORT_RECT.end.x + _extra - x0 - gap * (COMMANDS.size() - 1)) / COMMANDS.size()
	for i in _commands.size():
		_commands[i].position = Vector2(x0 + i * (w + gap), COMMAND_Y)
		_commands[i].size = Vector2(w, 72)
		_commands[i].custom_minimum_size = Vector2(w, 72)
	_info.size.x = OPTION_ROW.size.x + _extra
	_status.size = size
	if _pad:
		_pad.position = _view.position + _view.size - _pad.size - Vector2(24, 70)
	queue_redraw()
	_info.queue_redraw()


## Botón redondo con el estilo de la cruceta (✕ del mapa, flechas).
func _round_button(text: String, side: float, font: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.size = Vector2(side, side)
	b.add_theme_font_size_override("font_size", font)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UIStyle.INK, 0.55)
	sb.border_color = Color(UIStyle.WHITE, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(side * 0.15))
	var sb_on := sb.duplicate() as StyleBoxFlat
	sb_on.bg_color = Color(UIStyle.LIME, 0.85)
	for st in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("pressed", sb_on)
	b.add_theme_color_override("font_color", UIStyle.WHITE)
	b.add_theme_color_override("font_pressed_color", UIStyle.INK)
	return b


## Cruceta táctil sobre el visor (solo en pantallas táctiles): las mismas
## acciones que W/S/A/D/Q/E.
func _build_touch_pad() -> void:
	const SIDE := 118.0
	const GAP := 10.0
	_pad = Control.new()
	_pad.size = Vector2(SIDE * 3 + GAP * 2, SIDE * 2 + GAP)
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pad)
	var keys := [
		["↶", "left"], ["▲", "forward"], ["↷", "right"],
		["◀", "strafe_left"], ["▼", "back"], ["▶", "strafe_right"],
	]
	for i in keys.size():
		var b := _round_button(keys[i][0], SIDE, 52)
		b.position = Vector2((i % 3) * (SIDE + GAP), (i / 3) * (SIDE + GAP))
		b.button_down.connect(_touch_move.bind(keys[i][1]))
		_pad.add_child(b)


func _touch_move(action: String) -> void:
	if _map == null or _busy or _combat.visible or _status.visible:
		return
	if _big_map.visible:
		_toggle_map()
	_clear_options()
	_explorer.act(action)


func _toggle_map() -> void:
	_big_map.visible = not _big_map.visible
	_big_map.queue_redraw()


func _show_items() -> void:
	_clear_options()
	var any := false
	for id: String in GameState.inventory:
		var n: int = GameState.inventory[id]
		if n <= 0 or (_bare() and ItemDB.restores(id)):
			continue
		any = true
		var name_text := ItemDB.display_name(id)
		var label := ("%s  ·  %d carga%s" % [name_text, _charges, "" if _charges == 1 else "s"]) if id == ItemDB.SCANNER \
				else "%s  ×%d" % [name_text, n]
		_add_option(label, func() -> void:
			_set_info(ItemDB.description(id))
			if ItemDB.get_item(id).get("tool", false):
				_use_resonator()
			elif ItemDB.is_box(id):
				_open_box(id)
			elif ItemDB.charges(id) > 0:
				_use_battery(id)
			elif ItemDB.restores(id):
				_choose_item_target(id)
			elif ItemDB.is_attack(id):
				_log("%s: solo sirve en combate." % name_text)
			else:
				_log("%s: lo llevas encima; abrirá alguna puerta." % name_text))
	if not any:
		_log("No llevas nada.")


## Nombre de la mazmorra: la grieta o el sitio (La Torre).
func _place_name() -> String:
	return "la grieta" if _rift else LocationDB.display_name(GameState.location_id)


## Con lo puesto: en la grieta, hasta tener el escáner, no se usan objetos que curen.
func _bare() -> bool:
	return _rift and not GameState.phase_at_least("escaner")


## Combate: reglas de la grieta (CombatView.setup).
func _combat_rules() -> Dictionary:
	return {"retreat": true, "no_restore": _bare()} if _rift else {}


## Escáner: pulso que hace brillar las paredes secretas a 5 casillas o menos.
func _use_resonator() -> void:
	if GameState.item_count(ItemDB.SCANNER) <= 0:
		return
	_clear_options()
	if _explorer.is_pulsing():
		return
	if _charges <= 0:
		_log("El escáner está sin carga. Hace falta una batería (las traen las cajas).")
		if GameState.item_count("bateria") > 0:
			_add_option("Poner una batería  ×%d" % GameState.item_count("bateria"), _use_battery.bind("bateria"))
		return
	_charges -= 1
	_log("Activas el escáner. Un pulso rosado recorre los pasillos… (quedan %d carga%s)" % [_charges, "" if _charges == 1 else "s"])
	_explorer.pulse()


## Batería: gasta una y le da sus cargas al escáner (solo dura esta incursión).
func _use_battery(id: String) -> void:
	_clear_options()
	if not GameState.use_item(id):
		return
	_charges += ItemDB.charges(id)
	_log("Encajas la batería en el escáner. Cargas: %d." % _charges)


## Caja recién cogida: abrirla ya o guardarla para luego.
func _offer_box(id: String, count: int) -> void:
	_clear_options()
	var name_text := ItemDB.display_name(id)
	_log("Coges: %s%s. ¿La abres ya o la guardas?" % [name_text, " ×%d" % count if count > 1 else ""])
	_add_option("Abrir ya", _open_box.bind(id))
	_add_option("Guardar", func() -> void:
		_clear_options()
		_log("Guardas %s. Puedes abrirla cuando quieras desde Objetos o el móvil." % name_text.to_lower()))


func _open_box(id: String) -> void:
	_clear_options()
	var got := GameState.open_box(id)
	if got == "":
		return
	_log("Abres: %s. Dentro hay: %s." % [ItemDB.display_name(id), got])
	if GameState.item_count(id) > 0:
		_add_option("Abrir otra  ×%d" % GameState.item_count(id), _open_box.bind(id))
		_add_option("Guardar", _clear_options)


func _on_pulse_finished(found: int) -> void:
	_on_moved()
	var left := " Quedan %d carga%s." % [_charges, "" if _charges == 1 else "s"]
	if found == 0:
		_log("El pulso se apaga. Nada ha respondido." + left)
	elif found == 1:
		_log("Algo ha respondido al pulso: una pared brilla. Cuanto más intenso el brillo, más cerca estaba." + left)
	else:
		_log(("%d paredes han respondido al pulso. Cuanto más intenso el brillo, más cerca estaban." % found) + left)


## Objeto que cura: a quién del grupo se le da.
func _choose_item_target(item_id: String) -> void:
	_clear_options()
	var name_text := ItemDB.display_name(item_id)
	var pm_item: bool = ItemDB.get_item(item_id).get("heal", 0) <= 0
	for who in _party_battle.party:
		var f := _party_battle.fighter(who)
		_add_option(("%s  %d/%d PM" % [f.name, f.pm, f.pm_max]) if pm_item else ("%s  %d/%d PV" % [f.name, f.pv, f.pv_max]), func() -> void:
			if (f.pm >= f.pm_max) if pm_item else (f.pv >= f.pv_max):
				_log("%s ya está al máximo." % f.name)
				return
			var events := _party_battle.field_use_item(who, item_id)
			_after_field_action(events, "%s se toma: %s." % [f.name, name_text]))
	_add_option("Volver", _show_items)
	_log("¿A quién se lo das? (%s)" % name_text)


## Habilidades de cada miembro que sirven fuera del combate (Battle.is_field_skill).
func _show_skills() -> void:
	_clear_options()
	var any := false
	for who in _party_battle.party:
		var f := _party_battle.fighter(who)
		for id: String in f.skills:
			if not Battle.is_field_skill(id):
				continue
			any = true
			var skill := SkillDB.get_skill(id)
			var cost := _party_battle.skill_cost(who, id)
			_add_option("%s · %s  %d PM" % [f.name, skill.name, cost], func() -> void:
				_set_info("%s %s. Coste: %d PM." % [skill.desc, _party_battle.skill_summary(who, id), cost])
				var problem := _party_battle.skill_problem(who, id)
				if problem != "":
					_log(problem)
					return
				var events := _party_battle.field_use_skill(who, id)
				_after_field_action(events, "%s usa %s." % [f.name, skill.name]))
	if not any:
		_log("Nadie del grupo tiene habilidades que sirvan fuera del combate (curar o recuperar PM).")


## Tras usar algo explorando: guarda los PV/PM, actualiza fichas y cuenta lo que ha pasado.
func _after_field_action(events: Array, intro: String) -> void:
	if events.is_empty():
		_log("No ha servido de nada.")
		return
	var parts: Array[String] = []
	for ev: Dictionary in events:
		var who_name: String = _party_battle.fighter(ev.target).name if ev.has("target") else ""
		match ev.type:
			"heal", "restore":
				parts.append("%s +%d PV" % [who_name, ev.amount])
			"pm_restore":
				parts.append("%s +%d PM" % [who_name, ev.amount])
	_vitals = _party_battle.party_vitals()
	_update_cards()
	_clear_options()
	_log("%s %s." % [intro, ", ".join(parts)] if not parts.is_empty() else intro)


func _add_option(text: String, action: Callable) -> void:
	var b := SlantButton.new()
	b.label = text
	b.subtle = true
	b.hover_focus = false
	b.focus_mode = Control.FOCUS_NONE
	b.font_size = 24
	b.slant = 16
	# El contenedor no usa el ancho que calcula SlantButton: se le da a mano.
	b.custom_minimum_size = Vector2(b._get_minimum_size().x, 50)
	b.pressed.connect(action)
	_options.add_child(b)
	_info.queue_redraw()


func _clear_options() -> void:
	for ch in _options.get_children():
		_options.remove_child(ch)
		ch.queue_free()
	_info.queue_redraw()


# --- Combate y salida ----------------------------------------------------------------------

func _on_encounter(enemy_id: String, cell: Vector2i) -> void:
	if _busy:
		return
	_busy = true
	_clear_options()
	# En la grieta, si el grupo ya va muy tocado, ni se pelea: alguien dice de irse.
	if _rift and _party_battle.should_retreat():
		var who: String = _party.pick_random() if not _party.is_empty() else CharacterDB.PROTAGONIST
		var line := DungeonBanter.line(who, "retreat")
		_companion = who
		if line != "":
			_say(line)
		else:
			_log("No estáis para pelear. Os retiráis.")
		await get_tree().create_timer(2.4).timeout
		_busy = false
		_exit(true)
		return
	var ally_skills := _companion_skills
	if CharacterDB.is_enemy(enemy_id) and not GameState.first_creature_fight_done:
		GameState.first_creature_fight_done = true
	await SceneRouter.fade_out(0.25)
	# Un encuentro puede ser un grupo (`group`: los que acompañan al líder) y el jefe (`boss`).
	var th := _map.thing(cell)
	var ids: Array = [enemy_id] + th.get("group", [])
	_combat.setup(ids, _party, ally_skills, _vitals, _map.creature_level(), th.get("boss", false), _combat_rules())
	await SceneRouter.fade_in(0.25)
	_combat.begin()
	var won: bool = await _combat.finished
	var retreated := _combat.retreated()
	var wiped := not won and not retreated and _combat.party_down()
	# Los PV y PM siguen así en la incursión (quien cayó, con 1 PV).
	_vitals = _combat.party_vitals()
	_refresh_party()
	GameState.record("combat", CharacterDB.PROTAGONIST, enemy_id, {"won": won, "ally": ",".join(_party), "dungeon": _map_id},
			_party.duplicate())
	if retreated:   # retirada: fuera, sin perder lo ganado
		_combat.visible = false
		_busy = false
		_exit(true)
		return
	if wiped:
		await _restart_at_entry()
		return
	await SceneRouter.fade_out(0.25)
	_combat.visible = false
	await SceneRouter.fade_in(0.25)
	if won:
		_explorer.defeat(cell)
		var drop := _explorer.drop_at(cell)
		if drop != "":
			GameState.add_item(drop)
			_log("¡%s derrotado%s! Al caer suelta algo: %s. Lo guardas." % [_group_name(ids), "s" if ids.size() > 1 else "", ItemDB.display_name(drop)])
		else:
			_log("¡%s derrotado%s!" % [_group_name(ids), "s" if ids.size() > 1 else ""])
	else:
		_log("Retrocedes. %s sigue%s ahí." % [_group_name(ids), "n" if ids.size() > 1 else ""])
		await _explorer.act("back")
	queue_redraw()
	_busy = false
	_on_moved()
	if not (won and _explorer.drop_at(cell) != ""):   # que se lea lo que ha soltado
		_comment("victory" if won else "defeat", 1.4, true)


## «Imp», «Imp y Engendro», «Imp, Imp y Engendro».
static func _group_name(ids: Array) -> String:
	var names: Array = ids.map(func(id: String) -> String: return CharacterDB.display_name(id))
	if names.size() == 1:
		return names[0]
	return ", ".join(names.slice(0, -1)) + " y " + names.back()


## EXP por explorar para el grupo (y la parte del resto de compañeros).
func _explore_xp(amount: int, what: String) -> void:
	var results := GameState.grant_xp([CharacterDB.PROTAGONIST] + _party, amount)
	var ups := GameState.level_up_text(results)
	_refresh_party()
	await get_tree().create_timer(2.6).timeout
	if not is_inside_tree():
		return
	_log("%s: + %d EXP.%s" % [what, amount, ("  " + ups) if ups != "" else ""])


## Primera vez en una planta (en esta partida): EXP por explorar.
func _first_visit_xp() -> void:
	var seen: Dictionary = _explorer.state.get_or_add("xp_floors", {})
	var k := str(_map.level)
	if seen.has(k) or _map.level == _map.start_level:
		return
	seen[k] = true
	_explore_xp(ProgressionDB.new_floor_xp(_map.creature_level()), "Planta nueva")


## Fuera de una zona de extracción: aviso antes de salir.
func _ask_exit() -> void:
	_busy = true
	var ok := await ConfirmPopup.ask(self, "¿Salir de %s?" % _place_name(),
			EXIT_WARNING, "Salir", "Continuar explorando")
	_busy = false
	if ok:
		_exit(false)
	else:
		_log("Sigues explorando. Busca una zona de extracción (círculo cian) o vuelve a la entrada.")


## Vuelta a la calle: salir de la mazmorra cuenta como una actividad (pasa la franja).
## Sin `extracted`, se pierde lo conseguido en la incursión.
func _exit(extracted: bool) -> void:
	if _busy:
		return
	_busy = true
	_clear_options()
	if not extracted:
		_lose_run()
	if _rift:
		# Primera exploración hecha; con el escáner fuera, la fase siguiente (se abre el Pidl).
		if GameState.item_count(ItemDB.SCANNER) > 0 and not GameState.phase_at_least("escaner"):
			GameState.set_phase("escaner")
		elif not GameState.phase_at_least("exploracion_1"):
			GameState.set_phase("exploracion_1")
		GameState.expedition = []
	if GameState.slot_id() != "noche":
		GameState.advance_slot()
	GameState.save_game()
	SceneRouter.go_to(WORLD_SCREEN)


## Lo conseguido hasta ahora queda a salvo: al entrar y en cada punto de guardado.
func _mark_run_start() -> void:
	_run_start = {"inventory": GameState.inventory.duplicate(), "money": GameState.money,
		"taken": _explorer.state.taken.duplicate(), "defeated": _explorer.state.defeated.duplicate()}


## Punto de guardado: asegura lo conseguido (ya no se pierde al salir sin
## extraer) y guarda la partida.
func _use_save_point() -> void:
	if _busy:
		return
	_mark_run_start()
	GameState.save_game()
	_log("Conectas el móvil a la terminal. Partida guardada: lo que llevas ya está a salvo.")


## Deshace lo ganado desde que se entró (o desde el último punto de guardado): lo
## que haya de más en el inventario y el dinero vuelve a lo que había (lo gastado
## no se recupera) y los objetos cogidos vuelven a la mazmorra. Puertas, palancas,
## criaturas vencidas y mapa siguen igual, salvo las criaturas que soltaron algo:
## vuelven, para poder ganarlo otra vez.
func _lose_run() -> void:
	var before: Dictionary = _run_start.inventory
	for id: String in GameState.inventory.keys():
		GameState.inventory[id] = mini(GameState.inventory[id], before.get(id, 0))
	GameState.money = mini(GameState.money, _run_start.money)
	_explorer.restore_items(_run_start.taken)
	_explorer.restore_drops(_run_start.defeated)


## El grupo ha caído: de vuelta a la entrada como al entrar (se pierde todo lo
## de esta incursión, también lo asegurado en puntos de guardado) y con la vida llena.
func _restart_at_entry() -> void:
	await SceneRouter.fade_out(0.25)
	_run_start = _entry.duplicate(true)
	_lose_run()
	_vitals = {}
	_explorer.setup(_map, GameState.dungeon_state(_map_id))
	DungeonLook.apply(_view, _explorer)
	_charges = ItemDB.charges(ItemDB.SCANNER) if GameState.item_count(ItemDB.SCANNER) > 0 else 0
	_refresh_party()
	_combat.visible = false
	await SceneRouter.fade_in(0.25)
	queue_redraw()
	_busy = false
	_log("Os despertáis en la entrada. Todo lo de esta incursión se ha perdido.")
	_on_moved()


# --- Registro -------------------------------------------------------------------------------

func _log(text: String) -> void:
	_log_text = text
	_log_who = ""
	_fx.queue_redraw()


## El compañero dice `text` (sale en el registro con su nombre).
func _say(text: String) -> void:
	_log_text = text
	_log_who = _companion
	_fx.queue_redraw()


## Comentario del compañero para el momento `event` (DungeonBanter), al cabo de
## `delay` s para que antes se lea lo que ha pasado. Sin `force`, no comenta si
## lo ha hecho hace menos de COMMENT_GAP pasos.
func _comment(event: String, delay: float, force := false) -> void:
	if _party.is_empty() or (not force and _steps - _last_comment < COMMENT_GAP):
		return
	_companion = _party.pick_random()
	var text := DungeonBanter.line(_companion, event)
	if text == "":
		return
	_last_comment = _steps
	_comment_gen += 1
	var gen := _comment_gen
	await get_tree().create_timer(delay).timeout
	if gen != _comment_gen or _busy or _combat.visible:
		return
	_say(text)


## Al moverse o girar: pared falsa cerca, criatura delante, escaleras o, de vez
## en cuando, un comentario suelto.
func _banter_on_move() -> void:
	if _explorer == null or _explorer.map == null:
		return
	var pos := Vector3i(_explorer.cell.x, _explorer.cell.y, _explorer.map.level)
	var stepped := pos != _last_pos
	var prev_level := _last_pos.z
	if stepped:
		_steps += 1
	_last_pos = pos
	if prev_level != -999 and pos.z != prev_level:
		_comment("level_up" if pos.z > prev_level else "level_down", 1.8, true)
		return
	for k in _explorer.secrets_near():
		var rk := "%d|%s" % [pos.z, k]
		if not _remarked.has(rk):
			_remarked[rk] = true
			_comment("secret_hint", 0.7, true)
			return
	if _target.get("kind", "") == "enemy":
		var ek := "%d|%s" % [pos.z, _target.cell]
		if not _remarked.has(ek):
			_remarked[ek] = true
			_comment("enemy", 0.5)
			return
	if stepped and _steps >= _next_idle:
		_next_idle = _steps + randi_range(IDLE_STEPS.x, IDLE_STEPS.y)
		_comment("idle", 0.8)


func _set_info(text: String) -> void:
	_info_text = text
	_info.queue_redraw()


# --- Dibujo ----------------------------------------------------------------------------------

func _draw() -> void:
	var w := size.x
	draw_rect(Rect2(Vector2.ZERO, size), UIStyle.INK)

	draw_rect(Rect2(28, 16, 12, 50), ACCENT)
	var title := "Mazmorra - %s" % ("La grieta" if _rift else _place_name())
	draw_string(UIStyle.FONT_MEDIUM, Vector2(70, 46), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, UIStyle.WHITE)
	var lvl := _map.level_name() if _map else ""
	var sub := "%s / Zona: %s / %s" % [GameState.region_name, LocationDB.display_name(GameState.location_id), lvl]
	UIStyle.draw_spaced(self, UIStyle.FONT_REGULAR, Vector2(72, 74), sub, 18, 1.5, Color(UIStyle.WHITE, 0.9))

	var e := _extra
	draw_polyline(PackedVector2Array([
		Vector2(0, 112), Vector2(24, 88), Vector2(500, 88), Vector2(522, 70),
		Vector2(1400 + e, 70), Vector2(1430 + e, 40), Vector2(1440 + e, 40),
	]), UIStyle.LINE, 1.5, true)

	var hdr := PackedVector2Array([Vector2(1440 + e, 40), Vector2(1470 + e, 6), Vector2(1790 + e, 6), Vector2(1760 + e, 40)])
	draw_colored_polygon(hdr, Color(UIStyle.INK, 1.0))
	UIIcons.calendar(self, Vector2(1490 + e, 26), 26, UIStyle.WHITE)
	draw_string(UIStyle.FONT_MEDIUM, Vector2(1516 + e, 36), GameState.weekday_short().capitalize(), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UIStyle.WHITE)
	draw_line(Vector2(1592 + e, 14), Vector2(1592 + e, 40), UIStyle.WHITE, 1.5)
	draw_string(UIStyle.FONT_MEDIUM, Vector2(1608 + e, 36), "¥ %s" % UIStyle.format_money(GameState.money), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UIStyle.WHITE)
	for i in 7:
		var sx := w - 120 + i * 14
		draw_line(Vector2(sx, 40), Vector2(sx + 16, 6), UIStyle.WHITE, 2.5, true)

	var vp := UIStyle.chamfer_rect(Rect2(VIEWPORT_RECT.position, VIEWPORT_RECT.size + Vector2(e, 0)), [0.0, 0.0, 22.0, 0.0])
	UIStyle.draw_outline(self, vp, UIStyle.LINE, 1.5)
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
	if _options.get_child_count() == 0 and not App.is_touch():
		_info.draw_string(UIStyle.FONT_REGULAR, Vector2(30, 44), "[WASD] Moverte  [Q E] De lado  [Espacio] Usar  [F] Escáner  [M] Mapa  [Tab] Equipo  [V] Vista",
				HORIZONTAL_ALIGNMENT_LEFT, div_x - 50, 19, Color(UIStyle.WHITE, 0.6))
	_info.draw_colored_polygon(UIStyle.slanted_rect(Rect2(div_x + 34, 22, 9, 28), 7), UIStyle.LIME)
	_info.draw_string(UIStyle.FONT_REGULAR, Vector2(div_x + 60, 44), _info_text, HORIZONTAL_ALIGNMENT_LEFT,
			r.size.x - div_x - 80, 21, UIStyle.WHITE)


## Esquinas lima alrededor de `rect` y la etiqueta de lo que se puede hacer.
func _draw_target(rect: Rect2, label: String, hover: bool, accent: Color) -> void:
	var vs := _fx.size
	var r := rect.grow(14).intersection(Rect2(Vector2(8, 8), vs - Vector2(16, 70)))
	var col := Color(UIStyle.LIME, 1.0 if hover else 0.75)
	var k := minf(36.0, minf(r.size.x, r.size.y) * 0.3)
	var lw := 4.0 if hover else 3.0
	for corner in [[r.position, Vector2(1, 0), Vector2(0, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 0), Vector2(0, 1)],
			[r.end, Vector2(-1, 0), Vector2(0, -1)], [Vector2(r.position.x, r.end.y), Vector2(1, 0), Vector2(0, -1)]]:
		_fx.draw_line(corner[0], corner[0] + corner[1] * k, col, lw)
		_fx.draw_line(corner[0], corner[0] + corner[2] * k, col, lw)
	var font := UIStyle.FONT_BOLD_ITALIC
	var fs := 26
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tag_pos := Vector2(clampf(r.get_center().x - tw * 0.5 - 24, 10, vs.x - tw - 60), maxf(r.position.y - 54, 12))
	var tag := UIStyle.slanted_rect(Rect2(tag_pos, Vector2(tw + 48, 44)), 12)
	_fx.draw_colored_polygon(tag, Color(UIStyle.INK, 0.85))
	UIStyle.draw_outline(_fx, tag, col, 1.5)
	_fx.draw_colored_polygon(UIStyle.slanted_rect(Rect2(tag_pos + Vector2(14, 10), Vector2(7, 24)), 5), accent)
	_fx.draw_string(font, tag_pos + Vector2(30, 32), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIStyle.WHITE)


func _draw_fx() -> void:
	var vs := _fx.size
	# Lo de delante: esquinas lima alrededor y una etiqueta con lo que se puede hacer.
	# Junto a una puerta, la consola se marca en su lugar cuando el cursor está encima.
	if _hover_console and _console_rect.has_area():
		_draw_target(_console_rect, "Examinar  ·  Consola de acceso", true, UIStyle.LIME)
	elif not _target.is_empty() and _target_rect.has_area():
		var accent := UIStyle.RED if _target.kind == "enemy" else (DungeonScreen.PULSE_PINK if _target.kind == "secret" else UIStyle.LIME)
		_draw_target(_target_rect, "%s  ·  %s" % [_target.verb, _target.name], _hover_target, accent)

	# Brújula (arriba a la derecha del visor).
	if _map:
		var names := ["N", "E", "S", "O"]
		var cpos := Vector2(vs.x - 60, 52)
		_fx.draw_circle(cpos, 30, Color(UIStyle.INK, 0.75))
		_fx.draw_arc(cpos, 30, 0, TAU, 32, UIStyle.LINE, 1.5)
		_fx.draw_string(UIStyle.FONT_BOLD_ITALIC, cpos + Vector2(-14, 10), names[_explorer.dir], HORIZONTAL_ALIGNMENT_CENTER, 28, 26, UIStyle.LIME)

	# Registro: última acción, abajo del visor (como en el combate).
	var ty := vs.y - 50
	var lshape := PackedVector2Array([Vector2(0, ty), Vector2(vs.x - 40, ty), Vector2(vs.x, vs.y), Vector2(0, vs.y)])
	_fx.draw_colored_polygon(lshape, Color(UIStyle.INK, 0.85))
	UIStyle.draw_outline(_fx, lshape, UIStyle.LINE, 1.5)
	_fx.draw_colored_polygon(UIStyle.slanted_rect(Rect2(26, ty + 14, 8, 24), 6), ACCENT)
	var lx := 48.0
	if _log_who != "":
		var who := CharacterDB.display_name(_log_who) + ":  "
		_fx.draw_string(UIStyle.FONT_BOLD_ITALIC, Vector2(lx, ty + 34), who, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, CharacterDB.color(_log_who))
		lx += UIStyle.FONT_BOLD_ITALIC.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
	var line := "«%s»" % _log_text if _log_who != "" else _log_text
	_fx.draw_string(UIStyle.FONT_REGULAR_ITALIC, Vector2(lx, ty + 34), line, HORIZONTAL_ALIGNMENT_LEFT, vs.x - lx - 70, 21, UIStyle.WHITE)
