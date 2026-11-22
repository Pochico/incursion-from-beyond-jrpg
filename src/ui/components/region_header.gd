@tool
class_name RegionHeader
extends Control
## Cabecera «REGIÓN / LEGANÉS» de la esquina superior izquierda.
##
## Variantes (según las referencias de docs/ui/referencias):
##  - MAP:      grande, cursiva gruesa, barra lima y «///» (pantalla de mapa).
##  - SCENARIO: «//» lima, nombre recto y fino, subrayado con remate violeta.
##  - COMPACT:  pequeña, para la interfaz de conversación.

enum Variant { MAP, SCENARIO, COMPACT }

@export var variant: Variant = Variant.MAP:
	set(value):
		variant = value
		queue_redraw()

@export var caption: String = "REGIÓN":
	set(value):
		caption = value
		queue_redraw()

@export var region_name: String = "Leganés":
	set(value):
		region_name = value
		queue_redraw()

## Si está activo, muestra la región de GameState y se actualiza sola.
@export var follow_game_state: bool = true

## Con `follow_game_state`: muestra la ubicación actual como nombre y la región
## como rótulo pequeño (escenarios y conversación), en vez de «REGIÓN / LEGANÉS».
@export var show_location: bool = false:
	set(value):
		show_location = value
		if follow_game_state and is_inside_tree() and not Engine.is_editor_hint():
			_sync()

@export var accent: Color = UIStyle.LIME:
	set(value):
		accent = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if follow_game_state and not Engine.is_editor_hint():
		GameState.changed.connect(_sync)
		_sync()


func _sync() -> void:
	if show_location:
		caption = GameState.region_name
		region_name = LocationDB.display_name(GameState.location_id)
	else:
		caption = "REGIÓN"
		region_name = GameState.region_name


func _get_minimum_size() -> Vector2:
	return Vector2(420, 112)


func _draw() -> void:
	match variant:
		Variant.MAP:
			_draw_map()
		Variant.SCENARIO:
			_draw_scenario()
		Variant.COMPACT:
			_draw_compact()


func _draw_map() -> void:
	var font_caption := UIStyle.FONT_BOLD_ITALIC
	var font_name := UIStyle.FONT_HEAVY_ITALIC

	# Barra vertical de acento.
	draw_rect(Rect2(0, 6, 10, 64), accent)

	# «R E G I Ó N»
	UIStyle.draw_spaced(self, font_caption, Vector2(34, 26), caption.to_upper(), 20, 4.0, Color(UIStyle.WHITE, 0.85))

	# Nombre de la región.
	var name_text := region_name.to_upper()
	draw_string(font_name, Vector2(30, 72), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 52, UIStyle.WHITE)
	var name_w := font_name.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 52).x

	# Subrayado con quiebro diagonal y «///».
	var line_end := maxf(name_w + 40.0, 300.0)
	var y := 98.0
	draw_line(Vector2(0, y), Vector2(line_end, y), Color(UIStyle.WHITE, 0.9), 2.0, true)
	draw_line(Vector2(line_end, y), Vector2(line_end + 24, y - 22), Color(UIStyle.WHITE, 0.9), 2.0, true)
	UIStyle.draw_stripes(self, Vector2(line_end + 26, y - 6), 3, Vector2(14, 14), 6, UIStyle.WHITE)


func _draw_scenario() -> void:
	# «//» lima.
	for i in 2:
		var x := 4.0 + i * 16.0
		draw_line(Vector2(x, 62), Vector2(x + 22, 12), accent, 5.0, true)
	var x0 := 58.0
	UIStyle.draw_spaced(self, UIStyle.FONT_REGULAR, Vector2(x0, 28), caption.to_upper(), 18, 1.5, Color(UIStyle.WHITE, 0.9))
	var name_text := region_name.to_upper()
	var name_w := UIStyle.draw_spaced(self, UIStyle.FONT_MEDIUM, Vector2(x0 - 1, 66), name_text, 34, 2.0, UIStyle.WHITE)
	# Subrayado fino con remate violeta.
	var y := 84.0
	var end_x := x0 + maxf(name_w + 50.0, 240.0)
	draw_line(Vector2(x0, y), Vector2(end_x, y), Color(UIStyle.WHITE, 0.9), 1.5, true)
	draw_line(Vector2(end_x + 6, y), Vector2(end_x + 42, y), UIStyle.VIOLET, 4.0)


func _draw_compact() -> void:
	draw_colored_polygon(UIStyle.slanted_rect(Rect2(0, 8, 12, 42), 4), accent)
	UIStyle.draw_spaced(self, UIStyle.FONT_REGULAR_ITALIC, Vector2(34, 22), caption.to_upper(), 16, 3.0, Color(UIStyle.WHITE, 0.85))
	var name_text := region_name.to_upper()
	draw_string(UIStyle.FONT_ITALIC, Vector2(30, 56), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, UIStyle.WHITE)
	var name_w := UIStyle.FONT_ITALIC.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
	var y := 74.0
	var line_end := 30.0 + name_w + 36.0
	draw_line(Vector2(0, y), Vector2(line_end, y), Color(UIStyle.WHITE, 0.85), 1.5, true)
	draw_line(Vector2(line_end, y), Vector2(line_end + 14, y - 12), Color(UIStyle.WHITE, 0.85), 1.5, true)
	UIStyle.draw_stripes(self, Vector2(line_end + 16, y - 2), 3, Vector2(11, 9), 4, Color(UIStyle.WHITE, 0.9))
