class_name ConfirmPopup
extends Control
## Ventana de confirmación con el estilo del juego: oscurece la pantalla y
## muestra un título, un texto y dos botones (aceptar y cancelar).
##
##   var ok: bool = await ConfirmPopup.ask(self, "¿Salir?", "Texto…", "Salir", "Seguir")
##
## Esc o clic fuera = cancelar. Se borra sola al responder.

signal answered(accepted: bool)

const PANEL_SIZE := Vector2(820, 380)

var title := ""
var text := ""
var accent := UIStyle.RED
var _panel := Rect2()
var _accept: SlantButton
var _cancel: SlantButton


## Abre la ventana encima de `parent` y espera la respuesta.
static func ask(parent: Control, title_text: String, body: String, accept_text: String, cancel_text: String,
		accent_color: Color = UIStyle.RED) -> bool:
	var p := ConfirmPopup.new()
	p.title = title_text
	p.text = body
	p.accent = accent_color
	parent.add_child(p)
	p._build(accept_text, cancel_text)
	return await p.answered


func _build(accept_text: String, cancel_text: String) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var vs := get_viewport_rect().size if size == Vector2.ZERO else size
	_panel = Rect2((vs - PANEL_SIZE) * 0.5, PANEL_SIZE)
	_cancel = _button(cancel_text, false)
	_accept = _button(accept_text, true)
	var w := 340.0
	var y := _panel.end.y - 104
	_accept.position = Vector2(_panel.position.x + 60, y)
	_cancel.position = Vector2(_panel.end.x - 60 - w, y)
	for b in [_accept, _cancel]:
		b.size = Vector2(w, 64)
		b.custom_minimum_size = b.size
	# Por defecto, lo prudente: seguir.
	_cancel.grab_focus.call_deferred()
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


func _answer(accept: bool) -> void:
	if is_queued_for_deletion():
		return
	answered.emit(accept)
	queue_free()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not _panel.has_point(event.position):
		_answer(false)
	accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_answer(false)
		get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(UIStyle.INK, 0.72))
	var shape := UIStyle.chamfer_rect(_panel, [0.0, 28.0, 0.0, 28.0])
	draw_colored_polygon(shape, Color(UIStyle.INK, 0.97))
	UIStyle.draw_outline(self, shape, UIStyle.LINE, 1.5)
	var p := _panel.position
	draw_colored_polygon(UIStyle.slanted_rect(Rect2(p + Vector2(48, 44), Vector2(10, 40)), 8), accent)
	draw_string(UIStyle.FONT_HEAVY_ITALIC, p + Vector2(76, 78), title, HORIZONTAL_ALIGNMENT_LEFT, _panel.size.x - 120, 38, UIStyle.WHITE)
	for i in 3:
		var sx := _panel.end.x - 110 + i * 16
		draw_line(Vector2(sx, p.y + 70), Vector2(sx + 14, p.y + 46), Color(accent, 0.9), 3.0, true)
	draw_multiline_string(UIStyle.FONT_REGULAR, p + Vector2(52, 140), text, HORIZONTAL_ALIGNMENT_LEFT,
			_panel.size.x - 104, 25, -1, Color(UIStyle.WHITE, 0.9))
