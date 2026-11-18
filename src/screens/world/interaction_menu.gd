class_name InteractionMenu
extends Control
## Menú contextual que aparece al seleccionar a un personaje del escenario.
## Ocupa toda la pantalla (para cerrar al hacer clic fuera); el panel se coloca
## junto al personaje.

signal action_chosen(character_id: String, action: String)
signal closed

const ACTIONS := [
	{"id": "talk", "label": "Hablar", "desc": "Conversar con calma."},
	{"id": "fight", "label": "Luchar", "desc": "Proponer un combate."},
	{"id": "flirt", "label": "Ligar", "desc": "Probar suerte."},
]
const PANEL_SIZE := Vector2(360, 300)

var _character_id := ""
var _panel: Control
var _list: VBoxContainer
var _header_color := UIStyle.LIME
var _header_name := ""


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = Control.new()
	_panel.size = PANEL_SIZE
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.draw.connect(_draw_panel)
	add_child(_panel)

	_list = VBoxContainer.new()
	_list.position = Vector2(20, 82)
	_list.size = Vector2(PANEL_SIZE.x - 30, PANEL_SIZE.y - 100)
	_list.add_theme_constant_override("separation", 12)
	_panel.add_child(_list)

	for i in ACTIONS.size():
		var b := SlantButton.new()
		b.label = ACTIONS[i].label
		b.index_label = "%02d" % (i + 1)
		b.description = ACTIONS[i].desc
		b.font_size = 28
		b.slant = 16
		b.custom_minimum_size = Vector2(0, 56)
		b.pressed.connect(_on_action.bind(ACTIONS[i].id))
		_list.add_child(b)


func is_open() -> bool:
	return visible


## Abre el menú para `character_id`, colocándolo junto a `anchor` (rect en pantalla).
func open(character_id: String, anchor: Rect2) -> void:
	_character_id = character_id
	_header_name = CharacterDB.display_name(character_id)
	_header_color = CharacterDB.color(character_id)

	var pos := Vector2(anchor.end.x - anchor.size.x * 0.2, anchor.position.y + anchor.size.y * 0.25)
	if pos.x + PANEL_SIZE.x > size.x - 40:
		pos.x = anchor.position.x + anchor.size.x * 0.2 - PANEL_SIZE.x
	pos.x = clampf(pos.x, 40, size.x - PANEL_SIZE.x - 40)
	pos.y = clampf(pos.y, 160, size.y - PANEL_SIZE.y - 120)
	_panel.position = pos
	_panel.queue_redraw()

	visible = true
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.92, 0.92)
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_panel, "modulate:a", 1.0, 0.15)
	t.tween_property(_panel, "scale", Vector2.ONE, 0.2)
	for b: SlantButton in _list.get_children():
		b.reveal = 1.0
	(_list.get_child(0) as Control).grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _on_action(action: String) -> void:
	visible = false
	action_chosen.emit(_character_id, action)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _draw_panel() -> void:
	var s := PANEL_SIZE
	var shape := UIStyle.slanted_rect(Rect2(Vector2.ZERO, s), 24)
	_panel.draw_colored_polygon(UIStyle.slanted_rect(Rect2(Vector2(8, 8), s), 24), Color(_header_color, 0.55))
	_panel.draw_colored_polygon(shape, Color(UIStyle.INK, 0.94))
	UIStyle.draw_outline(_panel, shape, Color(UIStyle.WHITE, 0.9), 2.0)
	_panel.draw_rect(Rect2(34, 22, 10, 42), _header_color)
	_panel.draw_string(UIStyle.FONT_HEAVY_ITALIC, Vector2(58, 58), _header_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, UIStyle.WHITE)
	UIStyle.draw_stripes(_panel, Vector2(s.x - 92, 52), 3, Vector2(12, 14), 5, _header_color)
