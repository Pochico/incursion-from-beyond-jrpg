class_name BattleTransition
extends Control
## Transición de combate: un frente diagonal (franjas lima, violeta y blanca)
## barre la pantalla de derecha a izquierda y la deja en negro; después otro
## barrido la descubre. Mientras está cubierta muestra «¡COMBATE!» y el rival.
##
##   await transition.cover("Kael")   # pantalla tapada
##   ...cambiar lo que haya debajo...
##   await transition.reveal()

const SLANT := 360.0

var _edge := 0.0          # posición x del frente (borde del negro)
var _covering := true     # true: el negro queda a la derecha del frente
var _title_a := 0.0
var _subtitle := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func cover(subtitle: String = "", duration: float = 0.55) -> void:
	_subtitle = subtitle
	_covering = true
	_title_a = 0.0
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_method(_set_edge, size.x + SLANT + 200, -SLANT - 200, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	t = create_tween()
	t.tween_method(_set_title, 0.0, 1.0, 0.25)
	t.tween_interval(0.55)
	await t.finished


func reveal(duration: float = 0.5) -> void:
	var t := create_tween()
	t.tween_method(_set_title, _title_a, 0.0, 0.15)
	await t.finished
	_covering = false
	t = create_tween()
	t.tween_method(_set_edge, size.x + SLANT + 200, -SLANT - 200, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _set_edge(v: float) -> void:
	_edge = v
	queue_redraw()


func _set_title(v: float) -> void:
	_title_a = v
	queue_redraw()


func _band(x: float, width: float, color: Color) -> void:
	var h := size.y
	draw_colored_polygon(PackedVector2Array([
		Vector2(x + SLANT, 0), Vector2(x + SLANT + width, 0), Vector2(x + width, h), Vector2(x, h),
	]), color)


func _draw() -> void:
	var w := size.x
	var h := size.y
	# Zona negra: a la derecha del frente al cubrir, a la izquierda al descubrir.
	if _covering:
		if _edge < w + SLANT:
			draw_colored_polygon(PackedVector2Array([
				Vector2(_edge + SLANT, 0), Vector2(w + SLANT * 2, 0), Vector2(w + SLANT * 2, h), Vector2(_edge, h),
			]), UIStyle.INK)
		_band(_edge - 40, 40, UIStyle.LIME)
		_band(_edge - 80, 22, UIStyle.VIOLET)
		_band(_edge - 104, 6, UIStyle.WHITE)
	else:
		draw_colored_polygon(PackedVector2Array([
			Vector2(-SLANT * 2, 0), Vector2(_edge + SLANT, 0), Vector2(_edge, h), Vector2(-SLANT * 2, h),
		]), UIStyle.INK)
		_band(_edge, 40, UIStyle.LIME)
		_band(_edge + 40, 22, UIStyle.VIOLET)
		_band(_edge + 66, 6, UIStyle.WHITE)

	if _title_a > 0.0:
		var f := UIStyle.FONT_HEAVY_ITALIC
		var text := "¡COMBATE!"
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 140).x
		var y := h * 0.5 + 40
		draw_string(f, Vector2((w - tw) * 0.5 + 8, y + 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 140, Color(UIStyle.VIOLET, _title_a))
		draw_string(f, Vector2((w - tw) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 140, Color(UIStyle.WHITE, _title_a))
		if _subtitle != "":
			var sub := "VS  " + _subtitle.to_upper()
			var sw := UIStyle.spaced_width(UIStyle.FONT_BOLD_ITALIC, sub, 32, 8.0)
			UIStyle.draw_spaced(self, UIStyle.FONT_BOLD_ITALIC, Vector2((w - sw) * 0.5, y + 70), sub, 32, 8.0, Color(UIStyle.LIME, _title_a))
