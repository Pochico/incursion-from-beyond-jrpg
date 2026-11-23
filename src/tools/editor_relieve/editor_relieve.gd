extends Control
## Editor de relieve: marca qué zonas de una textura salen o se meten, para darle
## un poco de volumen en 3D (como en los juegos antiguos: parallax + luz).
##
## Cuatro niveles, de dentro a fuera: Hueco, Base, Placa y Placa saliente.
## Herramientas:
##  - Rellenar zona [F]: clic en una placa y se rellena todo lo de color parecido
##    que esté unido (varita mágica; la tolerancia se ajusta).
##  - Rectángulo [R]: arrastrar.
##  - Pincel [B]: pintar a mano.
##  - Lazo [L]: clic a clic se ponen puntos; al cerrar (clic en el primero,
##    doble clic o Intro) se rellena lo que queda dentro.
## Clic izquierdo = el nivel elegido (teclas 1–4); clic derecho = Base (borrar).
##
## Guarda junto a la textura, en <superficie>/relieve/:
##  - <nombre>.png          altura en grises (suavizada): la que usa el juego.
##  - <nombre>.niveles.png  los niveles tal cual, para seguir editando.
## La profundidad es del tema («relieve» en tema.json).
##
## Se abre desde el editor de mazmorras (botón «Relieve…» de la paleta), con la
## textura elegida; «Volver» regresa con el mapa como estaba. También abriendo
## esta escena y pulsando F6.

const TITLE_SCREEN := "res://src/screens/title/title_screen.tscn"
const SIDEBAR_W := 560.0
const PREVIEW_H := 260.0
const UNDO_MAX := 30
## El relieve se marca a mitad de resolución (de sobra para el volumen y más rápido).
const WORK_SCALE := 0.5

const LEVELS := [
	{"name": "Hueco", "height": 0, "color": Color("2f6bff")},
	{"name": "Base", "height": 110, "color": Color(0, 0, 0, 0)},
	{"name": "Placa", "height": 185, "color": Color("c8f53a")},
	{"name": "Placa saliente", "height": 255, "color": Color("ff3dbb")},
]
const BASE := 1
const TOOLS := ["fill", "lasso", "rect", "brush"]
const TOOL_LABELS := {"fill": "Rellenar zona  [F]", "lasso": "Lazo  [L]", "rect": "Rectángulo  [R]", "brush": "Pincel  [B]"}
const TOOL_HELP := {
	"fill": "Clic en una placa: se rellena todo lo de color parecido que esté unido. Si se escapa o se queda corto, cambia la tolerancia.",
	"rect": "Arrastra para marcar un rectángulo.",
	"brush": "Pinta a mano. El tamaño se ajusta abajo.",
	"lasso": "Clic para ir poniendo puntos por el borde. Cierra con clic en el primero, doble clic o Intro: se rellena lo de dentro con el nivel elegido. Clic derecho o Retroceso quita el último punto; Esc cancela.",
}
## Distancia en pantalla para cerrar el lazo al hacer clic cerca del primer punto.
const LASSO_SNAP := 14.0
const SURFACES := ["wall", "floor", "ceiling"]
const SURFACE_LABELS := ["Pared", "Suelo", "Techo"]
const SURFACE_FROM_DIR := {"pared": "wall", "suelo": "floor", "techo": "ceiling"}

# --- Estado ---------------------------------------------------------------------------
var _ctx: Dictionary = {}
var _theme_name := ""
var _surface := "wall"
var _tex_name := ""
var _tex_path := ""
var _albedo: Texture2D
var _w := 0
var _h := 0
var _src := PackedByteArray()        ## colores RGBA8 a resolución de trabajo
var _edge := PackedByteArray()       ## fuerza de borde por píxel (las juntas frenan el relleno)
var _levels := PackedByteArray()     ## nivel (0–3) por píxel de trabajo
var _ov := PackedByteArray()         ## capa de color RGBA8
var _overlay_tex: ImageTexture
var _height_tex: ImageTexture
var _level := 2
var _tool := "fill"
var _tolerance := 0.10
var _brush := 10.0
var _smooth := 1
var _depth := DungeonTextures.DEFAULT_RELIEF
var _overlay_alpha := 0.5
var _show_gray := false
var _undo: Array[PackedByteArray] = []
var _redo: Array[PackedByteArray] = []
var _dirty := false
var _pending_discard := ""
var _preview_pending := false
var _preview_timer := 0.0

var _zoom := 1.0
var _offset := Vector2.ZERO
var _panning := false
var _stroke_button := 0
var _stroke_before := PackedByteArray()
var _lasso: PackedVector2Array = []   ## puntos del lazo, en píxeles de trabajo
var _rect_from := Vector2i(-1, -1)
var _rect_to := Vector2i(-1, -1)
var _mouse := Vector2(-1, -1)

# --- Interfaz -------------------------------------------------------------------------
var _title: Control
var _canvas: Control
var _status: Label
var _theme_opt: OptionButton
var _surface_opt: OptionButton
var _tex_opt: OptionButton
var _tex_names: Array[String] = []
var _level_buttons: Array[Button] = []
var _tool_buttons := {}
var _tool_help: Label
var _tol_label: Label
var _brush_label: Label
var _depth_label: Label
var _smooth_label: Label
var _preview_mat: StandardMaterial3D
var _preview_mesh: MeshInstance3D
var _preview_light: OmniLight3D
var _preview_cam: Camera3D
var _t := 0.0


func _ready() -> void:
	theme = ToolTheme.get_theme()
	DungeonTextures.live_files = true
	_ctx = SceneRouter.tool_context
	SceneRouter.tool_context = {}
	_build_ui()
	var themes := DungeonTextures.themes()
	_theme_name = _ctx.get("theme", themes[0] if not themes.is_empty() else "")
	_surface = SURFACE_FROM_DIR.get(_ctx.get("surface", "pared"), "wall")
	_refresh_theme_opts()
	_set_level(_level)
	_set_tool(_tool)
	_open(_ctx.get("texture", ""))


# =====================================================================================
# Interfaz
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

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	root.add_child(header)
	_title = Control.new()
	_title.custom_minimum_size = Vector2(660, 76)
	_title.draw.connect(_draw_title)
	header.add_child(_title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	header.add_child(_button("Guardar", _save))
	header.add_child(_button("Volver", _go_back))

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	root.add_child(body)

	_canvas = Control.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.clip_contents = true
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_canvas)
	_canvas.gui_input.connect(_on_canvas_input)
	_canvas.resized.connect(_fit)
	_canvas.mouse_exited.connect(func() -> void:
		_mouse = Vector2(-1, -1)
		_canvas.queue_redraw())
	body.add_child(_canvas)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(SIDEBAR_W, 0)
	right.add_theme_constant_override("separation", 10)
	body.add_child(right)
	_build_preview(right)
	var side := PanelContainer.new()
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(side)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	scroll.add_child(col)
	_build_sidebar(col)

	_status = Label.new()
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.clip_text = true
	_status.add_theme_font_override("font", UIStyle.FONT_REGULAR_ITALIC)
	_status.add_theme_color_override("font_color", UIStyle.LIME)
	root.add_child(_status)


func _build_preview(parent: Control) -> void:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.custom_minimum_size = Vector2(SIDEBAR_W, PREVIEW_H)
	parent.add_child(box)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("101018")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("5a5f8a")
	e.ambient_light_energy = 0.3
	env.environment = e
	vp.add_child(env)
	_preview_mesh = MeshInstance3D.new()
	_preview_mat = StandardMaterial3D.new()
	_preview_mat.roughness = 0.9
	_preview_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_preview_mesh.material_override = _preview_mat
	vp.add_child(_preview_mesh)
	_preview_light = OmniLight3D.new()
	_preview_light.light_color = Color("fff1dc")
	_preview_light.light_energy = 2.2
	_preview_light.omni_range = 6.0
	vp.add_child(_preview_light)
	_preview_cam = Camera3D.new()
	_preview_cam.fov = 50
	vp.add_child(_preview_cam)


func _build_sidebar(col: VBoxContainer) -> void:
	col.add_child(_section("Textura"))
	_theme_opt = OptionButton.new()
	_theme_opt.item_selected.connect(func(i: int) -> void:
		var t := _theme_opt.get_item_text(i)
		_confirm_discard("theme:" + t, func() -> void:
			_theme_name = t
			_refresh_tex_opts()
			_open("")))
	col.add_child(_field("Tema", _theme_opt))
	_surface_opt = OptionButton.new()
	for l in SURFACE_LABELS:
		_surface_opt.add_item(l)
	_surface_opt.item_selected.connect(func(i: int) -> void:
		_confirm_discard("surface:" + SURFACES[i], func() -> void:
			_surface = SURFACES[i]
			_refresh_tex_opts()
			_open("")))
	col.add_child(_field("Superficie", _surface_opt))
	_tex_opt = OptionButton.new()
	_tex_opt.item_selected.connect(func(i: int) -> void:
		var n := _tex_names[i]
		_confirm_discard("tex:" + n, _open.bind(n)))
	col.add_child(_field("Imagen", _tex_opt))

	col.add_child(_section("Nivel"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for i in LEVELS.size():
		var b := _button("%s  [%d]" % [LEVELS[i].name, i + 1], _set_level.bind(i))
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lc: Color = LEVELS[i].color
		if lc.a > 0.0:
			b.add_theme_color_override("font_color", lc)
		grid.add_child(b)
		_level_buttons.append(b)
	col.add_child(grid)
	col.add_child(_small("De dentro a fuera. Clic derecho: Base (borra lo marcado)."))

	col.add_child(_section("Herramienta"))
	var tools := GridContainer.new()
	tools.columns = 2
	tools.add_theme_constant_override("h_separation", 10)
	tools.add_theme_constant_override("v_separation", 10)
	for t: String in TOOLS:
		var b := _button(TOOL_LABELS[t], _set_tool.bind(t))
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tools.add_child(b)
		_tool_buttons[t] = b
	col.add_child(tools)
	_tool_help = _small("")
	col.add_child(_tool_help)
	_tol_label = Label.new()
	col.add_child(_slider_row(_tol_label, 0.02, 0.45, 0.01, _tolerance, func(v: float) -> void:
		_tolerance = v
		_tol_label.text = "Tolerancia del relleno: %d %%" % roundi(v * 100)))
	_brush_label = Label.new()
	col.add_child(_slider_row(_brush_label, 2, 60, 1, _brush, func(v: float) -> void:
		_brush = v
		_brush_label.text = "Tamaño del pincel: %d" % roundi(v)))

	col.add_child(_section("Resultado"))
	_depth_label = Label.new()
	col.add_child(_slider_row(_depth_label, 0.5, 12.0, 0.5, _depth, func(v: float) -> void:
		_depth = v
		_depth_label.text = "Profundidad (todo el tema): %s" % str(v).replace(".", ",")
		_preview_mat.heightmap_scale = v
		_mark_dirty()))
	_smooth_label = Label.new()
	col.add_child(_slider_row(_smooth_label, 0, 4, 1, _smooth, func(v: float) -> void:
		_smooth = int(v)
		_smooth_label.text = "Suavizado de bordes: %d" % _smooth
		_queue_preview()
		_mark_dirty()))
	var ov_label := Label.new()
	col.add_child(_slider_row(ov_label, 0.0, 1.0, 0.05, _overlay_alpha, func(v: float) -> void:
		_overlay_alpha = v
		ov_label.text = "Opacidad de las marcas: %d %%" % roundi(v * 100)
		_canvas.queue_redraw()))
	var gray := CheckBox.new()
	gray.text = "Ver el relieve en grises  [G]"
	gray.toggled.connect(func(on: bool) -> void:
		_show_gray = on
		_canvas.queue_redraw())
	col.add_child(gray)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var auto := _button("Partir de la imagen", _from_image)
	auto.tooltip_text = "Primer intento automático según lo claro u oscuro de cada zona (luego se repasa a mano)."
	auto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(auto)
	var reset := _button("Todo a Base", _reset_all)
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(reset)
	col.add_child(row)
	col.add_child(_small("Cmd/Ctrl+Z deshace, Cmd/Ctrl+Shift+Z rehace, Cmd/Ctrl+S guarda. Rueda: zoom; clic central o dos dedos: mover."))


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	if action.is_valid():
		b.pressed.connect(action)
	return b


func _section(text: String) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 42)
	c.draw.connect(func() -> void:
		c.draw_colored_polygon(UIStyle.slanted_rect(Rect2(0, 8, 9, 26), 5), UIStyle.LIME)
		c.draw_string(UIStyle.FONT_BOLD_ITALIC, Vector2(20, 31), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UIStyle.WHITE)
		c.draw_line(Vector2(0, 40), Vector2(c.size.x, 40), Color(UIStyle.WHITE, 0.25), 1.0))
	return c


func _field(label: String, control: Control) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(130, 0)
	l.add_theme_font_size_override("font_size", 19)
	l.add_theme_color_override("font_color", Color(UIStyle.WHITE, 0.75))
	box.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(control)
	return box


func _small(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", Color(UIStyle.WHITE, 0.55))
	return l


func _slider_row(label: Label, lo: float, hi: float, step: float, value: float, changed: Callable) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", Color(UIStyle.WHITE, 0.75))
	box.add_child(label)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.focus_mode = Control.FOCUS_NONE
	s.value = value
	s.value_changed.connect(changed)
	box.add_child(s)
	changed.call(value)
	return box


func _set_level(i: int) -> void:
	_level = i
	for k in _level_buttons.size():
		_level_buttons[k].set_pressed_no_signal(k == i)


func _set_tool(t: String) -> void:
	_tool = t
	_lasso.clear()
	for k: String in _tool_buttons:
		_tool_buttons[k].set_pressed_no_signal(k == t)
	_tool_help.text = TOOL_HELP[t]
	_canvas.queue_redraw()


func _set_status(text: String, error := false) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", UIStyle.RED if error else UIStyle.LIME)


func _mark_dirty() -> void:
	if not _dirty:
		_dirty = true
		_title.queue_redraw()


## Cambiar de imagen con cambios sin guardar: hay que pedirlo dos veces.
func _confirm_discard(key: String, action: Callable) -> void:
	if _dirty and _pending_discard != key:
		_pending_discard = key
		_set_status("Hay cambios sin guardar: vuelve a hacerlo para descartarlos, o guarda antes (Cmd/Ctrl+S).", true)
		_refresh_theme_opts()
		return
	_pending_discard = ""
	action.call()


func _refresh_theme_opts() -> void:
	_theme_opt.clear()
	var themes := DungeonTextures.themes()
	if not _theme_name in themes and _theme_name != "":
		themes.append(_theme_name)
	for t in themes:
		_theme_opt.add_item(t)
	_theme_opt.select(themes.find(_theme_name))
	_surface_opt.select(SURFACES.find(_surface))
	_refresh_tex_opts()


func _refresh_tex_opts() -> void:
	_tex_opt.clear()
	_tex_names = DungeonTextures.list(_theme_name, _surface)
	for n in _tex_names:
		_tex_opt.add_item(n)
	_tex_opt.select(_tex_names.find(_tex_name))


# =====================================================================================
# Cargar y guardar
# =====================================================================================

func _open(tex_name: String) -> void:
	var names := DungeonTextures.list(_theme_name, _surface)
	if tex_name == "" or not tex_name in names:
		tex_name = names[0] if not names.is_empty() else ""
	_tex_name = tex_name
	_lasso.clear()
	_undo.clear()
	_redo.clear()
	_dirty = false
	_refresh_tex_opts()
	if tex_name == "":
		_albedo = null
		_w = 0
		_h = 0
		_set_status("El tema «%s» no tiene imágenes de %s." % [_theme_name, SURFACE_LABELS[SURFACES.find(_surface)].to_lower()], true)
		_canvas.queue_redraw()
		return
	_tex_path = DungeonTextures.path(_theme_name, _surface, tex_name)
	var img := Image.load_from_file(ProjectSettings.globalize_path(_tex_path))
	img.generate_mipmaps()
	_albedo = ImageTexture.create_from_image(img)
	var work := img.duplicate()
	work.clear_mipmaps()
	work.convert(Image.FORMAT_RGBA8)
	_w = maxi(1, roundi(img.get_width() * WORK_SCALE))
	_h = maxi(1, roundi(img.get_height() * WORK_SCALE))
	work.resize(_w, _h, Image.INTERPOLATE_BILINEAR)
	_src = work.get_data()
	_edge = _edges()
	_levels = PackedByteArray()
	_levels.resize(_w * _h)
	_levels.fill(BASE)
	_depth = DungeonTextures.relief_depth(_theme_name)
	# Niveles guardados (o, si solo hay relieve, aproximados a partir de él).
	var lp := DungeonTextures.levels_path(_tex_path)
	var rp := DungeonTextures.relief_path(_tex_path)
	var saved: Image = null
	var from_levels := false
	if FileAccess.file_exists(lp):
		saved = Image.load_from_file(ProjectSettings.globalize_path(lp))
		from_levels = true
	elif FileAccess.file_exists(rp):
		saved = Image.load_from_file(ProjectSettings.globalize_path(rp))
	if saved != null and not saved.is_empty():
		saved.clear_mipmaps()
		saved.convert(Image.FORMAT_L8)
		saved.resize(_w, _h, Image.INTERPOLATE_NEAREST)
		var d := saved.get_data()
		for i in d.size():
			_levels[i] = clampi(roundi(d[i] / 85.0), 0, 3) if from_levels else _nearest_level(d[i])
	_ov = PackedByteArray()
	_ov.resize(_w * _h * 4)
	_overlay_tex = null
	_refresh_overlay(Rect2i(0, 0, _w, _h))
	_set_preview_mesh()
	_rebuild_preview()
	_fit()
	_title.queue_redraw()
	_set_status("%s%s" % [_tex_path, "  ·  relieve cargado" if saved != null else "  ·  sin relieve todavía: todo está en Base"])


static func _nearest_level(v: int) -> int:
	var best := 0
	for i in LEVELS.size():
		if absi(int(LEVELS[i].height) - v) < absi(int(LEVELS[best].height) - v):
			best = i
	return best


## Altura en grises a resolución de trabajo, con el suavizado elegido.
func _height_image(smooth: int) -> Image:
	var lut := PackedByteArray()
	for l in LEVELS:
		lut.append(int(l.height))
	var hb := PackedByteArray()
	hb.resize(_w * _h)
	for i in hb.size():
		hb[i] = lut[_levels[i]]
	var img := Image.create_from_data(_w, _h, false, Image.FORMAT_L8, hb)
	if smooth > 0:
		var f := 1.0 + smooth * 0.75
		img.resize(maxi(1, roundi(_w / f)), maxi(1, roundi(_h / f)), Image.INTERPOLATE_BILINEAR)
		img.resize(_w, _h, Image.INTERPOLATE_BILINEAR)
	return img


func _save() -> void:
	if _w == 0:
		return
	var rp := DungeonTextures.relief_path(_tex_path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(rp.get_base_dir()))
	var err := _height_image(_smooth).save_png(rp)
	if err == OK:
		var lv := PackedByteArray()
		lv.resize(_levels.size())
		for i in lv.size():
			lv[i] = _levels[i] * 85
		err = Image.create_from_data(_w, _h, false, Image.FORMAT_L8, lv).save_png(DungeonTextures.levels_path(_tex_path))
	if err == OK:
		err = DungeonTextures.set_relief_depth(_theme_name, _depth)
	if err != OK:
		_set_status("No se pudo guardar (%s)." % error_string(err), true)
		return
	DungeonTextures.clear_cache()
	_dirty = false
	_pending_discard = ""
	_title.queue_redraw()
	_set_status("Guardado: %s" % rp)


func _go_back() -> void:
	_confirm_discard("back", func() -> void:
		var back: String = _ctx.get("back", TITLE_SCREEN)
		SceneRouter.tool_context = _ctx
		SceneRouter.go_to(back))


# =====================================================================================
# Edición
# =====================================================================================

func _push_undo(before: PackedByteArray) -> void:
	_undo.append(before)
	if _undo.size() > UNDO_MAX:
		_undo.pop_front()
	_redo.clear()


func _changed(r: Rect2i) -> void:
	_mark_dirty()
	_refresh_overlay(r)
	_queue_preview()


func _undo_step() -> void:
	if _undo.is_empty():
		return
	_redo.append(_levels.duplicate())
	_levels = _undo.pop_back()
	_changed(Rect2i(0, 0, _w, _h))
	_set_status("Deshecho.")


func _redo_step() -> void:
	if _redo.is_empty():
		return
	_undo.append(_levels.duplicate())
	_levels = _redo.pop_back()
	_changed(Rect2i(0, 0, _w, _h))
	_set_status("Rehecho.")


func _reset_all() -> void:
	_push_undo(_levels.duplicate())
	_levels.fill(BASE)
	_changed(Rect2i(0, 0, _w, _h))


## Primer intento automático: lo más oscuro, hueco; lo más claro, placa saliente.
func _from_image() -> void:
	if _w == 0:
		return
	_push_undo(_levels.duplicate())
	var n := _w * _h
	var lum := PackedByteArray()
	lum.resize(n)
	var hist := PackedInt32Array()
	hist.resize(256)
	for i in n:
		var v := (int(_src[i * 4]) * 3 + int(_src[i * 4 + 1]) * 6 + int(_src[i * 4 + 2])) / 10
		lum[i] = v
		hist[v] += 1
	var cuts := [0.12, 0.55, 0.9]
	var thresholds: Array[int] = []
	var acc := 0
	var k := 0
	for v in 256:
		acc += hist[v]
		while k < cuts.size() and acc >= n * cuts[k]:
			thresholds.append(v)
			k += 1
	while thresholds.size() < 3:
		thresholds.append(255)
	for i in n:
		var v := lum[i]
		_levels[i] = 0 if v <= thresholds[0] else (1 if v <= thresholds[1] else (2 if v <= thresholds[2] else 3))
	_changed(Rect2i(0, 0, _w, _h))
	_set_status("Primer intento según lo claro y lo oscuro. Repásalo con «Rellenar zona».")


## Fuerza de borde: el mayor salto de luminosidad con los 8 vecinos. Las juntas
## entre placas son líneas finas, más oscuras o más claras que la placa.
func _edges() -> PackedByteArray:
	var n := _w * _h
	var lum := PackedInt32Array()
	lum.resize(n)
	for i in n:
		lum[i] = (int(_src[i * 4]) * 3 + int(_src[i * 4 + 1]) * 6 + int(_src[i * 4 + 2])) / 10
	var e := PackedByteArray()
	e.resize(n)
	for y in range(1, _h - 1):
		for x in range(1, _w - 1):
			var i := y * _w + x
			var v := lum[i]
			var m := 0
			for nb: int in [i - 1, i + 1, i - _w, i + _w, i - _w - 1, i - _w + 1, i + _w - 1, i + _w + 1]:
				m = maxi(m, absi(lum[nb] - v))
			e[i] = mini(255, m)
	return e


## Varita mágica: rellena lo unido de color parecido al del píxel `seed`, sin
## cruzar bordes marcados (las juntas entre placas).
func _flood(seed: Vector2i, level: int) -> Rect2i:
	var w := _w
	var s := (seed.y * w + seed.x) * 4
	var sr := int(_src[s])
	var sg := int(_src[s + 1])
	var sb := int(_src[s + 2])
	var limit := int(_tolerance * 3.0 * 255.0)
	var edge_limit := maxi(6, int(_tolerance * 160.0))
	var seen := PackedByteArray()
	seen.resize(_w * _h)
	var stack := PackedInt32Array([seed.y * w + seed.x])
	seen[seed.y * w + seed.x] = 1
	var minx := seed.x
	var maxx := seed.x
	var miny := seed.y
	var maxy := seed.y
	while not stack.is_empty():
		var i: int = stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)
		_levels[i] = level
		var x := i % w
		var y := i / w
		minx = mini(minx, x)
		maxx = maxi(maxx, x)
		miny = mini(miny, y)
		maxy = maxi(maxy, y)
		for nb: int in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w if y > 0 else -1, i + w if y < _h - 1 else -1]:
			if nb < 0 or seen[nb] == 1:
				continue
			seen[nb] = 1
			var p := nb * 4
			if _edge[nb] <= edge_limit and absi(int(_src[p]) - sr) + absi(int(_src[p + 1]) - sg) + absi(int(_src[p + 2]) - sb) <= limit:
				stack.append(nb)
	var r := Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1)
	_fill_holes(seen, r, level)
	return r


## Tapa los agujeros que deja el relleno (óxido, tornillos, rayas): lo que no se
## ha rellenado pero queda encerrado por completo dentro de la zona.
func _fill_holes(seen: PackedByteArray, r: Rect2i, level: int) -> void:
	# `seen` = 1 en lo visitado; los visitados que no pasaron siguen sin nivel nuevo.
	var outside := PackedByteArray()
	outside.resize(r.size.x * r.size.y)
	var stack := PackedInt32Array()
	var inside := func(x: int, y: int) -> bool: return _levels[y * _w + x] == level and seen[y * _w + x] == 1
	for x in r.size.x:
		for y: int in [0, r.size.y - 1]:
			stack.append(y * r.size.x + x)
	for y in r.size.y:
		for x: int in [0, r.size.x - 1]:
			stack.append(y * r.size.x + x)
	while not stack.is_empty():
		var j: int = stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)
		if outside[j] == 1:
			continue
		var x := j % r.size.x
		var y := j / r.size.x
		if inside.call(r.position.x + x, r.position.y + y):
			continue
		outside[j] = 1
		if x > 0: stack.append(j - 1)
		if x < r.size.x - 1: stack.append(j + 1)
		if y > 0: stack.append(j - r.size.x)
		if y < r.size.y - 1: stack.append(j + r.size.x)
	for j in outside.size():
		if outside[j] == 0:
			_levels[(r.position.y + j / r.size.x) * _w + r.position.x + j % r.size.x] = level


func _fill_rect(r: Rect2i, level: int) -> void:
	for y in range(r.position.y, r.end.y):
		var row := y * _w
		for x in range(r.position.x, r.end.x):
			_levels[row + x] = level


func _paint_circle(c: Vector2, level: int) -> Rect2i:
	var rad := _brush * WORK_SCALE
	var r := Rect2i(Vector2i((c - Vector2.ONE * rad).floor()), Vector2i.ONE * (ceili(rad * 2) + 1)).intersection(Rect2i(0, 0, _w, _h))
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if Vector2(x + 0.5, y + 0.5).distance_to(c) <= rad:
				_levels[y * _w + x] = level
	return r


# =====================================================================================
# Lienzo
# =====================================================================================

func _image_rect() -> Rect2:
	if _albedo == null:
		return Rect2()
	return Rect2(_offset, _albedo.get_size() * _zoom)


## Píxel de trabajo bajo un punto del lienzo (puede caer fuera).
func _to_work(p: Vector2) -> Vector2:
	return (p - _offset) / _zoom * WORK_SCALE


func _fit() -> void:
	if _albedo == null or _canvas == null:
		return
	var area := _canvas.size if _canvas.size.x > 10 else Vector2(1200, 860)
	var ts := _albedo.get_size()
	_zoom = minf(area.x / ts.x, area.y / ts.y) * 0.94
	_offset = ((area - ts * _zoom) * 0.5).floor()
	_canvas.queue_redraw()


func _on_canvas_input(event: InputEvent) -> void:
	if _albedo == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mb.pressed
		elif mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_zoom_at(1.12 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12, mb.position)
		elif _tool == "lasso" and mb.pressed and mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_lasso_click(mb)
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			var level := _level if mb.button_index == MOUSE_BUTTON_LEFT else BASE
			var wp := _to_work(mb.position)
			var inside := Rect2(0, 0, _w, _h).has_point(wp)
			if mb.pressed and _stroke_button == 0:
				_stroke_button = mb.button_index
				_stroke_before = _levels.duplicate()
				match _tool:
					"fill":
						if inside:
							_changed(_flood(Vector2i(wp), level))
					"rect":
						_rect_from = Vector2i(wp.clamp(Vector2.ZERO, Vector2(_w - 1, _h - 1)))
						_rect_to = _rect_from
					"brush":
						_changed(_paint_circle(wp, level))
			elif not mb.pressed and mb.button_index == _stroke_button:
				if _tool == "rect" and _rect_from.x >= 0:
					var r := _rect(_rect_from, _rect_to)
					_fill_rect(r, level)
					_changed(r)
					_rect_from = Vector2i(-1, -1)
				_stroke_button = 0
				if _stroke_before != _levels:
					_push_undo(_stroke_before)
				_canvas.queue_redraw()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_mouse = mm.position
		if _panning:
			_offset += mm.relative
		elif _stroke_button != 0:
			var wp := _to_work(mm.position)
			if _tool == "brush":
				_changed(_paint_circle(wp, _level if _stroke_button == MOUSE_BUTTON_LEFT else BASE))
			elif _tool == "rect":
				_rect_to = Vector2i(wp.clamp(Vector2.ZERO, Vector2(_w - 1, _h - 1)))
		_canvas.queue_redraw()
	elif event is InputEventMagnifyGesture:
		_zoom_at((event as InputEventMagnifyGesture).factor, event.position)
	elif event is InputEventPanGesture:
		_offset -= (event as InputEventPanGesture).delta * 12.0
		_canvas.queue_redraw()


func _lasso_click(mb: InputEventMouseButton) -> void:
	if mb.button_index == MOUSE_BUTTON_RIGHT:
		_lasso_undo_point()
		return
	if _lasso.size() >= 3 and (mb.double_click or _from_work(_lasso[0]).distance_to(mb.position) <= LASSO_SNAP):
		_close_lasso()
		return
	if mb.double_click:
		return
	_lasso.append(_to_work(mb.position).clamp(Vector2.ZERO, Vector2(_w, _h)))
	_canvas.queue_redraw()


func _lasso_undo_point() -> void:
	if not _lasso.is_empty():
		_lasso.remove_at(_lasso.size() - 1)
		_canvas.queue_redraw()


## Rellena el interior del lazo (regla par-impar, por filas) con el nivel elegido.
func _close_lasso() -> void:
	if _lasso.size() < 3:
		_set_status("El lazo necesita al menos tres puntos.", true)
		return
	var before := _levels.duplicate()
	var poly := _lasso
	_lasso = PackedVector2Array()
	var bb := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		bb = bb.expand(p)
	var y0 := maxi(0, floori(bb.position.y))
	var y1 := mini(_h - 1, ceili(bb.end.y))
	var n := poly.size()
	for y in range(y0, y1 + 1):
		var cy := y + 0.5
		var xs: Array[float] = []
		for i in n:
			var a := poly[i]
			var b := poly[(i + 1) % n]
			if (a.y <= cy) != (b.y <= cy):
				xs.append(a.x + (cy - a.y) / (b.y - a.y) * (b.x - a.x))
		xs.sort()
		for k in range(0, xs.size() - 1, 2):
			var xa := maxi(0, ceili(xs[k] - 0.5))
			var xb := mini(_w - 1, floori(xs[k + 1] - 0.5))
			for x in range(xa, xb + 1):
				_levels[y * _w + x] = _level
	if before != _levels:
		_push_undo(before)
		_changed(Rect2i(Vector2i(0, y0), Vector2i(_w, y1 - y0 + 1)))
	_canvas.queue_redraw()


## Punto de trabajo → punto del lienzo.
func _from_work(p: Vector2) -> Vector2:
	return _offset + p / WORK_SCALE * _zoom


static func _rect(a: Vector2i, b: Vector2i) -> Rect2i:
	var p := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	return Rect2i(p, Vector2i(absi(a.x - b.x) + 1, absi(a.y - b.y) + 1))


func _zoom_at(factor: float, at: Vector2) -> void:
	var g := (at - _offset) / _zoom
	_zoom = clampf(_zoom * factor, 0.1, 8.0)
	_offset = at - g * _zoom
	_canvas.queue_redraw()


## Actualiza la capa de color (y la de grises) en la zona `r`.
func _refresh_overlay(r: Rect2i) -> void:
	if _w == 0:
		return
	r = r.intersection(Rect2i(0, 0, _w, _h))
	var cols := []
	for l in LEVELS:
		var c: Color = l.color
		cols.append([c.r8, c.g8, c.b8, 255 if c.a > 0.0 else 0])
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i := y * _w + x
			var c: Array = cols[_levels[i]]
			var o := i * 4
			_ov[o] = c[0]
			_ov[o + 1] = c[1]
			_ov[o + 2] = c[2]
			_ov[o + 3] = c[3]
	var img := Image.create_from_data(_w, _h, false, Image.FORMAT_RGBA8, _ov)
	if _overlay_tex == null:
		_overlay_tex = ImageTexture.create_from_image(img)
	else:
		_overlay_tex.update(img)
	_canvas.queue_redraw()


func _draw_canvas() -> void:
	var s := _canvas.size
	_canvas.draw_rect(Rect2(Vector2.ZERO, s), Color("16161c"))
	if _albedo != null:
		var r := _image_rect()
		if _show_gray:
			if _height_tex:
				_canvas.draw_texture_rect(_height_tex, r, false)
		else:
			_canvas.draw_texture_rect(_albedo, r, false)
			if _overlay_tex:
				_canvas.draw_texture_rect(_overlay_tex, r, false, Color(1, 1, 1, _overlay_alpha))
		_canvas.draw_rect(r, Color(UIStyle.WHITE, 0.4), false, 1.0)
		# Rectángulo en curso
		if _tool == "rect" and _rect_from.x >= 0:
			var rr := _rect(_rect_from, _rect_to)
			var k := _zoom / WORK_SCALE
			var cr := Rect2(_offset + Vector2(rr.position) * k, Vector2(rr.size) * k)
			var lc: Color = LEVELS[_level if _stroke_button == MOUSE_BUTTON_LEFT else BASE].color
			_canvas.draw_rect(cr, Color(lc if lc.a > 0 else UIStyle.WHITE, 0.3))
			_canvas.draw_rect(cr, UIStyle.WHITE, false, 2.0)
		# Lazo en curso
		if _tool == "lasso" and not _lasso.is_empty():
			var pts := PackedVector2Array()
			for p in _lasso:
				pts.append(_from_work(p))
			var lc: Color = LEVELS[_level].color
			if lc.a == 0.0:
				lc = UIStyle.WHITE
			if pts.size() >= 3:
				var tri := Geometry2D.triangulate_polygon(pts)
				if not tri.is_empty():
					_canvas.draw_colored_polygon(pts, Color(lc, 0.25))
			if pts.size() >= 2:
				_canvas.draw_polyline(pts, UIStyle.WHITE, 2.0, true)
			var near_first := pts.size() >= 3 and _mouse.distance_to(pts[0]) <= LASSO_SNAP
			if _mouse.x >= 0:
				_canvas.draw_line(pts[pts.size() - 1], pts[0] if near_first else _mouse, Color(UIStyle.WHITE, 0.6), 1.5, true)
			for i in pts.size():
				_canvas.draw_circle(pts[i], 4.0, lc if i > 0 else UIStyle.WHITE)
			_canvas.draw_arc(pts[0], LASSO_SNAP if near_first else 7.0, 0, TAU, 24, lc if near_first else UIStyle.WHITE, 2.0)
		# Pincel
		if _tool == "brush" and _mouse.x >= 0:
			_canvas.draw_arc(_mouse, _brush * _zoom, 0, TAU, 40, UIStyle.WHITE, 1.5)
	var frame := UIStyle.chamfer_rect(Rect2(Vector2(1, 1), s - Vector2(2, 2)), [0.0, 26.0, 0.0, 26.0])
	UIStyle.draw_outline(_canvas, frame, UIStyle.LINE, 1.5)
	# Leyenda
	var x := 20.0
	for i in LEVELS.size():
		var lc: Color = LEVELS[i].color
		_canvas.draw_rect(Rect2(x, s.y - 34, 18, 18), lc if lc.a > 0 else Color(UIStyle.WHITE, 0.15))
		_canvas.draw_rect(Rect2(x, s.y - 34, 18, 18), UIStyle.WHITE, false, 1.0)
		var label := "%d %s" % [i + 1, LEVELS[i].name]
		_canvas.draw_string(UIStyle.FONT_REGULAR, Vector2(x + 26, s.y - 19), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(UIStyle.WHITE, 0.8))
		x += 40 + UIStyle.FONT_REGULAR.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x


# =====================================================================================
# Vista previa 3D
# =====================================================================================

func _set_preview_mesh() -> void:
	var dir: String = DungeonTextures.SURFACE_DIR[_surface]
	var size_m: Vector2 = TextureFormats.SURFACES[dir].size_m
	var q := QuadMesh.new()
	q.size = size_m
	_preview_mesh.mesh = q
	_preview_mesh.position = Vector3(0, size_m.y * 0.5, 0)
	_preview_mat.albedo_texture = _albedo


func _queue_preview() -> void:
	_preview_pending = true


func _rebuild_preview() -> void:
	_preview_pending = false
	_preview_timer = 0.25
	if _w == 0:
		return
	var img := _height_image(_smooth)
	if _height_tex == null:
		_height_tex = ImageTexture.create_from_image(img)
	else:
		_height_tex.set_image(img)
	var rgba := img.duplicate()
	rgba.convert(Image.FORMAT_RGBA8)
	rgba.bump_map_to_normal_map(6.0)
	rgba.generate_mipmaps()
	var h2 := img.duplicate()
	h2.generate_mipmaps()
	DungeonBuilder.apply_relief(_preview_mat, {"height": ImageTexture.create_from_image(h2),
			"normal": ImageTexture.create_from_image(rgba), "depth": _depth})
	if _show_gray:
		_canvas.queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_preview_timer -= delta
	if _preview_pending and _preview_timer <= 0.0 and _stroke_button == 0:
		_rebuild_preview()
	if _preview_mesh.mesh == null:
		return
	var size_m: Vector2 = (_preview_mesh.mesh as QuadMesh).size
	var c := _preview_mesh.position
	_preview_light.position = c + Vector3(cos(_t * 0.9) * size_m.x * 0.6, sin(_t * 1.3) * size_m.y * 0.35, 1.2)
	var cam_pos := c + Vector3(sin(_t * 0.5) * 1.3, 0.2, maxf(size_m.x, size_m.y) * 1.15)
	_preview_cam.look_at_from_position(cam_pos, c)


# =====================================================================================
# Teclado y título
# =====================================================================================

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var cmd := key.is_command_or_control_pressed()
	match key.keycode:
		KEY_Z when cmd and not _lasso.is_empty() and not key.shift_pressed:
			_lasso_undo_point()
		KEY_Z when cmd:
			if key.shift_pressed:
				_redo_step()
			else:
				_undo_step()
		KEY_Y when cmd:
			_redo_step()
		KEY_S when cmd:
			_save()
		KEY_1, KEY_2, KEY_3, KEY_4:
			_set_level(key.keycode - KEY_1)
		KEY_F:
			_set_tool("fill")
		KEY_R:
			_set_tool("rect")
		KEY_B:
			_set_tool("brush")
		KEY_L:
			_set_tool("lasso")
		KEY_ENTER, KEY_KP_ENTER when not _lasso.is_empty():
			_close_lasso()
		KEY_BACKSPACE when not _lasso.is_empty():
			_lasso_undo_point()
		KEY_ESCAPE when not _lasso.is_empty():
			_lasso.clear()
			_canvas.queue_redraw()
		KEY_G:
			_show_gray = not _show_gray
			_canvas.queue_redraw()
		_:
			return
	get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UIStyle.INK)


func _draw_title() -> void:
	var c := _title
	c.draw_colored_polygon(UIStyle.slanted_rect(Rect2(0, 6, 12, 60), 5), UIStyle.LIME)
	c.draw_string(UIStyle.FONT_HEAVY_ITALIC, Vector2(28, 46), "Editor de relieve" + ("  •" if _dirty else ""),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 44, UIStyle.WHITE)
	var sub := "HUECOS · PLACAS · VOLUMEN  —  %s / %s" % [_theme_name.to_upper(), _tex_name.to_upper()]
	UIStyle.draw_spaced(c, UIStyle.FONT_REGULAR, Vector2(30, 72), sub, 15, 3.0, Color(UIStyle.WHITE, 0.6))
