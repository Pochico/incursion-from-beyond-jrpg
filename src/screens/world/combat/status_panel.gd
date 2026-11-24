class_name StatusPanel
extends Control
## Pantalla de estado de un miembro del grupo durante el combate
## (ver docs/ui/referencias/04_estado_personaje.webp).
##
## Ocupa toda la pantalla y oscurece el combate. El panel tiene:
##  - A la izquierda, las miniaturas del grupo (con flechas para cambiar).
##  - La ilustración del personaje en escala de grises con trazos lima.
##  - Pestañas «Estado» e «Historia» y botón de cerrar.
##  - Estado: nombre, nivel, naturaleza, PV/PM, atributos, habilidades/ataques
##    con su detalle (potencia, objetivo, recarga) y estados alterados.
##  - Historia: quién es.
##
## Ratón: todo es clicable; pasar por encima de una habilidad muestra su detalle.
## Teclado: ↑/↓ habilidad, ←/→ pestaña, AvPág/RePág cambia de miembro, Esc o Tab cierra.

signal closed

const PANEL := Rect2(160, 128, 1600, 800)
const CUT := 26.0
const TAB_STATE := Rect2(810, 8, 232, 52)
const TAB_STORY := Rect2(1052, 8, 262, 52)
const CLOSE := Rect2(1522, -16, 74, 66)
const THUMB_X := 30.0
const THUMB_Y := 126.0
const THUMB_SIZE := Vector2(118, 110)
const THUMB_STEP := 128.0
const THUMB_SLOTS := 4
const ARROW_UP := Rect2(60, 74, 60, 40)
const ARROW_DOWN := Rect2(60, 640, 60, 40)
const ART_RECT := Rect2(170, 20, 430, 770)
const STATS_BOX := Rect2(580, 180, 1000, 136)
const SKILL_X := 580.0
const SKILL_Y := 398.0
const SKILL_SIZE := Vector2(480, 48)
const SKILL_STEP := 56.0
const SKILL_ROWS := 4
const DETAIL_BOX := Rect2(1094, 398, 486, 236)
const PM_COLOR := Color("27b4f5")
const STATS := [
	["FUE", "Fuerza", "swords"], ["TEC", "Técnica", "antenna"], ["INT", "Inteligencia", "sparkle"],
	["VOL", "Voluntad", "heart"], ["RES", "Resistencia", "shield"], ["AGI", "Agilidad", "run"],
]

var _battle: Battle
var _party: Array[String] = []
var _index := 0
var _tab := 0                ## 0 = Estado, 1 = Historia
var _skill := 0
var _entries: Array[Dictionary] = []
var _hover := ""             ## zona bajo el ratón ("tab0", "close", "thumb1", "skill2", "status:curse"...)
var _status_rects := {}      ## status_id -> Rect2 de su píldora (coordenadas del panel)

var _panel: Control
var _art_clip: Control
var _art: TextureRect


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_panel = Control.new()
	_panel.position = PANEL.position
	_panel.size = PANEL.size
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.draw.connect(_draw_panel)
	add_child(_panel)

	# La ilustración va en un nodo propio para poder aplicarle el shader de grises.
	_art_clip = Control.new()
	_art_clip.position = ART_RECT.position
	_art_clip.size = ART_RECT.size
	_art_clip.clip_contents = true
	_art_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_clip.draw.connect(_draw_streaks)
	_panel.add_child(_art_clip)

	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://src/ui/shaders/grayscale.gdshader")
	_art.material = mat
	_art_clip.add_child(_art)

	# Encima de la ilustración: el resto del panel se dibuja en esta capa.
	var front := Control.new()
	front.size = PANEL.size
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.draw.connect(_draw_front.bind(front))
	_panel.add_child(front)


## Abre la pantalla con el miembro `who` ("player"/"ally") del combate en curso.
func open(battle: Battle, who: String) -> void:
	_battle = battle
	_party.assign(battle.party)
	_index = maxi(_party.find(who), 0)
	_tab = 0
	_load_member()
	visible = true
	modulate.a = 0.0
	_panel.scale = Vector2(0.97, 0.97)
	_panel.pivot_offset = PANEL.size * 0.5
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 1.0, 0.18)
	t.tween_property(_panel, "scale", Vector2.ONE, 0.22)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


# --- Datos ------------------------------------------------------------------------------

func _fighter() -> Dictionary:
	return _battle.fighter(_party[_index])


func _load_member() -> void:
	var f := _fighter()
	_skill = 0
	_entries.clear()
	var who := _party[_index]
	_entries.append({
		"name": f.attack, "icon": "slash", "cost": 0,
		"desc": "Ataque básico: golpe físico (FUE contra RES), sin coste ni recarga.",
		"power": "~%d" % _battle.attack_preview(who),
		"target": SkillDB.TARGET_NAMES.enemy, "cd": 0,
	})
	for id: String in f.skills:
		var sk := SkillDB.get_skill(id)
		var tier: String = (" (tier %d)" % sk.tier) if sk.get("tier", 0) > 0 else ""
		_entries.append({
			"name": sk.name, "icon": sk.get("icon", "sparkle"),
			"cost": _battle.skill_cost(who, id), "desc": sk.desc + tier,
			"power": _battle.skill_summary(who, id),
			"target": SkillDB.TARGET_NAMES.get(sk.target, "—"),
			"cd": sk.cd, "nature": sk.nature,
		})
	var tex := CharacterDB.portrait(f.id)
	_art.texture = tex
	if tex:
		# Ajustada al alto del hueco con margen: se corta por abajo, como en la referencia.
		var h := ART_RECT.size.y * 1.25
		var w := h * tex.get_width() / tex.get_height()
		_art.size = Vector2(w, h)
		_art.position = Vector2((ART_RECT.size.x - w) * 0.5, 10)
	_art_clip.queue_redraw()
	_redraw()


func _redraw() -> void:
	_panel.queue_redraw()
	for c in _panel.get_children():
		(c as CanvasItem).queue_redraw()


func _select_member(i: int) -> void:
	if i < 0 or i >= _party.size() or i == _index:
		return
	_index = i
	_load_member()


# --- Entrada ----------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not visible:
		return
	# Mientras está abierta, el teclado es solo suyo.
	if event is InputEventKey or event is InputEventJoypadButton:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_focus_next"):
			close()
		elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			_tab = 1 - _tab
			_redraw()
		elif event.is_action_pressed("ui_up") and _tab == 0:
			_skill = posmod(_skill - 1, mini(_entries.size(), SKILL_ROWS))
			_redraw()
		elif event.is_action_pressed("ui_down") and _tab == 0:
			_skill = posmod(_skill + 1, mini(_entries.size(), SKILL_ROWS))
			_redraw()
		elif event.is_action_pressed("ui_page_up"):
			_select_member(_index - 1)
		elif event.is_action_pressed("ui_page_down"):
			_select_member(_index + 1)
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var zone := _zone_at(event.position - PANEL.position)
		if zone != _hover:
			_hover = zone
			if zone.begins_with("skill"):
				_skill = int(zone.substr(5))
			var plain := zone == "" or zone == "panel" or zone.begins_with("status:")
			mouse_default_cursor_shape = Control.CURSOR_ARROW if plain else Control.CURSOR_POINTING_HAND
			_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var zone := _zone_at(event.position - PANEL.position)
		match zone:
			"", "close":
				close()   # Clic fuera del panel o en la X.
			"tab0", "tab1":
				_tab = int(zone.substr(3))
				_redraw()
			"up":
				_select_member(_index - 1)
			"down":
				_select_member(_index + 1)
			_:
				if zone.begins_with("thumb"):
					_select_member(int(zone.substr(5)))
		accept_event()
	elif event is InputEventMouseButton and event.pressed:
		accept_event()


func _zone_at(p: Vector2) -> String:
	if CLOSE.has_point(p):
		return "close"
	if TAB_STATE.has_point(p):
		return "tab0"
	if TAB_STORY.has_point(p):
		return "tab1"
	if ARROW_UP.has_point(p) and _party.size() > 1:
		return "up"
	if ARROW_DOWN.has_point(p) and _party.size() > 1:
		return "down"
	for i in mini(_party.size(), THUMB_SLOTS):
		if _thumb_rect(i).has_point(p):
			return "thumb%d" % i
	if _tab == 0:
		for i in mini(_entries.size(), SKILL_ROWS):
			if _skill_rect(i).has_point(p):
				return "skill%d" % i
		for status: String in _status_rects:
			if (_status_rects[status] as Rect2).has_point(p):
				return "status:" + status
	if Rect2(Vector2.ZERO, PANEL.size).has_point(p):
		return "panel"
	return ""


func _thumb_rect(i: int) -> Rect2:
	return Rect2(Vector2(THUMB_X, THUMB_Y + i * THUMB_STEP), THUMB_SIZE)


func _skill_rect(i: int) -> Rect2:
	return Rect2(Vector2(SKILL_X, SKILL_Y + i * SKILL_STEP), SKILL_SIZE)


# --- Dibujo -----------------------------------------------------------------------------

func _draw() -> void:
	# El combate se ve por detrás, oscurecido.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.72))


func _draw_panel() -> void:
	var p := _panel
	var frame := UIStyle.chamfer_rect(Rect2(Vector2.ZERO, PANEL.size), [CUT, 0.0, CUT, 0.0])
	p.draw_colored_polygon(frame, Color(UIStyle.INK.lightened(0.04), 0.98))
	UIStyle.draw_outline(p, frame, UIStyle.LINE, 2.0)
	# Marcas «////» arriba a la izquierda y abajo a la derecha.
	UIStyle.draw_stripes(p, Vector2(34, 30), 4, Vector2(16, 14), 5, Color(UIStyle.WHITE, 0.55))
	p.draw_line(Vector2(120, 22), Vector2(260, 22), Color(UIStyle.WHITE, 0.4), 6.0)
	UIStyle.draw_stripes(p, Vector2(PANEL.size.x - 150, PANEL.size.y - 14), 4, Vector2(16, 14), 5, Color(UIStyle.WHITE, 0.55))
	p.draw_line(Vector2(580, PANEL.size.y - 18), Vector2(PANEL.size.x - 170, PANEL.size.y - 18), Color(UIStyle.WHITE, 0.25), 1.5)


## Trazos diagonales lima detrás de la ilustración.
func _draw_streaks() -> void:
	var c := _art_clip
	var h := ART_RECT.size.y
	c.draw_colored_polygon(PackedVector2Array([
		Vector2(330, 0), Vector2(360, 0), Vector2(70, h), Vector2(40, h)]), Color(UIStyle.LIME, 0.9))
	c.draw_colored_polygon(PackedVector2Array([
		Vector2(400, 120), Vector2(414, 120), Vector2(160, h), Vector2(146, h)]), Color(UIStyle.LIME, 0.75))


func _draw_front(c: Control) -> void:
	if _battle == null:
		return
	_draw_party(c)
	_draw_tabs(c)
	var f := _fighter()
	# Nombre y nivel.
	c.draw_colored_polygon(UIStyle.slanted_rect(Rect2(624, 82, 12, 56), 8), UIStyle.LIME)
	c.draw_string(UIStyle.FONT_HEAVY_ITALIC, Vector2(656, 134), f.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 60, UIStyle.WHITE)
	c.draw_string(UIStyle.FONT_MEDIUM, Vector2(664, 172), "Nv.", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(UIStyle.WHITE, 0.85))
	c.draw_string(UIStyle.FONT_SEMIBOLD, Vector2(704, 172), str(f.level), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UIStyle.WHITE)
	_draw_nature_tag(c, f)
	if _tab == 0:
		_draw_stats(c, f)
		_draw_skills(c)
		_draw_statuses(c, f)
		_draw_status_tooltip(c, f)
	else:
		_status_rects.clear()
		_draw_story(c, f)


func _draw_party(c: Control) -> void:
	var many := _party.size() > 1
	var arrow_col := Color(UIStyle.WHITE, 0.9 if many else 0.25)
	_chevron(c, ARROW_UP.get_center(), true, arrow_col)
	_chevron(c, ARROW_DOWN.get_center(), false, arrow_col)
	for i in THUMB_SLOTS:
		var r := _thumb_rect(i)
		var shape := UIStyle.chamfer_rect(r, [0.0, 0.0, 16.0, 0.0])
		c.draw_colored_polygon(shape, Color(UIStyle.GRAY_DARK, 0.9))
		if i < _party.size():
			var id: String = _battle.fighter(_party[i]).id
			var tex := CharacterDB.portrait(id)
			var selected := i == _index
			var tint := Color.WHITE if selected else Color(0.6, 0.6, 0.62)
			c.draw_texture_rect_region(tex, r.grow(-4), CharacterDB.face_region(id), tint)
			if selected:
				UIStyle.draw_outline(c, shape, UIStyle.LIME, 4.0)
			elif _hover == "thumb%d" % i:
				UIStyle.draw_outline(c, shape, UIStyle.WHITE, 2.0)
			else:
				UIStyle.draw_outline(c, shape, Color(UIStyle.WHITE, 0.4), 1.5)
		else:
			UIStyle.draw_outline(c, shape, Color(UIStyle.WHITE, 0.15), 1.5)


func _draw_tabs(c: Control) -> void:
	var tabs := [[TAB_STATE, "Estado"], [TAB_STORY, "Historia"]]
	for i in 2:
		var r: Rect2 = tabs[i][0]
		var shape := UIStyle.slanted_rect(r, 18)
		var active := i == _tab
		if active:
			c.draw_colored_polygon(shape, UIStyle.LIME)
		else:
			c.draw_colored_polygon(shape, Color(UIStyle.INK, 0.95))
			UIStyle.draw_outline(c, shape, Color(UIStyle.WHITE, 0.9 if _hover == "tab%d" % i else 0.6), 1.5)
		var col := UIStyle.INK if active else UIStyle.WHITE
		var icon_c := r.position + Vector2(66, r.size.y * 0.5)
		if i == 0:
			_person_icon(c, icon_c, col)
		else:
			_book_icon(c, icon_c, col)
		c.draw_string(UIStyle.FONT_MEDIUM, r.position + Vector2(96, 35), tabs[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, col)
	# Cerrar.
	var close_shape := UIStyle.chamfer_rect(CLOSE, [0.0, 10.0, 0.0, 10.0])
	c.draw_colored_polygon(close_shape, UIStyle.INK)
	UIStyle.draw_outline(c, close_shape, UIStyle.LIME if _hover == "close" else UIStyle.WHITE, 2.0)
	var cc := CLOSE.get_center()
	c.draw_line(cc + Vector2(-16, -16), cc + Vector2(16, 16), UIStyle.WHITE, 3.0, true)
	c.draw_line(cc + Vector2(16, -16), cc + Vector2(-16, 16), UIStyle.WHITE, 3.0, true)


func _draw_nature_tag(c: Control, f: Dictionary) -> void:
	var nature: String = f.nature
	var label: String = SkillDB.NATURE_NAMES.get(nature, "Sin naturaleza")
	var col := SkillDB.nature_color(nature) if nature != "" else UIStyle.GRAY
	var r := Rect2(1250, 88, 330, 50)
	var shape := PackedVector2Array([r.position + Vector2(40, 0), Vector2(r.end.x, r.position.y),
			r.end, Vector2(r.position.x, r.end.y)])
	c.draw_colored_polygon(shape, Color(UIStyle.INK, 0.95))
	c.draw_polyline(PackedVector2Array([Vector2(r.position.x - 300, r.end.y), Vector2(r.position.x, r.end.y),
			r.position + Vector2(40, 0), Vector2(r.end.x, r.position.y)]), UIStyle.LINE, 1.5, true)
	UIIcons.sparkle(c, r.position + Vector2(84, 26), 26, col)
	c.draw_string(UIStyle.FONT_ITALIC, r.position + Vector2(112, 35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UIStyle.WHITE)
	UIStyle.draw_stripes(c, Vector2(r.end.x - 56, r.position.y + 34), 3, Vector2(10, 12), 4, UIStyle.WHITE)


func _draw_stats(c: Control, f: Dictionary) -> void:
	var b := STATS_BOX
	var shape := UIStyle.chamfer_rect(b, [18.0, 0.0, 18.0, 0.0])
	c.draw_colored_polygon(shape, Color(UIStyle.INK, 0.9))
	UIStyle.draw_outline(c, shape, UIStyle.LINE, 1.5)
	# PV / PM.
	var bars := [["PV", f.pv, f.pv_max, UIStyle.LIME, "heart"], ["PM", f.pm, f.pm_max, PM_COLOR, "sparkle"]]
	for i in 2:
		var y := b.position.y + 46 + i * 56
		var bar: Array = bars[i]
		UIIcons.draw_named(c, bar[4], Vector2(b.position.x + 36, y - 6), 26, UIStyle.WHITE)
		c.draw_string(UIStyle.FONT_MEDIUM, Vector2(b.position.x + 66, y), bar[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UIStyle.WHITE)
		var value := "%d / %d" % [bar[1], bar[2]]
		c.draw_string(UIStyle.FONT_MEDIUM, Vector2(b.position.x + 66, y), value, HORIZONTAL_ALIGNMENT_RIGHT, 334, 24, UIStyle.WHITE)
		var track := Rect2(b.position.x + 66, y + 10, 334, 9)
		c.draw_rect(track, Color(UIStyle.WHITE, 0.15))
		c.draw_rect(Rect2(track.position, Vector2(track.size.x * clampf(float(bar[1]) / maxf(bar[2], 1), 0, 1), track.size.y)), bar[3])
	# Atributos en dos columnas.
	for col in 2:
		var x := b.position.x + 440 + col * 290
		c.draw_line(Vector2(x - 20, b.position.y + 18), Vector2(x - 20, b.end.y - 18), Color(UIStyle.WHITE, 0.4), 1.5)
		for row in 3:
			var stat: Array = STATS[col * 3 + row]
			var y := b.position.y + 40 + row * 40
			UIIcons.draw_named(c, stat[2], Vector2(x + 14, y - 8), 22, UIStyle.WHITE)
			c.draw_string(UIStyle.FONT_MEDIUM, Vector2(x + 40, y), stat[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UIStyle.WHITE)
			c.draw_string(UIStyle.FONT_SEMIBOLD, Vector2(x + 40, y), str(int(f.stats.get(stat[0], 0))), HORIZONTAL_ALIGNMENT_RIGHT, 220, 24, UIStyle.WHITE)
			if row < 2:
				c.draw_line(Vector2(x, y + 12), Vector2(x + 260, y + 12), Color(UIStyle.WHITE, 0.12), 1.0)


func _section_title(c: Control, pos: Vector2, text: String, line_to: float) -> void:
	c.draw_colored_polygon(UIStyle.slanted_rect(Rect2(pos.x, pos.y - 26, 8, 30), 6), UIStyle.LIME)
	c.draw_string(UIStyle.FONT_ITALIC, pos + Vector2(24, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UIStyle.WHITE)
	var w := UIStyle.FONT_ITALIC.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	c.draw_line(Vector2(pos.x + 40 + w, pos.y + 10), Vector2(line_to, pos.y + 10), Color(UIStyle.WHITE, 0.3), 1.5)


func _draw_skills(c: Control) -> void:
	_section_title(c, Vector2(600, 366), "Habilidades / Ataques", 1580)
	for i in mini(_entries.size(), SKILL_ROWS):
		var e := _entries[i]
		var r := _skill_rect(i)
		var shape := UIStyle.chamfer_rect(r, [8.0, 8.0, 8.0, 8.0])
		var selected := i == _skill
		c.draw_colored_polygon(shape, UIStyle.LIME if selected else Color(UIStyle.INK, 0.9))
		if not selected:
			UIStyle.draw_outline(c, shape, Color(UIStyle.WHITE, 0.8), 1.5)
		var col := UIStyle.INK if selected else UIStyle.WHITE
		UIIcons.draw_named(c, e.icon, r.position + Vector2(36, 24), 26, col)
		c.draw_string(UIStyle.FONT_MEDIUM, r.position + Vector2(70, 33), e.name, HORIZONTAL_ALIGNMENT_LEFT, 300, 25, col)
		c.draw_string(UIStyle.FONT_REGULAR, r.position + Vector2(r.size.x - 86, 31), "PM", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, col)
		c.draw_string(UIStyle.FONT_SEMIBOLD, r.position + Vector2(r.size.x - 70, 33), str(e.cost), HORIZONTAL_ALIGNMENT_RIGHT, 52, 25, col)
	if _entries.size() > SKILL_ROWS:
		c.draw_string(UIStyle.FONT_REGULAR_ITALIC, Vector2(SKILL_X, SKILL_Y + SKILL_ROWS * SKILL_STEP + 4),
				"+%d más" % (_entries.size() - SKILL_ROWS), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UIStyle.GRAY)
	_draw_detail(c)


func _draw_detail(c: Control) -> void:
	if _entries.is_empty():
		return
	var e := _entries[_skill]
	var b := DETAIL_BOX
	var shape := UIStyle.chamfer_rect(b, [0.0, 16.0, 16.0, 0.0])
	c.draw_colored_polygon(shape, Color(UIStyle.INK, 0.9))
	UIStyle.draw_outline(c, shape, UIStyle.LINE, 1.5)
	c.draw_colored_polygon(UIStyle.slanted_rect(Rect2(b.position.x + 26, b.position.y + 18, 8, 30), 6), UIStyle.LIME)
	c.draw_string(UIStyle.FONT_ITALIC, b.position + Vector2(48, 44), e.name, HORIZONTAL_ALIGNMENT_LEFT, 330, 28, UIStyle.WHITE)
	c.draw_line(b.position + Vector2(26, 60), b.position + Vector2(b.size.x - 120, 60), Color(UIStyle.WHITE, 0.3), 1.0)
	c.draw_multiline_string(UIStyle.FONT_REGULAR, b.position + Vector2(28, 92), e.desc, HORIZONTAL_ALIGNMENT_LEFT,
			b.size.x - 150, 20, 4, Color(UIStyle.WHITE, 0.9))
	# Tajos decorativos.
	var sc := b.position + Vector2(b.size.x - 64, 90)
	for k in 3:
		var o := Vector2(k * 14 - 14, k * 6)
		c.draw_line(sc + o + Vector2(28, -40), sc + o + Vector2(-28, 40), Color(UIStyle.WHITE, 0.9 - k * 0.2), 3.0 - k * 0.6, true)
	# Pie: potencia, objetivo y recarga.
	var y := b.end.y - 26
	c.draw_line(Vector2(b.position.x + 26, y - 40), Vector2(b.end.x - 26, y - 40), Color(UIStyle.WHITE, 0.3), 1.0)
	var x := b.position.x + 30
	x = _draw_pair(c, Vector2(x, y), "Potencia:", e.power)
	x = _draw_pair(c, Vector2(x + 24, y), "Objetivo:", e.target)
	if e.cd > 0:
		_draw_pair(c, Vector2(x + 24, y), "Recarga:", str(e.cd))


## Dibuja «Etiqueta: valor» y devuelve la x final.
func _draw_pair(c: Control, pos: Vector2, label: String, value: String) -> float:
	c.draw_string(UIStyle.FONT_REGULAR, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, UIStyle.WHITE)
	var lw := UIStyle.FONT_REGULAR.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
	c.draw_string(UIStyle.FONT_SEMIBOLD, pos + Vector2(lw + 8, 2), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UIStyle.LIME)
	return pos.x + lw + 8 + UIStyle.FONT_SEMIBOLD.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x


func _draw_statuses(c: Control, f: Dictionary) -> void:
	_section_title(c, Vector2(630, 692), "Estado", 1580)
	# Solo los estados que tiene; si no tiene ninguno, «Normal».
	var statuses: Dictionary = f.statuses
	var pills := []
	if statuses.is_empty():
		pills.append({"text": "Normal", "icon": "plus", "on": true, "color": UIStyle.LIME, "status": ""})
	for status: String in statuses:
		var name_: String = SkillDB.STATUS_NAMES.get(status, status)
		pills.append({"text": "%s · %d t." % [name_, statuses[status].turns], "icon": "sparkle", "on": true,
			"color": UIStyle.VIOLET if SkillDB.status(status).get("debuff", false) else UIStyle.LIME, "status": status})
	_status_rects.clear()
	var x := 600.0
	for pill: Dictionary in pills:
		var w := 60.0 + UIStyle.FONT_MEDIUM.get_string_size(pill.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 30
		w = maxf(w, 180.0)
		var r := Rect2(x, 718, w, 46)
		if pill.status != "":
			_status_rects[pill.status] = r
		var hovered: bool = pill.status != "" and _hover == "status:" + pill.status
		var shape := UIStyle.chamfer_rect(r, [0.0, 0.0, 12.0, 0.0])
		c.draw_colored_polygon(shape, Color(pill.color, 0.18) if hovered else Color(UIStyle.INK, 0.9))
		var col: Color = pill.color if pill.on else Color(UIStyle.WHITE, 0.45)
		UIStyle.draw_outline(c, shape, col, 2.0 if pill.on else 1.5)
		var ic := r.position + Vector2(34, 23)
		if pill.icon == "plus":
			c.draw_circle(ic, 13, col)
			c.draw_line(ic + Vector2(-7, 0), ic + Vector2(7, 0), UIStyle.INK, 3.0)
			c.draw_line(ic + Vector2(0, -7), ic + Vector2(0, 7), UIStyle.INK, 3.0)
		else:
			UIIcons.sparkle(c, ic, 22, col)
		c.draw_string(UIStyle.FONT_MEDIUM, r.position + Vector2(60, 31), pill.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
				UIStyle.WHITE if pill.on else Color(UIStyle.WHITE, 0.55))
		x += w + 18


## Tooltip del estado bajo el ratón: nombre, turnos que le quedan y qué hace.
func _draw_status_tooltip(c: Control, f: Dictionary) -> void:
	if not _hover.begins_with("status:"):
		return
	var status := _hover.substr(7)
	if not _status_rects.has(status) or not f.statuses.has(status):
		return
	var st: Dictionary = f.statuses[status]
	var title: String = SkillDB.STATUS_NAMES.get(status, status)
	var desc: String = SkillDB.STATUS_DESC.get(status, "")
	var turns := "Quedan %d turno%s." % [st.turns, "" if st.turns == 1 else "s"]
	if st.get("tick", 0) > 0:
		turns = "Pierdes ~%d PV por turno. %s" % [st.tick, turns]
	elif st.get("regen", 0) > 0:
		turns = "Recuperas %d PV por turno. %s" % [st.regen, turns]
	var w := 460.0
	var body_w := w - 44
	var font := UIStyle.FONT_REGULAR
	var desc_h := font.get_multiline_string_size(desc, HORIZONTAL_ALIGNMENT_LEFT, body_w, 19).y
	var h := 70.0 + desc_h + 40.0
	var anchor: Rect2 = _status_rects[status]
	var r := Rect2(anchor.position.x, anchor.position.y - h - 12, w, h)
	var shape := UIStyle.chamfer_rect(r, [0.0, 14.0, 0.0, 14.0])
	c.draw_colored_polygon(shape, Color(UIStyle.INK, 0.97))
	UIStyle.draw_outline(c, shape, UIStyle.VIOLET, 2.0)
	c.draw_colored_polygon(UIStyle.slanted_rect(Rect2(r.position.x + 20, r.position.y + 18, 7, 28), 5), UIStyle.VIOLET)
	c.draw_string(UIStyle.FONT_ITALIC, r.position + Vector2(38, 42), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UIStyle.WHITE)
	c.draw_line(r.position + Vector2(20, 58), r.position + Vector2(w - 20, 58), Color(UIStyle.WHITE, 0.25), 1.0)
	c.draw_multiline_string(font, r.position + Vector2(22, 84), desc, HORIZONTAL_ALIGNMENT_LEFT, body_w, 19, -1,
			Color(UIStyle.WHITE, 0.9))
	c.draw_string(UIStyle.FONT_SEMIBOLD, Vector2(r.position.x + 22, r.end.y - 18), turns, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 18, UIStyle.LIME)


func _draw_story(c: Control, f: Dictionary) -> void:
	_section_title(c, Vector2(600, 240), "Historia", 1580)
	var data := CharacterDB.get_character(f.id)
	var bio: String = data.get("bio", CharacterDB.profile(f.id).get("identity", {}).get("role", ""))
	if bio == "":
		bio = "Todavía no sabes mucho de esta persona."
	c.draw_multiline_string(UIStyle.FONT_REGULAR, Vector2(624, 300), bio, HORIZONTAL_ALIGNMENT_LEFT, 920, 26, -1,
			Color(UIStyle.WHITE, 0.92))
	var nature: String = SkillDB.NATURE_NAMES.get(f.nature, "—")
	_draw_pair(c, Vector2(624, 560), "Naturaleza:", nature)
	_draw_pair(c, Vector2(624, 606), "Nivel:", str(f.level))
	if f.id in GameState.levelled_ids():
		var next := ProgressionDB.xp_to_next(f.level)
		_draw_pair(c, Vector2(624, 652), "Experiencia:",
				"%d / %d para el nivel %d" % [GameState.xp_of(f.id), next, f.level + 1] if next > 0 else "Nivel máximo")


# --- Iconos pequeños ----------------------------------------------------------------------

func _chevron(c: Control, center: Vector2, up: bool, col: Color) -> void:
	var d := -1.0 if up else 1.0
	c.draw_polyline(PackedVector2Array([center + Vector2(-16, -8 * d), center + Vector2(0, 8 * d),
			center + Vector2(16, -8 * d)]), col, 3.0, true)


func _person_icon(c: Control, center: Vector2, col: Color) -> void:
	c.draw_circle(center + Vector2(0, -6), 7, col)
	c.draw_colored_polygon(PackedVector2Array([center + Vector2(-12, 14), center + Vector2(-9, 4),
			center + Vector2(9, 4), center + Vector2(12, 14)]), col)


func _book_icon(c: Control, center: Vector2, col: Color) -> void:
	for s in [-1.0, 1.0]:
		c.draw_polyline(PackedVector2Array([center + Vector2(0, -8), center + Vector2(14 * s, -12),
				center + Vector2(14 * s, 10), center + Vector2(0, 14), center + Vector2(0, -8)]), col, 2.5, true)
