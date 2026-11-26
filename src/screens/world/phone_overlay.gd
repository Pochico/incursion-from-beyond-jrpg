class_name PhoneOverlay
extends Control
## Móvil de Ren («Terminal»), superpuesto al escenario (ver docs/ui/referencias/06_movil*.webp).
##
## Oscurece lo que haya detrás, como la pantalla de estado. Solo se abre fuera de combate.
## Pantallas:
##  - Inicio: rejilla de apps sobre el fondo de pantalla.
##  - Contactos: la agenda (CharacterDB.CONTACTS); al elegir uno se abre el chat.
##  - Relaciones: cómo está la relación de cada personaje con Ren (tramo, ánimo y
##    afecto / confianza / respeto, más lo que destaque de atracción, miedo...).
##  - Mensajes: conversaciones que ya existen (de la más reciente a la más antigua).
##  - Chat: burbujas de la conversación y botón «Saludar». La respuesta sale del
##    selector de Story (momento «movil» en el .dialogue de cada personaje).
##    Si el contacto espera respuesta (una invitación o un reproche por un plantón,
##    ver Invites), en vez de «Saludar» salen las respuestas posibles. Si no,
##    «Saludar» y «Proponer plan» (actividad y cuándo; ver Invites.ren_invite).
##  - Inventario: objetos de GameState.inventory. Tocar una caja la abre (`notice`
##    cuenta lo que traía).
##  - Equipo: arma, accesorio y módulo de Ren y sus compañeros.
## En versiones de depuración, tocar a alguien en Relaciones abre `DebugRelations`
## (barras para editar en directo sus relaciones y su ánimo).
## Misiones, Ajustes y Criaturas aún no tienen contenido (`app_unavailable`).
##
## Ratón: clic en apps, filas, «<» y botones; rueda para desplazar; clic fuera cierra.
## Teclado: flechas, Enter; Esc vuelve atrás (o cierra en el inicio); T cierra.

signal closed
signal app_unavailable(id: String)
## Aviso breve para mostrar fuera del móvil (p. ej. lo que traía una caja).
signal notice(text: String)

const BODY := Rect2(726, 40, 468, 1000)
const SCREEN_INSET := 12.0
const APPS := [
	{"id": "messages", "label": "Mensajes", "icon": "speech"},
	{"id": "contacts", "label": "Contactos", "icon": "people"},
	{"id": "relations", "label": "Relaciones", "icon": "heart"},
	{"id": "quests", "label": "Misiones", "icon": "bookmark"},
	{"id": "gear", "label": "Equipo", "icon": "bag"},
	{"id": "inventory", "label": "Inventario", "icon": "boxes"},
	{"id": "settings", "label": "Ajustes", "icon": "gear"},
	{"id": "creatures", "label": "Criaturas", "icon": "orbit"},
]
const TITLES := {"messages": "Mensajes", "contacts": "Contactos", "relations": "Relaciones",
	"inventory": "Inventario", "gear": "Equipo"}
## Apps con contenido; el resto avisa de que aún no están disponibles.
const READY_APPS := ["messages", "contacts", "relations", "inventory", "gear"]
const TIER_NAMES := {"hostil": "Hostil", "fria": "Fría", "neutral": "Neutral", "cercana": "Cercana", "intima": "Íntima"}
const TIER_COLORS := {"hostil": Color("ff3b47"), "fria": Color("27b4f5"), "neutral": Color("f2f2f4"),
	"cercana": Color("c6f432"), "intima": Color("ff7ad9")}
const MOOD_NAMES := {"alegre": "Alegre", "tranquilo": "Tranquilo", "curioso": "Curioso",
	"irritado": "Irritado", "ansioso": "Ansioso", "triste": "Triste"}
## Dimensiones que solo se muestran si destacan (de 0 a 100).
const EXTRA_DIMS := {"atraccion": "Atracción", "miedo": "Miedo", "asco": "Asco", "resentimiento": "Resentimiento"}
const GRID_X := 22.0       ## relativo al cuerpo del móvil
const GRID_Y := 272.0
const CELL := Vector2(206, 76)
const GAP := Vector2(16, 26)
const LIST_X := 22.0
const LIST_Y := 250.0
const LIST_W := 424.0
const LIST_BOTTOM := 950.0
const BACK := Rect2(30, 118, 54, 44)
const CHAT_AREA := Rect2(SCREEN_INSET + 6, 240, 468 - SCREEN_INSET * 2 - 12, 620)
const SEND := Rect2(34, 890, 400, 58)
const REPLY_STEP := 64.0   ## alto de cada botón de respuesta más la separación
const BUBBLE_W := 290.0
const BUBBLE_FONT := 19
const SKY := Color("1d1530")
const ROW_FILL := Color("101014")
const WALLPAPER := preload("res://assets/phone/fondo.png")

## Clima que se muestra en la cabecera. Sin sistema de clima por ahora.
var weather := "despejado"

var _screen := "home"
var _selected := 0
var _scroll := 0             ## primera fila visible de la lista
var _hover := ""             ## zona bajo el ratón ("app3", "row1", "back", "send")
var _chat_with := ""
var _chat_back := "contacts" ## pantalla a la que vuelve el chat
var _chat_scroll := 0.0      ## px desplazados hacia arriba desde el final del chat
var _busy := false           ## el contacto está respondiendo
var _typing := false
var _reply_sel := 0          ## respuesta seleccionada con el teclado
var _propose := ""           ## «Proponer plan»: "" | "actividad" | id de la actividad elegida
var _phone: Control
var _chat: Control           ## área recortada de las burbujas
var _debug: DebugRelations


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_phone = Control.new()
	_phone.position = BODY.position
	_phone.size = BODY.size
	_phone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phone.draw.connect(_draw_phone)
	add_child(_phone)
	_chat = Control.new()
	_chat.position = CHAT_AREA.position
	_chat.size = CHAT_AREA.size
	_chat.clip_contents = true
	_chat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chat.draw.connect(_draw_chat)
	_phone.add_child(_chat)
	# El reloj se refresca cada pocos segundos mientras está abierto.
	var timer := Timer.new()
	timer.wait_time = 5.0
	timer.autostart = true
	timer.timeout.connect(_redraw)
	add_child(timer)
	_debug = DebugRelations.new()
	_debug.closed.connect(_redraw)
	add_child(_debug)


func open() -> void:
	_go("home")
	_hover = ""
	size = get_parent_area_size()
	queue_redraw()
	visible = true
	modulate.a = 0.0
	_phone.position = BODY.position + Vector2(0, 60)
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 1.0, 0.2)
	t.tween_property(_phone, "position", BODY.position, 0.28)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


# --- Navegación -------------------------------------------------------------------------

func _go(screen: String, selected := 0) -> void:
	_screen = screen
	_selected = selected
	_scroll = 0
	_chat_scroll = 0.0
	_chat.visible = screen == "chat"
	_redraw()


func _back() -> void:
	match _screen:
		"home":
			close()
		"chat":
			_go(_chat_back)
			_selected = maxi(_rows().find(_chat_with), 0)
			_keep_visible()
			_redraw()
		_:
			_go("home", APPS.map(func(a: Dictionary) -> String: return a.id).find(_screen))


func _open_app(i: int) -> void:
	_selected = i
	var id: String = APPS[i].id
	if id in READY_APPS:
		_go(id)
	else:
		_redraw()
		app_unavailable.emit(id)


func _open_chat(who: String, from_screen: String) -> void:
	_propose = ""
	_reply_sel = 0
	_chat_with = who
	_chat_back = from_screen
	_go("chat")


## Filas de la pantalla actual (ids de contacto u objeto).
func _rows() -> Array:
	match _screen:
		"contacts":
			return Acquaintance.friends(CharacterDB.CONTACTS)
		"relations":
			return Acquaintance.friends(CharacterDB.RELATIONS)
		"messages":
			return Acquaintance.friends(GameState.conversations())
		"inventory":
			return GameState.inventory.keys().filter(func(id: String) -> bool: return GameState.item_count(id) > 0)
		"gear":
			return [CharacterDB.PROTAGONIST] + Acquaintance.friends(CharacterDB.COMPANIONS)
	return []


func _activate_row(i: int) -> void:
	_selected = i
	var rows := _rows()
	if i >= rows.size():
		return
	if _screen == "contacts" or _screen == "messages":
		_open_chat(rows[i], _screen)
	elif _screen == "inventory" and ItemDB.is_box(rows[i]):
		var got := GameState.open_box(rows[i])
		if got != "":
			GameState.save_game()
			notice.emit("%s: %s" % [ItemDB.display_name(rows[i]), got])
			_selected = mini(i, _rows().size() - 1)
			_keep_visible()
			_redraw()
	elif _screen == "relations" and DebugRelations.enabled():
		_debug.open(rows[i], BODY.position + Vector2(18, 50))
	else:
		_redraw()


func _redraw() -> void:
	# El chat se encoge para dejar sitio a los botones de respuesta.
	_chat.size.y = CHAT_AREA.size.y - maxi(_replies().size() - 1, 0) * REPLY_STEP
	_phone.queue_redraw()
	_chat.queue_redraw()


# --- Chat -------------------------------------------------------------------------------

## Ren saluda y el contacto responde (las líneas salen de su .dialogue, momento «movil»).
func _greet() -> void:
	if _busy or _chat_with == "":
		return
	var who := _chat_with
	# Se registra antes de elegir para que el criterio «veces» cuente este mensaje.
	GameState.record("message", CharacterDB.PROTAGONIST, who)
	await _play_chat(who, Story.pick(who, "movil"))


## Botones del chat: lo que espera el contacto (invitación o reproche) o, si no
## espera nada, «Saludar» / «Proponer plan» y sus pasos.
func _replies() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _screen != "chat" or _busy or _chat_with == "":
		return out
	out = Invites.replies(_chat_with)
	if not out.is_empty():
		return out
	match _propose:
		"":
			out.append({"label": "Saludar", "reply": "saludar"})
			out.append({"label": "Proponer plan", "reply": "proponer"})
		"actividad":
			for act: String in ChapterDB.REN_ACTIVITIES:
				if not Invites.proposal_slots(act).is_empty():
					out.append({"label": ChapterDB.REN_ACTIVITIES[act].title, "reply": "actividad", "activity": act})
			out.append({"label": "Cancelar", "reply": "cancelar"})
		_:
			for s: Dictionary in Invites.proposal_slots(_propose):
				out.append({"label": s.label, "reply": "cuando", "day": s.day, "slot": s.slot})
			out.append({"label": "Cancelar", "reply": "cancelar"})
	return out


func _reply_rect(i: int, n: int) -> Rect2:
	return Rect2(SEND.position.x, SEND.position.y + SEND.size.y - 54 - (n - 1 - i) * REPLY_STEP, SEND.size.x, 54)


## Ren contesta a una invitación o a un reproche; lo que se dicen sale del .dialogue
## (`<contacto>_movil_plan` / `_movil_plantado`, ver Invites.choose_reply).
func _reply(i: int) -> void:
	var replies := _replies()
	if i < 0 or i >= replies.size():
		return
	var who := _chat_with
	var option: Dictionary = replies[i]
	_reply_sel = 0
	match option.reply:
		"saludar":
			await _greet()
			return
		"proponer":
			_propose = "actividad"
			_redraw()
			return
		"actividad":
			_propose = option.activity
			_redraw()
			return
		"cancelar":
			_propose = ""
			_redraw()
			return
		"cuando":
			var activity := _propose
			_propose = ""
			GameState.record("message", CharacterDB.PROTAGONIST, who)
			await _play_chat(who, Invites.ren_invite(who, activity, option.day, option.slot))
			return
	GameState.record("message", CharacterDB.PROTAGONIST, who)
	await _play_chat(who, Invites.choose_reply(who, option))


## Reproduce una conversación de móvil como burbujas («escribiendo...» incluido).
func _play_chat(who: String, entry: Dictionary) -> void:
	if entry.is_empty():
		_redraw()
		return
	Story.speaker = CharacterDB.display_name(who)
	_busy = true
	_redraw()
	var line: DialogueLine = await DialogueManager.get_next_dialogue_line(entry.resource, entry.cue)
	var first := true
	while line != null:
		var from := CharacterDB.id_from_name(line.character)
		if from == "":
			from = who
		if from == CharacterDB.PROTAGONIST:
			if not first:
				await get_tree().create_timer(0.4).timeout
		else:
			# «Escribiendo...» un rato proporcional a lo largo del mensaje.
			_typing = true
			_chat_scroll = 0.0
			_redraw()
			await get_tree().create_timer(clampf(0.5 + line.text.length() * 0.02, 0.7, 1.8)).timeout
			_typing = false
		GameState.add_message(who, from, line.text)
		_chat_scroll = 0.0
		_redraw()
		first = false
		line = await DialogueManager.get_next_dialogue_line(entry.resource, line.next_id)
	_busy = false
	_redraw()
	GameState.save_game()


# --- Entrada ----------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not visible or _debug.visible:
		return
	if not (event is InputEventKey or event is InputEventJoypadButton):
		return
	if event.is_action_pressed("open_phone"):
		close()
	elif event.is_action_pressed("ui_cancel"):
		_back()
	elif _screen == "home":
		_input_home(event)
	elif _screen == "chat" and not _replies().is_empty():
		var n := _replies().size()
		if event.is_action_pressed("ui_accept"):
			_reply(_reply_sel)
		elif event.is_action_pressed("ui_up"):
			_reply_sel = posmod(_reply_sel - 1, n)
		elif event.is_action_pressed("ui_down"):
			_reply_sel = posmod(_reply_sel + 1, n)
	elif _screen == "chat":
		if event.is_action_pressed("ui_accept"):
			_greet()
		elif event.is_action_pressed("ui_up"):
			_scroll_chat(60)
		elif event.is_action_pressed("ui_down"):
			_scroll_chat(-60)
	else:
		var n := _rows().size()
		if event.is_action_pressed("ui_accept"):
			_activate_row(_selected)
		elif event.is_action_pressed("ui_up") and n > 0:
			_selected = posmod(_selected - 1, n)
			_keep_visible()
		elif event.is_action_pressed("ui_down") and n > 0:
			_selected = posmod(_selected + 1, n)
			_keep_visible()
	_redraw()
	get_viewport().set_input_as_handled()


func _input_home(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_open_app(_selected)
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		# La última app ocupa toda la fila.
		if _selected < APPS.size() - 1:
			_selected = _selected ^ 1
	elif event.is_action_pressed("ui_up"):
		if _selected >= 2:
			_selected -= 2
	elif event.is_action_pressed("ui_down"):
		_selected = mini(_selected + 2, APPS.size() - 1)


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouse:
		return
	var p: Vector2 = event.position - _phone.position
	if event is InputEventMouseMotion:
		var zone := _zone_at(p)
		if zone != _hover:
			_hover = zone
			if zone.begins_with("app") or zone.begins_with("row"):
				_selected = int(zone.substr(3))
			elif zone.begins_with("reply"):
				_reply_sel = int(zone.substr(5))
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if zone != "" else Control.CURSOR_ARROW
			_redraw()
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_wheel(-1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_wheel(1)
			MOUSE_BUTTON_LEFT:
				var zone := _zone_at(p)
				if zone == "back":
					_back()
				elif zone == "send":
					_greet()
				elif zone.begins_with("reply"):
					_reply(int(zone.substr(5)))
				elif zone.begins_with("app"):
					_open_app(int(zone.substr(3)))
				elif zone.begins_with("row"):
					_activate_row(int(zone.substr(3)))
				elif not Rect2(Vector2.ZERO, BODY.size).has_point(p):
					close()   # Clic fuera del móvil.
		accept_event()


func _wheel(dir: int) -> void:
	if _screen == "chat":
		_scroll_chat(-48.0 * dir)
	elif _screen != "home":
		_scroll = clampi(_scroll + dir, 0, maxi(_rows().size() - _visible_rows(), 0))
		_redraw()


func _scroll_chat(amount: float) -> void:
	_chat_scroll = clampf(_chat_scroll + amount, 0.0, maxf(_chat_height() - _chat.size.y, 0.0))
	_redraw()


func _zone_at(p: Vector2) -> String:
	if _screen != "home" and BACK.has_point(p):
		return "back"
	match _screen:
		"home":
			for i in APPS.size():
				if _app_rect(i).has_point(p):
					return "app%d" % i
		"chat":
			var replies := _replies()
			for i in replies.size():
				if _reply_rect(i, replies.size()).has_point(p):
					return "reply%d" % i
			if replies.is_empty() and SEND.has_point(p) and not _busy:
				return "send"
		_:
			for i in _rows().size():
				var r := _row_rect(i)
				if r.size.y > 0 and r.has_point(p):
					return "row%d" % i
	return ""


func _app_rect(i: int) -> Rect2:
	if i == APPS.size() - 1 and APPS.size() % 2 == 1:
		# Última app impar: fila completa.
		var row := i / 2
		return Rect2(Vector2(GRID_X, GRID_Y + row * (CELL.y + GAP.y)), Vector2(CELL.x * 2 + GAP.x, CELL.y))
	return Rect2(Vector2(GRID_X + (i % 2) * (CELL.x + GAP.x), GRID_Y + (i / 2) * (CELL.y + GAP.y)), CELL)


func _row_height() -> float:
	return 124.0 if _screen == "gear" or _screen == "relations" else 96.0


func _visible_rows() -> int:
	return int((LIST_BOTTOM - LIST_Y) / (_row_height() + 12.0))


## Rectángulo de la fila `i` (tamaño cero si queda fuera por el desplazamiento).
func _row_rect(i: int) -> Rect2:
	var k := i - _scroll
	if k < 0 or k >= _visible_rows():
		return Rect2()
	return Rect2(LIST_X, LIST_Y + k * (_row_height() + 12.0), LIST_W, _row_height())


func _keep_visible() -> void:
	var n := _visible_rows()
	if _selected < _scroll:
		_scroll = _selected
	elif _selected >= _scroll + n:
		_scroll = _selected - n + 1


# --- Dibujo: marco ----------------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.72))


func _screen_rect() -> Rect2:
	return Rect2(Vector2(SCREEN_INSET, SCREEN_INSET), BODY.size - Vector2(SCREEN_INSET, SCREEN_INSET) * 2)


func _draw_phone() -> void:
	var c := _phone
	var w := BODY.size.x
	var h := BODY.size.y
	# Carcasa: octógono con esquinas cortadas y doble contorno.
	var body := UIStyle.chamfer_rect(Rect2(Vector2.ZERO, BODY.size), [36.0, 36.0, 36.0, 36.0])
	c.draw_colored_polygon(body, Color("0e0d12"))
	UIStyle.draw_outline(c, body, UIStyle.WHITE, 3.0)
	var screen := UIStyle.chamfer_rect(_screen_rect(), [28.0, 28.0, 28.0, 28.0])
	c.draw_colored_polygon(screen, Color("141318"))
	if _screen == "home":
		_draw_wallpaper(c, screen)
	elif _screen != "chat":
		_draw_city(c, Rect2(SCREEN_INSET + 2, 700, w - SCREEN_INSET * 2 - 4, h - 700 - SCREEN_INSET - 30))
	UIStyle.draw_outline(c, screen, Color(UIStyle.WHITE, 0.35), 1.5)
	# Acento violeta en la esquina superior izquierda.
	c.draw_line(Vector2(8, 46), Vector2(46, 8), UIStyle.VIOLET, 5.0)
	# Altavoz.
	c.draw_line(Vector2(w * 0.5 - 30, 30), Vector2(w * 0.5 + 30, 30), Color(UIStyle.WHITE, 0.9), 3.0)

	_draw_status_bar(c, w)
	match _screen:
		"home":
			_draw_header(c, w, "Terminal", false)
			for i in APPS.size():
				_draw_app(c, i)
		"chat":
			_draw_header(c, w, CharacterDB.display_name(_chat_with), true)
			if _replies().is_empty():
				_draw_send(c)   # mientras el contacto escribe
			else:
				_draw_replies(c)
		_:
			_draw_header(c, w, TITLES[_screen], true)
			_draw_list(c)
			if _screen == "relations" and DebugRelations.enabled():
				c.draw_string(UIStyle.FONT_MEDIUM_ITALIC, Vector2(LIST_X, LIST_Y - 12), "Depuración: toca a alguien para editarlo",
						HORIZONTAL_ALIGNMENT_LEFT, LIST_W, 14, Color(UIStyle.LIME, 0.75))
	# Indicador de inicio.
	c.draw_line(Vector2(w * 0.5 - 26, h - 34), Vector2(w * 0.5 + 26, h - 34), UIStyle.LIME, 5.0)


## Fondo de pantalla del inicio, recortado a la pantalla y con un velo oscuro para que
## se lean los textos y botones.
func _draw_wallpaper(c: Control, screen: PackedVector2Array) -> void:
	var sr := _screen_rect()
	var ts := WALLPAPER.get_size()
	var k := maxf(sr.size.x / ts.x, sr.size.y / ts.y)
	var shown := ts * k
	var offset := (shown - sr.size) * Vector2(0.35, 0.5)   # algo a la izquierda: ahí está la figura
	var uvs := PackedVector2Array()
	var veil := PackedColorArray()
	for p in screen:
		uvs.append((p - sr.position + offset) / shown)
		# Velo: más oscuro arriba, en la cabecera.
		var t := (p.y - sr.position.y) / sr.size.y
		veil.append(Color(0.04, 0.03, 0.07, lerpf(0.82, 0.6, smoothstep(0.0, 0.3, t))))
	c.draw_polygon(screen, PackedColorArray([Color.WHITE]), uvs, WALLPAPER)
	c.draw_polygon(screen, veil)


func _draw_status_bar(c: Control, w: float) -> void:
	var t := Time.get_time_dict_from_system()
	c.draw_string(UIStyle.FONT_MEDIUM, Vector2(44, 78), "%02d:%02d" % [t.hour, t.minute], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UIStyle.WHITE)
	# Cobertura.
	for i in 4:
		var bh := 6.0 + i * 4.0
		c.draw_rect(Rect2(w - 166 + i * 7, 78 - bh, 4, bh), UIStyle.WHITE)
	# Batería.
	var b := Rect2(w - 124, 62, 36, 18)
	c.draw_rect(b, UIStyle.LIME, false, 2.0)
	c.draw_rect(b.grow(-4), UIStyle.LIME)
	c.draw_rect(Rect2(b.end.x, b.position.y + 5, 3, 8), UIStyle.LIME)
	c.draw_string(UIStyle.FONT_MEDIUM, Vector2(w - 80, 78), "92 %", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIStyle.WHITE)


func _draw_header(c: Control, w: float, title: String, back: bool) -> void:
	# Bandas diagonales violetas y emblema a la derecha.
	c.draw_colored_polygon(PackedVector2Array([Vector2(w - 150, 214), Vector2(w - 60, 100),
			Vector2(w - 40, 100), Vector2(w - 130, 214)]), Color(UIStyle.VIOLET, 0.45))
	c.draw_colored_polygon(PackedVector2Array([Vector2(w - 116, 214), Vector2(w - 26, 100),
			Vector2(w - 16, 100), Vector2(w - 16, 112), Vector2(w - 98, 214)]), Color(UIStyle.VIOLET, 0.25))
	_emblem(c, Vector2(w - 62, 156), Color("b9a4e8"))
	var x := 38.0
	if back:
		var shape := UIStyle.chamfer_rect(BACK, [10.0, 10.0, 10.0, 10.0])
		c.draw_colored_polygon(shape, Color(UIStyle.INK, 0.9))
		UIStyle.draw_outline(c, shape, UIStyle.LIME if _hover == "back" else UIStyle.WHITE, 2.0)
		var bc := BACK.get_center()
		c.draw_polyline(PackedVector2Array([bc + Vector2(5, -10), bc + Vector2(-5, 0), bc + Vector2(5, 10)]), UIStyle.WHITE, 3.0, true)
		x = BACK.end.x + 18
	# Título (se encoge si no cabe).
	var font_size := 44
	while font_size > 26 and UIStyle.FONT_HEAVY_ITALIC.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > w - x - 150:
		font_size -= 2
	c.draw_colored_polygon(UIStyle.slanted_rect(Rect2(x, 122, 12, 38), 7), UIStyle.LIME)
	c.draw_string(UIStyle.FONT_HEAVY_ITALIC, Vector2(x + 24, 156), title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UIStyle.WHITE)
	# Píldora del clima.
	var pill := Rect2(x, 174, 208, 36)
	var shape := UIStyle.chamfer_rect(pill, [10.0, 10.0, 10.0, 10.0])
	c.draw_colored_polygon(shape, Color(UIStyle.INK, 0.9))
	UIStyle.draw_outline(c, shape, Color(UIStyle.WHITE, 0.8), 1.5)
	_sun(c, pill.position + Vector2(24, 18), UIStyle.WHITE)
	c.draw_string(UIStyle.FONT_MEDIUM, pill.position + Vector2(46, 25), "Clima: %s" % weather, HORIZONTAL_ALIGNMENT_LEFT, 156, 17, UIStyle.WHITE)
	# Línea de separación con escalón.
	c.draw_polyline(PackedVector2Array([Vector2(SCREEN_INSET, 228), Vector2(x + 202, 228),
			Vector2(x + 216, 214), Vector2(w - SCREEN_INSET, 214)]), Color(UIStyle.WHITE, 0.3), 1.5)


func _draw_app(c: Control, i: int) -> void:
	var r := _app_rect(i)
	var shape := UIStyle.chamfer_rect(r, [10.0, 10.0, 10.0, 10.0])
	var selected := i == _selected
	c.draw_colored_polygon(shape, UIStyle.LIME if selected else ROW_FILL)
	UIStyle.draw_outline(c, shape, UIStyle.LIME if selected else Color(UIStyle.WHITE, 0.85), 1.5)
	var col := UIStyle.INK if selected else UIStyle.WHITE
	var label: String = APPS[i].label
	var tw := UIStyle.FONT_SEMIBOLD.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	# Icono + texto centrados en la caja.
	var total := 44.0 + 16.0 + tw
	var x0 := r.position.x + (r.size.x - total) * 0.5
	_app_icon(c, APPS[i].icon, Vector2(x0 + 22, r.get_center().y), col)
	c.draw_string(UIStyle.FONT_SEMIBOLD, Vector2(x0 + 60, r.get_center().y + 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col)


# --- Dibujo: listas -----------------------------------------------------------------------

func _draw_list(c: Control) -> void:
	var rows := _rows()
	if rows.is_empty():
		var msg := "Aún no hay conversaciones.\nEscribe a alguien desde Contactos." if _screen == "messages" else "No hay nada."
		c.draw_multiline_string(UIStyle.FONT_REGULAR_ITALIC, Vector2(LIST_X, LIST_Y + 80), msg,
				HORIZONTAL_ALIGNMENT_CENTER, LIST_W, 20, -1, Color(UIStyle.WHITE, 0.7))
		return
	for i in rows.size():
		var r := _row_rect(i)
		if r.size.y == 0:
			continue
		var selected := i == _selected
		_draw_row_frame(c, r, selected)
		match _screen:
			"contacts":
				_draw_contact_row(c, r, rows[i], selected)
			"messages":
				_draw_message_row(c, r, rows[i], selected)
			"inventory":
				_draw_item_row(c, r, rows[i], selected)
			"gear":
				_draw_gear_row(c, r, rows[i], selected)
			"relations":
				_draw_relation_row(c, r, rows[i], selected)
	# Indicadores de que hay más filas.
	if _scroll > 0:
		_chevron(c, Vector2(BODY.size.x * 0.5, LIST_Y - 8), true)
	if _scroll + _visible_rows() < rows.size():
		_chevron(c, Vector2(BODY.size.x * 0.5, LIST_BOTTOM + 4), false)


func _draw_row_frame(c: Control, r: Rect2, selected: bool) -> void:
	var shape := UIStyle.chamfer_rect(r, [12.0, 12.0, 12.0, 12.0])
	c.draw_colored_polygon(shape, Color("232a0c", 0.97) if selected else Color(ROW_FILL, 0.95))
	UIStyle.draw_outline(c, shape, UIStyle.LIME if selected else Color(UIStyle.WHITE, 0.8), 2.0 if selected else 1.5)


## Caja del icono o de la cara a la izquierda de la fila. Devuelve su rectángulo.
func _icon_box(c: Control, r: Rect2) -> Rect2:
	var s := minf(r.size.y - 20, 84.0)
	var box := Rect2(r.position + Vector2(14, (r.size.y - s) * 0.5), Vector2(s, s))
	var shape := UIStyle.chamfer_rect(box, [12.0, 12.0, 12.0, 12.0])
	c.draw_colored_polygon(shape, Color(UIStyle.INK, 0.9))
	UIStyle.draw_outline(c, shape, Color(UIStyle.WHITE, 0.7), 1.5)
	return box


func _draw_face(c: Control, box: Rect2, id: String) -> void:
	var tex := CharacterDB.portrait(id)
	if tex:
		c.draw_texture_rect_region(tex, box.grow(-4), CharacterDB.face_region(id))


## Título de la fila (con punto lima si está seleccionada).
func _row_title(c: Control, pos: Vector2, text: String, selected: bool, max_w: float) -> void:
	var x := pos.x
	if selected:
		c.draw_circle(Vector2(x + 7, pos.y - 9), 6, UIStyle.LIME)
		x += 22
	c.draw_string(UIStyle.FONT_ITALIC, Vector2(x, pos.y), _fit(text, UIStyle.FONT_ITALIC, 26, max_w - (x - pos.x)),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UIStyle.WHITE)


func _draw_contact_row(c: Control, r: Rect2, id: String, selected: bool) -> void:
	_draw_face(c, _icon_box(c, r), id)
	var x := r.position.x + 112
	_row_title(c, Vector2(x, r.position.y + 40), CharacterDB.display_name(id), selected, 240)
	c.draw_string(UIStyle.FONT_REGULAR_ITALIC, Vector2(x, r.position.y + 72),
			_fit(CharacterDB.tagline(id), UIStyle.FONT_REGULAR_ITALIC, 18, 240), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(UIStyle.WHITE, 0.8))
	# Burbuja de «escribir» a la derecha.
	var col := UIStyle.LIME if selected else UIStyle.WHITE
	UIIcons.speech(c, Vector2(r.end.x - 40, r.get_center().y), 34, Color(0, 0, 0, 0), col, col)


func _draw_message_row(c: Control, r: Rect2, id: String, selected: bool) -> void:
	_draw_face(c, _icon_box(c, r), id)
	var x := r.position.x + 112
	var last: Dictionary = GameState.messages[id].back()
	_row_title(c, Vector2(x, r.position.y + 40), CharacterDB.display_name(id), selected, 200)
	c.draw_string(UIStyle.FONT_MEDIUM, Vector2(r.end.x - 90, r.position.y + 38), last.time,
			HORIZONTAL_ALIGNMENT_RIGHT, 72, 17, Color(UIStyle.WHITE, 0.7))
	var preview: String = ("Tú: " if last.from == CharacterDB.PROTAGONIST else "") + last.text
	c.draw_string(UIStyle.FONT_REGULAR_ITALIC, Vector2(x, r.position.y + 72),
			_fit(preview, UIStyle.FONT_REGULAR_ITALIC, 18, r.end.x - x - 20), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(UIStyle.WHITE, 0.8))


func _draw_item_row(c: Control, r: Rect2, id: String, selected: bool) -> void:
	var box := _icon_box(c, r)
	var item := ItemDB.get_item(id)
	UIIcons.draw_named(c, item.get("icon", "can"), box.get_center(), 40, UIStyle.WHITE)
	var x := r.position.x + 112
	_row_title(c, Vector2(x, r.position.y + 40), item.get("name", id), selected, 230)
	c.draw_string(UIStyle.FONT_MEDIUM, Vector2(r.end.x - 90, r.position.y + 40), "x%d" % GameState.item_count(id),
			HORIZONTAL_ALIGNMENT_RIGHT, 70, 24, UIStyle.WHITE)
	c.draw_string(UIStyle.FONT_REGULAR_ITALIC, Vector2(x, r.position.y + 72),
			_fit(ItemDB.description(id), UIStyle.FONT_REGULAR_ITALIC, 17, r.end.x - x - 20), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(UIStyle.WHITE, 0.8))


func _draw_gear_row(c: Control, r: Rect2, id: String, selected: bool) -> void:
	var box := Rect2(r.position + Vector2(12, 14), Vector2(80, 96))
	var shape := UIStyle.chamfer_rect(box, [12.0, 12.0, 12.0, 12.0])
	c.draw_colored_polygon(shape, Color(UIStyle.INK, 0.9))
	UIStyle.draw_outline(c, shape, Color(UIStyle.WHITE, 0.7), 1.5)
	# La caja es más alta que ancha: se recorta la cara a esa proporción.
	var face := CharacterDB.face_region(id)
	var src := Rect2(face.position + Vector2(face.size.x * 0.0833, 0), Vector2(face.size.x * 0.8333, face.size.y))
	c.draw_texture_rect_region(CharacterDB.portrait(id), box.grow(-4), src)
	var x := r.position.x + 104
	_row_title(c, Vector2(x, r.position.y + 36), CharacterDB.display_name(id), selected, 300)
	var gear := CharacterDB.gear(id)
	var slots := [["arma", "ARMA"], ["accesorio", "ACCESORIO"], ["modulo", "MÓDULO"]]
	var cw := (r.end.x - x - 12 - 2 * 6) / 3.0
	for k in 3:
		var chip := Rect2(x + k * (cw + 6), r.position.y + 50, cw, 62)
		var cs := UIStyle.chamfer_rect(chip, [8.0, 8.0, 8.0, 8.0])
		c.draw_colored_polygon(cs, Color(UIStyle.INK, 0.85))
		UIStyle.draw_outline(c, cs, Color(UIStyle.WHITE, 0.6), 1.2)
		_slot_icon(c, slots[k][0], chip.position + Vector2(14, 16), Color(UIStyle.WHITE, 0.85))
		c.draw_string(UIStyle.FONT_MEDIUM, chip.position + Vector2(26, 21), slots[k][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(UIStyle.WHITE, 0.6))
		var value: String = gear[slots[k][0]]
		var empty := value == ""
		c.draw_multiline_string(UIStyle.FONT_MEDIUM_ITALIC if empty else UIStyle.FONT_MEDIUM, chip.position + Vector2(8, 40),
				"Vacío" if empty else value, HORIZONTAL_ALIGNMENT_LEFT, cw - 14, 14, 2,
				Color(UIStyle.WHITE, 0.45) if empty else UIStyle.WHITE)


## Cómo se siente `id` respecto a Ren: tramo, ánimo y barras (−100..100 desde el centro).
func _draw_relation_row(c: Control, r: Rect2, id: String, selected: bool) -> void:
	var box := Rect2(r.position + Vector2(12, 14), Vector2(80, 96))
	var shape := UIStyle.chamfer_rect(box, [12.0, 12.0, 12.0, 12.0])
	c.draw_colored_polygon(shape, Color(UIStyle.INK, 0.9))
	UIStyle.draw_outline(c, shape, Color(UIStyle.WHITE, 0.7), 1.5)
	var face := CharacterDB.face_region(id)
	var src := Rect2(face.position + Vector2(face.size.x * 0.0833, 0), Vector2(face.size.x * 0.8333, face.size.y))
	c.draw_texture_rect_region(CharacterDB.portrait(id), box.grow(-4), src)
	var x := r.position.x + 104
	# Tramo de la relación (píldora de su color) y ánimo de hoy.
	var tier := Social.tier(id, CharacterDB.PROTAGONIST)
	var tier_col: Color = TIER_COLORS[tier]
	var label: String = TIER_NAMES[tier]
	var tw := UIStyle.FONT_SEMIBOLD.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 22
	var pill := Rect2(r.end.x - tw - 14, r.position.y + 14, tw, 26)
	var ps := UIStyle.chamfer_rect(pill, [7.0, 7.0, 7.0, 7.0])
	c.draw_colored_polygon(ps, Color(tier_col, 0.18))
	UIStyle.draw_outline(c, ps, tier_col, 1.5)
	c.draw_string(UIStyle.FONT_SEMIBOLD, pill.position + Vector2(11, 19), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, tier_col)
	var mood: Dictionary = Social.mood(id)
	var mood_text: String = MOOD_NAMES.get(mood.id, mood.id)
	var mw := UIStyle.FONT_REGULAR_ITALIC.get_string_size(mood_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	c.draw_string(UIStyle.FONT_REGULAR_ITALIC, Vector2(pill.position.x - 10 - mw, r.position.y + 33),
			mood_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(UIStyle.WHITE, 0.6))
	_row_title(c, Vector2(x, r.position.y + 34), CharacterDB.display_name(id), selected, pill.position.x - mw - x - 24)
	# Afecto, confianza y respeto.
	var rel := Social.relation(id, CharacterDB.PROTAGONIST)
	var dims := [["afecto", "Afecto"], ["confianza", "Confianza"], ["respeto", "Respeto"]]
	var bar_x := x + 86
	var bar_w := r.end.x - bar_x - 16
	for k in 3:
		var y := r.position.y + 58 + k * 20
		var v: float = rel.get(dims[k][0], 0.0)
		c.draw_string(UIStyle.FONT_MEDIUM, Vector2(x, y + 5), dims[k][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(UIStyle.WHITE, 0.7))
		var track := Rect2(bar_x, y - 3, bar_w, 6)
		c.draw_rect(track, Color(UIStyle.WHITE, 0.12))
		var mid := track.position.x + track.size.x * 0.5
		var w := track.size.x * 0.5 * clampf(absf(v) / 100.0, 0.0, 1.0)
		var col := tier_col if v >= 0 else UIStyle.RED
		c.draw_rect(Rect2(mid if v >= 0 else mid - w, track.position.y, w, track.size.y), col)
		c.draw_line(Vector2(mid, track.position.y - 2), Vector2(mid, track.end.y + 2), Color(UIStyle.WHITE, 0.5), 1.0)
	# Lo que destaque del resto (atracción, miedo, asco, resentimiento).
	var extras := []
	for dim: String in EXTRA_DIMS:
		if rel.get(dim, 0.0) >= 15.0:
			extras.append(EXTRA_DIMS[dim])
	if not extras.is_empty():
		c.draw_string(UIStyle.FONT_MEDIUM_ITALIC, Vector2(x, r.end.y - 4), _fit(" · ".join(extras), UIStyle.FONT_MEDIUM_ITALIC, 13, r.end.x - x - 16),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIStyle.MAGENTA)


# --- Dibujo: chat -------------------------------------------------------------------------

## Tamaño de una burbuja con su texto.
func _bubble_size(text: String) -> Vector2:
	var s := UIStyle.FONT_REGULAR.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, BUBBLE_W - 28, BUBBLE_FONT)
	return Vector2(minf(s.x + 28, BUBBLE_W), s.y + 22)


func _chat_height() -> float:
	var total := 0.0
	for m: Dictionary in GameState.messages.get(_chat_with, []):
		total += _bubble_size(m.text).y + 30
	if _typing:
		total += 60
	return total + 10


## Burbujas desde abajo: lo más reciente pegado al final, como en cualquier chat.
func _draw_chat() -> void:
	var c := _chat
	var list: Array = GameState.messages.get(_chat_with, [])
	if list.is_empty() and not _typing:
		c.draw_multiline_string(UIStyle.FONT_REGULAR_ITALIC, Vector2(0, 80),
				"Todavía no habéis hablado por aquí.", HORIZONTAL_ALIGNMENT_CENTER, CHAT_AREA.size.x, 20, -1, Color(UIStyle.WHITE, 0.7))
		return
	var y := c.size.y - 10 + _chat_scroll
	if _typing:
		y -= 50
		_draw_typing(c, Vector2(48, y))
		y -= 10
	for i in range(list.size() - 1, -1, -1):
		var m: Dictionary = list[i]
		var bs := _bubble_size(m.text)
		y -= bs.y + 30
		if y + bs.y + 30 < 0:
			break
		var mine: bool = m.from == CharacterDB.PROTAGONIST
		var bx := CHAT_AREA.size.x - bs.x - 4 if mine else 48.0
		var r := Rect2(bx, y, bs.x, bs.y)
		var shape := UIStyle.chamfer_rect(r, [0.0, 10.0, 0.0, 10.0] if mine else [10.0, 0.0, 10.0, 0.0])
		c.draw_colored_polygon(shape, Color("232a0c", 0.97) if mine else Color(ROW_FILL, 0.97))
		UIStyle.draw_outline(c, shape, UIStyle.LIME if mine else Color(UIStyle.WHITE, 0.75), 1.5)
		c.draw_multiline_string(UIStyle.FONT_REGULAR, r.position + Vector2(14, 28), m.text, HORIZONTAL_ALIGNMENT_LEFT,
				BUBBLE_W - 28, BUBBLE_FONT, -1, UIStyle.WHITE)
		c.draw_string(UIStyle.FONT_REGULAR, Vector2(r.end.x - 60 if mine else r.position.x, r.end.y + 18), m.time,
				HORIZONTAL_ALIGNMENT_RIGHT if mine else HORIZONTAL_ALIGNMENT_LEFT, 60, 14, Color(UIStyle.WHITE, 0.5))
		if not mine:
			_mini_face(c, Vector2(4, r.end.y - 36), m.from)


func _mini_face(c: Control, pos: Vector2, id: String) -> void:
	var box := Rect2(pos, Vector2(36, 36))
	c.draw_texture_rect_region(CharacterDB.portrait(id), box, CharacterDB.face_region(id))
	c.draw_rect(box, Color(UIStyle.WHITE, 0.6), false, 1.0)


func _draw_typing(c: Control, pos: Vector2) -> void:
	var r := Rect2(pos, Vector2(78, 40))
	var shape := UIStyle.chamfer_rect(r, [10.0, 0.0, 10.0, 0.0])
	c.draw_colored_polygon(shape, Color(ROW_FILL, 0.97))
	UIStyle.draw_outline(c, shape, Color(UIStyle.WHITE, 0.75), 1.5)
	var step := Time.get_ticks_msec() / 250
	for k in 3:
		c.draw_circle(r.position + Vector2(22 + k * 17, 20), 4.0, Color(UIStyle.WHITE, 1.0 if step % 3 == k else 0.4))
	_mini_face(c, Vector2(4, r.end.y - 36), _chat_with)
	# Animación de los puntos mientras escribe.
	get_tree().create_timer(0.25).timeout.connect(_chat.queue_redraw, CONNECT_ONE_SHOT)


## Botones de respuesta (en lugar de «Saludar»), de abajo arriba.
func _draw_replies(c: Control) -> void:
	var replies := _replies()
	var n := replies.size()
	var top := _reply_rect(0, n).position.y
	c.draw_line(Vector2(SCREEN_INSET, top - 18), Vector2(BODY.size.x - SCREEN_INSET, top - 18), Color(UIStyle.WHITE, 0.3), 1.5)
	_reply_sel = clampi(_reply_sel, 0, n - 1)
	for i in n:
		var r := _reply_rect(i, n)
		var on := i == _reply_sel
		var shape := UIStyle.chamfer_rect(r, [12.0, 12.0, 12.0, 12.0])
		c.draw_colored_polygon(shape, UIStyle.LIME if on else Color(ROW_FILL, 0.95))
		UIStyle.draw_outline(c, shape, UIStyle.LIME if on else Color(UIStyle.WHITE, 0.5), 1.5)
		var col := UIStyle.INK if on else UIStyle.WHITE
		# Si no cabe, primero letra algo más pequeña y, solo si aún no cabe, «…».
		var fs := 20 if UIStyle.FONT_SEMIBOLD.get_string_size(replies[i].label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x <= r.size.x - 44 else 16
		c.draw_string(UIStyle.FONT_SEMIBOLD, r.position + Vector2(22, 34), _fit(replies[i].label, UIStyle.FONT_SEMIBOLD, fs, r.size.x - 44),
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw_send(c: Control) -> void:
	c.draw_line(Vector2(SCREEN_INSET, SEND.position.y - 18), Vector2(BODY.size.x - SCREEN_INSET, SEND.position.y - 18),
			Color(UIStyle.WHITE, 0.3), 1.5)
	var shape := UIStyle.chamfer_rect(SEND, [12.0, 12.0, 12.0, 12.0])
	var on := not _busy
	c.draw_colored_polygon(shape, UIStyle.LIME if on else Color(ROW_FILL, 0.95))
	UIStyle.draw_outline(c, shape, UIStyle.LIME if on else Color(UIStyle.WHITE, 0.4), 1.5)
	var col := UIStyle.INK if on else Color(UIStyle.WHITE, 0.6)
	var label := "Saludar"
	if not on:
		label = "%s está escribiendo..." % CharacterDB.display_name(_chat_with) if _typing else "Enviando..."
	UIIcons.speech(c, SEND.position + Vector2(40, SEND.size.y * 0.5), 30, Color(0, 0, 0, 0), col, col)
	c.draw_string(UIStyle.FONT_SEMIBOLD, SEND.position + Vector2(72, 37), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col)
	if on:
		c.draw_string(UIStyle.FONT_MEDIUM, SEND.position + Vector2(SEND.size.x - 92, 36), "Enter", HORIZONTAL_ALIGNMENT_RIGHT, 72, 16, Color(UIStyle.INK, 0.6))


# --- Dibujo: decoración ---------------------------------------------------------------------

## Ciudad nocturna con un anillo de luz, árbol en flor y bandas diagonales.
func _draw_city(c: Control, r: Rect2) -> void:
	# Cielo en degradado: transparente arriba, violeta noche abajo.
	var sky := UIStyle.chamfer_rect(r, [0.0, 0.0, 22.0, 22.0])
	var cols := PackedColorArray()
	for p in sky:
		cols.append(Color(SKY, 0.95 * clampf((p.y - r.position.y) / (r.size.y * 0.6), 0.0, 1.0)))
	c.draw_polygon(sky, cols)
	var ground := r.end.y - 50
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# Edificios del fondo (más claros) y del frente.
	for layer in 2:
		var x := r.position.x + 10
		var col := Color("2c2347") if layer == 0 else Color("191428")
		while x < r.end.x - 40:
			var bw := rng.randf_range(18, 40)
			var bh := rng.randf_range(40, 150) * (1.0 if layer == 0 else 0.7)
			var b := Rect2(x, ground - bh, bw, bh)
			c.draw_rect(b, col)
			# Ventanas.
			for k in rng.randi_range(1, 4):
				var wc := UIStyle.LIME if rng.randf() < 0.3 else Color("6d5aa6")
				c.draw_rect(Rect2(b.position.x + rng.randf_range(4, bw - 8), b.position.y + rng.randf_range(6, bh - 10), 3, 6), Color(wc, 0.8))
			x += bw + rng.randf_range(2, 10)
	# Anillo flotante.
	var ring_c := Vector2(r.position.x + r.size.x * 0.48, ground - 100)
	var pts := PackedVector2Array()
	for k in 49:
		var a := TAU * k / 48.0
		pts.append(ring_c + Vector2(cos(a) * 110, sin(a) * 22))
	c.draw_polyline(pts, Color("bfe9ff", 0.85), 2.5, true)
	# Suelo.
	c.draw_rect(Rect2(r.position.x, ground, r.size.x, 50 - 1), Color("120e1c"))
	c.draw_line(Vector2(r.position.x, ground), Vector2(r.end.x, ground), Color("6d5aa6", 0.6), 1.5)
	# Árbol en flor a la izquierda.
	var trunk := Vector2(r.position.x + 40, ground)
	c.draw_line(trunk, trunk + Vector2(14, -90), Color("1a1424"), 6.0)
	for k in 14:
		var p := trunk + Vector2(14, -96) + Vector2(rng.randf_range(-46, 50), rng.randf_range(-36, 26))
		c.draw_circle(p, rng.randf_range(8, 16), Color("7c4fa8", rng.randf_range(0.45, 0.8)))
	# Bandas diagonales lima y violeta abajo a la derecha.
	c.draw_colored_polygon(PackedVector2Array([Vector2(r.end.x - 120, r.end.y), Vector2(r.end.x, r.end.y - 150),
			Vector2(r.end.x, r.end.y - 128), Vector2(r.end.x - 100, r.end.y)]), Color(UIStyle.LIME, 0.75))
	c.draw_colored_polygon(PackedVector2Array([Vector2(r.end.x - 86, r.end.y), Vector2(r.end.x, r.end.y - 108),
			Vector2(r.end.x, r.end.y - 76), Vector2(r.end.x - 60, r.end.y)]), Color(UIStyle.VIOLET, 0.6))


# --- Iconos y utilidades ------------------------------------------------------------------

## Recorta `text` con «…» para que quepa en `width`.
static func _fit(text: String, font: Font, font_size: int, width: float) -> String:
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width:
		return text
	var s := text
	while s.length() > 1 and font.get_string_size(s + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
		s = s.substr(0, s.length() - 1)
	return s.strip_edges() + "…"


func _chevron(c: Control, center: Vector2, up: bool) -> void:
	var d := -1.0 if up else 1.0
	c.draw_polyline(PackedVector2Array([center + Vector2(-12, -5 * d), center + Vector2(0, 5 * d),
			center + Vector2(12, -5 * d)]), Color(UIStyle.WHITE, 0.8), 2.5, true)


func _slot_icon(c: Control, slot: String, p: Vector2, col: Color) -> void:
	match slot:
		"arma":
			c.draw_line(p + Vector2(-6, 6), p + Vector2(6, -6), col, 2.0, true)
			c.draw_line(p + Vector2(-7, 2), p + Vector2(-2, 7), col, 2.0, true)
		"accesorio":
			c.draw_arc(p + Vector2(0, 1), 5.5, 0, TAU, 16, col, 1.8, true)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-3, -5), p + Vector2(0, -9), p + Vector2(3, -5)]), col)
		"modulo":
			c.draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), col, false, 1.6)
			for k in 3:
				var o := -4.0 + k * 4.0
				c.draw_line(p + Vector2(o, -5), p + Vector2(o, -8), col, 1.2)
				c.draw_line(p + Vector2(o, 5), p + Vector2(o, 8), col, 1.2)


func _app_icon(c: Control, icon: String, p: Vector2, col: Color) -> void:
	match icon:
		"speech":
			var bubble := Rect2(p + Vector2(-20, -15), Vector2(40, 26))
			var shape := UIStyle.chamfer_rect(bubble, [8.0, 8.0, 8.0, 8.0])
			UIStyle.draw_outline(c, shape, col, 2.5)
			c.draw_polyline(PackedVector2Array([p + Vector2(-10, 11), p + Vector2(-14, 19), p + Vector2(-2, 11)]), col, 2.5, true)
			for k in 3:
				c.draw_circle(p + Vector2(-9 + k * 9, -2), 2.5, col)
		"people":
			for k in [-1, 1]:
				c.draw_circle(p + Vector2(k * 13, -6), 5, col)
				c.draw_colored_polygon(PackedVector2Array([p + Vector2(k * 13 - 9, 12), p + Vector2(k * 13 - 7, 2),
						p + Vector2(k * 13 + 7, 2), p + Vector2(k * 13 + 9, 12)]), col)
			c.draw_circle(p + Vector2(0, -9), 6.5, col)
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-12, 14), p + Vector2(-9, 1),
					p + Vector2(9, 1), p + Vector2(12, 14)]), col)
		"heart":
			UIIcons.heart(c, p + Vector2(0, -2), 34, col)
		"bookmark":
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-13, -20), p + Vector2(13, -20),
					p + Vector2(13, 20), p + Vector2(0, 10), p + Vector2(-13, 20)]), col)
			var bg := UIStyle.LIME if col == UIStyle.INK else ROW_FILL
			_star(c, p + Vector2(0, -4), 8.0, bg)
		"bag":
			var r := Rect2(p + Vector2(-15, -6), Vector2(30, 24))
			UIStyle.draw_outline(c, UIStyle.chamfer_rect(r, [5.0, 5.0, 5.0, 5.0]), col, 2.5)
			c.draw_arc(p + Vector2(0, -8), 9, PI, TAU, 16, col, 2.5, true)
			c.draw_circle(p + Vector2(0, 7), 2.5, col)
		"gear":
			c.draw_arc(p, 16, 0, TAU, 32, col, 3.0, true)
			c.draw_circle(p, 6, col)
			for k in 4:
				var a := k * PI * 0.5
				c.draw_line(p + Vector2.from_angle(a) * 16, p + Vector2.from_angle(a) * 22, col, 4.0)
		"boxes":
			for o in [Vector2(-8, -16), Vector2(-17, 0), Vector2(1, 0)]:
				var b := Rect2(p + o, Vector2(16, 16))
				c.draw_rect(b, col, false, 2.0)
				c.draw_line(b.position, b.end, col, 1.5)
				c.draw_line(Vector2(b.end.x, b.position.y), Vector2(b.position.x, b.end.y), col, 1.5)
		"orbit":
			for k in 3:
				var pts := PackedVector2Array()
				for s in 25:
					var a := PI * 1.6 * s / 24.0 + k * 0.5
					pts.append(p + Vector2(cos(a) * (20 - k * 4), sin(a) * (9 - k * 2)).rotated(-0.35))
				c.draw_polyline(pts, col, 2.5 - k * 0.5, true)
			c.draw_circle(p + Vector2(-2, 1), 3, col)


func _star(c: Control, center: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI * 0.5 + k * PI / 5.0
		pts.append(center + Vector2.from_angle(a) * (r if k % 2 == 0 else r * 0.45))
	c.draw_colored_polygon(pts, col)


func _sun(c: Control, p: Vector2, col: Color) -> void:
	c.draw_arc(p, 5, 0, TAU, 16, col, 2.0, true)
	for k in 8:
		var d := Vector2.from_angle(k * PI / 4.0)
		c.draw_line(p + d * 8, p + d * 11, col, 2.0)


## Emblema de la terminal: tridente afilado dentro de un escudo.
func _emblem(c: Control, p: Vector2, col: Color) -> void:
	c.draw_polyline(PackedVector2Array([p + Vector2(-26, -30), p + Vector2(-16, 8), p + Vector2(0, 30),
			p + Vector2(16, 8), p + Vector2(26, -30)]), col, 2.5, true)
	c.draw_polyline(PackedVector2Array([p + Vector2(0, -32), p + Vector2(-8, -6), p + Vector2(0, 20),
			p + Vector2(8, -6), p + Vector2(0, -32)]), col, 2.5, true)
	c.draw_line(p + Vector2(-16, -22), p + Vector2(-10, 4), col, 2.0, true)
	c.draw_line(p + Vector2(16, -22), p + Vector2(10, 4), col, 2.0, true)
