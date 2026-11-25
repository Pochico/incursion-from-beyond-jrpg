class_name DebugRelations
extends Control
## Depuración: editar en directo lo que siente un personaje y su ánimo.
##
## Se abre desde la app Relaciones del móvil (solo en versiones de depuración:
## `OS.is_debug_build()`, que incluye ejecutar desde el editor). Barras deslizables
## (ratón o dedo) para cada dimensión de `Social.DIMENSIONS` hacia Ren u otro
## personaje («Hacia»), botones de ánimo y su intensidad. Los cambios se aplican al
## momento en `GameState`; al cerrar se guarda la partida.

signal closed

const PANEL_SIZE := Vector2(432, 900)
const DIM_NAMES := {"afecto": "Afecto", "confianza": "Confianza", "respeto": "Respeto",
	"atraccion": "Atracción", "miedo": "Miedo", "asco": "Asco", "resentimiento": "Resentimiento"}
const MOOD_NAMES := {"alegre": "Alegre", "tranquilo": "Tranquilo", "curioso": "Curioso",
	"irritado": "Irritado", "ansioso": "Ansioso", "triste": "Triste"}

var _who := ""
var _target := CharacterDB.PROTAGONIST
var _box: Control
var _title: Label
var _target_button: Button
var _sliders := {}        # dim -> HSlider
var _values := {}         # dim -> Label
var _mood_buttons := {}   # mood -> Button
var _intensity: HSlider
var _intensity_label: Label
var _syncing := false     # al rellenar las barras no se reescribe el estado


static func enabled() -> bool:
	return OS.is_debug_build()


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func open(who: String, at: Vector2) -> void:
	_who = who
	_target = CharacterDB.PROTAGONIST
	_box.position = at
	visible = true
	_refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	GameState.save_game()
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("open_phone")):
		close()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	# Tocar fuera del panel lo cierra.
	if event is InputEventMouseButton and event.pressed and not _box.get_rect().has_point(event.position):
		close()
		accept_event()


# --- Construcción ---------------------------------------------------------------------

func _build() -> void:
	_box = Control.new()
	_box.size = PANEL_SIZE
	_box.draw.connect(func() -> void:
		var shape := UIStyle.chamfer_rect(Rect2(Vector2.ZERO, PANEL_SIZE), [18.0, 18.0, 18.0, 18.0])
		_box.draw_colored_polygon(shape, Color(UIStyle.INK, 0.97))
		UIStyle.draw_outline(_box, shape, UIStyle.LIME, 2.0))
	add_child(_box)
	var col := VBoxContainer.new()
	col.position = Vector2(22, 18)
	col.size = PANEL_SIZE - Vector2(44, 36)
	col.add_theme_constant_override("separation", 4)
	_box.add_child(col)

	var tag := _label("DEPURACIÓN", 14, UIStyle.LIME)
	col.add_child(tag)
	var head := HBoxContainer.new()
	_title = _label("", 30, UIStyle.WHITE)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_target_button = _button("", 16)
	_target_button.pressed.connect(_next_target)
	head.add_child(_target_button)
	col.add_child(head)

	for dim: String in Social.DIMENSIONS:
		var range_: Vector2 = Social.DIMENSIONS[dim]
		var row := HBoxContainer.new()
		var name_label := _label(DIM_NAMES.get(dim, dim), 17, Color(UIStyle.WHITE, 0.8))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		_values[dim] = _label("0", 17, UIStyle.LIME)
		row.add_child(_values[dim])
		col.add_child(row)
		var slider := _slider(range_.x, range_.y)
		slider.value_changed.connect(_on_dim_changed.bind(dim))
		_sliders[dim] = slider
		col.add_child(slider)

	col.add_child(_spacer(8))
	col.add_child(_label("Ánimo", 17, Color(UIStyle.WHITE, 0.8)))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for m: String in Social.MOODS:
		var b := _button(MOOD_NAMES.get(m, m), 17)
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(122, 44)
		b.pressed.connect(_on_mood.bind(m))
		_mood_buttons[m] = b
		grid.add_child(b)
	col.add_child(grid)
	var irow := HBoxContainer.new()
	var ilabel := _label("Intensidad", 17, Color(UIStyle.WHITE, 0.8))
	ilabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	irow.add_child(ilabel)
	_intensity_label = _label("0", 17, UIStyle.LIME)
	irow.add_child(_intensity_label)
	col.add_child(_spacer(4))
	col.add_child(irow)
	_intensity = _slider(0, 100)
	_intensity.value_changed.connect(_on_intensity)
	col.add_child(_intensity)

	col.add_child(_spacer(10))
	var done := _button("Listo", 20)
	done.custom_minimum_size = Vector2(0, 52)
	done.pressed.connect(close)
	col.add_child(done)


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


## Barra deslizable grande, cómoda con el dedo.
func _slider(lo: float, hi: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 1
	s.custom_minimum_size = Vector2(0, 40)
	s.focus_mode = Control.FOCUS_NONE
	var track := StyleBoxFlat.new()
	track.bg_color = Color(UIStyle.WHITE, 0.14)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := StyleBoxFlat.new()
	fill.bg_color = UIStyle.VIOLET
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := _knob()
	s.add_theme_icon_override("grabber", knob)
	s.add_theme_icon_override("grabber_highlight", knob)
	return s


static var _knob_texture: Texture2D

static func _knob() -> Texture2D:
	if _knob_texture == null:
		var n := 30
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var c := Vector2(n, n) * 0.5
		for y in n:
			for x in n:
				var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
				var a := clampf(n * 0.5 - d, 0.0, 1.0)
				var col := UIStyle.LIME if d < n * 0.5 - 3 else UIStyle.INK
				img.set_pixel(x, y, Color(col, a))
		_knob_texture = ImageTexture.create_from_image(img)
	return _knob_texture


func _button(text: String, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", UIStyle.WHITE)
	b.add_theme_color_override("font_hover_color", UIStyle.WHITE)
	b.add_theme_color_override("font_pressed_color", UIStyle.INK)
	b.add_theme_color_override("font_hover_pressed_color", UIStyle.INK)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(UIStyle.WHITE, 0.06)
	normal.border_color = Color(UIStyle.WHITE, 0.5)
	normal.set_border_width_all(1)
	normal.set_content_margin_all(8)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = UIStyle.LIME
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = UIStyle.LIME
	pressed.border_color = UIStyle.LIME
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	return b


# --- Estado ---------------------------------------------------------------------------

func _refresh() -> void:
	_syncing = true
	_title.text = CharacterDB.display_name(_who)
	_target_button.text = "Hacia: %s  ›" % CharacterDB.display_name(_target)
	var rel := Social.relation(_who, _target)
	for dim: String in _sliders:
		(_sliders[dim] as HSlider).value = rel[dim]
		(_values[dim] as Label).text = str(roundi(rel[dim]))
	var m := Social.mood(_who)
	for id: String in _mood_buttons:
		(_mood_buttons[id] as Button).button_pressed = id == m.id
	_intensity.value = m.intensity
	_intensity_label.text = str(roundi(m.intensity))
	_syncing = false


## Ren, los de la app Relaciones y luego el resto con ficha (menos el propio).
func _targets() -> Array:
	var out: Array = [CharacterDB.PROTAGONIST]
	for id: String in CharacterDB.RELATIONS + CharacterDB.with_profile():
		if id != _who and not id in out:
			out.append(id)
	return out


func _next_target() -> void:
	var t := _targets()
	_target = t[(t.find(_target) + 1) % t.size()]
	_refresh()


func _on_dim_changed(v: float, dim: String) -> void:
	(_values[dim] as Label).text = str(roundi(v))
	if _syncing:
		return
	if not GameState.relations.has(_who):
		GameState.relations[_who] = {}
	var rel := Social.relation(_who, _target)
	rel[dim] = v
	GameState.relations[_who][_target] = rel


func _on_mood(mood_id: String) -> void:
	Social.set_mood(_who, mood_id, _intensity.value)
	_refresh()


func _on_intensity(v: float) -> void:
	_intensity_label.text = str(roundi(v))
	if not _syncing:
		Social.set_mood(_who, Social.mood(_who).id, v)
