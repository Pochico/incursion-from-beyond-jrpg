extends Control
## Pantalla de juego principal.
##
## Reúne en una sola escena:
##  - El fondo de la ubicación actual (compartido por escenario y conversación).
##  - La interfaz de escenario: personajes interactuables con silueta de color.
##  - La interfaz de conversación (ConversationView).
##  - El mapa superpuesto (tecla M) y el menú de interacción.
##  - El móvil («Terminal», tecla T). Solo fuera de combate.
##
## Flujo: introducción en negro → libre (casa) → mapa → ubicación → personajes.
##
## Capas del escenario: `Backdrop` (la ubicación) contiene `Props` (objetos
## examinables, parte de la habitación) y `Scenario` (personajes). Así, al
## fundir a negro la ubicación desaparece todo junto, y al conversar solo se
## ocultan los personajes (salen en grande en la conversación): los objetos
## nunca quedan sobre negro ni la habitación se queda sin ellos. Los fundidos
## pasan siempre por `_fade_room` y `_fade_cast`, que cancelan el anterior.
## Mientras hay un paso de guion activo (capítulo 1, ver ChapterDB) se avisa del
## objetivo, solo se puede ir a su destino y al llegar se reproducen sus escenas.

enum Mode { INTRO, EXPLORE, MAP, MENU, TALK, TRAVEL, COMBAT, PHONE }

const TITLE_SCREEN := "res://src/screens/title/title_screen.tscn"
const DUNGEON_SCREEN := "res://src/screens/dungeon/dungeon_screen.tscn"
## Color del contorno de los objetos examinables.
const PROP_COLOR := UIStyle.LIME
## Intensidad del contorno de los objetos en reposo (en exploración).
const PROP_GLOW := 0.45
## Líneas de la conversación que se llegan a ver antes de que la incursión la corte.
const INCURSION_CUT_AFTER := 2
## Opciones extra de la cama (además de Examinar).
const BED_ACTIONS := [
	{"id": "nap", "label": "Siesta", "icon": "clock", "desc": "Descansar un rato: pasa a la siguiente franja del día."},
	{"id": "sleep", "label": "Dormir", "icon": "moon", "desc": "Dormir hasta mañana por la mañana."},
]

@onready var _backdrop: LocationBackdrop = %Backdrop
@onready var _props_layer: Control = %Props
@onready var _scenario: Control = %Scenario
@onready var _hud: Control = %Hud
@onready var _region_header: RegionHeader = %RegionHeader
@onready var _date_header: DateHeader = %DateHeader
@onready var _hint_bar: HintBar = %HintBar
@onready var _banner: LocationBanner = %Banner
@onready var _conversation: ConversationView = %Conversation
@onready var _interaction: InteractionMenu = %Interaction
@onready var _map: MapOverlay = %MapOverlay
@onready var _combat: CombatView = %Combat
@onready var _empty_hint: Label = %EmptyHint

var mode := Mode.INTRO
var _sprites: Dictionary = {}     # id -> CharacterSprite
var _tags: Dictionary = {}        # id -> NameTag
var _bubbles: Dictionary = {}     # id -> TalkIndicator (solo personajes)
var _props: Dictionary = {}       # id -> datos del objeto examinable (LocationDB.props)
var _poses: Dictionary = {}       # id -> rect (px del fondo) de los personajes con pose (LocationDB.pose)
var _last_character := ""
var _hint_toast: Toast
var _phone: PhoneOverlay
var _room_tween: Tween
var _cast_tween: Tween


func _ready() -> void:
	Story.stage = self
	tree_exiting.connect(func() -> void:
		if Story.stage == self:
			Story.stage = null)
	_conversation.closed.connect(func() -> void:
		# Un `Story.fondo(...)` de la escena dura lo que la conversación.
		if _backdrop.location_id != GameState.location_id:
			_backdrop.set_location(GameState.location_id))
	_refresh_hints()
	_phone = PhoneOverlay.new()
	add_child(_phone)
	_phone.closed.connect(func() -> void:
		if mode == Mode.PHONE:
			mode = Mode.EXPLORE
			_set_cast_interactive(true)
			_update_empty_hint())
	_phone.app_unavailable.connect(func(_id: String) -> void:
		Toast.show_in(self, "Todavía no disponible", UIStyle.LIME, 1.6))
	_phone.notice.connect(func(text: String) -> void:
		Toast.show_in(self, text, UIStyle.LIME, 2.6))
	_hint_bar.item_pressed.connect(_on_hint_pressed)
	_interaction.action_chosen.connect(_on_action_chosen)
	_interaction.closed.connect(_on_interaction_closed)
	_map.travel_requested.connect(_travel)
	_map.closed.connect(func() -> void:
		_update_empty_hint()
		if mode == Mode.MAP:
			mode = Mode.EXPLORE
			_set_cast_interactive(true))
	_scenario.resized.connect(_layout_cast)
	_backdrop.resized.connect(_layout_cast)

	_backdrop.set_location(GameState.location_id)
	_region_header.variant = RegionHeader.Variant.SCENARIO
	_region_header.show_location = true
	_date_header.variant = DateHeader.Variant.SCENARIO
	_hud.modulate.a = 0.0
	_empty_hint.visible = false
	_empty_hint.label_settings.font = UIStyle.FONT_LIGHT_ITALIC
	# La introducción es en negro: la habitación aparece al terminar.
	_fade_room(false)
	_spawn_cast()
	if GameState.intro_done:
		# Partida cargada: directamente a la ubicación guardada.
		_enter_explore()
		_banner.play(LocationDB.display_name(GameState.location_id), "Región · %s" % GameState.region_name)
		_show_objective(false)
		_announce_plans()
	else:
		_play_intro()


func _play_intro() -> void:
	mode = Mode.INTRO
	await get_tree().create_timer(0.8).timeout
	# El primer día empieza con su propia escena; los demás, con la de rutina.
	var cue := ChapterDB.START_CUE if GameState.story_step != "" else "intro"
	await _conversation.play(Story.cue(cue), "", false)
	GameState.intro_done = true
	GameState.save_game()
	_enter_explore()
	_show_objective(true)


## Avisa del objetivo del paso de guion en curso (y, si se pide, de la tecla del mapa).
func _show_objective(with_map_hint: bool) -> void:
	var step := ChapterDB.step(GameState.story_step)
	var y := 170.0
	if not step.is_empty():
		Toast.show_in(self, "Objetivo: %s" % step.objective, UIStyle.LIME, 5.0, y)
		y += 70.0
	if with_map_hint:
		_hint_toast = Toast.show_in(self, "Pulsa  [M]  para abrir el mapa", UIStyle.LIME, 5.0, y)


## Personajes de una ubicación. Durante el guion no hay nadie suelto por el mapa:
## los compañeros aparecen en las escenas.
func _cast(location_id: String) -> Array:
	return [] if GameState.story_step != "" else LocationDB.cast(location_id)


func _enter_explore() -> void:
	mode = Mode.EXPLORE
	_fade_room(true, 0.8)
	_fade_cast(true)
	_show_hud(true)
	_update_empty_hint()


# --- HUD ---------------------------------------------------------------------------

## `full` = interfaz de escenario completa; si no, la de conversación
## (solo la región, en versión compacta).
func _show_hud(full: bool) -> void:
	_region_header.variant = RegionHeader.Variant.SCENARIO if full else RegionHeader.Variant.COMPACT
	var t := create_tween().set_parallel(true)
	t.tween_property(_hud, "modulate:a", 1.0, 0.3)
	t.tween_property(_date_header, "modulate:a", 1.0 if full else 0.0, 0.3)
	t.tween_property(_hint_bar, "modulate:a", 1.0 if full else 0.0, 0.3)


## En una mazmorra se añade «Entrar» (tecla E).
func _refresh_hints() -> void:
	var items := [
		{"id": "menu", "key": "Esc", "label": "Título"},
		{"id": "phone", "key": "T", "label": "Terminal"},
		{"id": "map", "key": "M", "label": "Mapa"},
	]
	if LocationDB.is_dungeon(GameState.location_id):
		items.append({"id": "dungeon", "key": "E", "label": "Entrar"})
	_hint_bar.set_items(items)


func _on_hint_pressed(id: String) -> void:
	if mode != Mode.EXPLORE:
		return
	match id:
		"dungeon":
			_dungeon_entrance()
		"map":
			_open_map()
		"phone":
			_open_phone()
		"menu":
			SceneRouter.go_to(TITLE_SCREEN)


# --- Entrada -----------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	match mode:
		Mode.EXPLORE:
			if event.is_action_pressed("open_map"):
				_open_map()
			elif event.is_action_pressed("open_phone"):
				_open_phone()
			elif event.is_action_pressed("ui_cancel"):
				SceneRouter.go_to(TITLE_SCREEN)
			elif event is InputEventKey and event.pressed and not event.echo \
					and (event as InputEventKey).physical_keycode == KEY_E and LocationDB.is_dungeon(GameState.location_id):
				_dungeon_entrance()
			elif (event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right")) \
					and get_viewport().gui_get_focus_owner() == null:
				_focus_character(_first_character())
			else:
				return
			get_viewport().set_input_as_handled()
		Mode.MAP:
			if event.is_action_pressed("open_map") or event.is_action_pressed("ui_cancel"):
				_map.close()
				get_viewport().set_input_as_handled()


# --- Móvil ----------------------------------------------------------------------------

## Solo desde la exploración: nunca en combate, conversación ni viaje.
func _open_phone() -> void:
	if mode != Mode.EXPLORE:
		return
	mode = Mode.PHONE
	if is_instance_valid(_hint_toast):
		_hint_toast.queue_free()
	_set_cast_interactive(false)
	_empty_hint.visible = false
	_phone.open()


# --- Mapa y viajes -------------------------------------------------------------------

func _open_map() -> void:
	mode = Mode.MAP
	if is_instance_valid(_hint_toast):
		_hint_toast.queue_free()
	_set_cast_interactive(false)
	_empty_hint.visible = false
	_map.open(GameState.location_id)


func _travel(location_id: String) -> void:
	var step := ChapterDB.step(GameState.story_step)
	if not step.is_empty() and location_id != step.target:
		# El mapa sigue abierto: solo se avisa de adónde hay que ir.
		Toast.show_in(self, "Ahora no. Objetivo: %s" % step.objective, UIStyle.LIME, 2.6)
		return
	mode = Mode.TRAVEL
	await _map.close()
	await SceneRouter.fade_out(0.35)
	GameState.set_location(location_id)
	_backdrop.set_location(location_id)
	_refresh_hints()
	_empty_hint.visible = false
	_spawn_cast()
	await get_tree().process_frame
	await SceneRouter.fade_in(0.35)
	_banner.play(LocationDB.display_name(location_id), "Región · %s" % GameState.region_name)
	GameState.record("visit", CharacterDB.PROTAGONIST, location_id, {}, Social.present())
	if not step.is_empty():
		await _play_story_step()
		return
	var plan_id := ChapterDB.plan_at(location_id)
	if plan_id != "":
		await _play_plan(plan_id)
		return
	# Sucesos al llegar (las incursiones en la calle): no en sitios seguros ni en casa.
	if location_id != LocationDB.HOME and not LocationDB.get_location(location_id).get("safe", false) \
			and not LocationDB.is_dungeon(location_id):
		var beat := StoryBeats.check("arrive", "", _cast(location_id))
		if beat != "":
			await _run_beat(beat, StoryBeats.companion(ChapterDB.BEATS[beat], _cast(location_id)), "")
			return
	if LocationDB.is_dungeon(location_id):
		GameState.save_game()
		await _dungeon_entrance(1.4)
		return
	if LocationDB.is_hostile(location_id):
		await _ambush()
	GameState.save_game()
	mode = Mode.EXPLORE
	_update_empty_hint()


# --- Mazmorras ---------------------------------------------------------------------------

## Escena a la entrada de una mazmorra: Ren decide si entra («Entrar en la torre»)
## o se lo piensa. Al entrar empieza el modo mazmorra (DungeonScreen).
func _dungeon_entrance(delay: float = 0.0) -> void:
	mode = Mode.TALK
	_set_cast_interactive(false)
	_empty_hint.visible = false
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout   # deja ver el cartel de la ubicación
	_show_hud(false)
	GameState.set_flag("entrar_mazmorra", false)
	await _conversation.play(Story.cue("torre_llegada"), "")
	if GameState.get_flag("entrar_mazmorra"):
		GameState.set_flag("entrar_mazmorra", false)
		GameState.save_game()
		SceneRouter.go_to(DUNGEON_SCREEN)
		return
	_show_hud(true)
	mode = Mode.EXPLORE
	_set_cast_interactive(true)
	_update_empty_hint()


# --- Guion (capítulo 1) ---------------------------------------------------------------

## Escenas del paso de guion en curso; después pasa al siguiente y avisa del objetivo.
func _play_story_step() -> void:
	var step := ChapterDB.step(GameState.story_step)
	mode = Mode.TALK
	_set_cast_interactive(false)
	await get_tree().create_timer(1.4).timeout   # deja ver el cartel de la ubicación
	_show_hud(false)
	for scene: Dictionary in step.scenes:
		if scene.get("black", false):
			await _black_scene(Story.cue(scene.cue))
		else:
			await _conversation.play(Story.cue(scene.cue), scene.get("npc", ""))
	GameState.story_step = step.next
	if step.get("advance_time", false):
		_pass_time()
	if step.get("end_day", false):
		await _go_to_next_morning()
	else:
		GameState.save_game()
		_show_hud(true)
		mode = Mode.EXPLORE
		_set_cast_interactive(true)
		_update_empty_hint()
		_show_objective(false)


## Plan propuesto (ChapterDB.PLANS): sus escenas, como un paso del guion, y
## después juego libre en el mismo sitio.
func _play_plan(plan_id: String) -> void:
	var plan := ChapterDB.plan(plan_id)
	mode = Mode.TALK
	_set_cast_interactive(false)
	_empty_hint.visible = false
	await get_tree().create_timer(1.4).timeout   # deja ver el cartel de la ubicación
	_show_hud(false)
	# Quien Ren no conoce no cuenta como presente (p. ej. Akane en la reunión).
	GameState.scene_cast = plan.get("cast", []).filter(func(c: String) -> bool: return Acquaintance.is_friend(c))
	Invites.current_plan = plan_id   # para Story.activity() / other_guests() en las quedadas
	for scene: Dictionary in plan.scenes:
		if scene.get("black", false):
			await _black_scene(Story.cue(scene.cue))
		else:
			await _conversation.play(Story.cue(scene.cue), scene.get("npc", ""))
	var cast: Array = GameState.scene_cast
	GameState.scene_cast = []
	GameState.set_flag(ChapterDB.PLAN_DONE + plan_id)
	GameState.record("plan", CharacterDB.PROTAGONIST, plan_id, {}, cast)
	# A solas con alguien al acabar el plan: puede saltar un suceso (la incursión).
	if cast.size() == 1:
		var beat := StoryBeats.check("plan_end", cast[0], cast)
		if beat != "":
			await _run_beat(beat, cast[0], "")
	if plan.has("sets_phase"):
		GameState.set_phase(plan.sets_phase)
	if plan.get("advance_time", false) and GameState.slot_id() != "noche":
		_pass_time()
	_spawn_cast()
	GameState.save_game()
	_show_hud(true)
	mode = Mode.EXPLORE
	_set_cast_interactive(true)
	_update_empty_hint()
	_announce_plans()


## Invitaciones y mensajes que tocan a esta hora (Invites), plantones de planes
## aceptados y un aviso con los planes de hoy que siguen en pie.
func _announce_plans() -> void:
	var senders := Invites.check_missed()
	for who in Invites.deliver_due():
		if not senders.has(who):
			senders.append(who)
	var y := 250.0
	if not senders.is_empty():
		var names := senders.map(func(w: String) -> String: return CharacterDB.display_name(w))
		Toast.show_in(self, "Mensajes nuevos: %s (T)" % ", ".join(names), UIStyle.LIME, 6.0, y)
		y += 62.0
	var agenda := Invites.agenda()
	if agenda.is_empty():
		return
	Toast.show_in(self, "Planes de hoy (contesta desde el móvil)", UIStyle.VIOLET, 7.0, y)
	for label in agenda.slice(0, 5):
		y += 62.0
		Toast.show_in(self, label, UIStyle.VIOLET, 7.0, y)


## Fundido a negro, narración sobre negro y vuelta a la escena.
func _black_scene(entry: Dictionary) -> void:
	await SceneRouter.fade_out(0.5)
	_fade_room(false)
	await SceneRouter.fade_in(0.2)
	await _conversation.play(entry, "", false)
	await SceneRouter.fade_out(0.4)
	_fade_room(true)
	await SceneRouter.fade_in(0.5)


## Muestra u oculta la ubicación entera (fondo, objetos y personajes).
## Sin `duration`, de golpe. Cancela cualquier fundido anterior de la ubicación.
func _fade_room(on: bool, duration: float = 0.0) -> void:
	_room_tween = _fade(_backdrop, _room_tween, on, duration)


## Muestra u oculta solo a los personajes del escenario (los objetos se quedan).
func _fade_cast(on: bool, duration: float = 0.0) -> void:
	_cast_tween = _fade(_scenario, _cast_tween, on, duration)


func _fade(node: CanvasItem, previous: Tween, on: bool, duration: float) -> Tween:
	if previous and previous.is_valid():
		previous.kill()
	var alpha := 1.0 if on else 0.0
	if duration <= 0.0:
		node.modulate.a = alpha
		return null
	var t := create_tween()
	t.tween_property(node, "modulate:a", alpha, duration)
	return t


# --- Paso del tiempo ------------------------------------------------------------------

## Una actividad hecha: pasa a la franja siguiente del día y lo avisa. (De noche
## no se llama: para eso está dormir.)
func _pass_time() -> void:
	if GameState.advance_slot():
		return
	_backdrop.set_location(GameState.location_id)   # fondo de la nueva franja, si lo hay
	_spawn_cast()   # quién está aquí depende de la franja (p. ej. Mamá en casa)
	Toast.show_in(self, "Ahora: %s" % GameState.slot_name(), UIStyle.VIOLET, 3.0, 250.0)
	# Mensajes de la nueva franja y plantones de la que acaba de pasar.
	var senders := Invites.check_missed()
	for who in Invites.deliver_due():
		if not senders.has(who):
			senders.append(who)
	if not senders.is_empty():
		var names := senders.map(func(w: String) -> String: return CharacterDB.display_name(w))
		Toast.show_in(self, "Mensajes nuevos: %s (T)" % ", ".join(names), UIStyle.LIME, 5.0, 312.0)


## Ren duerme hasta la mañana siguiente (desde cualquier franja): fundido,
## `narration` opcional sobre negro, reloj y calendario, y la intro de rutina.
func _go_to_next_morning(narration: String = "") -> void:
	var before := _date_info()
	var from_hour := GameState.slot_hour()
	await SceneRouter.fade_out(0.8)
	_fade_room(false)
	_hud.modulate.a = 0.0
	if narration != "":
		await SceneRouter.fade_in(0.2)
		await _conversation.play(Story.cue(narration), "", false)
		await SceneRouter.fade_out(0.5)
	GameState.wake_up_next_day()
	_backdrop.set_location(GameState.location_id)
	_spawn_cast()
	var transition := DayTransition.new()
	add_child(transition)
	await SceneRouter.fade_in(0.3)
	await transition.play(before, _date_info(), from_hour)
	await SceneRouter.fade_out(0.4)
	transition.queue_free()
	await SceneRouter.fade_in(0.2)
	await get_tree().create_timer(0.6).timeout
	await _conversation.play(Story.cue("intro"), "", false)
	var morning: Dictionary = ChapterDB.MORNINGS.get(GameState.day_number(), {})
	if not morning.is_empty() and Story.has_cue(morning.cue):
		await SceneRouter.fade_out(0.3)
		_fade_room(true)
		await SceneRouter.fade_in(0.4)
		GameState.scene_cast = [morning.npc]
		await _conversation.play(Story.cue(morning.cue), morning.npc)
		GameState.scene_cast = []
	GameState.save_game()
	_enter_explore()
	await _check_partner()
	_show_objective(true)
	_announce_plans()


## Siesta: pasa una franja. De noche equivale a dormir hasta la mañana.
func _nap() -> void:
	if GameState.slot_id() == "noche":
		await _go_to_next_morning("siesta")
		return
	await _black_scene(Story.cue("siesta"))
	_pass_time()
	# Si con la siesta empieza un plan aquí (la cena en casa), se juega ya.
	var plan_id := ChapterDB.plan_at(GameState.location_id)
	if plan_id != "":
		await _play_plan(plan_id)


func _date_info() -> Dictionary:
	return {"weekday": GameState.weekday_long(), "day": int(GameState.date.day), "month": GameState.month_short()}


## Ubicación sin nadie: algo acecha y salta un combate contra un enemigo al azar.
func _ambush() -> void:
	mode = Mode.COMBAT
	await get_tree().create_timer(1.2).timeout
	await _quake()
	await _run_combat(LocationDB.RANDOM_ENEMIES.pick_random())


func _update_empty_hint() -> void:
	var id := GameState.location_id
	_empty_hint.text = "No queda nadie por aquí." if LocationDB.is_hostile(id) else "No hay nadie a estas horas."
	_empty_hint.visible = id != LocationDB.HOME and not LocationDB.is_dungeon(id) and _cast(id).is_empty() and GameState.story_step == ""


# --- Escenario: personajes -------------------------------------------------------------

## Crea objetos y personajes de la ubicación actual. No cambia su visibilidad:
## eso lo deciden `_fade_room` / `_fade_cast`.
func _spawn_cast() -> void:
	for child in _props_layer.get_children() + _scenario.get_children():
		child.queue_free()
	_sprites.clear()
	_tags.clear()
	_bubbles.clear()
	_props.clear()
	_poses.clear()

	for prop: Dictionary in LocationDB.props(GameState.location_id):
		_spawn_prop(prop)

	for id: String in _cast(GameState.location_id):
		var data := CharacterDB.get_character(id)
		var sprite := CharacterSprite.new()
		sprite.name = id.capitalize()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.glow_color = data.color
		sprite.glow_active = 1.0
		var pose := LocationDB.pose(GameState.location_id, id)
		if pose.is_empty():
			# Sin pose para este lugar: su retrato de pie, con el brillo siempre visible.
			sprite.texture = CharacterDB.portrait(id)
			sprite.glow_idle = 0.85
		else:
			# Integrado en el fondo, en su sitio: solo resalta al pasar por encima.
			sprite.texture = pose.texture
			sprite.stretch = true
			sprite.glow_idle = 0.0
			sprite.outline_screen_px = 2.0
			sprite.glow_screen_px = 8.0
			_poses[id] = pose.rect
		sprite.interactive = true
		sprite.activated.connect(_on_character_activated.bind(id))
		sprite.focus_entered.connect(_set_tag_visible.bind(id, true))
		sprite.focus_exited.connect(_set_tag_visible.bind(id, false))
		_scenario.add_child(sprite)
		_sprites[id] = sprite

		var bubble := TalkIndicator.new()
		bubble.color = data.color
		_scenario.add_child(bubble)
		_bubbles[id] = bubble

		var tag := NameTag.new()
		tag.text = data.name
		tag.color = data.color
		tag.visible = false
		_scenario.add_child(tag)
		_tags[id] = tag

	_layout_cast()


## Objeto examinable encajado sobre el fondo, con contorno y menú al seleccionarlo.
func _spawn_prop(prop: Dictionary) -> void:
	var id: String = prop.id
	var sprite := CharacterSprite.new()
	sprite.name = id.capitalize()
	sprite.texture = load(prop.texture)
	sprite.stretch = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.glow_color = PROP_COLOR
	sprite.outline_screen_px = 2.0
	sprite.glow_screen_px = 8.0
	sprite.glow_idle = PROP_GLOW
	sprite.glow_active = 1.0
	sprite.interactive = true
	sprite.activated.connect(_on_prop_activated.bind(id))
	sprite.focus_entered.connect(_set_tag_visible.bind(id, true))
	sprite.focus_exited.connect(_set_tag_visible.bind(id, false))
	_props_layer.add_child(sprite)
	_sprites[id] = sprite
	_props[id] = prop

	var tag := NameTag.new()
	tag.text = prop.name
	tag.color = PROP_COLOR
	tag.visible = false
	_props_layer.add_child(tag)
	_tags[id] = tag


func _layout_cast() -> void:
	var area := _scenario.size
	# Objetos: misma transformación que la imagen de fondo.
	for id: String in _props:
		var r: Rect2 = _props[id].rect
		var sprite: CharacterSprite = _sprites[id]
		sprite.position = _backdrop.image_to_local(r.position)
		sprite.size = r.size * _backdrop.cover_scale()
		var tag: NameTag = _tags[id]
		var top := sprite.position + sprite.head_point()
		tag.position = Vector2(clampf(top.x - tag.size.x * 0.5, 20, area.x - tag.size.x - 20),
				clampf(top.y - tag.size.y - 10, 130, area.y - tag.size.y - 20))
	# Personajes con pose: en su sitio del fondo, como los objetos.
	for id: String in _poses:
		var r: Rect2 = _poses[id]
		var sprite: CharacterSprite = _sprites[id]
		sprite.position = _backdrop.image_to_local(r.position)
		sprite.size = r.size * _backdrop.cover_scale()
		_place_marks(id, sprite.position + sprite.head_point())
	# El resto, repartidos a lo ancho: uno en el centro, dos a tercios, tres a cuartos...
	var ids := _sprites.keys().filter(func(k: String) -> bool: return not _props.has(k) and not _poses.has(k))
	for i in ids.size():
		var id: String = ids[i]
		var scene_data: Dictionary = CharacterDB.get_character(id).scene
		var x := (i + 1.0) / (ids.size() + 1.0)
		var sprite: CharacterSprite = _sprites[id]
		var h: float = scene_data.height * area.y / 1080.0
		var w := h * 0.75
		sprite.size = Vector2(w, h)
		sprite.position = Vector2(area.x * x - w * 0.5, area.y - h)
		_place_marks(id, sprite.position + sprite.head_point())


## Burbuja de «hablar» y nombre de un personaje sobre su cabeza.
func _place_marks(id: String, head: Vector2) -> void:
	var bubble: TalkIndicator = _bubbles[id]
	bubble.position = head + Vector2(-bubble.size.x * 0.5 + 8, -bubble.size.y + 4)
	var tag: NameTag = _tags[id]
	tag.position = head + Vector2(-bubble.size.x * 0.5 - tag.size.x - 4, -tag.size.y - 6)


## Los personajes solo responden en modo exploración (evita que roben el foco
## al menú, al mapa o a la conversación). Los objetos siguen a la vista, pero
## sin su contorno mientras no se pueden examinar.
func _set_cast_interactive(on: bool) -> void:
	for id: String in _sprites:
		var sprite: CharacterSprite = _sprites[id]
		sprite.interactive = on
		if _props.has(id):
			sprite.glow_idle = PROP_GLOW if on else 0.0


func _first_character() -> String:
	return _sprites.keys()[0] if not _sprites.is_empty() else ""


func _focus_character(id: String) -> void:
	if _sprites.has(id):
		(_sprites[id] as Control).grab_focus()


func _set_tag_visible(id: String, on: bool) -> void:
	if _tags.has(id):
		_tags[id].visible = on
	if _bubbles.has(id):
		_bubbles[id].highlighted = on


func _on_prop_activated(id: String) -> void:
	if mode != Mode.EXPLORE:
		return
	mode = Mode.MENU
	_last_character = id
	_set_cast_interactive(false)
	var sprite: CharacterSprite = _sprites[id]
	var img := sprite.image_rect()
	var actions: Array = InteractionMenu.OBJECT_ACTIONS.duplicate()
	if id == "cama":
		actions.append_array(BED_ACTIONS)
	_interaction.open(id, Rect2(sprite.position + img.position, img.size), _props[id].name, PROP_COLOR, actions)


func _on_character_activated(id: String) -> void:
	if mode != Mode.EXPLORE:
		return
	mode = Mode.MENU
	_last_character = id
	_set_cast_interactive(false)
	var sprite: CharacterSprite = _sprites[id]
	var img := sprite.image_rect()
	var actions: Array = InteractionMenu.ACTIONS
	if not Acquaintance.is_friend(id):
		actions = Acquaintance.menu_actions(id)   # saludar / charla corta / pedir el número
	elif CharacterDB.get_character(id).get("talk_only", false):
		actions = actions.filter(func(a: Dictionary) -> bool: return a.id in ["talk", "plan"])
	_interaction.open(id, Rect2(sprite.position + img.position, img.size), "", Color(0, 0, 0, 0), actions)


func _on_interaction_closed() -> void:
	if mode == Mode.MENU:
		mode = Mode.EXPLORE
		_set_cast_interactive(true)
		_focus_character(_last_character)


func _on_action_chosen(id: String, action: String) -> void:
	if action in ["nap", "sleep"]:
		await _use_bed(id, action)
		return
	if action == "date":
		_open_date_places(id)
		return
	if action == "plan":
		_open_plan_activities(id)
		return
	if action.begins_with(InteractionMenu.PLAN_PREFIX):
		_open_plan_slots(id, action.trim_prefix(InteractionMenu.PLAN_PREFIX))
		return
	if action.begins_with(InteractionMenu.PLAN_WHEN_PREFIX):
		var parts := action.trim_prefix(InteractionMenu.PLAN_WHEN_PREFIX).split("|")
		await _run_ren_invite(id, parts[0], int(parts[1]), parts[2])
		return
	if action.begins_with(InteractionMenu.DATE_PREFIX):
		await _run_date(id, action.trim_prefix(InteractionMenu.DATE_PREFIX))
		return
	mode = Mode.TALK
	get_viewport().gui_release_focus()
	_fade_cast(false, 0.25)
	_show_hud(false)
	if action == "examine":
		GameState.record("examine", CharacterDB.PROTAGONIST, id)
		await _conversation.play(Story.cue("examinar_" + id), "")
	elif not Acquaintance.is_friend(id):
		await _talk_to_acquaintance(id, action)
	elif action == "talk" and StoryBeats.check("talk", id, _cast(GameState.location_id)) != "":
		Social.begin_interaction(id, action, true)
		await _run_beat(StoryBeats.check("talk", id, _cast(GameState.location_id)), id, action)
	else:
		var result := Social.begin_interaction(id, action)
		if result != Social.OK:
			# Se ha hartado o no tiene el día: corta antes de empezar.
			await _conversation.play(Story.pick(id, Story.moment_for(action, result)), id)
		else:
			var entry := Story.pick(id, Story.moment_for(action))
			if action == "talk":
				# Si le dejaste plantado y no contestaste a su mensaje, te lo dice ahora.
				var reproach := Invites.reproach_cue(id, entry.get("cue", ""))
				if not reproach.is_empty():
					entry = reproach
			await _conversation.play(entry, id)
			if action == "flirt":
				Romance.on_flirt(id)
		if action == "fight" and result == Social.OK:
			var won := await _run_combat(id)
			await _conversation.play(Story.pick(id, "luchar_fin", {"resultado": "gana" if won else "pierde"}), id)
	GameState.save_game()
	_fade_cast(true, 0.3)
	_show_hud(true)
	mode = Mode.EXPLORE
	_set_cast_interactive(true)
	_focus_character(id)


## Charla con alguien que aún no es amigo de Ren (Acquaintance): presentarse, una
## charla corta o pedirle el número. Sin cue escrito, una línea genérica.
func _talk_to_acquaintance(id: String, action: String) -> void:
	var was := Acquaintance.state(id)
	var cue := Acquaintance.cue_for(id, action)
	if Story.has_cue(cue):
		await _conversation.play(Story.cue(cue), id)
	else:
		await _conversation.play(Story.cue("conocido_" + cue.trim_prefix(id + "_")), id)
	if was == Acquaintance.STRANGER:
		Acquaintance.introduce(id)
	elif action == "befriend":
		Acquaintance.befriend(id)
		Toast.show_in(self, "%s ya está en tus contactos" % CharacterDB.display_name(id), UIStyle.LIME, 3.0, 170.0)
	_spawn_cast()   # su nombre en la etiqueta


# --- Citas (Romance) -------------------------------------------------------------------

## «Quedar»: el menú pasa a las actividades que Ren puede proponer (ChapterDB.REN_ACTIVITIES).
func _open_plan_activities(id: String) -> void:
	if GameState.story_step != "":
		Toast.show_in(self, "Ahora no. Objetivo: %s" % ChapterDB.step(GameState.story_step).get("objective", ""), UIStyle.LIME, 3.0, 170.0)
		mode = Mode.EXPLORE
		_set_cast_interactive(true)
		_focus_character(id)
		return
	var actions: Array = []
	for act: String in ChapterDB.REN_ACTIVITIES:
		var a: Dictionary = ChapterDB.REN_ACTIVITIES[act]
		if Invites.proposal_slots(act).is_empty():
			continue
		actions.append({"id": InteractionMenu.PLAN_PREFIX + act, "label": a.title,
				"icon": "calendar", "desc": LocationDB.display_name(a.target)})
	_reopen_menu(id, "¿Qué plan?", actions)


## «Quedar» → actividad: ahora, cuándo (lo que queda de hoy o mañana).
func _open_plan_slots(id: String, activity: String) -> void:
	var actions: Array = []
	for s: Dictionary in Invites.proposal_slots(activity):
		actions.append({"id": "%s%s|%d|%s" % [InteractionMenu.PLAN_WHEN_PREFIX, activity, s.day, s.slot],
				"label": s.label, "icon": "clock", "desc": ChapterDB.REN_ACTIVITIES[activity].title})
	_reopen_menu(id, "¿Cuándo?", actions)


func _reopen_menu(id: String, title: String, actions: Array) -> void:
	var sprite: CharacterSprite = _sprites[id]
	var img := sprite.image_rect()
	_interaction.open(id, Rect2(sprite.position + img.position, img.size), title, CharacterDB.color(id), actions)


## Ren propone el plan en persona: contesta (su `<id>_quedar`) y queda apuntado.
func _run_ren_invite(id: String, activity: String, day: int, slot: String) -> void:
	mode = Mode.TALK
	get_viewport().gui_release_focus()
	_fade_cast(false, 0.25)
	_show_hud(false)
	GameState.record("talk", CharacterDB.PROTAGONIST, id)
	await _conversation.play(Invites.ren_invite(id, activity, day, slot), id)
	GameState.save_game()
	_fade_cast(true, 0.3)
	_show_hud(true)
	mode = Mode.EXPLORE
	_set_cast_interactive(true)
	_focus_character(id)


## «Cita»: el menú pasa a los sitios donde se le puede invitar.
func _open_date_places(id: String) -> void:
	var why := ""
	if GameState.story_step != "":
		why = "Ahora no. Objetivo: %s" % ChapterDB.step(GameState.story_step).get("objective", "")
	elif GameState.slot_id() == "noche":
		why = "Es muy tarde para una cita."
	elif Romance.dated_today():
		why = "Hoy ya has tenido una cita."
	if why != "":
		Toast.show_in(self, why, UIStyle.LIME, 3.0, 170.0)
		mode = Mode.EXPLORE
		_set_cast_interactive(true)
		_focus_character(id)
		return
	var actions: Array = []
	for place in Romance.DATE_PLACES:
		actions.append({"id": InteractionMenu.DATE_PREFIX + place, "label": LocationDB.display_name(place),
				"icon": "heart", "desc": "Invitarle a %s." % LocationDB.display_name(place)})
	var sprite: CharacterSprite = _sprites[id]
	var img := sprite.image_rect()
	_interaction.open(id, Rect2(sprite.position + img.position, img.size), "¿Adónde?", CharacterDB.color(id), actions)


## Pide la cita: responde según Romance.answer; si acepta, fundido al sitio, la
## escena de la cita (momento «cita») y pasa la franja.
func _run_date(id: String, place: String) -> void:
	mode = Mode.TALK
	get_viewport().gui_release_focus()
	_fade_cast(false, 0.25)
	_show_hud(false)
	var answer := Romance.answer(id, place)
	var accepted := answer in ["acepta", "rompe"]
	if accepted:
		Romance.start_date(id, place, answer)
	else:
		Romance.refused(id, place, answer)
	await _conversation.play(Story.pick(id, "cita_pide", {"resultado": answer}), id)
	if accepted:
		await SceneRouter.fade_out(0.5)
		GameState.set_location(place)
		_backdrop.set_location(place)
		_refresh_hints()
		_spawn_cast()
		GameState.scene_cast = [id]
		await SceneRouter.fade_in(0.5)
		_banner.play(LocationDB.display_name(place), "Cita con %s" % CharacterDB.display_name(id))
		await _conversation.play(Story.pick(id, "cita"), id)
		GameState.scene_cast = []
		Romance.finish_date(id)
		_pass_time()
		_spawn_cast()
	GameState.save_game()
	_fade_cast(true, 0.3)
	_show_hud(true)
	mode = Mode.EXPLORE
	_set_cast_interactive(true)
	if _sprites.has(id):
		_focus_character(id)
	_update_empty_hint()


## Cada mañana: se descubren secretos (Lies) y la pareja de Ren repasa el día
## anterior. Si le deja, se lo dice.
func _check_partner() -> void:
	RelationEvents.morning()   # antes: lo de esta mañana se cuenta mañana
	Lies.morning()
	var partner := Romance.ren_partner()
	var why := Romance.morning()
	if why == "":
		return
	mode = Mode.TALK
	_show_hud(false)
	_fade_cast(false)
	await _conversation.play(Story.pick(partner, "deja_a_ren", {"resultado": why}), partner)
	_fade_cast(true, 0.3)
	_show_hud(true)
	mode = Mode.EXPLORE
	GameState.save_game()


## Siesta o dormir. Durante el guion no se puede (hay un objetivo pendiente).
func _use_bed(id: String, action: String) -> void:
	var step := ChapterDB.step(GameState.story_step)
	if not step.is_empty():
		Toast.show_in(self, "Ahora no. Objetivo: %s" % step.objective, UIStyle.LIME, 3.0, 170.0)
		mode = Mode.EXPLORE
		_set_cast_interactive(true)
		_focus_character(id)
		return
	mode = Mode.TALK
	get_viewport().gui_release_focus()
	_show_hud(false)
	if action == "sleep":
		await _go_to_next_morning("dormir")
		return
	await _nap()
	GameState.save_game()
	_show_hud(true)
	mode = Mode.EXPLORE
	_set_cast_interactive(true)
	_focus_character(id)


## Fundido → combate → fundido. Devuelve si ha ganado el grupo.
## En el primer combate contra una criatura lucha también un compañero
## (`ally_hint` o uno al azar) con habilidades al azar de todo el catálogo.
## `enemies`: un id o una lista (hasta tres). Con `ally_hint` contra criaturas,
## ese compañero lucha con Ren (con 2 habilidades al azar, provisional hasta que
## cada uno tenga las suyas).
func _run_combat(enemies: Variant, ally_hint: String = "", rules: Dictionary = {}) -> bool:
	mode = Mode.COMBAT
	var enemy_id: String = enemies[0] if enemies is Array else enemies
	var ally := ""
	var ally_skills: Array = []
	if rules.get("basic_only", false):
		ally = ally_hint   # la primera incursión: quien estaba con Ren, sin habilidades
		GameState.first_creature_fight_done = true
	elif CharacterDB.is_enemy(enemy_id) and (ally_hint != "" or not GameState.first_creature_fight_done):
		GameState.first_creature_fight_done = true
		ally = ally_hint if ally_hint != "" else CharacterDB.COMPANIONS.pick_random()
		ally_skills = SkillDB.random_skills(2, CharacterDB.combat_tags(ally), CharacterDB.get_character(ally).get("nature", ""))
	await SceneRouter.fade_out(0.25)
	# Criaturas en la calle: al nivel de Ren (ver ProgressionDB). Las personas, al suyo.
	var level := ProgressionDB.street_creature_level(GameState.level_of(CharacterDB.PROTAGONIST)) \
			if CharacterDB.is_enemy(enemy_id) else 0
	_combat.setup(enemies, ally, ally_skills, {}, level, false, rules)
	await SceneRouter.fade_in(0.25)
	_combat.begin()
	var won: bool = await _combat.finished
	GameState.record("combat", CharacterDB.PROTAGONIST, enemy_id, {"won": won, "ally": ally},
			[ally] if ally != "" else [])
	await SceneRouter.fade_out(0.25)
	_combat.visible = false
	await SceneRouter.fade_in(0.25)
	mode = Mode.TALK
	return won


# --- Incursión ---------------------------------------------------------------------------

## Reproduce el suceso de guion `beat` (ChapterDB.BEATS) con `npc_id`.
## `action`: lo que Ren iba a hacer con él ("" si salta al acabar un plan).
func _run_beat(beat: String, npc_id: String, action: String) -> void:
	StoryBeats.mark_done(beat)
	match beat:
		"incursion_1":
			await _run_incursion(npc_id, action)
		"incursion_2", "incursion_3":
			await _run_street_incursion(beat, npc_id)


## Primera incursión: la conversación con `npc_id` (si la hay) se corta de golpe,
## tiembla todo, aparece la criatura de esta partida y hay que combatirla los dos
## solos, sin habilidades ni objetos. Si ganan, los dos suben un nivel.
func _run_incursion(npc_id: String, action: String) -> void:
	var enemy_id := GameState.incursion_enemy
	_fade_cast(false, 0.25)
	_show_hud(false)
	if action != "":
		await _conversation.play(Story.pick(npc_id, Story.moment_for(action)), npc_id, true, true, INCURSION_CUT_AFTER)
	await _conversation.play(Story.cue("temblor"), npc_id, true, true)   # tiembla: Story.efecto en el diálogo
	await _conversation.play(Story.pick(npc_id, "alarma"), npc_id, true, true)
	await _conversation.play(Story.cue("aparece_" + enemy_id), enemy_id, true)
	var pair := [CharacterDB.PROTAGONIST, npc_id]
	var before := pair.map(func(w: String) -> int: return GameState.level_of(w))
	var won := await _run_combat(enemy_id, npc_id, {"basic_only": true})
	if won:
		# Suben un nivel (si la EXP del combate no les ha subido ya).
		var up: Array[String] = []
		for i in pair.size():
			if GameState.level_of(pair[i]) == before[i]:
				GameState.level_up(pair[i])
			up.append(CharacterDB.display_name(pair[i]))
		Toast.show_in(self, "%s suben al nivel %d" % [" y ".join(up), GameState.level_of(npc_id)], UIStyle.LIME, 4.0, 170.0)
	GameState.incursion_done = true
	GameState.set_flag("con_incursion_1", npc_id)
	# Todos los presentes lo han visto: a partir de aquí saben que existen las criaturas.
	GameState.record("incursion", enemy_id, npc_id, {"won": won}, Social.present(), "incursion_1")
	GameState.set_flag("conoce_criaturas")
	GameState.set_flag("lugar_incursion", LocationDB.display_name(GameState.location_id))
	GameState.set_phase("incursion_1")
	var result := {"resultado": "gana" if won else "pierde"}
	await _conversation.play(Story.cue("derrota_%s_%s" % [enemy_id, result.resultado]), npc_id, true, true)
	await _conversation.play(Story.pick(npc_id, "tras_incursion", result), npc_id)
	if action != "":
		_announce_plans()   # el grupo convoca la reunión (tras un plan, ya avisa _play_plan)


## Incursiones 2 y 3 (ChapterDB.BEATS): al llegar a un sitio, tiembla todo y
## aparecen criaturas; Ren lucha con `ally_id` (alguien del grupo que estaba
## allí). Escenas `<cue>_aparece` y `<cue>_despues` (capitulo1.dialogue); la
## segunda sabe si ganaron por el flag `incursion_ganada`.
func _run_street_incursion(beat: String, ally_id: String) -> void:
	var b: Dictionary = ChapterDB.BEATS[beat]
	mode = Mode.TALK
	_set_cast_interactive(false)
	_empty_hint.visible = false
	await get_tree().create_timer(1.4).timeout   # deja ver el cartel de la ubicación
	_fade_cast(false, 0.25)
	_show_hud(false)
	await _conversation.play(Story.cue(b.cue + "_aparece"), ally_id, true, true)   # el temblor va en la escena
	var won := await _run_combat(b.enemies, ally_id)
	GameState.set_flag("incursion_ganada", won)
	GameState.set_flag("con_" + beat, ally_id)
	GameState.set_flag("lugar_" + beat, LocationDB.display_name(GameState.location_id))
	GameState.record("incursion", b.enemies[0], ally_id, {"won": won}, Social.present(), beat)
	GameState.set_phase(b.sets_phase)
	await _conversation.play(Story.cue(b.cue + "_despues"), ally_id)
	GameState.save_game()
	_fade_cast(true, 0.3)
	_show_hud(true)
	mode = Mode.EXPLORE
	_set_cast_interactive(true)
	_update_empty_hint()
	_announce_plans()


# --- Comandos de escena (Story.fondo/entra/sale/efecto, desde los .dialogue) -----------------

func scene_background(location_id: String) -> void:
	var id := location_id if location_id != "" else GameState.location_id
	if id == _backdrop.location_id:
		return
	await SceneRouter.fade_out(0.25)
	_fade_cast(id == GameState.location_id)
	_backdrop.set_location(id)
	await SceneRouter.fade_in(0.25)


func scene_enter(id: String) -> void:
	await _conversation.stage_enter(id)


func scene_leave(id: String) -> void:
	await _conversation.stage_leave(id)


func scene_effect(effect: String) -> void:
	match effect:
		"temblor":
			await _quake()
		"destello":
			var flash := ColorRect.new()
			flash.color = Color(1, 1, 1, 0)
			flash.set_anchors_preset(Control.PRESET_FULL_RECT)
			flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(flash)
			var t := create_tween()
			t.tween_property(flash, "color:a", 0.85, 0.06)
			t.tween_property(flash, "color:a", 0.0, 0.45)
			await t.finished
			flash.queue_free()
		"negro":
			await SceneRouter.fade_out(0.6)
		"vuelve":
			await SceneRouter.fade_in(0.6)
		_:
			push_warning("Story.efecto: efecto desconocido «%s» (ver Story.SCENE_EFFECTS)" % effect)


## Temblor de cámara: sacudida fuerte con destello, réplica y una más pequeña.
func _quake() -> void:
	var flash := ColorRect.new()
	flash.color = Color(UIStyle.VIOLET, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)

	# Zoom ligero para que la sacudida no deje ver los bordes de la pantalla.
	pivot_offset = size * 0.5
	create_tween().tween_property(self, "scale", Vector2(1.05, 1.05), 0.06)
	var ft := create_tween()
	ft.tween_property(flash, "color:a", 0.55, 0.06)
	ft.tween_property(flash, "color:a", 0.0, 0.5)
	await _shake_screen(38.0, 0.9)
	await get_tree().create_timer(0.25).timeout
	ft = create_tween()
	ft.tween_property(flash, "color:a", 0.25, 0.05)
	ft.tween_property(flash, "color:a", 0.0, 0.35)
	await _shake_screen(18.0, 0.55)
	await create_tween().tween_property(self, "scale", Vector2.ONE, 0.2).finished
	flash.queue_free()


func _shake_screen(strength: float, duration: float) -> void:
	var origin := position
	var steps := int(duration / 0.03)
	var t := create_tween()
	for i in steps:
		var k := 1.0 - float(i) / steps
		var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * k
		t.tween_property(self, "position", origin + off, 0.03)
	t.tween_property(self, "position", origin, 0.04)
	await t.finished
