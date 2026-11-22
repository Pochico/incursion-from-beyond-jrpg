class_name CharacterDB
extends RefCounted
## Catálogo de personajes.
##
## `scene` describe cómo aparece en la interfaz de escenario: `height` = altura
## en px (base 1080). La posición horizontal depende de cuántos personajes haya
## en la ubicación (ver LocationDB `cast`).
##
## `combat` son valores PROVISIONALES para el prototipo de combate (no son
## balance definitivo): nivel, PV/PM, nombre del ataque y daño que causa.
## `items` = objetos que lleva el personaje en combate.
## `stats` = atributos de docs/diseno/habilidades_1.md (FUE, TEC, INT, VOL, RES, AGI),
## usados por las fórmulas de SkillDB. `skills` = IDs de SkillDB que puede usar.
##
## Los enemigos (`enemy: true`) no aparecen en escenarios: surgen en eventos.
## `battle_rect` = rectángulo de su imagen dentro del visor de combate.
##
## Ficha de personalidad: `src/data/characters/<id>.json` (ver
## docs/diseno/personajes_y_relaciones.md). Si la ficha trae `combat`, sustituye
## al de esta tabla.

const PROTAGONIST := "ren"
const NARRATOR := "narrador"

const ALL := {
	"ren": {
		"name": "Ren", "color": Color("c6f432"),
		"portrait": "res://assets/characters/ren.png",
		"face": Rect2(470, 110, 400, 400),
		"nature": "biological",
		"gear": {"arma": "Cúter retráctil", "accesorio": "Auriculares rotos", "modulo": ""},
		"bio": "Estudia en el instituto de Leganés, última fila junto a la ventana. Lleva semanas viviendo en piloto automático: clase, pantalla, cama. Kenji es el único que sigue insistiendo en sacarlo de casa.",
		"combat": {"level": 14, "pv": 282, "pm": 112, "pm_now": 86,
			"attack": "Corte rápido", "damage": 42, "variance": 6,
			"stats": {"FUE": 24, "TEC": 14, "INT": 14, "VOL": 16, "RES": 20, "AGI": 22},
			"skills": ["bio_impulso_organico", "bio_regeneracion_celular"]},
	},
	"kenji": {
		"name": "Kenji", "color": Color("27d8ff"),
		"portrait": "res://assets/characters/kenji.png",
		"scene": {"height": 740.0},
		# Combate y personalidad: src/data/characters/kenji.json
	},
	"shiori": {
		"name": "Shiori", "color": Color("b46bff"),
		"portrait": "res://assets/characters/shiori.png",
		"scene": {"height": 660.0},
		# Combate y personalidad: src/data/characters/shiori.json
	},
	"akane": {
		"name": "Akane", "color": Color("ff3d5a"),
		"portrait": "res://assets/characters/akane.png",
		"scene": {"height": 770.0},
		# Combate y personalidad: src/data/characters/akane.json
	},
	"rika": {
		"name": "Rika", "color": Color("ff7ad9"),
		"portrait": "res://assets/characters/rika.png",
		"scene": {"height": 780.0},
		# Combate y personalidad: src/data/characters/rika.json
	},
	# Novia de Kenji, de su misma clase. Personalidad: src/data/characters/yuna.json
	"yuna": {
		"name": "Yuna", "color": Color("c58cf0"),
		"portrait": "res://assets/characters/yuna.png",
		"face": Rect2(400, 140, 420, 420),
		"scene": {"height": 780.0},
	},
	"madre_ren": {
		"name": "Mamá", "color": Color("ff9e7a"),
		"portrait": "res://assets/characters/madre_ren.png",
		"face": Rect2(330, 110, 440, 440),
		"scene": {"height": 780.0},
	},
	"madre_kenji": {
		"name": "Madre de Kenji", "color": Color("f2b45c"),
		"portrait": "res://assets/characters/madre_kenji.png",
		"face": Rect2(450, 140, 430, 430),
		"scene": {"height": 780.0},
	},
	# Aún sin nombre ni diseño: habla sin retrato.
	"profesora": {
		"name": "Profesora", "color": Color("e9dcc0"),
	},
	# --- Enemigos ---------------------------------------------------------------
	"tiranosaurio": {
		"name": "Tiranosaurio mutante", "color": Color("d63cff"), "enemy": true,
		"nature": "digital",
		"portrait": "res://assets/enemies/tiranosaurio_mutante.png",
		"battle_rect": Rect2(380, 190, 1020, 600),
		"combat": {"level": 16, "pv": 400, "pm": 50, "attack": "Dentellada", "damage": 36, "variance": 6,
			"stats": {"FUE": 30, "TEC": 20, "INT": 18, "VOL": 10, "RES": 28, "AGI": 14},
			"skills": ["dig_corrupcion_datos", "dig_depuracion"]},
	},
	"oni": {
		"name": "Oni", "color": Color("ff5a36"), "enemy": true,
		"nature": "mystic",
		"portrait": "res://assets/enemies/oni.png",
		# Más alto que el visor: se le cortan los pies.
		"battle_rect": Rect2(600, 150, 400, 740),
		"combat": {"level": 15, "pv": 340, "pm": 70, "attack": "Zarpazo", "damage": 30, "variance": 5,
			"stats": {"FUE": 18, "TEC": 10, "INT": 16, "VOL": 20, "RES": 22, "AGI": 20},
			"skills": ["mis_manifestacion_arcana", "mis_marca_funesta"]},
	},
	"engendro": {
		"name": "Engendro", "color": Color("ff4a1c"), "enemy": true,
		"nature": "biological",
		"portrait": "res://assets/enemies/engendro.png",
		"battle_rect": Rect2(510, 150, 560, 740),
		"combat": {"level": 15, "pv": 380, "pm": 60, "attack": "Zarpa larga", "damage": 34, "variance": 6,
			"stats": {"FUE": 28, "TEC": 8, "INT": 8, "VOL": 12, "RES": 26, "AGI": 18},
			"skills": ["bio_impulso_organico", "bio_secrecion_caustica"]},
	},
	"turbina": {
		"name": "Turbina", "color": Color("4d8dff"), "enemy": true,
		"nature": "mechanical",
		"portrait": "res://assets/enemies/turbina.png",
		"battle_rect": Rect2(420, 170, 760, 620),
		"combat": {"level": 15, "pv": 360, "pm": 55, "attack": "Tijeretazo", "damage": 32, "variance": 5,
			"stats": {"FUE": 24, "TEC": 26, "INT": 14, "VOL": 8, "RES": 30, "AGI": 26},
			"skills": ["mec_impacto_cinetico", "mec_proyeccion_fragmentos"]},
	},
	# Mecánico: torreta cuadrúpeda.
	"crawler": {
		"name": "Crawler", "color": Color("f08a2c"), "enemy": true,
		"nature": "mechanical",
		"portrait": "res://assets/enemies/crawler.png",
		"battle_rect": Rect2(370, 130, 720, 650),
		"combat": {"level": 15, "pv": 370, "pm": 55, "attack": "Cañonazo", "damage": 33, "variance": 6,
			"stats": {"FUE": 22, "TEC": 28, "INT": 12, "VOL": 8, "RES": 30, "AGI": 14},
			"skills": ["mec_impacto_cinetico", "mec_proyeccion_fragmentos"]},
	},
	# ARQ: esqueleto rastrero con cola de demonio.
	"imp": {
		"name": "Imp", "color": Color("d0473f"), "enemy": true,
		"nature": "mystic",
		"portrait": "res://assets/enemies/imp.png",
		"battle_rect": Rect2(440, 80, 580, 720),
		"combat": {"level": 15, "pv": 320, "pm": 70, "attack": "Garra hueca", "damage": 31, "variance": 5,
			"stats": {"FUE": 20, "TEC": 10, "INT": 14, "VOL": 18, "RES": 18, "AGI": 26},
			"skills": ["mis_manifestacion_arcana", "mis_marca_funesta"]},
	},
	# ARQ: querubín cabeza abajo con un ojo en el vientre. Flota.
	"querubin": {
		"name": "Querubín", "color": Color("f2d27a"), "enemy": true,
		"nature": "mystic",
		"portrait": "res://assets/enemies/querubin.png",
		"battle_rect": Rect2(520, 40, 600, 660),
		"combat": {"level": 15, "pv": 330, "pm": 80, "attack": "Flechazo", "damage": 30, "variance": 6,
			"stats": {"FUE": 14, "TEC": 18, "INT": 20, "VOL": 24, "RES": 16, "AGI": 22},
			"skills": ["mis_manifestacion_arcana", "mis_marca_funesta"]},
	},
	# Digital: caballo de Troya hecho de cables y glitch.
	"troyano": {
		"name": "Troyano", "color": Color("ff2d6a"), "enemy": true,
		"nature": "digital",
		"portrait": "res://assets/enemies/troyano.png",
		"battle_rect": Rect2(330, 100, 780, 700),
		"combat": {"level": 15, "pv": 360, "pm": 65, "attack": "Coz corrupta", "damage": 34, "variance": 6,
			"stats": {"FUE": 24, "TEC": 22, "INT": 20, "VOL": 10, "RES": 22, "AGI": 22},
			"skills": ["dig_corrupcion_datos", "dig_depuracion"]},
	},
}

## Compañeros que pueden unirse al grupo en combate.
const COMPANIONS: Array[String] = ["kenji", "shiori", "akane", "rika"]
## Agenda del móvil (a quién puede escribir Ren).
const CONTACTS: Array[String] = ["kenji", "rika", "shiori", "akane", "yuna", "madre_ren"]
## Personajes de la app Relaciones del móvil.
const RELATIONS: Array[String] = ["kenji", "rika", "shiori", "akane", "yuna", "madre_ren", "madre_kenji"]


const PROFILE_DIR := "res://src/data/characters/"

static var _profiles := {}     ## id -> ficha (Dictionary vacío si no tiene)
static var _merged := {}       ## id -> datos de ALL con el combate de la ficha


static func get_character(id: String) -> Dictionary:
	if not _merged.has(id):
		var data: Dictionary = ALL.get(id, {})
		var p := profile(id)
		if p.has("combat") or p.get("identity", {}).has("nature"):
			data = data.duplicate()
			if p.has("combat"):
				data["combat"] = p.combat
			if not data.has("nature") and p.get("identity", {}).has("nature"):
				data["nature"] = p.identity.nature
		_merged[id] = data
	return _merged[id]


## Ficha de personalidad de `id` ({} si todavía no tiene).
## Equipo de un personaje: {arma, accesorio, modulo} (texto vacío = hueco libre).
## De momento solo se muestra en el móvil; aún no afecta al combate.
static func gear(id: String) -> Dictionary:
	var g: Dictionary = ALL.get(id, {}).get("gear", profile(id).get("gear", {}))
	return {"arma": g.get("arma", ""), "accesorio": g.get("accesorio", ""), "modulo": g.get("modulo", "")}


## Línea corta para la agenda del móvil (p. ej. «Compañera de clase»).
static func tagline(id: String) -> String:
	return profile(id).get("identity", {}).get("tagline", "")


static func profile(id: String) -> Dictionary:
	if not _profiles.has(id):
		var path := PROFILE_DIR + id + ".json"
		var data: Variant = null
		if FileAccess.file_exists(path):
			data = JSON.parse_string(FileAccess.get_file_as_string(path))
			if not data is Dictionary:
				push_error("Ficha ilegible: %s" % path)
		_profiles[id] = _intify(data) if data is Dictionary else {}
	return _profiles[id]


## JSON lee todos los números como float: los enteros se dejan como int.
static func _intify(v: Variant) -> Variant:
	if v is Dictionary:
		for k in v:
			v[k] = _intify(v[k])
	elif v is Array:
		for i in v.size():
			v[i] = _intify(v[i])
	elif v is float and v == floorf(v):
		return int(v)
	return v


## Personajes con ficha de personalidad.
static func with_profile() -> Array[String]:
	var out: Array[String] = []
	for id: String in ALL:
		if not profile(id).is_empty():
			out.append(id)
	return out


## Id a partir del nombre visible ("Rika" -> "rika"); "" si no existe.
static func id_from_name(character_name: String) -> String:
	for id: String in ALL:
		if ALL[id].name == character_name:
			return id
	return ""


static func display_name(id: String) -> String:
	return get_character(id).get("name", "")


static func color(id: String) -> Color:
	return get_character(id).get("color", UIStyle.WHITE)


static func is_enemy(id: String) -> bool:
	return get_character(id).get("enemy", false)


## Región de la cara dentro del retrato (px de textura), para miniaturas.
## Sin `face` definido: un cuadrado centrado en la parte alta del retrato.
static func face_region(id: String) -> Rect2:
	var tex := portrait(id)
	if tex == null:
		return Rect2()
	var ts := tex.get_size()
	return get_character(id).get("face", Rect2(ts.x * 0.3, ts.y * 0.06, ts.x * 0.4, ts.x * 0.4))


## Los retratos se guardan: una textura cargada solo para dibujarla en `_draw` se
## liberaría antes de pintarse (y saldría en blanco).
static var _portraits := {}


static func portrait(id: String) -> Texture2D:
	if not _portraits.has(id):
		var path: String = get_character(id).get("portrait", "")
		_portraits[id] = load(path) if path != "" else null
	return _portraits[id]
