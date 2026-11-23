class_name DungeonScreen
extends Control
## Modo mazmorra: exploración en primera persona con la interfaz del combate.
##
## Composición (base 1920×1080, la misma que CombatView):
##  - Cabecera magenta «Mazmorra - <lugar>», planta; fecha y dinero arriba a la derecha.
##  - Visor grande: la vista 3D (DungeonExplorer). Lo que hay justo delante y se
##    puede usar (puerta, palanca, objeto, criatura) se recuadra; clic encima o
##    Espacio para usarlo.
##  - Columna derecha: automapa (en el hueco del minimapa) y fichas del grupo.
##  - Fila de comandos: Usar, Objetos, Mapa, Salir.
##  - Fila de opciones + descripción / registro.
##
## El mapa es `dungeon_map` de la ubicación actual (LocationDB). El progreso
## (puertas, enemigos vencidos, objetos cogidos, automapa) se guarda en
## GameState.dungeons; al volver se empieza otra vez en la entrada.

const WORLD_SCREEN := "res://src/screens/world/world_screen.tscn"
const VIEWPORT_RECT := Rect2(10, 96, 1418, 782)
const COMMAND_Y := 898.0
const OPTION_ROW := Rect2(30, 990, 1864, 70)
const RIGHT_X := 1440.0
const ACCENT := UIStyle.MAGENTA

const COMMANDS := [
	{"id": "use", "label": "Usar", "icon": "sparkle", "desc": "Usar lo que hay justo delante: abrir, coger, accionar o luchar."},
	{"id": "items", "label": "Objetos", "icon": "flask", "desc": "Lo que llevas encima."},
	{"id": "map", "label": "Mapa", "icon": "antenna", "desc": "Automapa de la planta: lo que ya has recorrido.  [M]"},
	{"id": "exit", "label": "Salir", "icon": "run", "desc": "Volver a la calle. Lo que hayas abierto o vencido seguirá así."},
]

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
var _busy := false          ## combate o salida en curso


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_map_id = LocationDB.get_location(GameState.location_id).get("dungeon_map", "torre")
	_map = DungeonMap.load_map(_map_id)
	_build()
	if _map == null:
		_log("No se encuentra el mapa «%s» (src/data/mazmorras/)." % _map_id)
		return
	_explorer.setup(_map, GameState.dungeon_state(_map_id))
	_refresh_party()
	_set_info(COMMANDS[0].desc)
	_log("Entras en %s." % LocationDB.display_name(GameState.location_id))


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
	vp.msaa_3d = Viewport.MSAA_4X
	_view.add_child(vp)
	_explorer = DungeonExplorer.new()
	vp.add_child(_explorer)
	_explorer.moved.connect(func(_c: Vector2i, _d: int) -> void: _on_moved())
	_explorer.level_changed.connect(func(_l: int) -> void:
		queue_redraw()
		_on_moved())
	_explorer.message.connect(_log)
	_explorer.encounter.connect(_on_encounter)

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
		b.hover_focus = false
		b.focus_mode = Control.FOCUS_NONE   # las flechas son para andar
		b.font_size = 30
		b.slant = 26
		b.position = Vector2(x + i * (w + 8), COMMAND_Y)
		b.size = Vector2(w, 72)
		b.custom_minimum_size = Vector2(w, 72)
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
	_options.add_theme_constant_override("separation", 18)
	add_child(_options)

	# Combate, por encima de todo.
	_combat = CombatView.new()
	_combat.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg: String = LocationDB.get_location(GameState.location_id).get("battle_background", "")
	if bg != "" and ResourceLoader.exists(bg):
		_combat.backdrop_override = load(bg)
	add_child(_combat)


## Ficha de Ren con sus datos de combate (los PV se recuperan al salir de cada combate).
func _refresh_party() -> void:
	var id := CharacterDB.PROTAGONIST
	var c: Dictionary = CharacterDB.get_character(id).get("combat", {})
	_cards[0].setup(id, 1, {"level": c.get("level", 1), "pv": c.get("pv", 100), "pv_max": c.get("pv", 100),
			"pm": c.get("pm_now", c.get("pm", 0)), "pm_max": c.get("pm", 0)})
	for i in range(1, _cards.size()):
		_cards[i].setup("", i + 1)


# --- Estado y entrada -------------------------------------------------------------------

func _on_moved() -> void:
	_target = _explorer.front()
	_automap.queue_redraw()
	_big_map.queue_redraw()
	queue_redraw()
	_fx.queue_redraw()


func _process(_delta: float) -> void:
	if _map == null:
		return
	# El recuadro sigue a la cámara mientras se anima (pasos, giros, puertas).
	var r := _explorer.front_rect(_target) if not _target.is_empty() else Rect2()
	if r != _target_rect:
		_target_rect = r
		_fx.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _map == null or _busy or _combat.visible:
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
	if _busy or _combat.visible:
		return
	if event is InputEventMouseMotion:
		var inside := _target_rect.has_area() and _target_rect.grow(12).has_point(event.position)
		if inside != _hover_target:
			_hover_target = inside
			_fx.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if inside else Control.CURSOR_ARROW
			_fx.queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _target_rect.has_area() and _target_rect.grow(12).has_point(event.position):
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
		"items":
			_show_items()
		"map":
			_toggle_map()
		"exit":
			_clear_options()
			_add_option("Salir de %s" % LocationDB.display_name(GameState.location_id), _exit)
			_add_option("Seguir explorando", _clear_options)
			_log("¿Salir? Lo que hayas abierto o vencido seguirá así.")


func _toggle_map() -> void:
	_big_map.visible = not _big_map.visible
	_big_map.queue_redraw()


func _show_items() -> void:
	_clear_options()
	var any := false
	for id: String in GameState.inventory:
		var n: int = GameState.inventory[id]
		if n <= 0:
			continue
		any = true
		var name_text: String = ItemDB.get_item(id).get("name", id)
		_add_option("%s  ×%d" % [name_text, n], func() -> void:
			_set_info(ItemDB.description(id))
			_log("%s: mejor guardarlo para un combate." % name_text))
	if not any:
		_log("No llevas nada.")


func _add_option(text: String, action: Callable) -> void:
	var b := SlantButton.new()
	b.label = text
	b.subtle = true
	b.hover_focus = false
	b.focus_mode = Control.FOCUS_NONE
	b.font_size = 24
	b.slant = 16
	b.custom_minimum_size = Vector2(0, 50)
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
	var ally := ""
	var ally_skills: Array = []
	if CharacterDB.is_enemy(enemy_id) and not GameState.first_creature_fight_done:
		GameState.first_creature_fight_done = true
		ally = CharacterDB.COMPANIONS.pick_random()
		ally_skills = SkillDB.random_skills(2)
	await SceneRouter.fade_out(0.25)
	_combat.setup(enemy_id, ally, ally_skills)
	await SceneRouter.fade_in(0.25)
	_combat.begin()
	var won: bool = await _combat.finished
	GameState.record("combat", CharacterDB.PROTAGONIST, enemy_id, {"won": won, "ally": ally, "dungeon": _map_id},
			[ally] if ally != "" else [])
	await SceneRouter.fade_out(0.25)
	_combat.visible = false
	await SceneRouter.fade_in(0.25)
	if won:
		_explorer.defeat(cell)
		_log("¡%s derrotado!" % CharacterDB.display_name(enemy_id))
		GameState.save_game()
	else:
		_log("Retrocedes. %s sigue ahí." % CharacterDB.display_name(enemy_id))
		await _explorer.act("back")
	queue_redraw()
	_busy = false
	_on_moved()


## Vuelta a la calle: salir de la mazmorra cuenta como una actividad (pasa la franja).
func _exit() -> void:
	if _busy:
		return
	_busy = true
	_clear_options()
	if GameState.slot_id() != "noche":
		GameState.advance_slot()
	GameState.save_game()
	SceneRouter.go_to(WORLD_SCREEN)


# --- Registro -------------------------------------------------------------------------------

func _log(text: String) -> void:
	_log_text = text
	_fx.queue_redraw()


func _set_info(text: String) -> void:
	_info_text = text
	_info.queue_redraw()


# --- Dibujo ----------------------------------------------------------------------------------

func _draw() -> void:
	var w := size.x
	draw_rect(Rect2(Vector2.ZERO, size), UIStyle.INK)

	draw_rect(Rect2(28, 16, 12, 50), ACCENT)
	var title := "Mazmorra - %s" % LocationDB.display_name(GameState.location_id)
	draw_string(UIStyle.FONT_MEDIUM, Vector2(70, 46), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, UIStyle.WHITE)
	var lvl := _map.level_name() if _map else ""
	var sub := "%s / Zona: %s / %s" % [GameState.region_name, LocationDB.display_name(GameState.location_id), lvl]
	UIStyle.draw_spaced(self, UIStyle.FONT_REGULAR, Vector2(72, 74), sub, 18, 1.5, Color(UIStyle.WHITE, 0.9))

	draw_polyline(PackedVector2Array([
		Vector2(0, 112), Vector2(24, 88), Vector2(500, 88), Vector2(522, 70),
		Vector2(1400, 70), Vector2(1430, 40), Vector2(1440, 40),
	]), UIStyle.LINE, 1.5, true)

	var hdr := PackedVector2Array([Vector2(1440, 40), Vector2(1470, 6), Vector2(1790, 6), Vector2(1760, 40)])
	draw_colored_polygon(hdr, Color(UIStyle.INK, 1.0))
	UIIcons.calendar(self, Vector2(1490, 26), 26, UIStyle.WHITE)
	draw_string(UIStyle.FONT_MEDIUM, Vector2(1516, 36), GameState.weekday_short().capitalize(), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UIStyle.WHITE)
	draw_line(Vector2(1592, 14), Vector2(1592, 40), UIStyle.WHITE, 1.5)
	draw_string(UIStyle.FONT_MEDIUM, Vector2(1608, 36), "¥ %s" % UIStyle.format_money(GameState.money), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UIStyle.WHITE)
	for i in 7:
		var sx := w - 120 + i * 14
		draw_line(Vector2(sx, 40), Vector2(sx + 16, 6), UIStyle.WHITE, 2.5, true)

	var vp := UIStyle.chamfer_rect(VIEWPORT_RECT, [0.0, 0.0, 22.0, 0.0])
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
	if _options.get_child_count() == 0:
		_info.draw_string(UIStyle.FONT_REGULAR, Vector2(30, 44), "[W A S D] Moverte   [Q E] De lado   [Espacio / clic] Usar   [M] Mapa",
				HORIZONTAL_ALIGNMENT_LEFT, div_x - 50, 21, Color(UIStyle.WHITE, 0.6))
	_info.draw_colored_polygon(UIStyle.slanted_rect(Rect2(div_x + 34, 22, 9, 28), 7), UIStyle.LIME)
	_info.draw_string(UIStyle.FONT_REGULAR, Vector2(div_x + 60, 44), _info_text, HORIZONTAL_ALIGNMENT_LEFT,
			r.size.x - div_x - 80, 21, UIStyle.WHITE)


func _draw_fx() -> void:
	var vs := _fx.size
	# Lo de delante: esquinas lima alrededor y una etiqueta con lo que se puede hacer.
	if not _target.is_empty() and _target_rect.has_area():
		var r := _target_rect.grow(14).intersection(Rect2(Vector2(8, 8), vs - Vector2(16, 70)))
		var col := Color(UIStyle.LIME, 1.0 if _hover_target else 0.75)
		var k := minf(36.0, minf(r.size.x, r.size.y) * 0.3)
		var lw := 4.0 if _hover_target else 3.0
		for corner in [[r.position, Vector2(1, 0), Vector2(0, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 0), Vector2(0, 1)],
				[r.end, Vector2(-1, 0), Vector2(0, -1)], [Vector2(r.position.x, r.end.y), Vector2(1, 0), Vector2(0, -1)]]:
			_fx.draw_line(corner[0], corner[0] + corner[1] * k, col, lw)
			_fx.draw_line(corner[0], corner[0] + corner[2] * k, col, lw)
		var label := "%s  ·  %s" % [_target.verb, _target.name]
		var font := UIStyle.FONT_BOLD_ITALIC
		var fs := 26
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tag_pos := Vector2(clampf(r.get_center().x - tw * 0.5 - 24, 10, vs.x - tw - 60), maxf(r.position.y - 54, 12))
		var tag := UIStyle.slanted_rect(Rect2(tag_pos, Vector2(tw + 48, 44)), 12)
		_fx.draw_colored_polygon(tag, Color(UIStyle.INK, 0.85))
		UIStyle.draw_outline(_fx, tag, col, 1.5)
		var accent := UIStyle.RED if _target.kind == "enemy" else UIStyle.LIME
		_fx.draw_colored_polygon(UIStyle.slanted_rect(Rect2(tag_pos + Vector2(14, 10), Vector2(7, 24)), 5), accent)
		_fx.draw_string(font, tag_pos + Vector2(30, 32), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIStyle.WHITE)

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
	_fx.draw_string(UIStyle.FONT_REGULAR_ITALIC, Vector2(48, ty + 34), _log_text, HORIZONTAL_ALIGNMENT_LEFT, vs.x - 120, 21, UIStyle.WHITE)
