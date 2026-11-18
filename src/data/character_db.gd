class_name CharacterDB
extends RefCounted
## Catálogo de personajes.
##
## `scene` describe cómo aparece en la interfaz de escenario:
## `x` = centro horizontal normalizado, `height` = altura en px (base 1080).
##
## `combat` son valores PROVISIONALES para el prototipo de combate (no son
## balance definitivo): nivel, PV/PM, nombre del ataque y daño que causa.
## `items` = objetos que lleva el personaje en combate.

const PROTAGONIST := "aiden"
const NARRATOR := "narrador"

const ALL := {
	"aiden": {
		"name": "Aiden", "color": Color("c6f432"),
		"portrait": "res://assets/characters/aiden.png",
		"face": Rect2(470, 110, 400, 400),
		"combat": {"level": 14, "pv": 282, "pm": 112, "pm_now": 86,
			"attack": "Corte rápido", "damage": 42, "variance": 6},
	},
	"kael": {
		"name": "Kael", "color": Color("27d8ff"),
		"portrait": "res://assets/characters/kael.png",
		"scene": {"x": 0.23, "height": 740.0},
		"combat": {"level": 15, "pv": 230, "attack": "Golpe de bajo", "damage": 34, "items": {"pochicola": 1}},
	},
	"elara": {
		"name": "Elara", "color": Color("b46bff"),
		"portrait": "res://assets/characters/elara.png",
		"scene": {"x": 0.50, "height": 660.0},
		"combat": {"level": 14, "pv": 190, "attack": "Tapa dura", "damage": 30, "items": {"pochicola": 1}},
	},
	"misaki": {
		"name": "Misaki", "color": Color("ff3d5a"),
		"portrait": "res://assets/characters/misaki.png",
		"scene": {"x": 0.77, "height": 770.0},
		"combat": {"level": 15, "pv": 250, "attack": "Patada de pogo", "damage": 38, "items": {"pochicola": 1}},
	},
	# Arte disponible, todavía sin papel asignado.
	"rina": {
		"name": "Rina", "color": Color("ff7ad9"),
		"portrait": "res://assets/characters/rina.png",
	},
}

## Personajes presentes en los escenarios (de momento, los mismos en todas partes).
const SCENARIO_CAST: Array[String] = ["kael", "elara", "misaki"]


static func get_character(id: String) -> Dictionary:
	return ALL.get(id, {})


static func display_name(id: String) -> String:
	return get_character(id).get("name", "")


static func color(id: String) -> Color:
	return get_character(id).get("color", UIStyle.WHITE)


static func portrait(id: String) -> Texture2D:
	var path: String = get_character(id).get("portrait", "")
	return load(path) if path != "" else null
