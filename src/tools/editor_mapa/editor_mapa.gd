extends Control
## Editor del mapa 3D: vista, iluminación por horas, colores, capa gris y
## ubicaciones (posición, nombre, descripción y puntos nuevos). Guarda en MapConfig.PATH.
##
## Abrir la escena editor_mapa.tscn y pulsar F6 (o «Ejecutar escena actual»).
## La vista tiene la misma proporción que el mapa del juego. En el juego el mapa
## sale siempre recto y entero: aquí el giro y el zoom solo sirven para trabajar
## (no se guardan); «Ver como en el juego» vuelve a ese encuadre.
## Ratón sobre el mapa:
##  - Clic derecho + arrastrar: girar la cámara.  Rueda / pellizco: acercar.
##  - Clic central + arrastrar, Mayús + clic derecho, dos dedos o WASD: desplazar.
##  - Clic izquierdo: coloca la ubicación seleccionada en la lista; sobre un
##    marcador, lo selecciona y se puede arrastrar.
## Ctrl/Cmd + S guarda.

const PANEL_W := 500.0
const ORBIT_SPEED := 0.25        ## grados por píxel
const PAN_KEYS_SPEED := 0.6      ## fracción de la distancia por segundo

var _cfg: Dictionary
var _map: CityMap
var _area: Control               ## Zona izquierda (la vista va centrada dentro)
var _view: SubViewportContainer
var _selected := ""
var _dragging := false
var _syncing := false            ## true mientras se actualizan los controles desde código
var _key := 0                    ## Momento del día que se está editando
var _hour := 13.0                ## Hora de la vista previa

var _title: Label
var _status: Label

var _light_controls := {}        ## clave del momento -> HSlider o ColorPickerButton
var _key_buttons: Array[Button] = []
var _hour_slider: HSlider
var _hour_label: Label
var _rows_box: VBoxContainer
var _hidden_box: VBoxContainer
var _rows := {}                  ## id de ubicación -> {button, state, remove}
var _name_edit: LineEdit
var _desc_edit: LineEdit
var _loc_editor: Control


func _ready() -> void:
	_cfg = MapConfig.load_config()
	MapConfig.set_current(_cfg)   # LocationDB lee de aquí los nombres y los puntos nuevos.
	var theme_ := Theme.new()
	theme_.default_font = UIStyle.FONT_REGULAR
	theme_.default_font_size = 19
	theme = theme_

	_area = ColorRect.new()
	(_area as ColorRect).color = UIStyle.GRAPHITE
	_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_area.offset_right = -PANEL_W
	_area.resized.connect(_fit_view)
	add_child(_area)
	_view = SubViewportContainer.new()
	_view.stretch = true
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.gui_input.connect(_on_view_input)
	_area.add_child(_view)
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.handle_input_locally = false
	_view.add_child(vp)
	_map = CityMap.new()
	_map.cfg = _cfg
	vp.add_child(_map)

	_build_panel()
	_select_key(_key_for_hour(13.0))
	_rebuild_rows()
	_select("")
	_set_dirty(false)
	_fit_view()
	_frame_game.call_deferred()


func _frame_game() -> void:
	_map.pitch = _cfg.camera.pitch
	_map.frame_all()


## La vista ocupa la zona izquierda con la proporción del mapa del juego.
func _fit_view() -> void:
	if _view == null:
		return
	var avail := _area.size - Vector2(40, 40)
	var aspect := MapConfig.VIEW_SIZE.x / MapConfig.VIEW_SIZE.y
	var s := Vector2(avail.x, avail.x / aspect)
	if s.y > avail.y:
		s = Vector2(avail.y * aspect, avail.y)
	_view.size = s
	_view.position = (_area.size - s) * 0.5
	if _map and _map.camera:
		_frame_game.call_deferred()


# --- Panel ---------------------------------------------------------------------------

func _build_panel() -> void:
	var bg := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UIStyle.INK, 0.96)
	sb.border_color = Color(UIStyle.WHITE, 0.15)
	sb.border_width_left = 1
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	bg.add_theme_stylebox_override("panel", sb)
	bg.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	bg.offset_left = -PANEL_W
	add_child(bg)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	bg.add_child(outer)

	_title = Label.new()
	_title.add_theme_font_override("font", UIStyle.FONT_HEAVY_ITALIC)
	_title.add_theme_font_size_override("font_size", 30)
	outer.add_child(_title)
	var help := _small("Clic derecho: girar · Rueda o pellizco: zoom · Clic central, dos dedos o WASD: mover · Clic izquierdo: colocar o arrastrar ubicaciones · Cmd+S: guardar")
	outer.add_child(help)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_right", 18)   # hueco para la barra de desplazamiento
	scroll.add_child(margin)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	_build_locations(box)
	_build_view(box)
	_build_lighting(box)
	_build_colors(box)

	var save := Button.new()
	save.text = "Guardar"
	save.custom_minimum_size.y = 52
	save.add_theme_font_override("font", UIStyle.FONT_SEMIBOLD)
	save.add_theme_font_size_override("font_size", 22)
	save.pressed.connect(_save)
	outer.add_child(save)
	_status = _small("")
	outer.add_child(_status)


func _build_locations(box: VBoxContainer) -> void:
	_section(box, "Ubicaciones")
	box.add_child(_small("Elige una y haz clic en el mapa para colocarla. Las que no se han colocado salen con «(?)» en una posición provisional."))
	_rows_box = VBoxContainer.new()
	box.add_child(_rows_box)
	var add := Button.new()
	add.text = "+ Nuevo punto"
	add.pressed.connect(_new_point)
	box.add_child(add)
	_hidden_box = VBoxContainer.new()
	box.add_child(_hidden_box)
	# Edición de la ubicación seleccionada.
	var ed := VBoxContainer.new()
	_loc_editor = ed
	box.add_child(ed)
	_name_edit = _line(ed, "Nombre", func(t: String) -> void: _set_text("names", t))
	_desc_edit = _line(ed, "Descripción", func(t: String) -> void: _set_text("descs", t))


func _build_view(box: VBoxContainer) -> void:
	_section(box, "Vista")
	box.add_child(_small("En el juego el mapa sale recto (norte arriba) y entero, con esta inclinación. El giro y el zoom del ratón solo sirven para trabajar aquí."))
	_slider(box, "Inclinación", 15, 89, 1, _cfg.camera.pitch, func(v: float) -> void: _set_camera("pitch", v))
	_slider(box, "Campo de visión", 15, 90, 1, _cfg.camera.fov, func(v: float) -> void: _set_camera("fov", v))
	var reset := Button.new()
	reset.text = "Ver como en el juego"
	reset.pressed.connect(_frame_game)
	box.add_child(reset)
	_slider(box, "Capa gris", 0, 1, 0.01, _cfg.veil.amount, func(v: float) -> void: _set_value(_cfg.veil, "amount", v))
	_color(box, "Color de la capa", _cfg.veil.color, func(c: Color) -> void: _set_value(_cfg.veil, "color", "#" + c.to_html(false)))


func _build_lighting(box: VBoxContainer) -> void:
	_section(box, "Iluminación según la hora")
	box.add_child(_small("En el juego, cada franja del día usa su hora: mañana 8:00, día 13:00, tarde 19:30 y noche 23:00 (GameState.TIME_SLOTS). Entre un momento y el siguiente, la luz se mezcla poco a poco."))
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = "Ver a las"
	l.custom_minimum_size.x = 150
	row.add_child(l)
	_hour_slider = HSlider.new()
	_hour_slider.min_value = 0
	_hour_slider.max_value = 23.75
	_hour_slider.step = 0.25
	_hour_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hour_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hour_slider.value_changed.connect(_set_preview_hour)
	row.add_child(_hour_slider)
	_hour_label = Label.new()
	_hour_label.custom_minimum_size.x = 150
	_hour_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_hour_label)
	box.add_child(row)

	var keys_row := HBoxContainer.new()
	var group := ButtonGroup.new()
	for i in _cfg.lighting.keys.size():
		var b := Button.new()
		b.text = _cfg.lighting.keys[i].name
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void: _select_key(i))
		keys_row.add_child(b)
		_key_buttons.append(b)
	box.add_child(keys_row)

	_light_controls.hour = _slider(box, "Hora del momento", 0, 23.75, 0.25, 0, func(v: float) -> void: _set_key("hour", v))
	_light_controls.azimuth = _slider(box, "Dirección", 0, 360, 1, 0, func(v: float) -> void: _set_key("azimuth", v))
	_light_controls.elevation = _slider(box, "Altura", 2, 90, 1, 0, func(v: float) -> void: _set_key("elevation", v))
	_light_controls.energy = _slider(box, "Intensidad", 0, 3, 0.05, 0, func(v: float) -> void: _set_key("energy", v))
	_light_controls.color = _color(box, "Color de la luz", "#ffffff", func(c: Color) -> void: _set_key("color", "#" + c.to_html(false)))
	_light_controls.ambient_energy = _slider(box, "Luz ambiente", 0, 2, 0.05, 0, func(v: float) -> void: _set_key("ambient_energy", v))
	_light_controls.ambient = _color(box, "Color ambiente", "#ffffff", func(c: Color) -> void: _set_key("ambient", "#" + c.to_html(false)))
	_light_controls.windows = _slider(box, "Ventanas encendidas", 0, 1, 0.05, 0, func(v: float) -> void: _set_key("windows", v))
	var shadows := CheckBox.new()
	shadows.text = "Sombras"
	shadows.button_pressed = _cfg.lighting.shadows
	shadows.toggled.connect(func(on: bool) -> void: _set_value(_cfg.lighting, "shadows", on))
	box.add_child(shadows)


func _build_colors(box: VBoxContainer) -> void:
	_section(box, "Colores del modelo")
	for key: String in MapConfig.COLOR_NAMES:
		_color(box, MapConfig.COLOR_NAMES[key], _cfg.colors[key],
				func(c: Color) -> void: _set_value(_cfg.colors, key, "#" + c.to_html(false)))


func _rebuild_rows() -> void:
	for c in _rows_box.get_children():
		c.queue_free()
	_rows.clear()
	var group := ButtonGroup.new()
	group.allow_unpress = true
	for id: String in LocationDB.map_ids():
		var row := HBoxContainer.new()
		var btn := Button.new()
		btn.toggle_mode = true
		btn.button_group = group
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.clip_text = true
		btn.toggled.connect(func(on: bool) -> void:
			if on:
				_select(id)
			elif _selected == id:
				_select(""))
		row.add_child(btn)
		var state := Label.new()
		state.custom_minimum_size.x = 96
		state.add_theme_font_size_override("font_size", 15)
		row.add_child(state)
		var remove := Button.new()
		remove.text = "Quitar"
		remove.tooltip_text = "Quita la posición (vuelve a la provisional)."
		remove.pressed.connect(_unplace.bind(id))
		row.add_child(remove)
		var delete := Button.new()
		delete.text = "Borrar"
		delete.pressed.connect(_delete.bind(id))
		if id in LocationDB.required_ids():
			delete.disabled = true
			delete.tooltip_text = "No se puede borrar: es la casa o un destino de la historia."
		else:
			delete.tooltip_text = "La borra del mapa."
		row.add_child(delete)
		_rows_box.add_child(row)
		_rows[id] = {"button": btn, "state": state, "remove": remove}
	# Borradas: se pueden recuperar.
	for c in _hidden_box.get_children():
		c.queue_free()
	if not _cfg.hidden.is_empty():
		_hidden_box.add_child(_small("Borradas del mapa:"))
		for id: String in _cfg.hidden:
			var row := HBoxContainer.new()
			var l := Label.new()
			l.text = LocationDB.ALL.get(id, {}).get("name", id)
			l.modulate = Color(1, 1, 1, 0.5)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			var restore := Button.new()
			restore.text = "Recuperar"
			restore.pressed.connect(func() -> void:
				_cfg.hidden.erase(id)
				_rebuild_rows()
				_points_changed())
			row.add_child(restore)
			_hidden_box.add_child(row)
	_refresh_rows()


func _section(box: VBoxContainer, text: String) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	box.add_child(gap)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UIStyle.FONT_SEMIBOLD)
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", UIStyle.LIME)
	box.add_child(l)
	box.add_child(HSeparator.new())


func _small(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.modulate = Color(1, 1, 1, 0.6)
	return l


func _slider(box: VBoxContainer, text: String, lo: float, hi: float, step: float, value: float, on_change: Callable) -> HSlider:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = 190
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var v := Label.new()
	v.custom_minimum_size.x = 64
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.text = _fmt(value, step)
	row.add_child(v)
	s.value_changed.connect(func(x: float) -> void:
		v.text = _fmt(x, step)
		if not _syncing:
			on_change.call(x))
	box.add_child(row)
	return s


func _color(box: VBoxContainer, text: String, value: String, on_change: Callable) -> ColorPickerButton:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var p := ColorPickerButton.new()
	p.color = Color(value)
	p.edit_alpha = false
	p.custom_minimum_size = Vector2(120, 34)
	p.color_changed.connect(func(c: Color) -> void:
		if not _syncing:
			on_change.call(c))
	row.add_child(p)
	box.add_child(row)
	return p


func _line(box: VBoxContainer, text: String, on_change: Callable) -> LineEdit:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = 130
	row.add_child(l)
	var e := LineEdit.new()
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.text_changed.connect(func(t: String) -> void:
		if not _syncing:
			on_change.call(t))
	row.add_child(e)
	box.add_child(row)
	return e


static func _fmt(v: float, step: float) -> String:
	if step == 0.25:
		return "%02d:%02d" % [int(v), int(fmod(v, 1.0) * 60.0)]
	return str(int(round(v))) if step >= 1.0 else "%.2f" % v


# --- Cambios -------------------------------------------------------------------------

func _set_value(dict: Dictionary, key: String, value: Variant) -> void:
	dict[key] = value
	_map.apply(_cfg)
	_set_dirty(true)


## Inclinación o campo de visión: se guardan y se vuelve al encuadre del juego.
func _set_camera(key: String, value: float) -> void:
	_cfg.camera[key] = value
	_map.camera.fov = _cfg.camera.fov
	_frame_game()
	_set_dirty(true)


func _key_for_hour(h: float) -> int:
	var best := 0
	var best_d := 99.0
	for i in _cfg.lighting.keys.size():
		var d := absf(fposmod(h - _cfg.lighting.keys[i].hour + 12.0, 24.0) - 12.0)
		if d < best_d:
			best_d = d
			best = i
	return best


## Edita el momento `i` y pone la vista previa a su hora.
func _select_key(i: int) -> void:
	_key = i
	_key_buttons[i].set_pressed_no_signal(true)
	var k: Dictionary = _cfg.lighting.keys[i]
	_syncing = true
	for key: String in _light_controls:
		var c: Control = _light_controls[key]
		if c is ColorPickerButton:
			(c as ColorPickerButton).color = Color(k[key])
		else:
			(c as HSlider).value = k[key]
	_syncing = false
	_hour_slider.value = k.hour   # llama a _set_preview_hour


func _set_key(key: String, value: Variant) -> void:
	_cfg.lighting.keys[_key][key] = value
	if key == "hour":
		_hour_slider.set_value_no_signal(value)
	_set_preview_hour(_hour_slider.value)
	_set_dirty(true)


func _set_preview_hour(h: float) -> void:
	_hour = h
	_map.set_hour(h)
	_hour_label.text = "%02d:%02d · %s" % [int(h), int(fmod(h, 1.0) * 60.0), MapConfig.light_at(_cfg, h).name]


func _set_text(field: String, text: String) -> void:
	if _selected == "":
		return
	var original: String = LocationDB.ALL.get(_selected, {}).get("name" if field == "names" else "desc", "")
	# Si coincide con el original (y no es un punto nuevo), no hace falta guardarlo.
	if text == original and not (_selected in _cfg.custom):
		_cfg[field].erase(_selected)
	else:
		_cfg[field][_selected] = text
	_map.apply(_cfg)
	_refresh_rows()
	_set_dirty(true)


func _points_changed() -> void:
	_map.apply(_cfg)
	_refresh_rows()
	_set_dirty(true)


func _new_point() -> void:
	var n := 1
	while LocationDB.ALL.has("punto_%d" % n) or ("punto_%d" % n) in _cfg.custom:
		n += 1
	var id := "punto_%d" % n
	_cfg.custom.append(id)
	_cfg.names[id] = "Nuevo punto %d" % n
	_cfg.descs[id] = ""
	_rebuild_rows()
	_select(id)
	_map.apply(_cfg)
	_set_dirty(true)
	_status.text = "Haz clic en el mapa para colocar «%s» y ponle nombre abajo." % _cfg.names[id]
	_name_edit.grab_focus()
	_name_edit.select_all()


## «Quitar»: borra solo la posición (vuelve a la provisional).
func _unplace(id: String) -> void:
	_cfg.points.erase(id)
	_points_changed()


## «Borrar»: la quita del mapa. Un punto nuevo se borra del todo; una ubicación
## del juego pasa a «Borradas» y se puede recuperar.
func _delete(id: String) -> void:
	_cfg.points.erase(id)
	if id in _cfg.custom:
		_cfg.custom.erase(id)
		_cfg.names.erase(id)
		_cfg.descs.erase(id)
	elif not (id in _cfg.hidden):
		_cfg.hidden.append(id)
	if _selected == id:
		_select("")
	_rebuild_rows()
	_points_changed()


func _select(id: String) -> void:
	_selected = id
	_map.set_highlight(id)
	if id != "" and _rows.has(id) and not (_rows[id].button as Button).button_pressed:
		(_rows[id].button as Button).set_pressed_no_signal(true)
	_loc_editor.visible = id != ""
	if id != "":
		var loc := LocationDB.get_location(id)
		_syncing = true
		_name_edit.text = loc.get("name", "")
		_desc_edit.text = loc.get("desc", "")
		_syncing = false
	_refresh_rows()


func _refresh_rows() -> void:
	for id: String in _rows:
		var placed: bool = _cfg.points.has(id)
		var custom: bool = id in _cfg.custom
		(_rows[id].button as Button).text = LocationDB.display_name(id)
		var state: Label = _rows[id].state
		state.text = "colocada" if placed else "sin colocar"
		state.modulate = UIStyle.LIME if placed else Color(1, 1, 1, 0.45)
		(_rows[id].remove as Button).disabled = not placed


func _set_dirty(on: bool) -> void:
	_title.text = "Editor del mapa" + ("  •" if on else "")
	if _status and on:
		_status.text = "Cambios sin guardar."
		_status.modulate = Color(1, 1, 1, 0.6)


func _save() -> void:
	var err := MapConfig.save_config(_cfg)
	_set_dirty(err != OK)
	_status.text = ("Guardado en %s" % MapConfig.PATH) if err == OK else ("No se pudo guardar: %s" % error_string(err))
	_status.modulate = UIStyle.LIME if err == OK else UIStyle.RED


# --- Entrada sobre el mapa -------------------------------------------------------------

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_S and event.is_command_or_control_pressed():
		_save()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# WASD / flechas: desplazar, solo con el ratón sobre el mapa y sin texto enfocado.
	if not _view.get_global_rect().has_point(get_global_mouse_position()):
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): v.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): v.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): v.y -= 1
	if Input.is_physical_key_pressed(KEY_S) and not Input.is_key_pressed(KEY_META) and not Input.is_key_pressed(KEY_CTRL): v.y += 1
	if Input.is_physical_key_pressed(KEY_DOWN): v.y += 1
	if v != Vector2.ZERO:
		_pan_world(v.normalized() * _map.distance * PAN_KEYS_SPEED * delta)


func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_view.grab_focus()   # Suelta el foco de los campos de texto.
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom(0.9)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom(1.0 / 0.9)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_on_left_click(mb.position)
			else:
				_dragging = false
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var right := mm.button_mask & MOUSE_BUTTON_MASK_RIGHT != 0
		var middle := mm.button_mask & MOUSE_BUTTON_MASK_MIDDLE != 0
		if middle or (right and mm.shift_pressed):
			_pan_screen(mm.relative)
		elif right:
			_map.yaw = wrapf(_map.yaw - mm.relative.x * ORBIT_SPEED, -180.0, 180.0)
			_map.pitch = clampf(_map.pitch + mm.relative.y * ORBIT_SPEED, 10.0, 89.0)
			_map.update_camera()
		elif _dragging and _selected != "":
			_place(_selected, mm.position)
	elif event is InputEventMagnifyGesture:
		_zoom(1.0 / (event as InputEventMagnifyGesture).factor)
	elif event is InputEventPanGesture:
		_pan_screen(-(event as InputEventPanGesture).delta * 12.0)


func _on_left_click(pos: Vector2) -> void:
	var hit := _map.marker_at(pos)
	if hit != "":
		_select(hit)
		_dragging = true
	elif _selected != "":
		_place(_selected, pos)
		_dragging = true


func _place(id: String, pos: Vector2) -> void:
	var p = _map.ground_point(pos)
	if p == null:
		return
	var half := _map.map_size * 0.5
	_cfg.points[id] = [snappedf(clampf(p.x, -half.x, half.x), 0.1), snappedf(clampf(p.z, -half.y, half.y), 0.1)]
	_points_changed()


func _zoom(factor: float) -> void:
	_map.distance = clampf(_map.distance * factor, 150.0, 20000.0)
	_map.update_camera()


## Desplaza arrastrando: el punto del suelo bajo el ratón se queda bajo el ratón.
func _pan_screen(relative: Vector2) -> void:
	var center := _view.size * 0.5
	var a = _map.ground_point(center)
	var b = _map.ground_point(center + relative)
	if a == null or b == null:
		return
	var d: Vector3 = a - b
	_map.target += Vector2(d.x, d.z)
	_map.update_camera()


## Desplaza en metros relativos a la orientación de la cámara (x = derecha, y = atrás).
func _pan_world(v: Vector2) -> void:
	var yaw := deg_to_rad(_map.yaw)
	var right := Vector2(cos(yaw), -sin(yaw))
	var back := Vector2(sin(yaw), cos(yaw))
	_map.target += right * v.x + back * v.y
	_map.update_camera()
