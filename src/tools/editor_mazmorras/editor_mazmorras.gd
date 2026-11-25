extends Control
## Editor de mazmorras: plano 2D por casillas, vista 3D y «Probar mapa».
##
## Herramientas (teclas 1–9):
##  - Casillas: clic izquierdo pinta, derecho borra (se puede arrastrar).
##  - Muros: clic en el borde entre dos casillas pone un muro; derecho lo quita.
##  - Puertas: clic en el borde entre dos casillas pone una puerta (o la
##    selecciona para editarla); derecho la quita.
##  - Texturas: pinta suelo o techo (casillas) o la cara de una pared (la que
##    mira a la casilla en la que haces clic). Clic derecho = la del tema.
##  - Inicio: casilla y orientación de salida (clic otra vez para girar).
##  - Enemigos: pone el enemigo elegido en la casilla; derecho lo quita.
##  - Escaleras: pone una escalera que sube o baja (crea la planta si hace falta
##    y la escalera de vuelta); clic otra vez para girarla; derecho la quita.
##  - Objetos: deja en el suelo el objeto elegido (se coge en el juego); derecho lo quita.
##  - Interruptores: pone una palanca (o la selecciona); con una seleccionada,
##    clic en una puerta la vincula o desvincula; derecho la quita.
##
## Plantas: «Planta» en el panel o Re Pág / Av Pág. La planta de debajo se ve
## en gris para alinear.
##
## Las texturas son las del Estudio de texturas (assets/textures/<tema>/...).
## El botón «Estudio de texturas» lleva allí con el tema y la superficie
## elegidos, y al volver el mapa sigue como estaba (aunque no se haya guardado).
##
## Abrir: menú de inicio (botón «Editor de mazmorras», solo desde el editor de
## Godot) o abrir esta escena y pulsar F6. Guarda en src/data/mazmorras/<id>.json.

const SELF_PATH := "res://src/tools/editor_mazmorras/editor_mazmorras.tscn"
const TITLE_SCREEN := "res://src/screens/title/title_screen.tscn"
const TEXTURE_STUDIO := "res://src/tools/texture_studio/texture_studio.tscn"
const RELIEF_EDITOR := "res://src/tools/editor_relieve/editor_relieve.tscn"
const SIDEBAR_W := 560.0
const PREVIEW_H := 380.0
const UNDO_MAX := 100

const TOOLS := ["cells", "walls", "doors", "paint", "start", "enemies", "stairs", "items", "switches", "extraction", "save", "lights"]
const TOOL_LABELS := {"cells": "Casillas  [1]", "walls": "Muros  [2]", "doors": "Puertas  [3]", "paint": "Texturas  [4]",
		"start": "Inicio  [5]", "enemies": "Enemigos  [6]", "stairs": "Escaleras  [7]", "items": "Objetos  [8]",
		"switches": "Interruptores  [9]", "extraction": "Extracción  [0]", "save": "Guardado",
		"lights": "Luces"}
const TOOL_HELP := {
	"cells": "Clic izquierdo: pintar casillas. Clic derecho: borrar. Se puede arrastrar. Las paredes del contorno salen solas.",
	"walls": "Clic en el borde entre dos casillas pintadas: muro. Clic derecho: quitarlo. Se puede arrastrar.",
	"doors": "Clic en el borde entre dos casillas pintadas: puerta (si ya hay una, la selecciona para editarla abajo). Clic derecho: quitarla.",
	"paint": "Elige superficie y textura. Suelo y techo se pintan por casilla; una pared, por la cara que mira a la casilla donde haces clic. Clic derecho: la del tema. Con «Suelo», R gira el de la casilla bajo el ratón (p. ej. para que una flecha apunte a la escalera).",
	"start": "Clic en una casilla: punto de inicio (en esta planta). Clic otra vez en la misma: gira la orientación.",
	"enemies": "Elige el enemigo (y lo que suelta al morir, si algo) y haz clic en una casilla. Clic derecho: quitarlo. Al probar el mapa, chocar con él empieza el combate.",
	"lights": "Clic en una casilla: punto de luz con los valores de abajo (o selecciona el que hay, para cambiarlo). Clic derecho: quitarlo. En el plano, el círculo es su alcance. En el juego se encienden las 6 más cercanas al grupo.",
	"save": "Clic en una casilla: punto de guardado (terminal; se usa desde la casilla de al lado: guarda la partida y lo conseguido ya no se pierde). Ponle al lado una zona de extracción. Clic derecho: quitarlo.",
	"stairs": "Clic en una casilla: escalera hacia donde apunta la flecha (se entra andando en esa dirección). Clic otra vez: girarla. Clic derecho: quitarla. Crea la planta y la escalera de vuelta.",
	"items": "Elige el objeto y la cantidad, y haz clic en una casilla: queda en el suelo y en el juego se coge desde la casilla de al lado. Clic derecho: quitarlo.",
	"extraction": "Clic en una casilla: zona de extracción segura (saliendo desde ella el jugador se lleva lo que ha conseguido; la casilla de inicio ya lo es). Clic derecho: quitarla.",
	"switches": "Clic en una casilla: palanca (o la selecciona). Con una seleccionada, clic en una puerta para vincularla o desvincularla: la palanca la abre y la cierra. Clic derecho: quitarla.",
}
const SURFACES := ["floor", "ceiling", "wall"]
const SURFACE_LABELS := ["Suelo", "Techo", "Pared"]

# --- Estado ---------------------------------------------------------------------------
var _map: DungeonMap
var _tool := "cells"
var _surface := "floor"
var _paint_tex := ""                 ## "" = la del tema
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _dirty := false
var _stroke_before: Dictionary = {}
var _stroke_button := 0
var _sel_edge: Dictionary = {}       ## {cell, dir}
var _hover: Dictionary = {}          ## {cell, dir} (dir = −1 si no está cerca de un borde)
var _cell_px := 48.0
var _origin := Vector2(200, 200)     ## píxel del plano donde cae la esquina de la casilla (0, 0)
var _panning := false
var _rebuild_pending := false

var _yaw := 0.6
var _pitch := 0.95
var _dist := 18.0
var _target := Vector3.ZERO
var _orbiting := false
var _show_ceiling := false

# --- Interfaz -------------------------------------------------------------------------
var _title: Control
var _plan: Control
var _viewport: SubViewport
var _world: Node3D
var _model: Node3D
var _camera: Camera3D
var _status: Label
var _info: Label
var _tool_buttons := {}
var _tool_help: Label
var _name_edit: LineEdit
var _theme_opt: OptionButton
var _maps_opt: OptionButton
var _path_label: Label
var _surface_opt: OptionButton
var _palette: ItemList
var _palette_names: Array[String] = []
var _default_btn: Button
var _sel_label: Label
var _door_box: VBoxContainer
var _door_state: OptionButton
var _door_req: LineEdit
var _test: Control
var _explorer: DungeonExplorer
var _test_info: Label
var _test_msg: Label
var _combat: CombatView
var _level_label: Label
var _level_remove: Button
var _enemy_opt: OptionButton
var _enemy_ids: Array[String] = []
var _drop_opt: OptionButton
var _drop_ids: Array[String] = []
var _stairs_opt: OptionButton
var _stairs_dir := DungeonMap.N
var _item_opt: OptionButton
var _item_ids: Array[String] = []
var _item_count: SpinBox
var _door_switch_only: CheckBox
var _door_secret: CheckBox
var _door_hidden: CheckBox
var _sel_switch: Dictionary = {}     ## {cell}
var _sel_light: Dictionary = {}      ## {cell}
var _light_box: VBoxContainer
var _light_values := DungeonMap.LIGHT_DEFAULT.duplicate()   ## valores de la próxima luz (o de la seleccionada)
var _light_color: ColorPickerButton
var _light_sliders := {}             ## clave -> HSlider


func _ready() -> void:
	theme = ToolTheme.get_theme()
	DungeonTextures.live_files = true
	DungeonTextures.clear_cache()
	_build_ui()
	var ctx := SceneRouter.tool_context
	if ctx.has("dungeon"):
		# Vuelta del Estudio de texturas: el mapa sigue como estaba.
		_map = DungeonMap.from_dict(ctx.dungeon)
		_dirty = ctx.get("dirty", false)
		_tool = ctx.get("tool", _tool)
		_surface = ctx.get("paint_surface", _surface)
		_set_status("Texturas recargadas.")
	else:
		var saved := DungeonMap.list_maps()
		_map = DungeonMap.load_map(saved[0]) if not saved.is_empty() else _new_map()
	SceneRouter.tool_context = {}
	_load_into_ui()


func _new_map() -> DungeonMap:
	var m := DungeonMap.new()
	m.id = "mazmorra"
	var themes := DungeonTextures.themes()
	m.theme = themes[0] if not themes.is_empty() else "pruebas"
	m.set_cell(Vector2i.ZERO)
	return m


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
	_title = Control.new()
	_title.custom_minimum_size = Vector2(660, 76)
	_title.draw.connect(_draw_title)
	header.add_child(_title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	header.add_child(_button("Nuevo", _on_new))
	header.add_child(_button("Guardar", _save))
	header.add_child(_button("Probar mapa  [P]", _start_test))
	header.add_child(_button("Estudio de texturas", _go_to_studio))
	header.add_child(_button("Volver", func() -> void: SceneRouter.go_to(TITLE_SCREEN)))

	# Cuerpo: plano + (vista 3D y panel)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	root.add_child(body)

	_plan = Control.new()
	_plan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_plan.clip_contents = true
	_plan.mouse_filter = Control.MOUSE_FILTER_STOP
	_plan.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_plan.draw.connect(_draw_plan)
	_plan.gui_input.connect(_on_plan_input)
	_plan.mouse_exited.connect(func() -> void:
		_hover = {}
		_plan.queue_redraw())
	body.add_child(_plan)

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
	col.add_theme_constant_override("separation", 12)
	scroll.add_child(col)
	_build_sidebar(col)

	# Pie
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	root.add_child(footer)
	_info = Label.new()
	_info.add_theme_color_override("font_color", Color(UIStyle.WHITE, 0.8))
	footer.add_child(_info)
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.custom_minimum_size = Vector2(100, 0)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.clip_text = true
	_status.add_theme_font_override("font", UIStyle.FONT_REGULAR_ITALIC)
	_status.add_theme_color_override("font_color", UIStyle.LIME)
	footer.add_child(_status)

	_build_test_overlay()


func _build_preview(parent: Control) -> void:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.custom_minimum_size = Vector2(SIDEBAR_W, PREVIEW_H)
	box.gui_input.connect(_on_preview_input)
	parent.add_child(box)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	box.add_child(_viewport)
	_world = Node3D.new()
	_viewport.add_child(_world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("1a1a20")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = 0.55
	env.environment = e
	_viewport.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 0.8
	_viewport.add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 45
	_viewport.add_child(_camera)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var ceil_btn := _button("Techo", func() -> void: pass)
	ceil_btn.toggle_mode = true
	ceil_btn.toggled.connect(func(on: bool) -> void:
		_show_ceiling = on
		_apply_ceiling())
	row.add_child(ceil_btn)
	row.add_child(_button("Encuadrar", _frame_preview))
	var hint := Label.new()
	hint.text = "Clic derecho: girar · Rueda: zoom"
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color(UIStyle.WHITE, 0.5))
	row.add_child(hint)


func _build_sidebar(col: VBoxContainer) -> void:
	# --- Herramienta ---
	col.add_child(_section("Herramienta"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var group := ButtonGroup.new()
	for t: String in TOOLS:
		var b := _button(TOOL_LABELS[t], _set_tool.bind(t))
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(b)
		_tool_buttons[t] = b
	col.add_child(grid)
	_tool_help = _small("")
	col.add_child(_tool_help)
	_enemy_opt = OptionButton.new()
	for eid: String in CharacterDB.ALL:
		if CharacterDB.is_enemy(eid):
			_enemy_ids.append(eid)
			_enemy_opt.add_item(CharacterDB.display_name(eid))
	_enemy_opt.item_selected.connect(func(_i: int) -> void: _set_tool("enemies"))
	col.add_child(_field("Enemigo a colocar", _enemy_opt))
	_drop_opt = OptionButton.new()
	_drop_opt.add_item("Nada")
	for iid: String in ItemDB.ALL:
		if not ItemDB.get_item(iid).has("loot"):
			_drop_ids.append(iid)
			_drop_opt.add_item(ItemDB.display_name(iid))
	_drop_opt.item_selected.connect(func(_i: int) -> void: _set_tool("enemies"))
	col.add_child(_field("Suelta al morir (se añade al inventario)", _drop_opt))
	_stairs_opt = OptionButton.new()
	_stairs_opt.add_item("Sube")
	_stairs_opt.add_item("Baja")
	_stairs_opt.item_selected.connect(func(_i: int) -> void: _set_tool("stairs"))
	col.add_child(_field("Escalera nueva", _stairs_opt))
	var irow := HBoxContainer.new()
	irow.add_theme_constant_override("separation", 10)
	_item_opt = OptionButton.new()
	_item_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for iid: String in ItemDB.ALL:
		_item_ids.append(iid)
		_item_opt.add_item(ItemDB.get_item(iid).get("name", iid))
	_item_opt.item_selected.connect(func(_i: int) -> void: _set_tool("items"))
	irow.add_child(_item_opt)
	_item_count = SpinBox.new()
	_item_count.min_value = 1
	_item_count.max_value = 99
	_item_count.value = 1
	irow.add_child(_item_count)
	col.add_child(_field("Objeto a colocar · cantidad", irow))
	_build_light_box(col)

	# --- Selección ---
	col.add_child(_section("Selección"))
	_sel_label = _small("Nada seleccionado. Con «Puertas», haz clic en una puerta para editarla.")
	col.add_child(_sel_label)
	_door_box = VBoxContainer.new()
	_door_box.add_theme_constant_override("separation", 10)
	col.add_child(_door_box)
	_door_state = OptionButton.new()
	_door_state.add_item("Cerrada")
	_door_state.add_item("Abierta")
	_door_state.item_selected.connect(func(i: int) -> void:
		_push_undo()
		_map.set_door(_sel_edge.cell, _sel_edge.dir, "open", i == 1)
		_changed())
	_door_box.add_child(_field("Estado inicial", _door_state))
	_door_req = LineEdit.new()
	_door_req.placeholder_text = "Vacío = se abre sin más"
	_door_req.text_changed.connect(func(t: String) -> void:
		_map.set_door(_sel_edge.cell, _sel_edge.dir, "requires", t.strip_edges())
		_mark_dirty())
	_door_box.add_child(_field("Objeto necesario (id)", _door_req))
	_door_switch_only = CheckBox.new()
	_door_switch_only.text = "Solo se abre con una palanca"
	_door_switch_only.toggled.connect(func(on: bool) -> void:
		_push_undo()
		_map.set_door(_sel_edge.cell, _sel_edge.dir, "switch_only", on)
		_mark_dirty())
	_door_box.add_child(_door_switch_only)
	_door_secret = CheckBox.new()
	_door_secret.text = "Secreta: parece pared hasta que se examina"
	_door_secret.toggled.connect(func(on: bool) -> void:
		_push_undo()
		_map.set_door(_sel_edge.cell, _sel_edge.dir, "secret", on)
		_mark_dirty()
		_rebuild_pending = true
		_plan.queue_redraw())
	_door_box.add_child(_door_secret)
	_door_hidden = CheckBox.new()
	_door_hidden.text = "Oculta: solo se encuentra con el resonador"
	_door_hidden.tooltip_text = "Pared secreta que no se puede empujar a ciegas ni la comenta el compañero: hay que hacerla brillar con el pulso del resonador (5 casillas) y luego inspeccionarla."
	_door_hidden.toggled.connect(func(on: bool) -> void:
		_push_undo()
		_map.set_door(_sel_edge.cell, _sel_edge.dir, "hidden", on)
		if on:
			_map.set_door(_sel_edge.cell, _sel_edge.dir, "secret", true)
			_door_secret.set_pressed_no_signal(true)
		_mark_dirty()
		_rebuild_pending = true
		_plan.queue_redraw())
	_door_box.add_child(_door_hidden)
	_door_box.visible = false

	# --- Planta ---
	col.add_child(_section("Planta"))
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 10)
	lrow.add_child(_button("▼", _change_level.bind(-1)))
	_level_label = Label.new()
	_level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.add_theme_font_override("font", UIStyle.FONT_BOLD_ITALIC)
	_level_label.add_theme_font_size_override("font_size", 24)
	lrow.add_child(_level_label)
	lrow.add_child(_button("▲", _change_level.bind(1)))
	col.add_child(lrow)
	var lrow2 := HBoxContainer.new()
	lrow2.add_theme_constant_override("separation", 10)
	for b in [_button("+ Encima", _add_level.bind(true)), _button("+ Debajo", _add_level.bind(false))]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lrow2.add_child(b)
	_level_remove = _button("Borrar planta", _remove_level)
	_level_remove.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lrow2.add_child(_level_remove)
	col.add_child(lrow2)
	col.add_child(_small("Re Pág / Av Pág: cambiar de planta. La de debajo se ve en gris. Con «Escaleras» las plantas se crean solas."))

	# --- Mapa ---
	col.add_child(_section("Mapa"))
	_name_edit = LineEdit.new()
	_name_edit.text_changed.connect(func(t: String) -> void:
		_map.id = _clean(t)
		_mark_dirty()
		_refresh_path())
	col.add_child(_field("Nombre", _name_edit))
	_theme_opt = OptionButton.new()
	_theme_opt.item_selected.connect(func(i: int) -> void:
		_push_undo()
		_map.theme = _theme_opt.get_item_text(i)
		_changed()
		_refresh_palette())
	col.add_child(_field("Tema de texturas", _theme_opt))
	_maps_opt = OptionButton.new()
	_maps_opt.item_selected.connect(func(i: int) -> void:
		if i > 0:
			_open(_maps_opt.get_item_text(i)))
	col.add_child(_field("Abrir mapa guardado", _maps_opt))
	_path_label = _small("")
	_path_label.add_theme_color_override("font_color", Color(UIStyle.LIME, 0.85))
	col.add_child(_path_label)

	# --- Texturas ---
	col.add_child(_section("Texturas"))
	_surface_opt = OptionButton.new()
	for l in SURFACE_LABELS:
		_surface_opt.add_item(l)
	_surface_opt.item_selected.connect(func(i: int) -> void:
		_surface = SURFACES[i]
		_paint_tex = ""
		_set_tool("paint")
		_refresh_palette())
	col.add_child(_field("Superficie", _surface_opt))
	_palette = ItemList.new()
	_palette.custom_minimum_size = Vector2(0, 330)
	_palette.max_columns = 3
	_palette.same_column_width = true
	_palette.icon_mode = ItemList.ICON_MODE_TOP
	_palette.fixed_icon_size = Vector2i(128, 128)
	_palette.fixed_column_width = 150
	_palette.add_theme_font_size_override("font_size", 16)
	_palette.item_selected.connect(func(i: int) -> void:
		_paint_tex = _palette_names[i]
		_set_tool("paint")
		_refresh_default_btn())
	col.add_child(_palette)
	_default_btn = _button("Usar como predeterminada del tema", _set_theme_default)
	col.add_child(_default_btn)
	col.add_child(_button("Recargar texturas", _reload_textures))
	col.add_child(_button("Relieve de la textura…", _go_to_relief))
	col.add_child(_small("Salen del Estudio de texturas (assets/textures/<tema>/suelo, techo o pared). " +
			"Las casillas sin textura propia usan la predeterminada del tema; si el tema no tiene ninguna, una provisional."))

func _build_test_overlay() -> void:
	_test = Control.new()
	_test.set_anchors_preset(Control.PRESET_FULL_RECT)
	_test.mouse_filter = Control.MOUSE_FILTER_STOP
	_test.visible = false
	add_child(_test)
	var box := SubViewportContainer.new()
	box.stretch = true
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_test.add_child(box)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(vp)
	_explorer = DungeonExplorer.new()
	vp.add_child(_explorer)
	_explorer.message.connect(func(t: String) -> void:
		_test_msg.text = t
		_test_msg.modulate.a = 1.0
		var tw := create_tween()
		tw.tween_interval(1.8)
		tw.tween_property(_test_msg, "modulate:a", 0.0, 0.5))
	_explorer.moved.connect(func(c: Vector2i, d: int) -> void:
		_test_info.text = "Probando «%s»  ·  %s  ·  casilla (%d, %d)  ·  mirando al %s" % [_map.id, _explorer.map.level_name(),
				c.x, c.y, DungeonMap.DIR_NAMES[d].to_lower()])
	_explorer.encounter.connect(_on_encounter)

	var hud := Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.draw.connect(func() -> void:
		hud.draw_rect(Rect2(0, hud.size.y - 70, hud.size.x, 70), Color(UIStyle.INK, 0.75)))
	_test.add_child(hud)
	_test_info = Label.new()
	_test_info.position = Vector2(40, 30)
	_test_info.add_theme_font_override("font", UIStyle.FONT_BOLD_ITALIC)
	_test_info.add_theme_font_size_override("font_size", 26)
	_test.add_child(_test_info)
	var keys := Label.new()
	keys.text = "[W / S] Avanzar · retroceder     [A / D] Girar     [Q / E] De lado     [Espacio] Usar lo de delante     [Esc] Volver al editor"
	keys.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	keys.offset_top = -52
	keys.offset_bottom = -14
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keys.add_theme_color_override("font_color", Color(UIStyle.WHITE, 0.85))
	_test.add_child(keys)
	_test_msg = Label.new()
	_test_msg.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_test_msg.offset_top = -170
	_test_msg.offset_left = -500
	_test_msg.offset_right = 500
	_test_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_test_msg.add_theme_font_override("font", UIStyle.FONT_BOLD_ITALIC)
	_test_msg.add_theme_font_size_override("font_size", 30)
	_test_msg.add_theme_color_override("font_color", UIStyle.LIME)
	_test_msg.modulate.a = 0.0
	_test.add_child(_test_msg)

	_combat = CombatView.new()
	_combat.set_anchors_preset(Control.PRESET_FULL_RECT)
	_test.add_child(_combat)


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
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


func _small(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", Color(UIStyle.WHITE, 0.55))
	return l


# =====================================================================================
# Estado → interfaz
# =====================================================================================

func _load_into_ui() -> void:
	_name_edit.text = _map.id
	_refresh_level()
	_refresh_themes()
	_refresh_maps()
	_surface_opt.select(SURFACES.find(_surface))
	_set_tool(_tool)
	_refresh_palette()
	_sel_edge = {}
	_refresh_selection()
	_fit_plan()
	_rebuild()
	_frame_preview()
	_refresh_path()


func _refresh_themes() -> void:
	_theme_opt.clear()
	var themes := DungeonTextures.themes()
	if not _map.theme in themes:
		themes.append(_map.theme)
	for t in themes:
		_theme_opt.add_item(t)
	_theme_opt.select(themes.find(_map.theme))


func _refresh_maps() -> void:
	_maps_opt.clear()
	_maps_opt.add_item("Elegir…")
	for id in DungeonMap.list_maps():
		_maps_opt.add_item(id)
	_maps_opt.select(0)


func _refresh_path() -> void:
	_path_label.text = DungeonMap.path_for(_map.id)
	_title.queue_redraw()


func _refresh_palette() -> void:
	_palette.clear()
	_palette_names.clear()
	var def := DungeonTextures.default_name(_map.theme, _surface)
	_palette.add_item("Del tema" + (" (%s)" % def if def != "" else " (provisional)"),
			DungeonTextures.resolve(_map.theme, _surface, ""))
	_palette_names.append("")
	for n in DungeonTextures.list(_map.theme, _surface):
		_palette.add_item(n + ("  ★" if n == def else ""), DungeonTextures.resolve(_map.theme, _surface, n))
		_palette_names.append(n)
	var i := _palette_names.find(_paint_tex)
	if i < 0:
		_paint_tex = ""
		i = 0
	_palette.select(i)
	_refresh_default_btn()


func _refresh_default_btn() -> void:
	_default_btn.disabled = _paint_tex == "" or _paint_tex == DungeonTextures.default_name(_map.theme, _surface)


func _refresh_info() -> void:
	_info.text = "%s: %d casillas  ·  %d plantas  ·  %d puertas  ·  %d enemigos  ·  %d objetos  ·  1 casilla = %s m" % [_map.level_name(),
			_map.cells.size(), _map.floors.size(), _map.door_count(), _map.enemy_count(), _map.count_of(DungeonMap.ITEM),
			str(TextureFormats.TILE_SIZE_M).replace(".", ",")]


func _refresh_level() -> void:
	_level_label.text = "%s  (%d de %d)" % [_map.level_name(), _map.level + 1, _map.floors.size()]
	_level_remove.disabled = not _map.can_remove_level(_map.level)
	_level_remove.tooltip_text = "Solo se puede borrar la de arriba o la de abajo del todo." if _level_remove.disabled else ""
	_sel_edge = {}
	_sel_switch = {}
	_refresh_selection()
	_title.queue_redraw()


func _change_level(delta: int) -> void:
	var i := _map.level + delta
	if i < 0 or i >= _map.floors.size():
		_set_status("No hay más plantas por ahí: añade una con «+ Encima» / «+ Debajo» o pon una escalera.", true)
		return
	_map.set_level(i)
	_after_level_switch()


func _after_level_switch() -> void:
	_refresh_level()
	_refresh_info()
	_rebuild_pending = true
	_plan.queue_redraw()
	_set_status("Editando la %s." % _map.level_name().to_lower())


func _add_level(above: bool) -> void:
	_push_undo()
	var i := _map.add_level(above)
	_map.set_level(i)
	_mark_dirty()
	_after_level_switch()


func _remove_level() -> void:
	if not _map.can_remove_level(_map.level):
		return
	_push_undo()
	_map.remove_level(_map.level)
	_changed()
	_after_level_switch()
	_set_status("Planta borrada (Cmd/Ctrl+Z para recuperarla).")


func _refresh_selection() -> void:
	if not _sel_switch.is_empty() and _map.thing(_sel_switch.cell).get("type", "") == DungeonMap.SWITCH:
		var sc: Vector2i = _sel_switch.cell
		var n: int = _map.thing(sc).doors.size()
		_sel_label.text = "Palanca en (%d, %d): %s. Haz clic en una puerta para vincularla o desvincularla." % [
				sc.x, sc.y, "sin puertas" if n == 0 else "%d puerta%s vinculada%s" % [n, "" if n == 1 else "s", "" if n == 1 else "s"]]
		_door_box.visible = false
		return
	_sel_switch = {}
	if _sel_edge.is_empty() or _map.edge_type(_sel_edge.cell, _sel_edge.dir) != DungeonMap.DOOR:
		_sel_edge = {}
		_sel_label.text = "Nada seleccionado. Con «Puertas», haz clic en una puerta para editarla."
		_door_box.visible = false
		return
	var c: Vector2i = _sel_edge.cell
	_sel_label.text = "Puerta entre (%d, %d) y su vecina al %s." % [c.x, c.y, DungeonMap.DIR_NAMES[_sel_edge.dir].to_lower()]
	var d := _map.door(c, _sel_edge.dir)
	_door_state.select(1 if d.get("open", false) else 0)
	_door_req.text = d.get("requires", "")
	_door_switch_only.set_pressed_no_signal(d.get("switch_only", false))
	_door_secret.set_pressed_no_signal(d.get("secret", false))
	_door_hidden.set_pressed_no_signal(d.get("hidden", false))
	_door_box.visible = true


# --- Luces ---

func _build_light_box(col: VBoxContainer) -> void:
	_light_box = VBoxContainer.new()
	_light_box.add_theme_constant_override("separation", 8)
	col.add_child(_light_box)
	_light_color = ColorPickerButton.new()
	_light_color.custom_minimum_size = Vector2(0, 40)
	_light_color.edit_alpha = false
	_light_color.color = Color(String(_light_values.color))
	_light_color.pressed.connect(func() -> void:
		if not _sel_light.is_empty():
			_push_undo())
	_light_color.color_changed.connect(func(cc: Color) -> void: _set_light_value("color", cc.to_html(false)))
	_light_box.add_child(_field("Color", _light_color))
	for spec: Array in [["energy", "Potencia", 0.1, 8.0, 0.1], ["range", "Alcance (m)", 1.0, 16.0, 0.5],
			["decay", "Caída (más = se apaga antes)", 0.2, 4.0, 0.1], ["height", "Altura (m)", 0.2, 2.4, 0.1]]:
		var key: String = spec[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var sl := HSlider.new()
		sl.min_value = spec[2]
		sl.max_value = spec[3]
		sl.step = spec[4]
		sl.value = float(_light_values[key])
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var val := Label.new()
		val.custom_minimum_size = Vector2(52, 0)
		val.text = "%.1f" % sl.value
		sl.drag_started.connect(func() -> void:
			if not _sel_light.is_empty():
				_push_undo())
		sl.value_changed.connect(func(v: float) -> void:
			val.text = "%.1f" % v
			_set_light_value(key, v))
		row.add_child(sl)
		row.add_child(val)
		_light_sliders[key] = sl
		_light_box.add_child(_field(spec[1], row))
	_light_box.add_child(_small("Los valores se usan para la próxima luz y cambian la seleccionada."))
	_light_box.visible = false


func _set_light_value(key: String, v: Variant) -> void:
	_light_values[key] = v
	if _sel_light.is_empty() or _map.light(_sel_light.cell).is_empty():
		return
	_map.lights[_sel_light.cell][key] = v
	_changed()


func _select_light(c: Vector2i) -> void:
	_sel_light = {"cell": c}
	var l := _map.light(c)
	for key: String in _light_sliders:
		_light_values[key] = l[key]
		_light_sliders[key].set_value_no_signal(float(l[key]))
		(_light_sliders[key].get_parent().get_child(1) as Label).text = "%.1f" % float(l[key])
	_light_values.color = l.color
	_light_color.color = Color(String(l.color))
	_set_status("Luz en (%d, %d): cambia sus valores en el panel." % [c.x, c.y])
	_plan.queue_redraw()


func _set_tool(t: String) -> void:
	if not t in TOOLS:
		t = "cells"
	_tool = t
	for k: String in _tool_buttons:
		_tool_buttons[k].set_pressed_no_signal(k == t)
	_tool_help.text = TOOL_HELP[t]
	_enemy_opt.get_parent().visible = t == "enemies"
	_stairs_opt.get_parent().visible = t == "stairs"
	_item_opt.get_parent().get_parent().visible = t == "items"
	_light_box.visible = t == "lights"
	if t != "lights":
		_sel_light = {}
	if t != "switches":
		_sel_switch = {}
	if _door_box:
		_refresh_selection()
	_plan.queue_redraw()


func _set_status(text: String, error := false) -> void:
	_status.text = text
	_status.tooltip_text = text
	_status.add_theme_color_override("font_color", UIStyle.RED if error else UIStyle.LIME)


func _clean(text: String) -> String:
	var t := text.strip_edges().to_lower().replace(" ", "_")
	var accents := {"á": "a", "é": "e", "í": "i", "ó": "o", "ú": "u", "ü": "u", "ñ": "n"}
	for ch: String in accents:
		t = t.replace(ch, accents[ch])
	var out := ""
	for ch in t:
		if ch.is_valid_identifier() or ch.is_valid_int() or ch == "-" or ch == "_":
			out += ch
	return out if out != "" else "mazmorra"


# =====================================================================================
# Cambios, deshacer y guardado
# =====================================================================================

func _push_undo() -> void:
	_undo.append(_map.to_dict())
	if _undo.size() > UNDO_MAX:
		_undo.pop_front()
	_redo.clear()


func _mark_dirty() -> void:
	if not _dirty:
		_dirty = true
		_title.queue_redraw()


## Tras cualquier cambio del mapa: plano, vista 3D (una vez por fotograma) e información.
func _changed() -> void:
	_mark_dirty()
	_rebuild_pending = true
	_plan.queue_redraw()
	_refresh_info()


func _restore(d: Dictionary) -> void:
	_map = DungeonMap.from_dict(d)
	_name_edit.text = _map.id
	_refresh_level()
	_refresh_themes()
	_refresh_palette()
	_refresh_selection()
	_changed()


func _undo_step() -> void:
	if _undo.is_empty():
		return
	_redo.append(_map.to_dict())
	_restore(_undo.pop_back())
	_set_status("Deshecho.")


func _redo_step() -> void:
	if _redo.is_empty():
		return
	_undo.append(_map.to_dict())
	_restore(_redo.pop_back())
	_set_status("Rehecho.")


func _save() -> void:
	var err := _map.save()
	if err != OK:
		_set_status("No se pudo guardar (%s)." % error_string(err), true)
		return
	_dirty = false
	_title.queue_redraw()
	_refresh_maps()
	_set_status("Guardado: %s" % DungeonMap.path_for(_map.id))


func _on_new() -> void:
	_push_undo()
	var m := _new_map()
	m.theme = _map.theme
	_map = m
	_load_into_ui()
	_mark_dirty()
	_set_status("Mapa nuevo (Cmd/Ctrl+Z para recuperar el anterior).")


func _open(id: String) -> void:
	var m := DungeonMap.load_map(id)
	if m == null:
		_set_status("No se pudo abrir «%s»." % id, true)
		return
	_push_undo()
	_map = m
	_dirty = false
	_load_into_ui()
	_set_status("Abierto: %s" % DungeonMap.path_for(id))


func _go_to_studio() -> void:
	SceneRouter.tool_context = {
		"back": SELF_PATH,
		"theme": _map.theme,
		"surface": DungeonTextures.SURFACE_DIR[_surface],
		"dungeon": _map.to_dict(), "dirty": _dirty, "tool": _tool, "paint_surface": _surface,
	}
	SceneRouter.go_to(TEXTURE_STUDIO)


## Editor de relieve con la textura elegida en la paleta (o la predeterminada).
func _go_to_relief() -> void:
	SceneRouter.tool_context = {
		"back": SELF_PATH,
		"theme": _map.theme,
		"surface": DungeonTextures.SURFACE_DIR[_surface],
		"texture": _paint_tex if _paint_tex != "" else DungeonTextures.default_name(_map.theme, _surface),
		"dungeon": _map.to_dict(), "dirty": _dirty, "tool": _tool, "paint_surface": _surface,
	}
	SceneRouter.go_to(RELIEF_EDITOR)


func _set_theme_default() -> void:
	if _paint_tex == "":
		return
	var err := DungeonTextures.set_default(_map.theme, _surface, _paint_tex)
	if err != OK:
		_set_status("No se pudo guardar tema.json (%s)." % error_string(err), true)
		return
	_set_status("«%s» es ahora la %s predeterminada de «%s»." % [_paint_tex, SURFACE_LABELS[SURFACES.find(_surface)].to_lower(), _map.theme])
	_refresh_palette()
	_rebuild_pending = true
	_plan.queue_redraw()


func _reload_textures() -> void:
	DungeonTextures.clear_cache()
	_refresh_themes()
	_refresh_palette()
	_rebuild_pending = true
	_plan.queue_redraw()
	_set_status("Texturas recargadas.")


func _notification(what: int) -> void:
	# Al volver a la ventana (p. ej. tras exportar desde otra copia del Estudio).
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and _palette != null:
		_reload_textures()


# =====================================================================================
# Plano 2D
# =====================================================================================

func _cell_at(p: Vector2) -> Vector2:
	return (p - _origin) / _cell_px


## Casilla bajo el ratón y, si está cerca de uno de sus lados, ese borde.
func _pick(p: Vector2) -> Dictionary:
	var g := _cell_at(p)
	var c := Vector2i(floori(g.x), floori(g.y))
	var f := g - Vector2(c)
	var dists := [f.y, 1.0 - f.x, 1.0 - f.y, f.x]   # N, E, S, O
	var best := 0
	for d in 4:
		if dists[d] < dists[best]:
			best = d
	return {"cell": c, "dir": best if dists[best] < 0.28 else -1}


func _fit_plan() -> void:
	var b := _map.bounds()
	var area := _plan.size if _plan.size.x > 10 else Vector2(1200, 860)
	_cell_px = clampf(minf(area.x / (b.size.x + 4), area.y / (b.size.y + 4)), 16.0, 72.0)
	_origin = (area * 0.5 - (Vector2(b.position) + Vector2(b.size) * 0.5) * _cell_px).floor()
	_plan.queue_redraw()


func _on_plan_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mb.pressed
		elif mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_zoom_plan(1.12 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12, mb.position)
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			if mb.pressed:
				_stroke_before = _map.to_dict()
				_stroke_button = mb.button_index
				_apply_tool(_pick(mb.position), mb.button_index == MOUSE_BUTTON_LEFT, true)
			elif mb.button_index == _stroke_button:
				_end_stroke()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _panning:
			_origin += mm.relative
			_plan.queue_redraw()
			return
		var h := _pick(mm.position)
		if h != _hover:
			_hover = h
			_plan.queue_redraw()
			if _stroke_button != 0 and _tool in ["cells", "paint", "walls"]:
				_apply_tool(h, _stroke_button == MOUSE_BUTTON_LEFT, false)
	elif event is InputEventMagnifyGesture:
		_zoom_plan((event as InputEventMagnifyGesture).factor, event.position)
	elif event is InputEventPanGesture:
		_origin -= (event as InputEventPanGesture).delta * 12.0
		_plan.queue_redraw()


func _zoom_plan(factor: float, at: Vector2) -> void:
	var g := _cell_at(at)
	_cell_px = clampf(_cell_px * factor, 12.0, 140.0)
	_origin = at - g * _cell_px
	_plan.queue_redraw()


## Un trazo (pulsar, arrastrar, soltar) es un solo paso de deshacer.
func _end_stroke() -> void:
	_stroke_button = 0
	if JSON.stringify(_stroke_before) != JSON.stringify(_map.to_dict()):
		_undo.append(_stroke_before)
		if _undo.size() > UNDO_MAX:
			_undo.pop_front()
		_redo.clear()
	_stroke_before = {}


func _apply_tool(h: Dictionary, primary: bool, first: bool) -> void:
	var c: Vector2i = h.cell
	var d: int = h.dir
	match _tool:
		"cells":
			if primary and _map.set_cell(c):
				_changed()
			elif not primary and _map.erase_cell(c):
				if c == _map.start:
					_set_status("Has borrado la casilla de inicio: colócalo otra vez con «Inicio».", true)
				_changed()
		"walls":
			if d < 0 or not _map.is_inner_edge(c, d):
				if first and d >= 0 and _map.edge_type(c, d) == DungeonMap.WALL:
					_set_status("Ese borde da al exterior: ya es pared (pinta la casilla de al lado para abrirlo).", true)
				return
			var t := _map.edge_type(c, d)
			if primary and t != DungeonMap.WALL:
				_map.set_edge_type(c, d, DungeonMap.WALL)
				_changed()
			elif not primary and t == DungeonMap.WALL:
				_map.set_edge_type(c, d, DungeonMap.OPEN)
				_changed()
		"doors":
			if not first or d < 0:
				return
			if not _map.is_inner_edge(c, d):
				_set_status("Las puertas van entre dos casillas pintadas: pinta primero la del otro lado.", true)
				return
			var t := _map.edge_type(c, d)
			if not primary:
				if t == DungeonMap.DOOR:
					_map.set_edge_type(c, d, DungeonMap.OPEN)
					_sel_edge = {}
					_refresh_selection()
					_changed()
				return
			if t != DungeonMap.DOOR:
				_map.set_edge_type(c, d, DungeonMap.DOOR)
				_changed()
			_sel_edge = {"cell": c, "dir": d}
			_refresh_selection()
			_plan.queue_redraw()
		"paint":
			if not _map.has_cell(c):
				return
			var tex := _paint_tex if primary else ""
			if _surface == "wall":
				if d < 0 or _map.edge_type(c, d) in [DungeonMap.OPEN, DungeonMap.NONE]:
					return
				if _map.face_texture(c, d) != tex:
					_map.set_face_texture(c, d, tex)
					_changed()
			elif _map.cell_texture(c, _surface) != tex:
				_map.set_cell_texture(c, _surface, tex)
				_changed()
		"start":
			if not first or not _map.has_cell(c):
				return
			if c == _map.start and _map.start_level == _map.level:
				_map.start_dir = (_map.start_dir + (1 if primary else 3)) % 4
			else:
				_map.start = c
				_map.start_level = _map.level
			_changed()
		"enemies":
			if primary:
				if _enemy_ids.is_empty():
					return
				if _map.thing(c).get("type", "") == DungeonMap.STAIRS:
					_set_status("Ahí hay una escalera.", true)
				elif _map.set_enemy(c, _enemy_ids[_enemy_opt.selected],
						_drop_ids[_drop_opt.selected - 1] if _drop_opt.selected > 0 else ""):
					_changed()
			elif _map.erase_enemy(c):
				_changed()
		"items":
			if primary:
				if _item_ids.is_empty():
					return
				if _map.thing(c).get("type", "") == DungeonMap.STAIRS:
					_set_status("Ahí hay una escalera.", true)
				elif _map.set_item(c, _item_ids[_item_opt.selected], int(_item_count.value)):
					_changed()
			elif _map.thing(c).get("type", "") == DungeonMap.ITEM and _map.erase_thing(c):
				_changed()
		"extraction":
			if primary:
				if _map.thing(c).get("type", "") not in ["", DungeonMap.EXTRACTION]:
					_set_status("Ahí ya hay algo.", true)
				elif _map.set_extraction(c):
					_changed()
			elif _map.thing(c).get("type", "") == DungeonMap.EXTRACTION and _map.erase_thing(c):
				_changed()
		"save":
			if primary:
				if _map.thing(c).get("type", "") not in ["", DungeonMap.SAVE]:
					_set_status("Ahí ya hay algo.", true)
				elif _map.set_save_point(c):
					_changed()
			elif _map.thing(c).get("type", "") == DungeonMap.SAVE and _map.erase_thing(c):
				_changed()
		"lights":
			if not first or not _map.has_cell(c):
				return
			if not primary:
				if _map.erase_light(c):
					_sel_light = {}
					_changed()
				return
			if _map.light(c).is_empty():
				_map.set_light(c, _light_values)
				_changed()
			_select_light(c)
		"switches":
			if not first:
				return
			if not primary:
				if _map.thing(c).get("type", "") == DungeonMap.SWITCH and _map.erase_thing(c):
					_sel_switch = {}
					_refresh_selection()
					_changed()
				return
			if not _sel_switch.is_empty() and d >= 0 and _map.edge_type(c, d) == DungeonMap.DOOR:
				var linked := _map.toggle_switch_door(_sel_switch.cell, DungeonMap.edge_key(c, d))
				_set_status("Puerta %s." % ("vinculada a la palanca" if linked else "desvinculada"))
				_refresh_selection()
				_changed()
				return
			if _map.thing(c).get("type", "") != DungeonMap.SWITCH:
				if not _map.has_cell(c) or _map.thing(c).get("type", "") == DungeonMap.STAIRS:
					return
				_map.set_switch(c)
				_changed()
				_set_status("Palanca puesta. Ahora haz clic en las puertas que debe abrir.")
			_sel_switch = {"cell": c}
			_refresh_selection()
			_plan.queue_redraw()
		"stairs":
			if not first:
				return
			var th := _map.thing(c)
			var is_stairs: bool = th.get("type", "") == DungeonMap.STAIRS
			if not primary:
				if _map.erase_stairs(c):
					_changed()
				return
			var up := _stairs_opt.selected == 0
			var d2 := _stairs_dir
			if is_stairs:
				up = th.up
				d2 = (int(th.dir) + 1) % 4
			_stairs_dir = d2
			var other := _map.place_stairs(c, up, d2)
			_refresh_level()
			_changed()
			_set_status("Escalera que %s a la %s (allí está la de vuelta). Clic otra vez para girarla." % [
					"sube" if up else "baja", _map.level_name(other).to_lower()])


func _draw_plan() -> void:
	var s := _plan.size
	_plan.draw_rect(Rect2(Vector2.ZERO, s), Color("16161c"))
	# Rejilla
	var first := _cell_at(Vector2.ZERO).floor()
	var last := _cell_at(s).ceil()
	var grid_col := Color(UIStyle.WHITE, 0.06)
	for x in range(int(first.x), int(last.x) + 1):
		var px := _origin.x + x * _cell_px
		_plan.draw_line(Vector2(px, 0), Vector2(px, s.y), grid_col, 1.0)
	for y in range(int(first.y), int(last.y) + 1):
		var py := _origin.y + y * _cell_px
		_plan.draw_line(Vector2(0, py), Vector2(s.x, py), grid_col, 1.0)
	# Ejes de la casilla (0, 0)
	_plan.draw_line(Vector2(_origin.x, 0), Vector2(_origin.x, s.y), Color(UIStyle.WHITE, 0.14), 1.0)
	_plan.draw_line(Vector2(0, _origin.y), Vector2(s.x, _origin.y), Color(UIStyle.WHITE, 0.14), 1.0)

	# Planta de debajo, en gris, para alinear.
	if _map.level > 0:
		for c: Vector2i in _map.floors[_map.level - 1].cells:
			var r := _cell_rect(c)
			_plan.draw_rect(r, Color(UIStyle.WHITE, 0.05))
			_plan.draw_rect(r.grow(-1), Color(UIStyle.WHITE, 0.12), false, 1.0)

	var show_surface := _surface if _tool == "paint" and _surface != "wall" else "floor"
	for c: Vector2i in _map.cells:
		var r := _cell_rect(c)
		var tex := DungeonTextures.resolve(_map.theme, show_surface, _map.cell_texture(c, show_surface))
		var rot := _map.cell_rot(c) if show_surface == "floor" else 0
		if rot == 0:
			_plan.draw_texture_rect(tex, r, false, Color(1, 1, 1, 0.85))
		else:
			_plan.draw_set_transform(r.get_center(), rot * PI * 0.5)
			_plan.draw_texture_rect(tex, Rect2(-r.size * 0.5, r.size), false, Color(1, 1, 1, 0.85))
			_plan.draw_set_transform(Vector2.ZERO)
		if _map.cell_texture(c, show_surface) != "" and _tool == "paint":
			_plan.draw_rect(r.grow(-3), Color(UIStyle.LIME, 0.55), false, 2.0)
	# Paredes y puertas
	var wall_w := maxf(3.0, _cell_px * 0.08)
	for c: Vector2i in _map.cells:
		var r := _cell_rect(c)
		for d in 4:
			var t := _map.edge_type(c, d)
			if t == DungeonMap.OPEN:
				continue
			if _tool == "paint" and _surface == "wall":
				_draw_face_strip(c, d, r)
			var seg := _side(r, d)
			if t == DungeonMap.WALL:
				_plan.draw_line(seg[0], seg[1], UIStyle.WHITE, wall_w)
			elif d == DungeonMap.N or d == DungeonMap.W:   # cada puerta, una vez
				_draw_door(seg[0], seg[1], wall_w, _map.is_secret(DungeonMap.edge_key(c, d)))
	_draw_things()
	# Selección y cursor
	if not _sel_edge.is_empty():
		var seg := _side(_cell_rect(_sel_edge.cell), _sel_edge.dir)
		_plan.draw_line(seg[0], seg[1], Color(UIStyle.VIOLET, 0.9), wall_w + 6.0)
	_draw_hover()
	_draw_start()
	# Escala
	_plan.draw_string(UIStyle.FONT_REGULAR, Vector2(16, s.y - 16), "Rueda: zoom · Clic central o dos dedos: mover",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(UIStyle.WHITE, 0.45))
	var frame := UIStyle.chamfer_rect(Rect2(Vector2(1, 1), s - Vector2(2, 2)), [0.0, 26.0, 0.0, 26.0])
	UIStyle.draw_outline(_plan, frame, UIStyle.LINE, 1.5)


func _cell_rect(c: Vector2i) -> Rect2:
	return Rect2(_origin + Vector2(c) * _cell_px, Vector2(_cell_px, _cell_px))


func _side(r: Rect2, d: int) -> Array[Vector2]:
	match d:
		DungeonMap.N: return [r.position, Vector2(r.end.x, r.position.y)]
		DungeonMap.E: return [Vector2(r.end.x, r.position.y), r.end]
		DungeonMap.S: return [Vector2(r.position.x, r.end.y), r.end]
		_: return [r.position, Vector2(r.position.x, r.end.y)]


## Franja con la textura de la cara de pared que mira a la casilla (modo Texturas · Pared).
func _draw_face_strip(c: Vector2i, d: int, r: Rect2) -> void:
	var w := _cell_px * 0.22
	var strip: Rect2
	match d:
		DungeonMap.N: strip = Rect2(r.position, Vector2(r.size.x, w))
		DungeonMap.S: strip = Rect2(Vector2(r.position.x, r.end.y - w), Vector2(r.size.x, w))
		DungeonMap.W: strip = Rect2(r.position, Vector2(w, r.size.y))
		_: strip = Rect2(Vector2(r.end.x - w, r.position.y), Vector2(w, r.size.y))
	var tex := DungeonTextures.resolve(_map.theme, "wall", _map.face_texture(c, d))
	_plan.draw_texture_rect(tex, strip, false)
	if _map.face_texture(c, d) != "":
		_plan.draw_rect(strip, UIStyle.LIME, false, 1.5)


## Puerta: muro con un hueco lima. La secreta, muro entero con trazos violeta.
func _draw_door(a: Vector2, b: Vector2, w: float, secret := false) -> void:
	if secret:
		_plan.draw_line(a, b, UIStyle.WHITE, w)
		_plan.draw_dashed_line(a, b, UIStyle.VIOLET, w * 0.6, w * 1.6)
		return
	var along := (b - a) / 3.0
	_plan.draw_line(a, a + along, UIStyle.WHITE, w)
	_plan.draw_line(b - along, b, UIStyle.WHITE, w)
	var n := along.normalized().orthogonal() * w * 1.3
	var p0 := a + along
	var p1 := b - along
	_plan.draw_colored_polygon(PackedVector2Array([p0 - n, p1 - n, p1 + n, p0 + n]), UIStyle.LIME)


func _draw_hover() -> void:
	if _hover.is_empty() or _test.visible:
		return
	var r := _cell_rect(_hover.cell)
	var d: int = _hover.dir
	var edge_tool := _tool in ["walls", "doors"] or (_tool == "paint" and _surface == "wall") \
			or (_tool == "switches" and not _sel_switch.is_empty() and d >= 0 and _map.edge_type(_hover.cell, d) == DungeonMap.DOOR)
	if edge_tool:
		if d >= 0:
			var seg := _side(r, d)
			_plan.draw_line(seg[0], seg[1], Color(UIStyle.LIME, 0.8), maxf(3.0, _cell_px * 0.08) + 4.0)
	else:
		_plan.draw_rect(r, Color(UIStyle.LIME, 0.18))
		_plan.draw_rect(r, Color(UIStyle.LIME, 0.8), false, 2.0)


func _draw_things() -> void:
	_draw_lights()
	for c: Vector2i in _map.things:
		if not _map.has_cell(c):
			continue
		var th: Dictionary = _map.things[c]
		var r := _cell_rect(c)
		if th.type == DungeonMap.ENEMY:
			var center := r.get_center()
			var rad := _cell_px * 0.36
			var col := CharacterDB.color(th.enemy)
			_plan.draw_circle(center, rad + 2.0, UIStyle.INK)
			var tex := CharacterDB.portrait(th.enemy)
			if tex != null:
				var face := CharacterDB.face_region(th.enemy)
				_plan.draw_texture_rect_region(tex, Rect2(center - Vector2(rad, rad), Vector2(rad, rad) * 2.0), face)
			else:
				_plan.draw_circle(center, rad, col)
			_plan.draw_arc(center, rad, 0, TAU, 32, col, maxf(2.0, _cell_px * 0.06))
			if th.get("drop", "") != "":
				# Suelta algo: rombo lima en la esquina.
				var dc := r.position + Vector2(_cell_px * 0.82, _cell_px * 0.18)
				var k := _cell_px * 0.13
				var dia := PackedVector2Array([dc + Vector2(0, -k), dc + Vector2(k, 0), dc + Vector2(0, k), dc + Vector2(-k, 0)])
				_plan.draw_colored_polygon(dia, UIStyle.LIME)
				UIStyle.draw_outline(_plan, dia, UIStyle.INK, 1.5)
		elif th.type == DungeonMap.SAVE:
			var center := r.get_center()
			var k := _cell_px * 0.3
			var dia := PackedVector2Array([center + Vector2(0, -k), center + Vector2(k, 0), center + Vector2(0, k), center + Vector2(-k, 0)])
			_plan.draw_colored_polygon(dia, UIStyle.CYAN)
			UIStyle.draw_outline(_plan, dia, UIStyle.INK, 2.0)
		elif th.type == DungeonMap.EXTRACTION:
			_plan.draw_arc(r.get_center(), _cell_px * 0.34, 0, TAU, 32, UIStyle.CYAN, maxf(2.0, _cell_px * 0.08), true)
		elif th.type == DungeonMap.ITEM:
			var center := r.get_center()
			var k := _cell_px * 0.26
			var dia := PackedVector2Array([center + Vector2(0, -k), center + Vector2(k, 0), center + Vector2(0, k), center + Vector2(-k, 0)])
			_plan.draw_colored_polygon(dia, UIStyle.LIME)
			UIStyle.draw_outline(_plan, dia, UIStyle.INK, 2.0)
			if int(th.get("count", 1)) > 1:
				_plan.draw_string(UIStyle.FONT_BOLD_ITALIC, r.position + Vector2(_cell_px * 0.62, _cell_px * 0.95), "×%d" % th.count,
						HORIZONTAL_ALIGNMENT_LEFT, -1, int(maxf(10.0, _cell_px * 0.24)), UIStyle.WHITE)
		elif th.type == DungeonMap.SWITCH:
			var center := r.get_center()
			var selected: bool = not _sel_switch.is_empty() and _sel_switch.cell == c
			for k: String in th.doors:
				var cs := DungeonMap.key_cells(k)
				if _map.edges.get(k, {}).get("type", "") != DungeonMap.DOOR:
					continue
				var mid := (_cell_rect(cs[0]).get_center() + _cell_rect(cs[1]).get_center()) * 0.5
				_plan.draw_dashed_line(center, mid, Color(UIStyle.VIOLET, 0.95 if selected else 0.45), 2.5 if selected else 1.5, 8.0)
			var box := Rect2(center - Vector2.ONE * _cell_px * 0.22, Vector2.ONE * _cell_px * 0.44)
			_plan.draw_rect(box, UIStyle.INK)
			_plan.draw_rect(box, UIStyle.VIOLET if not selected else UIStyle.WHITE, false, 2.0)
			_plan.draw_line(center + Vector2(0, _cell_px * 0.12), center + Vector2(_cell_px * 0.1, -_cell_px * 0.14), UIStyle.LIME, maxf(2.0, _cell_px * 0.06))
		elif th.type == DungeonMap.STAIRS:
			var col := UIStyle.LIME if th.up else UIStyle.VIOLET
			_plan.draw_rect(r.grow(-_cell_px * 0.1), Color(UIStyle.INK, 0.75))
			var f := Vector2(DungeonMap.DIRS[th.dir])
			var side := f.orthogonal()
			# Peldaños: más claros hacia donde sube, más oscuros hacia donde baja.
			for i in 4:
				var a := r.get_center() + f * _cell_px * (-0.3 + i * 0.2)
				var w := Color(col, (0.35 + i * 0.2) if th.up else (0.95 - i * 0.2))
				_plan.draw_line(a - side * _cell_px * 0.32, a + side * _cell_px * 0.32, w, maxf(2.0, _cell_px * 0.07))
			_plan.draw_string(UIStyle.FONT_BOLD_ITALIC, r.position + Vector2(4, _cell_px * 0.3), "▲" if th.up else "▼",
					HORIZONTAL_ALIGNMENT_LEFT, -1, int(maxf(10.0, _cell_px * 0.26)), col)


## Puntos de luz: su alcance (círculo tenue) y la bombilla con su color.
func _draw_lights() -> void:
	for c: Vector2i in _map.lights:
		var l: Dictionary = _map.lights[c]
		var col := Color(String(l.color))
		var center := _cell_rect(c).get_center() + Vector2(_cell_px * 0.3, -_cell_px * 0.3)
		var reach := float(l.range) / DungeonBuilder.tile() * _cell_px
		var selected: bool = not _sel_light.is_empty() and _sel_light.cell == c
		if _tool == "lights" or selected:
			_plan.draw_circle(center, reach, Color(col, 0.07))
			_plan.draw_arc(center, reach, 0, TAU, 48, Color(col, 0.5 if selected else 0.25), 1.5, true)
		_plan.draw_circle(center, _cell_px * 0.13, col)
		_plan.draw_arc(center, _cell_px * 0.13, 0, TAU, 16, UIStyle.WHITE if selected else UIStyle.INK, 2.0, true)


func _draw_start() -> void:
	if _map.start_level != _map.level:
		return
	var r := _cell_rect(_map.start)
	var c := r.get_center()
	var f := Vector2(DungeonMap.DIRS[_map.start_dir])
	var side := f.orthogonal()
	var k := _cell_px * 0.32
	var ok := _map.has_cell(_map.start)
	var col := UIStyle.LIME if ok else UIStyle.RED
	var tri := PackedVector2Array([c + f * k, c - f * k * 0.6 + side * k * 0.7, c - f * k * 0.3, c - f * k * 0.6 - side * k * 0.7])
	_plan.draw_colored_polygon(tri, col)
	UIStyle.draw_outline(_plan, tri, UIStyle.INK, 2.0)


# =====================================================================================
# Vista 3D
# =====================================================================================

func _process(_delta: float) -> void:
	if _rebuild_pending:
		_rebuild()


func _rebuild() -> void:
	_rebuild_pending = false
	if _model:
		_model.queue_free()
	_model = DungeonBuilder.build(_map)
	_world.add_child(_model)
	_apply_ceiling()
	_refresh_info()


func _apply_ceiling() -> void:
	if _model:
		_model.get_node("Techos").visible = _show_ceiling


func _frame_preview() -> void:
	var b := _map.bounds()
	var t := TextureFormats.TILE_SIZE_M
	_target = Vector3((b.position.x + b.size.x * 0.5) * t, 0.0, (b.position.y + b.size.y * 0.5) * t)
	_dist = maxf(8.0, maxf(b.size.x, b.size.y) * t * 1.5)
	_yaw = 0.6
	_pitch = 0.95
	_update_camera()


func _update_camera() -> void:
	var offset := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _dist
	_camera.look_at_from_position(_target + offset, _target)


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_LEFT]:
			_orbiting = mb.pressed
		elif mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_dist = clampf(_dist * (0.9 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 3.0, 200.0)
			_update_camera()
	elif event is InputEventMouseMotion and _orbiting:
		var rel := (event as InputEventMouseMotion).relative
		_yaw -= rel.x * 0.008
		_pitch = clampf(_pitch + rel.y * 0.006, 0.15, 1.5)
		_update_camera()
	elif event is InputEventMagnifyGesture:
		_dist = clampf(_dist / (event as InputEventMagnifyGesture).factor, 3.0, 200.0)
		_update_camera()


# =====================================================================================
# Probar mapa
# =====================================================================================

func _start_test() -> void:
	if not _map.floors[_map.start_level].cells.has(_map.start):
		_set_status("El inicio no está en una casilla: colócalo con la herramienta «Inicio».", true)
		return
	# Una copia: el explorador cambia de planta y no debe mover la del editor.
	_explorer.setup(DungeonMap.from_dict(_map.to_dict()))
	_test.visible = true
	_test_msg.modulate.a = 0.0


## Choque con un enemigo durante la prueba: el combate de verdad.
func _on_encounter(enemy_id: String, cell: Vector2i) -> void:
	if _combat.visible:
		return
	_combat.setup(enemy_id)
	_combat.begin()
	var won: bool = await _combat.finished
	_combat.visible = false
	if won:
		_explorer.defeat(cell)
		_explorer.message.emit("¡%s derrotado!" % CharacterDB.display_name(enemy_id))
	else:
		_explorer.message.emit("%s sigue ahí." % CharacterDB.display_name(enemy_id))


func _stop_test() -> void:
	_test.visible = false
	_set_status("Has vuelto al editor.")


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	if _test.visible:
		if _combat.visible:
			return
		var action := ""
		match key.physical_keycode:
			KEY_W, KEY_UP: action = "forward"
			KEY_S, KEY_DOWN: action = "back"
			KEY_A, KEY_LEFT: action = "left"
			KEY_D, KEY_RIGHT: action = "right"
			KEY_Q: action = "strafe_left"
			KEY_E: action = "strafe_right"
			KEY_SPACE, KEY_ENTER: action = "interact"
			KEY_ESCAPE: _stop_test()
		if action != "" and not key.echo:
			_explorer.act(action)
		elif action in ["forward", "back", "strafe_left", "strafe_right"]:
			_explorer.act(action)   # mantener pulsado: sigue andando
		get_viewport().set_input_as_handled()
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	var cmd := key.is_command_or_control_pressed()
	match key.keycode:
		KEY_Z when cmd:
			if key.shift_pressed:
				_redo_step()
			else:
				_undo_step()
		KEY_Y when cmd:
			_redo_step()
		KEY_S when cmd:
			_save()
		KEY_P:
			_start_test()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
			_set_tool(TOOLS[key.keycode - KEY_1])
		KEY_0:
			_set_tool("extraction")
		KEY_R when _tool == "paint" and _surface == "floor" and not _hover.is_empty() and _map.has_cell(_hover.cell):
			_push_undo()
			_map.set_cell_rot(_hover.cell, _map.cell_rot(_hover.cell) + (3 if key.shift_pressed else 1))
			_changed()
			_set_status("Suelo girado: lo de arriba de la imagen mira al %s." % DungeonMap.DIR_NAMES[_map.cell_rot(_hover.cell)].to_lower())
		KEY_PAGEUP:
			_change_level(1)
		KEY_PAGEDOWN:
			_change_level(-1)
		_:
			return
	get_viewport().set_input_as_handled()


# =====================================================================================
# Dibujo
# =====================================================================================

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UIStyle.INK)


func _draw_title() -> void:
	var c := _title
	c.draw_colored_polygon(UIStyle.slanted_rect(Rect2(0, 6, 12, 60), 5), UIStyle.LIME)
	var t := "Editor de mazmorras" + ("  •" if _dirty else "")
	c.draw_string(UIStyle.FONT_HEAVY_ITALIC, Vector2(28, 46), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, UIStyle.WHITE)
	var sub := "PLANO · VISTA 3D · PROBAR  —  %s" % ("%s · %s" % [_map.id.to_upper(), _map.level_name().to_upper()] if _map else "")
	UIStyle.draw_spaced(c, UIStyle.FONT_REGULAR, Vector2(30, 72), sub, 15, 3.0, Color(UIStyle.WHITE, 0.6))
