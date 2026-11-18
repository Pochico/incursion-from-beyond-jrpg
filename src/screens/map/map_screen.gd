extends Control
## Pantalla de mapa: cabeceras de región/fecha y mapa de la zona.

const TITLE_SCREEN := "res://src/screens/title/title_screen.tscn"

@onready var _map: MapView = %Map
@onready var _info: InfoBar = %Info


func _ready() -> void:
	_map.location_focused.connect(_on_location_focused)
	_map.location_selected.connect(_on_location_selected)
	_map.grab_focus()
	_map.selected = 0


func _on_location_focused(location: Dictionary) -> void:
	_info.text = "%s  —  %s" % [location.name, location.desc]


func _on_location_selected(location: Dictionary) -> void:
	# TODO: abrir la interfaz de escenario de esta localización.
	_info.text = "%s  —  La interfaz de escenario todavía no está implementada." % location.name


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not SceneRouter.is_busy():
		SceneRouter.go_to(TITLE_SCREEN)
		get_viewport().set_input_as_handled()
