class_name EnemyModel
extends Node3D
## Modelo 3D de un enemigo en la mazmorra (assets/modelos/<id>.glb): gira sobre
## sí mismo para mirar siempre a la cámara, como hacía su retrato plano.
## El modelo se usa a su tamaño (metros, con el origen en los pies) y mirando a +Z,
## como exportan Meshy y glTF. Las criaturas con `hover` en su ficha
## (CharacterDB.hover) flotan a esa altura y suben y bajan despacio.

const DIR := "res://assets/modelos/"
const TURN_SPEED := 6.0   ## Lo rápido que se gira hacia la cámara.
const BOB_HEIGHT := 0.08  ## m: vaivén de las que vuelan.
const BOB_SPEED := 1.6

var hover := 0.0
var _time := randf() * TAU


static func path_for(enemy_id: String) -> String:
	var path := "%s%s.glb" % [DIR, enemy_id]
	return path if ResourceLoader.exists(path) else ""


static func create(enemy_id: String) -> EnemyModel:
	var path := path_for(enemy_id)
	if path == "":
		return null
	var node := EnemyModel.new()
	node.name = "Modelo"
	node.hover = CharacterDB.hover(enemy_id)
	node.position.y = node.hover
	node.add_child((load(path) as PackedScene).instantiate())
	return node


func _ready() -> void:
	_face_camera(1.0)


func _process(delta: float) -> void:
	_face_camera(minf(1.0, delta * TURN_SPEED))
	if hover > 0.0:
		_time += delta * BOB_SPEED
		position.y = hover + sin(_time) * BOB_HEIGHT


func _face_camera(weight: float) -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return
	var to := cam.global_position - global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return
	var target := atan2(to.x, to.z)   # +Z del modelo hacia la cámara
	rotation.y = lerp_angle(rotation.y, target, weight)
