class_name TeamPicker
extends Control
## Elegir equipo antes de entrar en la grieta (fase 6), con el estilo de
## ConfirmPopup: Ren va siempre (no se puede quitar) y se le suman hasta `limit`
## de `candidates`, que se marcan y desmarcan.
##
##   var team: Variant = await TeamPicker.ask(self, ChapterDB.EXPEDITION, 3)
##   # Array con los elegidos (sin Ren), o null si se cancela.
##
## Sin `can_cancel` (el día límite) no hay «Ahora no» ni se cierra con Esc.

signal answered(team: Variant)

const PANEL_SIZE := Vector2(1040, 560)
const ROW_H := 72.0

var title := "Elegir equipo"
var candidates: Array = []
var limit := 3
var can_cancel := true
var _picked: Array = []
var _toggles: Array[PillButton] = []
var _panel := Rect2()
var _accept: SlantButton


static func ask(parent: Control, who: Array, max_people: int, cancellable: bool = true) -> Variant:
	var p := TeamPicker.new()
	p.candidates = who
	p.limit = max_people
	p.can_cancel = cancellable
	parent.add_child(p)
	p._build()
	return await p.answered


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var vs := get_viewport_rect().size if size == Vector2.ZERO else size
	_panel = Rect2((vs - PANEL_SIZE) * 0.5, PANEL_SIZE)
	var x := _panel.position.x + 60
	var y := _panel.position.y + 230
	for i in candidates.size():
		var id: String = candidates[i]
		var t := PillButton.new()
		t.label = "%s  ·  Nv %d" % [CharacterDB.display_name(id), GameState.level_of(id)]
		t.icon_name = ""
		t.toggle_mode = true
		t.selectable = true
		t.font_size = 26
		t.position = Vector2(x + (i % 2) * 470, y + (i / 2) * ROW_H)
		t.toggled.connect(_on_toggled.bind(id))
		add_child(t)
		_toggles.append(t)
	var w := 340.0
	_accept = _button("Entrar", true)
	_accept.position = Vector2(_panel.position.x + 60, _panel.end.y - 104)
	_accept.size = Vector2(w, 64)
	_accept.custom_minimum_size = _accept.size
	if can_cancel:
		var cancel := _button("Ahora no", false)
		cancel.position = Vector2(_panel.end.x - 60 - w, _panel.end.y - 104)
		cancel.size = Vector2(w, 64)
		cancel.custom_minimum_size = cancel.size
	if not _toggles.is_empty():
		_toggles[0].grab_focus.call_deferred()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)


func _button(label_text: String, accept: bool) -> SlantButton:
	var b := SlantButton.new()
	b.label = label_text
	b.icon_name = "run" if accept else ""
	b.font_size = 26
	b.slant = 20
	b.pressed.connect(_answer.bind(accept))
	add_child(b)
	return b


## Al llegar al límite, los que no están marcados se bloquean.
func _on_toggled(on: bool, id: String) -> void:
	if on and not id in _picked:
		_picked.append(id)
	elif not on:
		_picked.erase(id)
	for i in _toggles.size():
		_toggles[i].disabled = _picked.size() >= limit and not candidates[i] in _picked
	queue_redraw()


func _answer(accept: bool) -> void:
	if is_queued_for_deletion():
		return
	answered.emit(_picked.duplicate() if accept else null)
	queue_free()


func _gui_input(event: InputEvent) -> void:
	if can_cancel and event is InputEventMouseButton and event.pressed and not _panel.has_point(event.position):
		_answer(false)
	accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if can_cancel and event.is_action_pressed("ui_cancel"):
		_answer(false)
		get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(UIStyle.INK, 0.72))
	var shape := UIStyle.chamfer_rect(_panel, [0.0, 28.0, 0.0, 28.0])
	draw_colored_polygon(shape, Color(UIStyle.INK, 0.97))
	UIStyle.draw_outline(self, shape, UIStyle.LINE, 1.5)
	var p := _panel.position
	draw_colored_polygon(UIStyle.slanted_rect(Rect2(p + Vector2(48, 44), Vector2(10, 40)), 8), UIStyle.LIME)
	draw_string(UIStyle.FONT_HEAVY_ITALIC, p + Vector2(76, 78), title, HORIZONTAL_ALIGNMENT_LEFT, _panel.size.x - 120, 38, UIStyle.WHITE)
	for i in 3:
		var sx := _panel.end.x - 110 + i * 16
		draw_line(Vector2(sx, p.y + 70), Vector2(sx + 14, p.y + 46), Color(UIStyle.LIME, 0.9), 3.0, true)
	var line := "Ren y hasta %d más. Elegidos: %d/%d." % [limit, _picked.size(), limit]
	draw_string(UIStyle.FONT_REGULAR, p + Vector2(52, 140), line, HORIZONTAL_ALIGNMENT_LEFT, _panel.size.x - 104, 25, Color(UIStyle.WHITE, 0.9))
	draw_string(UIStyle.FONT_SEMIBOLD, p + Vector2(60, 186), "%s  ·  Nv %d  ·  siempre va" % [CharacterDB.display_name(CharacterDB.PROTAGONIST),
			GameState.level_of(CharacterDB.PROTAGONIST)], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UIStyle.LIME)
