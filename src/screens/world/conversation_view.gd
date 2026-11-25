class_name ConversationView
extends Control
## Interfaz de conversación: retratos + caja de diálogo + opciones.
##
## El protagonista siempre aparece a la izquierda y el interlocutor a la derecha.
## El fondo NO es parte de esta vista: se ve el de la ubicación actual por detrás.
##
## Los diálogos vienen de Dialogue Manager (src/dialogue/*.dialogue):
##   await conversation.play(Story.pick("kenji", "hablar"), "kenji")
## Las etiquetas de las opciones son los estilos de Ren ([#franco, #bromista]) y,
## con «=», posturas ([#criaturas=acoger]). Cada personaje presente reacciona por
## detrás (Social.on_choice); no se muestra nada.
##
## Si habla alguien que no está en el retrato de la derecha (escenas con varios
## personajes), su retrato pasa a ocupar ese lugar.
##
## Gestos: el retrato de la derecha cambia de cara (CharacterDB `faces`) con un
## fundido breve. Manda, por este orden:
##   1. una etiqueta en la línea: `Rika: ¿Desde cuándo? [#cara=sorpresa]`
##      (`[#cara=normal]` fuerza la cara normal), solo para esa línea;
##   2. su reacción a la última opción de Ren (si le ha sentado mal, enfado; si
##      le ha dado miedo, sorpresa), durante sus REACTION_LINES líneas siguientes;
##   3. su ánimo, si es intenso (MOOD_FACES).
##
## Para encadenar guiones sin cerrar la vista (p. ej. un evento que interrumpe
## la charla), usar `keep_open`; `stop_after` corta el guion de golpe.

signal finished
signal _line_done
signal _typed
signal _choice_made(index: int)

## Marca del nombre de la persona elegida en una opción «por persona».
const PERSON_PLACEHOLDER := "{persona}"

enum State { IDLE, TYPING, WAITING, CHOOSING }

const CHARS_PER_SECOND := 48.0
const AUTO_DELAY := 1.4
const SPEAKING_DIM := 0.0
const LISTENING_DIM := 0.55

## Gestos con retrato propio (ver CharacterDB `faces`). Vacío = cara normal.
const FACES: Array[String] = ["enfado", "sorpresa", "incomodo"]
const FACE_TAG := "cara"
## Si el personaje no tiene ese gesto, prueba con este antes de la cara normal.
const FACE_FALLBACK := {"sorpresa": "incomodo"}
const FACE_MOTION := {
	"enfado": CharacterSprite.Motion.SHAKE,
	"sorpresa": CharacterSprite.Motion.HOP,
}
## Ánimo → gesto, a partir de MOOD_FACE_INTENSITY.
const MOOD_FACES := {"irritado": "enfado", "ansioso": "incomodo", "triste": "incomodo"}
const MOOD_FACE_INTENSITY := 45
## Cuánto tiene que sentarle mal (o asustarle) una opción para que se le note
## (ver Social.displeasure) y durante cuántas de sus líneas.
const REACTION_MIN := 2.0
const REACTION_LINES := 2

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
var _right_id := ""
var _has_protagonist := false
var _pending_choices: Array = []
var _right_face := ""
## Reacciones en curso: id → {face, lines}.
var _reactions := {}
var _open := false


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


## Reproduce un diálogo. `entry` = {resource, cue} (ver Story.pick / Story.cue).
## `npc_id` vacío = sin interlocutor (p. ej. narración).
## `with_protagonist` muestra a Ren a la izquierda.
## `keep_open`: al terminar, la vista sigue en pantalla para el siguiente diálogo.
## `stop_after`: si es > 0, el diálogo se interrumpe solo, sin esperar al jugador,
## en cuanto termina de escribirse la primera línea sin opciones a partir de
## esa cantidad de líneas mostradas.
func play(entry: Dictionary, npc_id: String = "", with_protagonist: bool = true,
		keep_open: bool = false, stop_after: int = -1) -> void:
	_skipping = false
	# Para las frases genéricas de general.dialogue («{{Story.speaker}}: ...»).
	if npc_id != "":
		Story.speaker = CharacterDB.display_name(npc_id)
	_choices.visible = false
	if _open:
		await _swap_portraits(npc_id, with_protagonist)
	else:
		_npc_id = npc_id
		_has_protagonist = with_protagonist
		_setup_portraits()
		await _animate_in()

	var line: DialogueLine = null
	if entry.has("resource"):
		Story.mark_seen(entry.cue)
		line = await DialogueManager.get_next_dialogue_line(entry.resource, entry.cue)
	var shown := 0
	while line != null:
		var choices := _choices_from(line)
		_show_line({"who": _speaker_id(line.character), "text": line.text.replace(PERSON_PLACEHOLDER, Story.persona_name()),
				"choices": choices, "face": line.get_tag_value(FACE_TAG)})
		shown += 1
		if stop_after > 0 and shown >= stop_after and choices.is_empty():
			if _state == State.TYPING:
				await _typed
			_state = State.IDLE
			_box.show_continue = false
			await get_tree().create_timer(0.5).timeout
			break
		var next_id := line.next_id
		if not choices.is_empty():
			var picked: int = await _choice_made
			var choice: Dictionary = choices[picked]
			if choice.has("persona"):
				Story.persona = choice.persona
			# Las reacciones van por detrás: no se muestra nada.
			# Sin interlocutor fijo (escenas de grupo), cuenta quien está en el retrato.
			var target := _npc_id if _npc_id != "" else _right_id
			if target != "":
				_react(Social.on_choice(target, choice))
				if choice.has("lie"):
					Lies.tell(target, choice.lie)
			next_id = choice.next_id
		else:
			await _line_done
		line = await DialogueManager.get_next_dialogue_line(entry.resource, next_id)

	_state = State.IDLE
	if keep_open:
		finished.emit()
		return
	await _animate_out()
	finished.emit()


## Opciones disponibles de una línea: {text, next_id, styles, stance, mentions}.
## `#alude=rika` (o `#alude=rika|kenji`) marca a quién menciona Ren: si está
## presente, se da por aludido (ver Social.on_choice).
## `#persona` repite la opción una vez por cada personaje que cumpla sus filtros
## (ver Social.PERSON_TAG), con {persona} sustituido por su nombre; la copia
## lleva "persona" y menciona a ese personaje.
func _choices_from(line: DialogueLine) -> Array:
	var out := []
	for r: DialogueResponse in line.responses:
		if not r.is_allowed:
			continue
		var styles: Array[String] = []
		var stance := {}
		var mentions: Array[String] = []
		var per_person := Social.PERSON_TAG in r.tags
		var filters: Array[String] = []
		var lie := ""
		for tag: String in r.tags:
			if tag == Social.PERSON_TAG:
				continue
			if per_person and Social.is_person_filter(tag):
				filters.append(tag)
			elif tag.begins_with(Lies.TAG + "="):
				lie = tag.get_slice("=", 1)
			elif tag.begins_with(Social.MENTION_TAG + "="):
				for who in tag.get_slice("=", 1).split("|", false):
					if not who in mentions:
						mentions.append(who)
			elif "=" in tag:
				stance[tag.get_slice("=", 0)] = tag.get_slice("=", 1)
			else:
				styles.append(tag)
		if per_person:
			# Nunca quien acaba de hablar (el que pregunta) ni el interlocutor.
			var exclude := [_speaker_id(line.character), _npc_id]
			for who in Social.person_candidates(filters, exclude):
				var m := mentions.duplicate()
				if not who in m:
					m.append(who)
				out.append({"text": r.text.replace(PERSON_PLACEHOLDER, CharacterDB.display_name(who)),
					"next_id": r.next_id, "styles": styles, "stance": stance, "mentions": m, "persona": who})
			continue
		var choice := {"text": r.text.replace(PERSON_PLACEHOLDER, Story.persona_name()), "next_id": r.next_id,
			"styles": styles, "stance": stance, "mentions": mentions}
		if lie != "":
			choice["lie"] = lie   # [#miente=tema]: ver Lies
		out.append(choice)
	return out


func _speaker_id(character_name: String) -> String:
	if character_name == "":
		return CharacterDB.NARRATOR
	var id := CharacterDB.id_from_name(character_name)
	if id == "":
		push_warning("ConversationView: personaje desconocido '%s'" % character_name)
		return CharacterDB.NARRATOR
	return id


# --- Retratos -------------------------------------------------------------------

func _setup_portraits() -> void:
	_left.texture = CharacterDB.portrait(CharacterDB.PROTAGONIST) if _has_protagonist else null
	_left.visible = _has_protagonist
	_right_id = _npc_id
	_right_face = _face_for(_npc_id)
	CharacterDB.preload_faces(_npc_id)
	_right.texture = CharacterDB.portrait(_npc_id, _right_face) if _npc_id != "" else null
	_right.visible = _npc_id != ""


## Gesto que toca para `who` ahora: el de la línea, su reacción o su ánimo.
func _face_for(who: String, line_face: String = "") -> String:
	if who == "" or line_face == "normal":
		return ""
	var face := line_face
	if face == "" and _reactions.has(who):
		face = _reactions[who].face
	if face == "":
		var m := Social.mood(who)
		if m.intensity >= MOOD_FACE_INTENSITY:
			face = MOOD_FACES.get(m.id, "")
	if face != "" and not CharacterDB.has_face(who, face):
		face = FACE_FALLBACK.get(face, "")
		if not CharacterDB.has_face(who, face):
			face = ""
	return face


## Pone al de la derecha la cara que le toca; si cambia, con transición.
func _refresh_face(line_face: String = "") -> void:
	if _right_id == "":
		return
	var face := _face_for(_right_id, line_face)
	if face == _right_face:
		return
	_right_face = face
	_right.change_texture(CharacterDB.portrait(_right_id, face), FACE_MOTION.get(face, CharacterSprite.Motion.NONE))


## Tras una opción de Ren: a quien le ha sentado mal o le ha asustado se le nota.
func _react(reactions: Dictionary) -> void:
	for who: String in reactions:
		var deltas: Dictionary = reactions[who]
		var face := ""
		if deltas.get("miedo", 0.0) >= REACTION_MIN:
			face = "sorpresa"
		elif Social.displeasure(deltas) >= REACTION_MIN:
			face = "enfado"
		if face != "":
			_reactions[who] = {"face": face, "lines": REACTION_LINES}
	_refresh_face()


func _focus_speaker(who: String) -> void:
	var left_dim := LISTENING_DIM
	var right_dim := LISTENING_DIM
	if who == CharacterDB.PROTAGONIST:
		left_dim = SPEAKING_DIM
	elif who == _right_id:
		right_dim = SPEAKING_DIM
	var t := create_tween().set_parallel(true)
	t.tween_property(_left, "dim", left_dim, 0.2)
	t.tween_property(_right, "dim", right_dim, 0.2)


## Cambia de interlocutor con la vista ya abierta: el anterior sale por la
## derecha y entra el nuevo.
func _swap_portraits(npc_id: String, with_protagonist: bool) -> void:
	if npc_id != _right_id:
		var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		t.tween_property(_right, "slide", 220.0, 0.2)
		await t.finished
	var changed := npc_id != _right_id
	_npc_id = npc_id
	_has_protagonist = with_protagonist
	_setup_portraits()
	if changed:
		var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(_right, "slide", 0.0, 0.35)
		await t.finished


func _animate_in() -> void:
	_open = true
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
	_open = false
	_reactions.clear()


# --- Líneas ----------------------------------------------------------------------

func _show_line(line: Dictionary) -> void:
	_line_token += 1
	var who: String = line.get("who", CharacterDB.NARRATOR)
	_box.speaker_name = CharacterDB.display_name(who) if who != CharacterDB.NARRATOR else ""
	_box.speaker_color = CharacterDB.color(who) if who != CharacterDB.NARRATOR else UIStyle.GRAY
	_box.text = line.get("text", "")
	_box.show_continue = false
	if who != CharacterDB.NARRATOR and who != CharacterDB.PROTAGONIST and who != _right_id \
			and CharacterDB.portrait(who) != null:
		# Interviene otro personaje de la escena: ocupa el retrato de la derecha.
		_right_id = who
		# Entra con su cara de fondo; el gesto de la línea, con su transición.
		_right_face = _face_for(who)
		CharacterDB.preload_faces(who)
		_right.texture = CharacterDB.portrait(who, _right_face)
		_right.visible = true
	# La etiqueta [#cara=…] es de quien habla; el que escucha sigue con la suya.
	_refresh_face(line.get("face", "") if who == _right_id else "")
	if _reactions.has(who):
		_reactions[who].lines -= 1
		if _reactions[who].lines <= 0:
			_reactions.erase(who)
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
	# Al final: quien espere esta señal puede cambiar el estado sin que se pise.
	_typed.emit()


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
