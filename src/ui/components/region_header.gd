@tool
class_name RegionHeader
extends Control
## Cabecera «REGIÓN / LEGANÉS» de la esquina superior izquierda.

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
	region_name = GameState.region_name


func _get_minimum_size() -> Vector2:
	return Vector2(420, 112)


func _draw() -> void:
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
