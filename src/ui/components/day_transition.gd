class_name DayTransition
extends Control
## Paso al día siguiente: un reloj cuyas agujas corren hasta la mañana y una
## hoja de calendario en la que cambian el número y el día de la semana.
##
##   var t := DayTransition.new()
##   add_child(t)
##   await t.play(fecha_antes, fecha_despues, hora_antes)
##
## Las fechas son {weekday, day, month} (weekday en texto largo, month abreviado).

const DURATION := 3.4
const WAKE_HOUR := 7.0
const CLOCK_C := Vector2(740, 500)
const CLOCK_R := 170.0
const CARD := Rect2(1040, 300, 300, 380)

var _from: Dictionary
var _to: Dictionary
var _from_hour := 23.0
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func play(from: Dictionary, to: Dictionary, from_hour: float) -> void:
	_from = from
	_to = to
	_from_hour = from_hour
	_t = 0.0
	queue_redraw()
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		_t = v
		queue_redraw(), 0.0, 1.0, DURATION)
	tw.tween_interval(0.9)
	await tw.finished


## Hora que marca el reloj ahora (puede pasar de 24).
func _clock_hour() -> float:
	var target := WAKE_HOUR + 24.0
	if _from_hour < WAKE_HOUR:
		target = WAKE_HOUR   # Si se duerme de madrugada, despierta esa misma mañana.
	var k := smoothstep(0.05, 0.8, _t)
	return lerpf(_from_hour, target, k)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UIStyle.INK)
	if _to.is_empty():
		return   # Aún sin fechas (antes de play).
	_draw_clock()
	_draw_card()
	# Pie: «Martes 17 · Mañana».
	var a := smoothstep(0.82, 1.0, _t)
	if a > 0.0:
		var caption := "%s %d  ·  Mañana" % [_to.weekday, _to.day]
		var f := UIStyle.FONT_BOLD_ITALIC
		var w := f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
		draw_string(f, Vector2((size.x - w) * 0.5, 800 + (1.0 - a) * 16.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 40,
				Color(UIStyle.WHITE, a))


func _draw_clock() -> void:
	var c := CLOCK_C
	draw_circle(c, CLOCK_R, Color(UIStyle.GRAPHITE, 0.6))
	draw_arc(c, CLOCK_R, 0, TAU, 96, Color(UIStyle.WHITE, 0.35), 3.0, true)
	for i in 60:
		var ang := i * TAU / 60.0 - PI * 0.5
		var dir := Vector2(cos(ang), sin(ang))
		var big := i % 5 == 0
		var tick_len := 22.0 if i % 15 == 0 else (14.0 if big else 6.0)
		var col := UIStyle.LIME if i % 15 == 0 else Color(UIStyle.WHITE, 0.7 if big else 0.3)
		draw_line(c + dir * (CLOCK_R - 10 - tick_len), c + dir * (CLOCK_R - 10), col, 3.0 if big else 1.5, true)
	var h := _clock_hour()
	var min_ang := fmod(h, 1.0) * TAU - PI * 0.5
	var hour_ang := fmod(h, 12.0) / 12.0 * TAU - PI * 0.5
	draw_line(c, c + Vector2(cos(hour_ang), sin(hour_ang)) * CLOCK_R * 0.5, UIStyle.WHITE, 8.0, true)
	draw_line(c, c + Vector2(cos(min_ang), sin(min_ang)) * CLOCK_R * 0.78, UIStyle.LIME, 4.0, true)
	draw_circle(c, 10, UIStyle.LIME)
	# Hora en digital debajo.
	var hh := int(fmod(h, 24.0))
	var mm := int(fmod(h, 1.0) * 60.0)
	var text := "%02d:%02d" % [hh, mm]
	var f := UIStyle.FONT_SEMIBOLD
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x
	draw_string(f, Vector2(c.x - w * 0.5, c.y + CLOCK_R + 70), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, UIStyle.WHITE)


func _draw_card() -> void:
	var r := CARD
	var body := UIStyle.chamfer_rect(r, [0.0, 22.0, 0.0, 22.0])
	draw_colored_polygon(body, UIStyle.WHITE)
	# Banda superior con el mes.
	var band := Rect2(r.position, Vector2(r.size.x, 78))
	draw_colored_polygon(UIStyle.chamfer_rect(band, [0.0, 22.0, 0.0, 0.0]), UIStyle.LIME)
	for k in 2:   # anillas
		draw_circle(Vector2(r.position.x + 80 + k * 140, r.position.y + 4), 9, UIStyle.INK)
	var month: String = _to.month
	var mw := UIStyle.spaced_width(UIStyle.FONT_BOLD, month, 34, 6.0)
	UIStyle.draw_spaced(self, UIStyle.FONT_BOLD, Vector2(r.get_center().x - mw * 0.5, r.position.y + 56), month, 34, 6.0, UIStyle.INK)
	# Número y día de la semana: el de antes sube y se va; el nuevo entra desde abajo.
	var p := smoothstep(0.5, 0.8, _t)
	_card_face(_from, -p * 90.0, 1.0 - p)
	_card_face(_to, (1.0 - p) * 90.0, p)


func _card_face(d: Dictionary, dy: float, alpha: float) -> void:
	if alpha <= 0.01:
		return
	var r := CARD
	var num := str(d.day)
	var f := UIStyle.FONT_HEAVY_ITALIC
	var w := f.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 170).x
	draw_string(f, Vector2(r.get_center().x - w * 0.5, r.position.y + 270 + dy), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 170,
			Color(UIStyle.INK, alpha))
	var wd: String = d.weekday.to_upper()
	var ww := UIStyle.spaced_width(UIStyle.FONT_BOLD, wd, 30, 4.0)
	UIStyle.draw_spaced(self, UIStyle.FONT_BOLD, Vector2(r.get_center().x - ww * 0.5, r.position.y + 340 + dy * 0.6), wd, 30, 4.0,
			Color(UIStyle.INK, alpha * 0.8))
