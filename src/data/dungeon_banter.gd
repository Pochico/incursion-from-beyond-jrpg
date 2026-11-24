class_name DungeonBanter
extends RefCounted
## Comentarios del compañero durante la mazmorra (salen en el registro del visor).
##
## Las frases están en src/dialogue/mazmorra.dialogue (se editan como cualquier
## diálogo, también desde el editor web): un cue «mazmorra_<id>_<momento>» por
## personaje y momento, con una variante «%» por frase. Se lee el texto del
## archivo, como hace Story con las reglas (el complemento incursion_export lo
## incluye en las versiones exportadas).
##
## `line()` no repite una frase hasta haber dicho las demás del mismo momento.

const FILE := "res://src/dialogue/mazmorra.dialogue"
const CUE_PREFIX := "mazmorra_"
## Momento del juego (los avisa DungeonScreen / DungeonExplorer) -> momento del cue.
const MOMENTS := {
	"enter": "entrar", "idle": "andar", "enemy": "enemigo", "victory": "victoria",
	"defeat": "derrota", "item": "objeto", "level_up": "subir", "level_down": "bajar",
	"secret_hint": "pista_secreta", "secret_found": "secreto", "locked": "cerrada",
	"switch": "palanca",
}

static var _lines := {}     ## cue -> Array[String]
static var _bags := {}


## Una frase de `who` para el momento `event` ("" si no tiene).
static func line(who: String, event: String) -> String:
	var cue: String = CUE_PREFIX + who + "_" + MOMENTS.get(event, event)
	var all: Array = _all_lines().get(cue, [])
	if all.is_empty():
		return ""
	var bag: Array = _bags.get(cue, [])
	if bag.is_empty():
		bag = all.duplicate()
		bag.shuffle()
		_bags[cue] = bag
	return bag.pop_back()


static func _all_lines() -> Dictionary:
	if _lines.is_empty():
		_lines = parse(FileAccess.get_file_as_string(FILE))
	return _lines


## Frases de cada cue de un texto .dialogue: sin «%», sin «Nombre: » y sin etiquetas.
static func parse(text: String) -> Dictionary:
	var out := {}
	var cue := ""
	var tags := RegEx.create_from_string("\\s*\\[#[^\\]]*\\]")
	var speaker := RegEx.create_from_string("^[^:]{1,40}:\\s")
	var variant := RegEx.create_from_string("^%\\d*\\s*")
	for raw in text.split("\n"):
		var t := raw.strip_edges()
		if t.begins_with("~ "):
			cue = t.substr(2).strip_edges()
			out[cue] = []
		elif cue != "" and t.begins_with("%"):
			t = variant.sub(t, "")
			t = tags.sub(speaker.sub(t, ""), "", true).strip_edges()
			if t != "":
				out[cue].append(t)
	return out
