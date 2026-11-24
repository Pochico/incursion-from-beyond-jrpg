class_name ItemSpin
extends Node3D
## Gira despacio y sube y baja: el objeto que hay en una casilla de la mazmorra.

const TURN_SPEED := 0.9   ## rad/s
const BOB_HEIGHT := 0.05  ## m
const BOB_SPEED := 2.0

var base_y := 0.0
var _time := randf() * TAU


func _ready() -> void:
	base_y = position.y
	rotation.y = randf() * TAU


func _process(delta: float) -> void:
	_time += delta * BOB_SPEED
	rotation.y += delta * TURN_SPEED
	position.y = base_y + sin(_time) * BOB_HEIGHT
