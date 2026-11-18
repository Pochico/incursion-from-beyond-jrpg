@tool
class_name DateHeader
extends Control
## Cabecera de fecha «/ MAR | 17 NOV 2026» de la esquina superior derecha.
## Se dibuja alineada a la derecha del control.
##
## Variantes:
##  - MAP:      día grande en cursiva, separador lima y «///» (pantalla de mapa).
##  - SCENARIO: icono de calendario, «MAR | 17», «NOV 2026» y «/» violeta.

enum Variant { MAP, SCENARIO }

@export var variant: Variant = Variant.MAP:
	set(value):
		variant = value
		queue_redraw()

@export var weekday: String = "MAR":
	set(value):
		weekday = value
		queue_redraw()

@export var day: int = 17:
	set(value):
		day = value
		queue_redraw()

@export var month: String = "NOV":
	set(value):
		month = value
		queue_redraw()

@export var year: int = 2026:
	set(value):
		year = value
		queue_redraw()

## Si está activo, muestra la fecha de GameState y se actualiza sola.
@export var follow_game_state: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if follow_game_state and not Engine.is_editor_hint():
		GameState.changed.connect(_sync)
		_sync()


func _sync() -> void:
	weekday = GameState.weekday_short()
	day = int(GameState.date.day)
	month = GameState.month_short()
	year = int(GameState.date.year)


func _get_minimum_size() -> Vector2:
	return Vector2(400, 112)


func _draw() -> void:
	if variant == Variant.SCENARIO:
		_draw_scenario()
	else:
		_draw_map()


func _draw_scenario() -> void:
	var right := size.x
	# «/» violeta al final.
	draw_line(Vector2(right - 26, 74), Vector2(right, 18), UIStyle.VIOLET, 2.5, true)
	var text_r := right - 44.0
	# Fila 1: «MAR | 17»
	var f := UIStyle.FONT_MEDIUM
	var day_text := str(day)
	var day_w := f.get_string_size(day_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	var wd_w := f.get_string_size(weekday, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	var day_x := text_r - day_w
	draw_string(f, Vector2(day_x, 44), day_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, UIStyle.WHITE)
	var sep_x := day_x - 16.0
	draw_line(Vector2(sep_x, 20), Vector2(sep_x, 46), UIStyle.LIME, 2.0)
	var wd_x := sep_x - 16.0 - wd_w
	draw_string(f, Vector2(wd_x, 44), weekday, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, UIStyle.WHITE)
	# Fila 2: «NOV 2026» espaciado.
	var row2 := "%s %d" % [month, year]
	var r2w := UIStyle.spaced_width(UIStyle.FONT_REGULAR, row2, 20, 2.5)
	UIStyle.draw_spaced(self, UIStyle.FONT_REGULAR, Vector2(text_r - r2w, 78), row2, 20, 2.5, Color(UIStyle.WHITE, 0.9))
	# Icono de calendario lima.
	UIIcons.calendar(self, Vector2(wd_x - 34, 32), 28, UIStyle.LIME)


func _draw_map() -> void:
	var f_small := UIStyle.FONT_BOLD
	var f_day := UIStyle.FONT_HEAVY_ITALIC
	var right := size.x
	var y_base := 76.0

	# Bloque mes / año (a la derecha del todo).
	var month_w := UIStyle.spaced_width(f_small, month, 24, 3.0)
	var year_text := str(year)
	var year_w := f_small.get_string_size(year_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var block_w := maxf(month_w, year_w)
	var block_x := right - block_w
	UIStyle.draw_spaced(self, f_small, Vector2(block_x, 42), month, 24, 3.0, UIStyle.WHITE)
	draw_string(f_small, Vector2(block_x, y_base), year_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UIStyle.WHITE)

	# Día grande.
	var day_text := str(day)
	var day_w := f_day.get_string_size(day_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 72).x
	var day_x := block_x - 26.0 - day_w
	draw_string(f_day, Vector2(day_x, y_base + 6), day_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 72, UIStyle.WHITE)

	# Separador lima.
	var sep_x := day_x - 30.0
	draw_line(Vector2(sep_x, 18), Vector2(sep_x, 84), UIStyle.LIME, 3.0)

	# Día de la semana.
	var wd_w := f_small.get_string_size(weekday, HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x
	var wd_x := sep_x - 32.0 - wd_w
	draw_string(f_small, Vector2(wd_x, y_base), weekday, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, UIStyle.WHITE)

	# Línea inferior con diagonal de entrada y «///» final (blanco + lima).
	var y := 100.0
	var start_x := wd_x - 70.0
	var stripes_w := 3 * 14.0 + 2 * 6.0
	var line_end := right - stripes_w - 12.0
	draw_line(Vector2(start_x + 30, y - 40), Vector2(start_x, y), Color(UIStyle.WHITE, 0.9), 2.0, true)
	draw_line(Vector2(start_x, y), Vector2(line_end, y), Color(UIStyle.WHITE, 0.9), 2.0, true)
	UIStyle.draw_stripes(self, Vector2(line_end + 8, y + 6), 3, Vector2(14, 14), 6, UIStyle.WHITE,
			[UIStyle.WHITE, UIStyle.LIME, UIStyle.LIME])
