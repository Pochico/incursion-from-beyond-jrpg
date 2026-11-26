class_name Acquaintance
extends RefCounted
## Gente que Ren no conoce todavía (Akane al principio, compañeros nuevos,
## vendedores…): los que tienen `stranger_name` en CharacterDB. Tres estados:
##
##   desconocido  sale con `stranger_name`; solo se le puede saludar
##                (cue `<id>_presentacion`). No sale en el móvil ni escribe.
##   presentado   ya sale su nombre; charlas cortas (cue `<id>_charla`) y la
##                opción de pedirle el número (cue `<id>_amistad`).
##   amigo        como cualquier otro: móvil, mensajes, relaciones y planes.
##
## Quien no tiene `stranger_name` es amigo desde el principio.
## El estado se guarda en `GameState.acquaintance` (id -> estado).

const STRANGER := "desconocido"
const INTRODUCED := "presentado"
const FRIEND := "amigo"

## Acciones del menú del personaje mientras no es amigo.
const GREET_ACTION := {"id": "talk", "label": "Saludar", "icon": "speech", "desc": "Presentarte."}
const CHAT_ACTION := {"id": "talk", "label": "Hablar", "icon": "speech", "desc": "Una charla corta."}
const BEFRIEND_ACTION := {"id": "befriend", "label": "Pedir el número", "icon": "people", "desc": "Haceros amigos e intercambiar contactos."}


static func state(id: String) -> String:
	if not CharacterDB.get_character(id).has("stranger_name"):
		return FRIEND
	return GameState.acquaintance.get(id, STRANGER)


static func is_friend(id: String) -> bool:
	return state(id) == FRIEND


static func is_stranger(id: String) -> bool:
	return state(id) == STRANGER


## Ren se presenta (o se lo presentan): desde ahora sale su nombre.
static func introduce(id: String) -> void:
	if state(id) == STRANGER:
		GameState.acquaintance[id] = INTRODUCED
		GameState.record("presentacion", CharacterDB.PROTAGONIST, id)


## Intercambian contactos: ya sale en el móvil y puede escribir y proponer planes.
static func befriend(id: String) -> void:
	if state(id) != FRIEND:
		GameState.acquaintance[id] = FRIEND
		GameState.record("amistad", CharacterDB.PROTAGONIST, id)


## Los amigos de `ids` (para las listas del móvil).
static func friends(ids: Array) -> Array[String]:
	var out: Array[String] = []
	for id: String in ids:
		if is_friend(id):
			out.append(id)
	return out


## Acciones del menú para alguien que no es amigo ([] si lo es).
static func menu_actions(id: String) -> Array:
	match state(id):
		STRANGER:
			return [GREET_ACTION]
		INTRODUCED:
			return [CHAT_ACTION, BEFRIEND_ACTION]
	return []


## Cue de la acción `action` con alguien que no es amigo ("" si es amigo).
static func cue_for(id: String, action: String) -> String:
	match state(id):
		STRANGER:
			return id + "_presentacion"
		INTRODUCED:
			return id + ("_amistad" if action == "befriend" else "_charla")
	return ""
