class_name ConversationView
extends Control
## Interfaz de conversación: retratos + caja de diálogo + opciones.
##
## El protagonista siempre aparece a la izquierda y el interlocutor a la derecha.
## El fondo NO es parte de esta vista: se ve el de la ubicación actual por detrás.
##
## Uso:  await conversation.play(DialogueDB.for_interaction("kael", "talk"), "kael")

signal finished
signal _line_done
signal _choice_made(index: int)

enum State { IDLE, TYPING, WAITING, CHOOSING }

const CHARS_PER_SECOND := 48.0
const AUTO_DELAY := 1.4
const SPEAKING_DIM := 0.0
const LISTENING_DIM := 0.55

@onready var _left: CharacterSprite = %LeftPortrait
@onready var _right: CharacterSprite = %RightPortrait
@onready var _box: DialogueBox = %Box
@onready var _choices: VBoxContainer = %Choices

var _state := State.IDLE
var _type_tween: Tween
var _auto := false
var _skipping := false
var _line_token := 0
var _npc_id := ""
var _has_protagonist := false
var _pending_choices: Array = []


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_box.skip_pressed.connect(_on_skip)
	_box.auto_toggled.connect(func(on: bool) -> void:
		_auto = on
		if on and _state == State.WAITING:
			_schedule_auto())


func is_active() -> bool:
	return _state != State.IDLE


## Reproduce un guion. `npc_id` vacío = sin interlocutor (p. ej. narración).
## `with_protagonist` muestra a Aiden a la izquierda.
func play(lines: Array, npc_id: String = "", with_protagonist: bool = true) -> void:
	_npc_id = npc_id
	_has_protagonist = with_protagonist
	_skipping = false
	_choices.visible = false
	_setup_portraits()
	await _animate_in()

	var i := 0
	while i < lines.size():
		var line: Dictionary = lines[i]
		_show_line(line)
		if line.has("choices"):
			var picked: int = await _choice_made
			var choice: Dictionary = line.choices[picked]
			var delta: int = choice.get("affinity", 0)
			if delta != 0 and _npc_id != "":
				GameState.add_affinity(_npc_id, delta)
			i = _index_of(lines, choice.get("goto", ""), i + 1)
			continue
		await _line_done
		if line.get("end", false):
			break
		i = _index_of(lines, line.get("goto", ""), i + 1)

	_state = State.IDLE
	await _animate_out()
	finished.emit()


func _index_of(lines: Array, label: String, fallback: int) -> int:
	if label == "":
		return fallback
	for j in lines.size():
		if lines[j].get("id", "") == label:
			return j
	push_warning("ConversationView: etiqueta '%s' no encontrada" % label)
	return fallback


# --- Retratos -------------------------------------------------------------------

func _setup_portraits() -> void:
	_left.texture = CharacterDB.portrait(CharacterDB.PROTAGONIST) if _has_protagonist else null
	_left.visible = _has_protagonist
	_right.texture = CharacterDB.portrait(_npc_id) if _npc_id != "" else null
	_right.visible = _npc_id != ""


func _focus_speaker(who: String) -> void:
	var left_dim := LISTENING_DIM
	var right_dim := LISTENING_DIM
	if who == CharacterDB.PROTAGONIST:
		left_dim = SPEAKING_DIM
	elif who == _npc_id:
		right_dim = SPEAKING_DIM
	var t := create_tween().set_parallel(true)
	t.tween_property(_left, "dim", left_dim, 0.2)
	t.tween_property(_right, "dim", right_dim, 0.2)


func _animate_in() -> void:
	visible = true
	modulate.a = 0.0
	_left.slide = -160.0
	_right.slide = 160.0
	_box.text = ""
	_box.speaker_name = ""
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 1.0, 0.25)
	t.tween_property(_left, "slide", 0.0, 0.45)
	t.tween_property(_right, "slide", 0.0, 0.45).set_delay(0.08)
	await t.finished


func _animate_out() -> void:
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(self, "modulate:a", 0.0, 0.25)
	t.tween_property(_right, "slide", 160.0, 0.25)
	await t.finished
	visible = false


# --- Líneas ----------------------------------------------------------------------

func _show_line(line: Dictionary) -> void:
	_line_token += 1
	var who: String = line.get("who", CharacterDB.NARRATOR)
	_box.speaker_name = CharacterDB.display_name(who) if who != CharacterDB.NARRATOR else ""
	_box.speaker_color = CharacterDB.color(who) if who != CharacterDB.NARRATOR else UIStyle.GRAY
	_box.text = line.get("text", "")
	_box.show_continue = false
	_focus_speaker(who)

	var label := _box.get_text_label()
	label.visible_ratio = 0.0
	_state = State.TYPING
	_pending_choices = line.get("choices", [])
	if _type_tween:
		_type_tween.kill()
	var duration := maxf(label.text.length() / CHARS_PER_SECOND, 0.05)
	_type_tween = create_tween()
	_type_tween.tween_property(label, "visible_ratio", 1.0, duration)
	_type_tween.finished.connect(_finish_typing)
	if _skipping:
		_finish_typing()



func _finish_typing() -> void:
	if _state != State.TYPING:
		return
	if _type_tween:
		_type_tween.kill()
	_box.get_text_label().visible_ratio = 1.0
	if _pending_choices.is_empty():
		_state = State.WAITING
		_box.show_continue = true
		if _skipping:
			_advance_later(0.06)
		elif _auto:
			_schedule_auto()
	else:
		_skipping = false
		_show_choices(_pending_choices)


func _schedule_auto() -> void:
	var text_len := _box.get_text_label().text.length()
	_advance_later(AUTO_DELAY + text_len * 0.015)


func _advance_later(delay: float) -> void:
	var token := _line_token
	await get_tree().create_timer(delay).timeout
	if token == _line_token and _state == State.WAITING:
		_advance()


func _advance() -> void:
	match _state:
		State.TYPING:
			_finish_typing()
		State.WAITING:
			_state = State.IDLE
			_line_done.emit()


func _on_skip() -> void:
	if _state == State.CHOOSING or _state == State.IDLE:
		return
	_skipping = true
	_advance()


# --- Opciones ----------------------------------------------------------------------

func _show_choices(choices: Array) -> void:
	_state = State.CHOOSING
	for child in _choices.get_children():
		child.queue_free()
	var buttons: Array[SlantButton] = []
	for idx in choices.size():
		var b := SlantButton.new()
		b.label = choices[idx].text
		b.index_label = "%02d" % (idx + 1)
		b.font_size = 28
		b.subtle = true
		b.slant = 18
		b.custom_minimum_size = Vector2(0, 58)
		b.pressed.connect(_on_choice_pressed.bind(idx))
		_choices.add_child(b)
		buttons.append(b)
	_choices.visible = true
	_choices.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(_choices, "modulate:a", 1.0, 0.2)
	for k in buttons.size():
		buttons[k].reveal = 0.0
		t.tween_property(buttons[k], "reveal", 1.0, 0.25).set_delay(k * 0.05)
	buttons[0].grab_focus()


func _on_choice_pressed(index: int) -> void:
	if _state != State.CHOOSING:
		return
	_state = State.IDLE
	_choices.visible = false
	_choice_made.emit(index)


# --- Entrada ------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _state == State.IDLE or _state == State.CHOOSING:
		return
	if event.is_action_pressed("ui_accept"):
		_advance()
		get_viewport().set_input_as_handled()
