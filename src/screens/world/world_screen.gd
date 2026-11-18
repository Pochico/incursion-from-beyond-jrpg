extends Control
## Pantalla de juego principal.
##
## Reúne en una sola escena:
##  - El fondo de la ubicación actual (compartido por escenario y conversación).
##  - La interfaz de escenario: personajes interactuables con silueta de color.
##  - La interfaz de conversación (ConversationView).
##  - El mapa superpuesto (tecla M) y el menú de interacción.
##
## Flujo: introducción en negro → libre (casa) → mapa → ubicación → personajes.

enum Mode { INTRO, EXPLORE, MAP, MENU, TALK, TRAVEL }

const TITLE_SCREEN := "res://src/screens/title/title_screen.tscn"

@onready var _backdrop: LocationBackdrop = %Backdrop
@onready var _scenario: Control = %Scenario
@onready var _hud: Control = %Hud
@onready var _date_header: Control = %DateHeader
@onready var _hint_bar: HintBar = %HintBar
@onready var _banner: LocationBanner = %Banner
@onready var _conversation: ConversationView = %Conversation
@onready var _interaction: InteractionMenu = %Interaction
@onready var _map: MapOverlay = %MapOverlay
@onready var _empty_hint: Label = %EmptyHint

var mode := Mode.INTRO
var _sprites: Dictionary = {}     # id -> CharacterSprite
var _tags: Dictionary = {}        # id -> NameTag
var _last_character := ""


func _ready() -> void:
	_hint_bar.set_items([
		{"id": "menu", "key": "Esc", "label": "Título"},
		{"id": "map", "key": "M", "label": "Mapa"},
	])
	_hint_bar.item_pressed.connect(_on_hint_pressed)
	_interaction.action_chosen.connect(_on_action_chosen)
	_interaction.closed.connect(_on_interaction_closed)
	_map.travel_requested.connect(_travel)
	_map.closed.connect(func() -> void:
		_empty_hint.visible = GameState.location_id == LocationDB.HOME
		if mode == Mode.MAP:
			mode = Mode.EXPLORE
			_set_cast_interactive(true))
	_scenario.resized.connect(_layout_cast)
	GameState.affinity_changed.connect(_on_affinity_changed)

	_backdrop.set_location(GameState.location_id)
	_hud.modulate.a = 0.0
	_empty_hint.visible = false
	_play_intro()


func _play_intro() -> void:
	mode = Mode.INTRO
	await get_tree().create_timer(0.8).timeout
	await _conversation.play(DialogueDB.intro(), "", false)
	_enter_explore()
	Toast.show_in(self, "Pulsa  [M]  para abrir el mapa", UIStyle.LIME, 4.0)


func _enter_explore() -> void:
	mode = Mode.EXPLORE
	_show_hud(true)
	_empty_hint.visible = GameState.location_id == LocationDB.HOME


# --- HUD ---------------------------------------------------------------------------

func _show_hud(full: bool) -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(_hud, "modulate:a", 1.0, 0.3)
	t.tween_property(_date_header, "modulate:a", 1.0 if full else 0.0, 0.3)
	t.tween_property(_hint_bar, "modulate:a", 1.0 if full else 0.0, 0.3)


func _on_hint_pressed(id: String) -> void:
	if mode != Mode.EXPLORE:
		return
	match id:
		"map":
			_open_map()
		"menu":
			SceneRouter.go_to(TITLE_SCREEN)


# --- Entrada -----------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	match mode:
		Mode.EXPLORE:
			if event.is_action_pressed("open_map"):
				_open_map()
			elif event.is_action_pressed("ui_cancel"):
				SceneRouter.go_to(TITLE_SCREEN)
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


# --- Mapa y viajes -------------------------------------------------------------------

func _open_map() -> void:
	mode = Mode.MAP
	_set_cast_interactive(false)
	_empty_hint.visible = false
	_map.open(GameState.location_id)


func _travel(location_id: String) -> void:
	mode = Mode.TRAVEL
	await _map.close()
	await SceneRouter.fade_out(0.35)
	GameState.set_location(location_id)
	_backdrop.set_location(location_id)
	_empty_hint.visible = false
	_spawn_cast()
	await get_tree().process_frame
	await SceneRouter.fade_in(0.35)
	_banner.play(LocationDB.display_name(location_id), "Región · %s" % GameState.region_name)
	mode = Mode.EXPLORE


# --- Escenario: personajes -------------------------------------------------------------

func _spawn_cast() -> void:
	for child in _scenario.get_children():
		child.queue_free()
	_sprites.clear()
	_tags.clear()
	if GameState.location_id == LocationDB.HOME:
		return

	for id: String in CharacterDB.SCENARIO_CAST:
		var data := CharacterDB.get_character(id)
		var sprite := CharacterSprite.new()
		sprite.name = id.capitalize()
		sprite.texture = CharacterDB.portrait(id)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.glow_color = data.color
		sprite.glow_idle = 0.4
		sprite.glow_active = 1.0
		sprite.interactive = true
		sprite.activated.connect(_on_character_activated.bind(id))
		sprite.focus_entered.connect(_set_tag_visible.bind(id, true))
		sprite.focus_exited.connect(_set_tag_visible.bind(id, false))
		_scenario.add_child(sprite)
		_sprites[id] = sprite

		var tag := NameTag.new()
		tag.text = data.name
		tag.color = data.color
		tag.visible = false
		_scenario.add_child(tag)
		_tags[id] = tag

	_layout_cast()
	_scenario.modulate.a = 1.0


func _layout_cast() -> void:
	var area := _scenario.size
	for id: String in _sprites:
		var scene_data: Dictionary = CharacterDB.get_character(id).scene
		var sprite: CharacterSprite = _sprites[id]
		var h: float = scene_data.height * area.y / 1080.0
		var w := h * 0.75
		sprite.size = Vector2(w, h)
		sprite.position = Vector2(area.x * scene_data.x - w * 0.5, area.y - h)
		var img := sprite.image_rect()
		var tag: NameTag = _tags[id]
		tag.position = sprite.position + Vector2(img.get_center().x - tag.size.x * 0.5, img.position.y + h * 0.02 - 30)


## Los personajes solo responden en modo exploración (evita que roben el foco
## al menú, al mapa o a la conversación).
func _set_cast_interactive(on: bool) -> void:
	for sprite: CharacterSprite in _sprites.values():
		sprite.interactive = on


func _first_character() -> String:
	return CharacterDB.SCENARIO_CAST[0] if not _sprites.is_empty() else ""


func _focus_character(id: String) -> void:
	if _sprites.has(id):
		(_sprites[id] as Control).grab_focus()


func _set_tag_visible(id: String, on: bool) -> void:
	if _tags.has(id):
		_tags[id].visible = on


func _on_character_activated(id: String) -> void:
	if mode != Mode.EXPLORE:
		return
	mode = Mode.MENU
	_last_character = id
	_set_cast_interactive(false)
	var sprite: CharacterSprite = _sprites[id]
	var img := sprite.image_rect()
	_interaction.open(id, Rect2(sprite.position + img.position, img.size))


func _on_interaction_closed() -> void:
	if mode == Mode.MENU:
		mode = Mode.EXPLORE
		_set_cast_interactive(true)
		_focus_character(_last_character)


func _on_action_chosen(id: String, action: String) -> void:
	mode = Mode.TALK
	get_viewport().gui_release_focus()
	var t := create_tween()
	t.tween_property(_scenario, "modulate:a", 0.0, 0.25)
	_show_hud(false)
	await _conversation.play(DialogueDB.for_interaction(id, action), id)
	t = create_tween()
	t.tween_property(_scenario, "modulate:a", 1.0, 0.3)
	_show_hud(true)
	mode = Mode.EXPLORE
	_set_cast_interactive(true)
	_focus_character(id)


func _on_affinity_changed(id: String, _value: int, delta: int) -> void:
	var arrow := "↑" if delta > 0 else "↓"
	Toast.show_in(self, "Afinidad con %s %s" % [CharacterDB.display_name(id), arrow], CharacterDB.color(id), 1.8)
