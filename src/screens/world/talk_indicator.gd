class_name TalkIndicator
extends Control
## Bocadillo «...» flotante sobre un personaje interactuable (como en la
## referencia de escenario). Se resalta con el color del personaje al seleccionarlo.

var color := UIStyle.LIME
var highlighted := false:
	set(value):
		highlighted = value
		queue_redraw()

var _time := 0.0

const SIZE := 52.0


func _init() -> void:
	size = Vector2(SIZE + 12, SIZE + 16)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_time = randf() * TAU


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var bob := sin(_time * 2.4) * 4.0
	var c := Vector2(size.x * 0.5, size.y * 0.42 + bob)
	var fill := color if highlighted else UIStyle.WHITE
	# Sombra suave
	UIIcons.speech(self, c + Vector2(3, 4), SIZE, Color(0, 0, 0, 0.35), Color(0, 0, 0, 0))
	UIIcons.speech(self, c, SIZE, fill, UIStyle.INK, Color(UIStyle.INK, 0.9))
