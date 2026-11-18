class_name LocationDB
extends RefCounted
## Catálogo de ubicaciones.
##
## `pos` es la posición normalizada en el mapa; `sky_*`, `trees`, `water` y
## `tower` alimentan el fondo provisional generado por código.

const HOME := "casa"

const ALL := {
	"casa": {
		"name": "Tu habitación", "desc": "", "on_map": false,
	},
	"plaza": {
		"name": "Plaza Mayor", "desc": "Centro del distrito. Siempre hay alguien con quien hablar.",
		"on_map": true, "pos": Vector2(0.46, 0.46),
		"sky_top": Color("15112a"), "sky_bottom": Color("7a64b4"), "trees": true, "tower": true,
	},
	"estacion": {
		"name": "Estación Central", "desc": "Cercanías y metro. Los paneles parpadean más de la cuenta.",
		"on_map": true, "pos": Vector2(0.24, 0.30),
		"sky_top": Color("0f1424"), "sky_bottom": Color("4f6a9a"), "tower": true,
	},
	"parque": {
		"name": "Parque de la Ribera", "desc": "Zona verde junto al río. Tranquila... casi siempre.",
		"on_map": true, "pos": Vector2(0.20, 0.72),
		"sky_top": Color("1a1026"), "sky_bottom": Color("a0628e"), "trees": true, "water": true,
	},
	"campus": {
		"name": "Campus", "desc": "Facultades y laboratorios. Rumores de un servidor que nadie administra.",
		"on_map": true, "pos": Vector2(0.70, 0.24),
		"sky_top": Color("111a1c"), "sky_bottom": Color("4f8a86"), "trees": true,
	},
	"galeria": {
		"name": "Galería comercial", "desc": "Tiendas, recreativas y un café abierto 24 horas.",
		"on_map": true, "pos": Vector2(0.66, 0.66),
		"sky_top": Color("1d0f22"), "sky_bottom": Color("b04f86"),
	},
	"torre": {
		"name": "La Torre", "desc": "Mazmorra. El acceso al Corredor de la Torre está aquí.",
		"on_map": true, "pos": Vector2(0.86, 0.48), "dungeon": true,
		"sky_top": Color("08060f"), "sky_bottom": Color("4a2a6e"), "tower": true,
	},
}


static func get_location(id: String) -> Dictionary:
	return ALL.get(id, {})


static func display_name(id: String) -> String:
	return get_location(id).get("name", id)


## Ubicaciones visibles en el mapa, en orden de navegación.
static func map_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in ALL:
		if ALL[id].get("on_map", false):
			ids.append(id)
	return ids
