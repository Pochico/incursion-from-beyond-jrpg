extends Control
## Menú de inicio.

const MAP_SCREEN := "res://src/screens/map/map_screen.tscn"

@onready var _logo: Control = %Logo
@onready var _menu: VBoxContainer = %Menu
@onready var _info: InfoBar = %Info
@onready var _version: Label = %Version
@onready var _new_game: SlantButton = %NewGame
@onready var _continue: SlantButton = %Continue
@onready var _options: SlantButton = %Options
@onready var _quit: SlantButton = %Quit


func _ready() -> void:
	_version.text = "v%s" % App.version()
	_continue.disabled = not GameState.has_save()

	for button: SlantButton in _buttons():
		button.focus_entered.connect(_on_button_focused.bind(button))

	_new_game.pressed.connect(_on_new_game)
	_continue.pressed.connect(_on_continue)
	_options.pressed.connect(_on_options)
	_quit.pressed.connect(_on_quit)

	_play_intro()


func _buttons() -> Array[SlantButton]:
	var result: Array[SlantButton] = []
	for child in _menu.get_children():
		if child is SlantButton:
			result.append(child)
	return result


func _play_intro() -> void:
	_logo.modulate.a = 0.0
	_info.modulate.a = 0.0
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_logo, "modulate:a", 1.0, 0.6)
	var buttons := _buttons()
	for i in buttons.size():
		buttons[i].reveal = 0.0
		tween.tween_property(buttons[i], "reveal", 1.0, 0.4).set_delay(0.25 + i * 0.07)
	tween.tween_property(_info, "modulate:a", 1.0, 0.4).set_delay(0.6)
	_new_game.grab_focus()


func _on_button_focused(button: SlantButton) -> void:
	_info.text = button.description


func _on_new_game() -> void:
	GameState.new_game()
	SceneRouter.go_to(MAP_SCREEN)


func _on_continue() -> void:
	if _continue.disabled:
		return
	# TODO: cargar partida cuando exista el sistema de guardado.


func _on_options() -> void:
	# TODO: pantalla de opciones.
	_info.text = "Las opciones todavía no están disponibles."


func _on_quit() -> void:
	get_tree().quit()
