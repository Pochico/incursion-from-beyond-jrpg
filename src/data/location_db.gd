class_name LocationDB
extends RefCounted
## Catálogo de ubicaciones.
##
## `pos` es la posición normalizada en el mapa; `sky_*`, `trees`, `water` y
## `tower` alimentan el fondo provisional generado por código.
## `props` = objetos examinables encajados sobre el fondo, en orden de dibujo.
## Su posición y tamaño se ajustan a mano en la escena `layout` (ver RoomLayout).
## `cast` = personajes que pueden estar en la ubicación. `capacity` = cuántos
## puede haber a la vez como mucho (por defecto DEFAULT_CAPACITY; se cambia en el
## editor del mapa). Si el `cast` tiene más, cada franja del día se eligen
## `capacity` (siempre los mismos durante esa franja). Sin nadie, al llegar salta un
## combate contra un enemigo al azar (ver `RANDOM_ENEMIES`), salvo en los
## (`cast_phase` = el `cast` solo aparece desde esa fase de la historia)
## lugares seguros (`safe`), en casa y en las mazmorras (`dungeon`: al llegar se
## pregunta si entrar; `dungeon_map` = mapa de src/data/mazmorras/;
## `battle_background` = fondo de los combates dentro de la mazmorra).
## El fondo real, si existe, es assets/backgrounds/<id>.png.
##
## Poses: si existe `assets/escenas/<id>/<personaje>.png` y la escena `layout`
## tiene un nodo con el id del personaje, ese personaje aparece integrado en el
## fondo con esa pose, en su sitio (ver `pose`). Si no, sale su retrato de pie.

const HOME := "casa"
## Personajes a la vez en una ubicación si no se dice otra cosa.
const DEFAULT_CAPACITY := 3
## Máximo que admite el editor (y que cabe en el escenario).
const MAX_CAPACITY := 6

const RANDOM_ENEMIES: Array[String] = ["tiranosaurio", "oni", "engendro", "turbina",
		"crawler", "imp", "querubin", "troyano"]

const ALL := {
	"casa": {
		"name": "Casa", "desc": "Tu habitación. Aquí no te espera nadie.",
		"on_map": true, "pos": Vector2(0.08, 0.52),
		"layout": "res://src/rooms/casa_layout.tscn",
		"props": [
			{"id": "pantalla", "name": "Pantalla", "texture": "res://assets/props/pantalla.png"},
			{"id": "estanteria", "name": "Estantería", "texture": "res://assets/props/estanteria.png"},
			# Después de la estantería: la tapa por abajo, como en el fondo.
			{"id": "cama", "name": "Cama", "texture": "res://assets/props/cama.png"},
		],
	},
	"plaza": {
		"name": "Plaza Mayor", "desc": "Centro del distrito. Siempre hay alguien con quien hablar.",
		"on_map": true, "pos": Vector2(0.46, 0.46), "cast": ["kenji", "rika", "yuna"],
		"sky_top": Color("15112a"), "sky_bottom": Color("7a64b4"), "trees": true, "tower": true,
	},
	"estacion": {
		"name": "Estación de Zarzaquemada", "desc": "Cercanías y metro. Los paneles parpadean más de la cuenta.",
		"on_map": true, "pos": Vector2(0.24, 0.30),
		"sky_top": Color("0f1424"), "sky_bottom": Color("4f6a9a"), "tower": true,
	},
	"instituto": {
		"name": "Instituto", "desc": "Donde estudian Ren, Rika y Shiori. Fuera de horario, el aula se queda vacía.",
		"on_map": true, "pos": Vector2(0.50, 0.08), "safe": true,
		"sky_top": Color("1a1430"), "sky_bottom": Color("c08aa8"), "trees": true,
	},
	"parque": {
		"name": "Parque de la Ribera", "desc": "Zona verde junto al río. Tranquila... casi siempre.",
		"on_map": true, "pos": Vector2(0.20, 0.72),
		"sky_top": Color("1a1026"), "sky_bottom": Color("a0628e"), "trees": true, "water": true,
	},
	"campus": {
		"name": "Campus", "desc": "Facultades y laboratorios. Rumores de un servidor que nadie administra.",
		"on_map": true, "pos": Vector2(0.70, 0.24), "cast": ["shiori"],
		"sky_top": Color("111a1c"), "sky_bottom": Color("4f8a86"), "trees": true,
	},
	"galeria": {
		"name": "Westfield Parquesur", "desc": "Centro comercial: tiendas, recreativas, cine y camas elásticas.",
		"on_map": true, "pos": Vector2(0.66, 0.66), "cast": ["akane"],
		"sky_top": Color("1d0f22"), "sky_bottom": Color("b04f86"),
	},
	"cloacas": {
		"name": "Cloacas", "desc": "Un canal bajo la ciudad con una cascada en escalones. Por las rejillas entra la luz de la calle.",
		"on_map": true, "pos": Vector2(0.36, 0.60), "capacity": 5, "safe": true,
		"cast": ["kenji", "shiori", "rika", "akane", "yuna"], "cast_phase": "incursion_1",
		"layout": "res://src/rooms/cloacas_layout.tscn",
		"sky_top": Color("120d0a"), "sky_bottom": Color("6a4a2e"), "water": true,
	},
	"lago": {
		"name": "Westlake", "desc": "La terraza junto al lago del Parquesur: tarima, barandilla de cristal y las terrazas al otro lado del agua.",
		"on_map": true, "pos": Vector2(0.72, 0.74), "safe": true,
		"cast": ["kenji", "shiori", "rika", "akane", "yuna"],
		"layout": "res://src/rooms/lago_layout.tscn",
		"sky_top": Color("1f4f9a"), "sky_bottom": Color("8fc4e8"), "trees": true, "water": true,
	},
	"torre": {
		"name": "La Torre", "desc": "Mazmorra. El acceso al Corredor de la Torre está aquí.",
		"on_map": true, "pos": Vector2(0.86, 0.48), "dungeon": true, "dungeon_map": "torre",
		"battle_background": "res://assets/backgrounds/torre_mazmorra.png",
		"sky_top": Color("08060f"), "sky_bottom": Color("4a2a6e"), "tower": true,
	},
}


## Datos de la ubicación, con el nombre y la descripción cambiados en el editor
## del mapa (MapConfig) y también las ubicaciones nuevas creadas allí.
static func get_location(id: String) -> Dictionary:
	var cfg := MapConfig.current()
	var loc: Dictionary
	if ALL.has(id):
		loc = (ALL[id] as Dictionary).duplicate()
	elif id in cfg.custom:
		loc = {"name": id, "desc": "", "on_map": true, "pos": Vector2(0.5, 0.5)}
	else:
		return {}
	if cfg.names.has(id):
		loc.name = cfg.names[id]
	if cfg.descs.has(id):
		loc.desc = cfg.descs[id]
	if cfg.get("capacity", {}).has(id):
		loc.capacity = int(cfg.capacity[id])
	return loc


static func display_name(id: String) -> String:
	return get_location(id).get("name", id)


## Objetos examinables con su `rect` (píxeles del fondo) leído de la escena `layout`.
static func props(id: String) -> Array:
	var rects := RoomLayout.load_rects(get_location(id).get("layout", ""))
	var out := []
	for prop: Dictionary in get_location(id).get("props", []):
		if rects.has(prop.id):
			var p := prop.duplicate()
			p["rect"] = rects[prop.id]
			out.append(p)
		else:
			push_warning("LocationDB: «%s» no está en la escena de %s" % [prop.id, id])
	return out


## Cuántos personajes puede haber a la vez en `id`.
static func capacity(id: String) -> int:
	return clampi(int(get_location(id).get("capacity", DEFAULT_CAPACITY)), 0, MAX_CAPACITY)


## Personajes que hay ahora en `id`: nunca más que su `capacity`. Si caben
## todos, todos; si no, una selección estable durante la franja del día actual,
## en el orden de `cast`.
const POSE_DIR := "res://assets/escenas/"


## Pose de `character` en la ubicación `id`: {texture, rect} (rect en píxeles del
## fondo, de la escena `layout`), o {} si no tiene.
static func pose(id: String, character: String) -> Dictionary:
	var path := "%s%s/%s.png" % [POSE_DIR, id, character]
	if not ResourceLoader.exists(path):
		return {}
	var rects := RoomLayout.load_rects(get_location(id).get("layout", ""))
	if not rects.has(character):
		push_warning("LocationDB: la pose de «%s» no está en la escena de %s" % [character, id])
		return {}
	return {"texture": load(path), "rect": rects[character]}


static func cast(id: String) -> Array:
	var loc := get_location(id)
	if loc.has("cast_phase") and not GameState.phase_at_least(loc.cast_phase):
		return []
	var all: Array = loc.get("cast", [])
	var limit := capacity(id)
	if all.size() <= limit:
		return all.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s|%d" % [id, str(GameState.date), GameState.time_slot])
	var picked := all.duplicate()
	for i in range(picked.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = picked[i]
		picked[i] = picked[j]
		picked[j] = tmp
	picked = picked.slice(0, limit)
	return all.filter(func(c: String) -> bool: return c in picked)


## Ubicación del mapa sin nadie: al llegar hay un combate.
static func is_hostile(id: String) -> bool:
	var loc := get_location(id)
	return id != HOME and not loc.get("safe", false) and not loc.get("dungeon", false) and cast(id).is_empty()


static func is_dungeon(id: String) -> bool:
	return get_location(id).get("dungeon", false)


## Ubicaciones visibles en el mapa, en orden de navegación.
static func map_ids() -> Array[String]:
	var ids: Array[String] = []
	var cfg := MapConfig.current()
	for id: String in ALL:
		if ALL[id].get("on_map", false) and not (id in cfg.hidden):
			ids.append(id)
	for id: String in cfg.custom:
		ids.append(id)
	return ids


## Ubicaciones que no se pueden borrar del mapa: casa y los destinos de la historia.
static func required_ids() -> Array[String]:
	var ids: Array[String] = [HOME]
	for step: Dictionary in ChapterDB.STEPS.values():
		if step.get("target", "") != "" and not ids.has(step.target):
			ids.append(step.target)
	return ids
