class_name MapOverlay
extends Control
## Mapa superpuesto (tecla M). Al elegir una ubicación emite `travel_requested`.

signal travel_requested(location_id: String)
signal closed

var _map: MapView
var _info: InfoBar
var _frame: Control


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	_frame = Control.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Medidas para que el mapa salga de MapConfig.VIEW_SIZE (1720 × 700).
	_frame.offset_left = 70
	_frame.offset_top = 110
	_frame.offset_right = -70
	_frame.offset_bottom = -110
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.draw.connect(_draw_frame)
	add_child(_frame)

	_map = MapView.new()
	_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map.offset_left = 30
	_map.offset_top = 90
	_map.offset_right = -30
	_map.offset_bottom = -70
	_frame.add_child(_map)
	_map.location_focused.connect(func(loc: Dictionary) -> void:
		_info.text = "%s  —  %s" % [loc.name, loc.desc])
	_map.location_selected.connect(func(loc: Dictionary) -> void:
		travel_requested.emit(loc.id))

	_info = InfoBar.new()
	_info.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_info.offset_left = 30
	_info.offset_right = -30
	_info.offset_top = -66
	_info.offset_bottom = -8
	_frame.add_child(_info)


func is_open() -> bool:
	return visible


func open(current_id: String) -> void:
	_map.refresh()
	_map.current_id = current_id
	_frame.queue_redraw()
	visible = true
	modulate.a = 0.0
	_frame.pivot_offset = _frame.size * 0.5
	_frame.scale = Vector2(0.97, 0.97)
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 1.0, 0.18)
	t.tween_property(_frame, "scale", Vector2.ONE, 0.22)
	_map.grab_focus()
	_map.select_id(current_id)


func close() -> void:
	if not visible:
		return
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.14)
	await t.finished
	visible = false
	closed.emit()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(UIStyle.INK, 0.72))


func _draw_frame() -> void:
	var s := _frame.size
	var body := PackedVector2Array([
		Vector2(0, 40), Vector2(260, 40), Vector2(290, 0), Vector2(s.x - 40, 0), Vector2(s.x, 40),
		Vector2(s.x, s.y), Vector2(40, s.y), Vector2(0, s.y - 40),
	])
	_frame.draw_colored_polygon(body, Color(UIStyle.GRAPHITE, 0.97))
	UIStyle.draw_outline(_frame, body, UIStyle.LINE, 1.5)
	UIStyle.draw_stripes(_frame, Vector2(300, 30), 4, Vector2(14, 8), 4, Color(UIStyle.WHITE, 0.35))
	_frame.draw_colored_polygon(UIStyle.slanted_rect(Rect2(28, 50, 14, 38), 6), UIStyle.LIME)
	_frame.draw_string(UIStyle.FONT_BOLD_ITALIC, Vector2(56, 82), "Mapa", HORIZONTAL_ALIGNMENT_LEFT, -1, 38, UIStyle.WHITE)
	# Día y franja (la luz del mapa la sigue).
	_frame.draw_string(UIStyle.FONT_MEDIUM, Vector2(176, 80), "%s %d  ·  %s" % [GameState.weekday_long(), int(GameState.date.day), GameState.slot_name()],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(UIStyle.WHITE, 0.6))
	var hint := "[← →] Elegir   /   [Enter] Ir   /   [Rueda, + −] Zoom   /   [M] Cerrar"
	var hw := UIStyle.FONT_REGULAR.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	_frame.draw_string(UIStyle.FONT_REGULAR, Vector2(s.x - 140 - hw, 76), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(UIStyle.WHITE, 0.75))
	# Brújula (el mapa sale siempre con el norte arriba).
	var n := Vector2(s.x - 70, 60)
	_frame.draw_colored_polygon(PackedVector2Array([n + Vector2(0, -22), n + Vector2(12, 10), n + Vector2(0, 2), n + Vector2(-12, 10)]), UIStyle.WHITE)
