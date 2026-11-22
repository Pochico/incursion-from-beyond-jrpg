extends Control
## Estudio de texturas: prepara imágenes para las superficies del dungeon crawler.
##
## 1. Formato: recorta la imagen a la proporción de la superficie (suelo, techo,
##    pared; ver TextureFormats) y mezcla los bordes para que se repita sin costuras.
## 2. Simplificar: desenfoque previo que funde el ruido fino en manchas.
##    Aplanado / Resalte: baja o sube saturación y contraste.
## 3. Posterizado: reduce los tonos por canal (0 = desactivado, 10 = 2 tonos).
## 4. Entintado: líneas en las fronteras entre formas (1 = ninguna, 10 = todas).
##
## Todo se calcula en un shader (vista previa en tiempo real). Al guardar se
## renderiza a la resolución final y se escribe un PNG en
## assets/textures/<tema>/<superficie>/<nombre>.png, junto a un .estilo.json con
## los ajustes usados (para repetir el mismo estilo en otras texturas).
##
## Abrir: desde el editor de Godot, abrir esta escena y pulsar F6, o desde el
## menú de inicio (botón «Estudio de texturas», solo al ejecutar desde el editor).

const SHADER := preload("res://src/tools/texture_studio/texture_studio.gdshader")
const TITLE_SCREEN := "res://src/screens/title/title_screen.tscn"
const SIDEBAR_W := 540.0

const REPEAT_LABELS := ["No", "Horizontal", "Horizontal y vertical"]

# --- Estado -------------------------------------------------------------------------
var _material: ShaderMaterial
var _source: Image
var _source_path := ""

var _surface := "suelo"
var _density := TextureFormats.DEFAULT_DENSITY
var _repeat: int = TextureFormats.Repeat.BOTH
var _seam := 0.15
var _zoom := 1.0
var _pan := Vector2(0.5, 0.5)      # centro del recorte, en UV de la imagen original

var _poster := 0                    # 0..10
var _ink := 1                       # 1..10
var _ink_width := 1.0               # px
var _ink_from_shape := true
var _tone := 0                      # −10..10
var _simplify := 3                  # 0..10

var _tiles := 1
var _compare := false
var _dragging := false

# --- Interfaz -------------------------------------------------------------------------
var _preview: Control
var _view: ColorRect
var _empty_hint: Label
var _info: Label
var _status: Label
var _surface_desc: Label
var _surface_opt: OptionButton
var _repeat_opt: OptionButton
var _theme_edit: LineEdit
var _name_edit: LineEdit
var _path_label: Label
var _sliders := {}                  # id -> HSlider
var _value_labels := {}             # id -> Label
var _tile_btn: Button
var _compare_btn: Button
var _open_dialog: FileDialog
var _save_dialog: FileDialog


func _ready() -> void:
	theme = ToolTheme.get_theme()
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_build_ui()
	get_window().files_dropped.connect(_on_files_dropped)
	_apply_surface_defaults()
	_refresh_all()


# =====================================================================================
# Construcción de la interfaz
# =====================================================================================

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 20)
	margin.add_child(root)

	# Cabecera
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	root.add_child(header)
	var title := Control.new()
	title.custom_minimum_size = Vector2(620, 76)
	title.draw.connect(_draw_title.bind(title))
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	header.add_child(_button("Abrir imagen…", _open_file))
	header.add_child(_button("Guardar", _save_default))
	header.add_child(_button("Guardar como…", _save_as))
	header.add_child(_button("Volver", _go_back))

	# Cuerpo: vista previa + panel lateral
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	root.add_child(body)

	_preview = Control.new()
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.clip_contents = true
	_preview.draw.connect(_draw_preview_bg)
	_preview.resized.connect(_layout_view)
	body.add_child(_preview)

	_view = ColorRect.new()
	_view.material = _material
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.gui_input.connect(_on_view_input)
	_view.mouse_default_cursor_shape = Control.CURSOR_MOVE
	_preview.add_child(_view)

	_empty_hint = Label.new()
	_empty_hint.text = "Arrastra una imagen aquí\no pulsa «Abrir imagen…»"
	_empty_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_empty_hint.add_theme_font_override("font", UIStyle.FONT_LIGHT_ITALIC)
	_empty_hint.add_theme_font_size_override("font_size", 34)
	_empty_hint.add_theme_color_override("font_color", Color(UIStyle.WHITE, 0.55))
	_empty_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.add_child(_empty_hint)

	var side := PanelContainer.new()
	side.custom_minimum_size = Vector2(SIDEBAR_W, 0)
	body.add_child(side)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 12)
	scroll.add_child(col)
	_build_sidebar(col)

	# Pie
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	root.add_child(footer)
	_compare_btn = _button("Comparar  [C]", Callable())
	_compare_btn.button_down.connect(func() -> void: _set_compare(true))
	_compare_btn.button_up.connect(func() -> void: _set_compare(false))
	footer.add_child(_compare_btn)
	_tile_btn = _button("Mosaico 3×3  [T]", _toggle_tiles)
	_tile_btn.toggle_mode = true
	footer.add_child(_tile_btn)
	_info = Label.new()
	_info.add_theme_color_override("font_color", Color(UIStyle.WHITE, 0.8))
	footer.add_child(_info)
	_status = Label.new()
	# Ocupa el espacio libre y recorta textos largos (rutas) para no ensanchar la ventana.
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.custom_minimum_size = Vector2(100, 0)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.clip_text = true
	_status.add_theme_font_override("font", UIStyle.FONT_REGULAR_ITALIC)
	_status.add_theme_color_override("font_color", UIStyle.LIME)
	footer.add_child(_status)

	# Diálogos de archivo (nativos en macOS/Windows).
	_open_dialog = FileDialog.new()
	_open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_open_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_open_dialog.use_native_dialog = true
	_open_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Imágenes"])
	_open_dialog.file_selected.connect(load_image_file)
	add_child(_open_dialog)

	_save_dialog = FileDialog.new()
	_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_save_dialog.use_native_dialog = true
	_save_dialog.filters = PackedStringArray(["*.png ; PNG"])
	_save_dialog.file_selected.connect(func(path: String) -> void: export_to(path))
	add_child(_save_dialog)


func _build_sidebar(col: VBoxContainer) -> void:
	# --- Formato ---
	col.add_child(_section("Formato"))
	var surf := OptionButton.new()
	_surface_opt = surf
	for id in TextureFormats.SURFACE_ORDER:
		surf.add_item(TextureFormats.SURFACES[id].name)
	surf.item_selected.connect(func(i: int) -> void:
		_surface = TextureFormats.SURFACE_ORDER[i]
		_apply_surface_defaults()
		_refresh_all())
	col.add_child(_field("Superficie", surf))
	_surface_desc = Label.new()
	_surface_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_surface_desc.add_theme_font_override("font", UIStyle.FONT_REGULAR_ITALIC)
	_surface_desc.add_theme_font_size_override("font_size", 18)
	_surface_desc.add_theme_color_override("font_color", Color(UIStyle.WHITE, 0.65))
	col.add_child(_surface_desc)

	var dens := OptionButton.new()
	for d in TextureFormats.DENSITIES:
		dens.add_item("%d px por metro" % d)
	dens.select(TextureFormats.DENSITIES.find(_density))
	dens.item_selected.connect(func(i: int) -> void:
		_density = TextureFormats.DENSITIES[i]
		_refresh_all())
	col.add_child(_field("Resolución", dens))

	_repeat_opt = OptionButton.new()
	for l in REPEAT_LABELS:
		_repeat_opt.add_item(l)
	_repeat_opt.item_selected.connect(func(i: int) -> void:
		_repeat = i
		_refresh_all())
	col.add_child(_field("Repetible (sin costuras)", _repeat_opt))

	_add_slider(col, "seam", "Mezcla de bordes", 5, 50, 1, 15, func(v: float) -> String: return "%d %%" % v,
			func(v: float) -> void: _seam = v / 100.0)
	_add_slider(col, "zoom", "Zoom del recorte", 100, 400, 5, 100, func(v: float) -> String: return "×%.2f" % (v / 100.0),
			func(v: float) -> void: _zoom = v / 100.0)
	var hint := Label.new()
	hint.text = "Arrastra la vista previa para mover el recorte; rueda para el zoom. La mezcla de bordes está pensada para texturas (ladrillo, baldosa…): en ilustraciones con objetos puede verlos duplicados."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color(UIStyle.WHITE, 0.5))
	col.add_child(hint)

	# --- Estilo ---
	col.add_child(_section("Estilo"))
	_add_slider(col, "simplify", "Simplificar", 0, 10, 1, _simplify,
			func(v: float) -> String: return "Desactivado" if v == 0 else "%d · %.1f px" % [v, _simplify_px(int(v))],
			func(v: float) -> void: _simplify = int(v))
	_add_slider(col, "tone", "Aplanado  ←  →  Resalte", -10, 10, 1, 0, _tone_text,
			func(v: float) -> void: _tone = int(v))
	_add_slider(col, "poster", "Posterizado", 0, 10, 1, 0, _poster_text,
			func(v: float) -> void: _poster = int(v))
	_add_slider(col, "ink", "Entintado", 1, 10, 1, 1, _ink_text,
			func(v: float) -> void: _ink = int(v))
	_add_slider(col, "ink_width", "Grosor de línea", 5, 30, 1, 10, func(v: float) -> String: return "%.1f px" % (v / 10.0),
			func(v: float) -> void: _ink_width = v / 10.0)
	var ink_col := OptionButton.new()
	ink_col.add_item("Oscuro de cada forma")
	ink_col.add_item("Tinta (negro violáceo)")
	ink_col.item_selected.connect(func(i: int) -> void:
		_ink_from_shape = i == 0
		_refresh_all())
	col.add_child(_field("Color de línea", ink_col))
	col.add_child(_button("Restablecer estilo", _reset_style))

	# --- Guardar ---
	col.add_child(_section("Guardar en el proyecto"))
	_theme_edit = LineEdit.new()
	_theme_edit.text = "pruebas"
	_theme_edit.text_changed.connect(func(_t: String) -> void: _refresh_path())
	col.add_child(_field("Tema", _theme_edit))
	_name_edit = LineEdit.new()
	_name_edit.text = "textura"
	_name_edit.text_changed.connect(func(_t: String) -> void: _refresh_path())
	col.add_child(_field("Nombre", _name_edit))
	_path_label = Label.new()
	_path_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_path_label.add_theme_font_size_override("font_size", 17)
	_path_label.add_theme_color_override("font_color", Color(UIStyle.LIME, 0.85))
	col.add_child(_path_label)


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	if action.is_valid():
		b.pressed.connect(action)
	return b


func _section(text: String) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 52)
	c.draw.connect(func() -> void:
		c.draw_colored_polygon(UIStyle.slanted_rect(Rect2(0, 14, 10, 30), 5), UIStyle.LIME)
		c.draw_string(UIStyle.FONT_BOLD_ITALIC, Vector2(22, 40), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UIStyle.WHITE)
		c.draw_line(Vector2(0, 50), Vector2(c.size.x, 50), Color(UIStyle.WHITE, 0.25), 1.0))
	return c


func _field(label: String, control: Control) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", 19)
	l.add_theme_color_override("font_color", Color(UIStyle.WHITE, 0.75))
	box.add_child(l)
	box.add_child(control)
	return box


func _add_slider(col: VBoxContainer, id: String, label: String, min_v: float, max_v: float, step: float,
		value: float, fmt: Callable, apply: Callable) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 19)
	l.add_theme_color_override("font_color", Color(UIStyle.WHITE, 0.75))
	row.add_child(l)
	var v := Label.new()
	v.add_theme_font_override("font", UIStyle.FONT_MEDIUM)
	v.add_theme_font_size_override("font_size", 19)
	v.add_theme_color_override("font_color", UIStyle.LIME)
	row.add_child(v)
	box.add_child(row)
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(0, 28)
	s.value_changed.connect(func(nv: float) -> void:
		apply.call(nv)
		v.text = fmt.call(nv)
		_refresh_all())
	v.text = fmt.call(value)
	box.add_child(s)
	col.add_child(box)
	_sliders[id] = s
	_value_labels[id] = v


func _tone_text(v: float) -> String:
	if v == 0:
		return "Neutro"
	return ("Aplanado %d" % -v) if v < 0 else ("Resalte %d" % v)


func _poster_text(v: float) -> String:
	return "Desactivado" if v == 0 else "%d · %d tonos/canal" % [v, _poster_steps(int(v))]


func _ink_text(v: float) -> String:
	return "1 · sin líneas" if v <= 1 else "%d" % v


# =====================================================================================
# Parámetros → shader
# =====================================================================================

func _poster_steps(level: int) -> int:
	if level <= 0:
		return 0
	return roundi(lerpf(20.0, 2.0, (level - 1) / 9.0))


func _ink_threshold(level: int) -> float:
	if level <= 1:
		return 10.0
	return 0.30 * pow(0.05 / 0.30, (level - 2) / 8.0)


func _simplify_px(level: int) -> float:
	return level * 0.8


func _out_size() -> Vector2i:
	return TextureFormats.pixel_size(_surface, _density)


func _apply_surface_defaults() -> void:
	_repeat = TextureFormats.SURFACES[_surface].repeat
	if _surface_opt:
		_surface_opt.select(TextureFormats.SURFACE_ORDER.find(_surface))
	if _repeat_opt:
		_repeat_opt.select(_repeat)


func _refresh_all() -> void:
	var out := _out_size()
	var m := _material
	m.set_shader_parameter("has_source", _source != null)
	m.set_shader_parameter("out_size", Vector2(out))
	m.set_shader_parameter("tiles", float(_tiles))
	m.set_shader_parameter("show_original", _compare)
	m.set_shader_parameter("seamless_x", _repeat != TextureFormats.Repeat.NONE)
	m.set_shader_parameter("seamless_y", _repeat == TextureFormats.Repeat.BOTH)
	m.set_shader_parameter("seam_width", _seam)
	m.set_shader_parameter("tone", _tone / 10.0)
	m.set_shader_parameter("poster_steps", _poster_steps(_poster))
	m.set_shader_parameter("smooth_px", _simplify_px(_simplify))
	m.set_shader_parameter("ink_threshold", _ink_threshold(_ink))
	m.set_shader_parameter("ink_px", _ink_width)
	m.set_shader_parameter("ink_from_shape", 1.0 if _ink_from_shape else 0.0)
	_update_crop()

	var surf: Dictionary = TextureFormats.SURFACES[_surface]
	_surface_desc.text = surf.desc
	var sm: Vector2 = surf.size_m
	_info.text = "%d × %d px  ·  %s × %s m" % [out.x, out.y, _m(sm.x), _m(sm.y)]
	_empty_hint.visible = _source == null
	_refresh_path()
	_layout_view()


func _m(v: float) -> String:
	return ("%.1f" % v).replace(".", ",")


func _update_crop() -> void:
	if _source == null:
		return
	var out := Vector2(_out_size())
	var src_aspect := float(_source.get_width()) / _source.get_height()
	var out_aspect := out.x / out.y
	var base := Vector2.ONE
	if src_aspect > out_aspect:
		base.x = out_aspect / src_aspect
	else:
		base.y = src_aspect / out_aspect
	var size := base / _zoom
	var pos := (_pan - size * 0.5).clamp(Vector2.ZERO, Vector2.ONE - size)
	_pan = pos + size * 0.5
	_material.set_shader_parameter("crop_pos", pos)
	_material.set_shader_parameter("crop_size", size)


func _layout_view() -> void:
	if _preview == null:
		return
	var area := _preview.size - Vector2(40, 40)
	var out := Vector2(_out_size())
	var s := minf(area.x / out.x, area.y / out.y)
	var vs := (out * s).floor()
	_view.size = vs
	_view.position = ((_preview.size - vs) * 0.5).floor()
	_view.visible = _source != null
	_preview.queue_redraw()


func _refresh_path() -> void:
	if _path_label:
		_path_label.text = TextureFormats.output_path(_clean(_theme_edit.text), _surface, _clean(_name_edit.text))


func _clean(text: String) -> String:
	var t := text.strip_edges().to_lower().replace(" ", "_")
	var accents := {"á": "a", "é": "e", "í": "i", "ó": "o", "ú": "u", "ü": "u", "ñ": "n"}
	for ch: String in accents:
		t = t.replace(ch, accents[ch])
	var out := ""
	for ch in t:
		if ch.is_valid_identifier() or ch.is_valid_int() or ch == "-" or ch == "_":
			out += ch
	return out if out != "" else "textura"


# =====================================================================================
# Carga y guardado
# =====================================================================================

## Carga una imagen del disco (ruta del sistema o res://).
func load_image_file(path: String) -> bool:
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		_set_status("No se pudo abrir «%s»." % path.get_file(), true)
		return false
	img.convert(Image.FORMAT_RGBA8)
	img.generate_mipmaps()
	_source = img
	_source_path = path
	_material.set_shader_parameter("source", ImageTexture.create_from_image(img))
	_pan = Vector2(0.5, 0.5)
	_zoom = 1.0
	_sliders["zoom"].set_value_no_signal(100)
	_value_labels["zoom"].text = "×1.00"
	_name_edit.text = _clean(path.get_file().get_basename())
	_set_status("Abierta: %s (%d × %d px)" % [path.get_file(), img.get_width(), img.get_height()])
	_refresh_all()
	return true


func _on_files_dropped(files: PackedStringArray) -> void:
	if files.size() > 0:
		load_image_file(files[0])


func _open_file() -> void:
	_open_dialog.popup_centered_ratio(0.6)


func _save_default() -> void:
	var path := TextureFormats.output_path(_clean(_theme_edit.text), _surface, _clean(_name_edit.text))
	export_to(path)


func _save_as() -> void:
	if _source == null:
		_set_status("Primero abre una imagen.", true)
		return
	_save_dialog.current_file = _clean(_name_edit.text) + ".png"
	_save_dialog.popup_centered_ratio(0.6)


## Renderiza la textura a su resolución final y la guarda como PNG (+ .estilo.json).
func export_to(path: String) -> Error:
	if _source == null:
		_set_status("Primero abre una imagen.", true)
		return ERR_UNCONFIGURED
	var img := await render_output()
	var abs_dir := ProjectSettings.globalize_path(path.get_base_dir())
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var err := img.save_png(path)
	if err != OK:
		_set_status("Error %d al guardar %s" % [err, path], true)
		return err
	var meta := FileAccess.open(path.get_basename() + ".estilo.json", FileAccess.WRITE)
	if meta:
		meta.store_string(JSON.stringify(settings(), "\t"))
	_set_status("Guardada: %s" % path)
	return OK


## Renderiza la salida (sin mosaico ni comparación) a la resolución del formato.
func render_output() -> Image:
	var out := _out_size()
	var vp := SubViewport.new()
	vp.size = out
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var rect := ColorRect.new()
	rect.size = Vector2(out)
	var mat := _material.duplicate() as ShaderMaterial
	mat.set_shader_parameter("tiles", 1.0)
	mat.set_shader_parameter("show_original", false)
	rect.material = mat
	vp.add_child(rect)
	add_child(vp)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	img.convert(Image.FORMAT_RGB8)
	return img


## Ajustes actuales (se guardan junto a cada textura).
func settings() -> Dictionary:
	return {
		"origen": _source_path,
		"superficie": _surface,
		"resolucion": [_out_size().x, _out_size().y],
		"densidad_px_m": _density,
		"repetible": REPEAT_LABELS[_repeat],
		"mezcla_bordes": _seam,
		"zoom_recorte": _zoom,
		"centro_recorte": [_pan.x, _pan.y],
		"simplificar": _simplify,
		"aplanado_resalte": _tone,
		"posterizado": _poster,
		"entintado": _ink,
		"grosor_linea": _ink_width,
		"color_linea": "forma" if _ink_from_shape else "tinta",
	}


## Aplica ajustes de estilo por código (útil para pruebas o lotes).
func set_style(poster: int, ink: int, tone: int, ink_width: float = 1.0, simplify: int = 3) -> void:
	_sliders["simplify"].value = simplify
	_sliders["poster"].value = poster
	_sliders["ink"].value = ink
	_sliders["tone"].value = tone
	_sliders["ink_width"].value = ink_width * 10.0


func set_surface(surface: String) -> void:
	_surface = surface
	_apply_surface_defaults()
	_refresh_all()


func _reset_style() -> void:
	set_style(0, 1, 0, 1.0)
	_set_status("Estilo restablecido.")


func _go_back() -> void:
	SceneRouter.go_to(TITLE_SCREEN)


func _set_status(text: String, error := false) -> void:
	_status.text = text
	_status.tooltip_text = text
	_status.add_theme_color_override("font_color", UIStyle.RED if error else UIStyle.LIME)


# =====================================================================================
# Vista previa: arrastre, zoom, comparar, mosaico
# =====================================================================================

func _on_view_input(event: InputEvent) -> void:
	if _source == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var z: float = _sliders["zoom"].value * (1.08 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.08)
			_sliders["zoom"].value = clampf(z, 100, 400)
	elif event is InputEventMouseMotion and _dragging:
		var crop: Vector2 = _material.get_shader_parameter("crop_size")
		_pan -= (event as InputEventMouseMotion).relative / _view.size * crop * _tiles
		_update_crop()


func _set_compare(on: bool) -> void:
	_compare = on
	_material.set_shader_parameter("show_original", on)


func _toggle_tiles() -> void:
	_tiles = 3 if _tile_btn.button_pressed else 1
	_refresh_all()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or key.echo:
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	match key.keycode:
		KEY_C:
			_set_compare(key.pressed)
		KEY_T:
			if key.pressed:
				_tile_btn.button_pressed = not _tile_btn.button_pressed
				_toggle_tiles()


# =====================================================================================
# Dibujo
# =====================================================================================

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UIStyle.INK)


func _draw_title(c: Control) -> void:
	c.draw_colored_polygon(UIStyle.slanted_rect(Rect2(0, 6, 12, 60), 5), UIStyle.LIME)
	c.draw_string(UIStyle.FONT_HEAVY_ITALIC, Vector2(28, 46), "Estudio de texturas", HORIZONTAL_ALIGNMENT_LEFT, -1, 44, UIStyle.WHITE)
	UIStyle.draw_spaced(c, UIStyle.FONT_REGULAR, Vector2(30, 72), "SUELO · TECHO · PARED  —  DUNGEON CRAWLER", 15, 3.0, Color(UIStyle.WHITE, 0.6))


func _draw_preview_bg() -> void:
	var s := _preview.size
	# Damero para ver bordes y transparencias.
	var cell := 24.0
	_preview.draw_rect(Rect2(Vector2.ZERO, s), Color("1a1a20"))
	var y := 0.0
	var row := 0
	while y < s.y:
		var x := (row % 2) * cell
		while x < s.x:
			_preview.draw_rect(Rect2(x, y, cell, cell), Color("202028"))
			x += cell * 2
		y += cell
		row += 1
	var frame := UIStyle.chamfer_rect(Rect2(Vector2(1, 1), s - Vector2(2, 2)), [0.0, 26.0, 0.0, 26.0])
	UIStyle.draw_outline(_preview, frame, UIStyle.LINE, 1.5)
