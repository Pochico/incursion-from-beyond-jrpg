extends CanvasLayer
## Cambios de pantalla con fundido a negro.

signal scene_changed(path: String)

const FADE_TIME := 0.3

var _curtain: ColorRect
var _busy := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_curtain = ColorRect.new()
	_curtain.color = UIStyle.INK
	_curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_curtain.modulate.a = 0.0
	add_child(_curtain)


func is_busy() -> bool:
	return _busy


func go_to(path: String, fade_time: float = FADE_TIME) -> void:
	if _busy:
		return
	_busy = true
	_curtain.mouse_filter = Control.MOUSE_FILTER_STOP

	var tween := create_tween()
	tween.tween_property(_curtain, "modulate:a", 1.0, fade_time)
	await tween.finished

	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneRouter: no se pudo cargar '%s' (error %d)" % [path, err])
	# El cambio de escena es diferido: esperamos a que la nueva esté en el árbol.
	await get_tree().process_frame
	await get_tree().process_frame

	tween = create_tween()
	tween.tween_property(_curtain, "modulate:a", 0.0, fade_time)
	await tween.finished

	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
	scene_changed.emit(path)
