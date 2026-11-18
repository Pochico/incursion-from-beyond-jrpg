extends Node
## Configuración global de la aplicación: tema por defecto y atajos de ventana.


func _ready() -> void:
	get_tree().root.theme = UIStyle.get_theme()


func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		var alt_enter := key.keycode == KEY_ENTER and key.alt_pressed
		if key.keycode == KEY_F11 or alt_enter:
			toggle_fullscreen()
			get_viewport().set_input_as_handled()


func toggle_fullscreen() -> void:
	var win := get_window()
	if win.mode == Window.MODE_FULLSCREEN or win.mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		win.mode = Window.MODE_WINDOWED
	else:
		win.mode = Window.MODE_FULLSCREEN
