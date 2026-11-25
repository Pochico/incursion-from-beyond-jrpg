class_name CharacterDB
extends RefCounted
## Catálogo de personajes.
##
## `scene` describe cómo aparece en la interfaz de escenario: `height` = altura
## en px (base 1080). La posición horizontal depende de cuántos personajes haya
## en la ubicación (ver LocationDB `cast`).
##
## `combat` (PROVISIONAL, pendiente de prueba de combate):
##   level  : nivel (1..60). Todos empiezan en el 1.
##   stats  : atributos FUE, TEC, INT, VOL, RES (y AGI, aún sin uso). Referencia
##            de diseño: 10 + floor((nivel − 1) / 2).
##   attack : nombre del ataque básico (0,75 × D con FUE contra RES).
##   skills : IDs de SkillDB. items: objetos que lleva en combate.
##   tags   : etiquetas de compatibilidad (SkillDB.NATURE_TAGS); si no hay, las
##            de su naturaleza.
##   pv_mult: solo enemigos; multiplica sus PV (luchan solos contra el grupo).
## PV = 100 + 10·nivel + 5·RES y PM = 35 + 3·nivel + 2·max(INT, VOL) (SkillDB).
##
## Los enemigos (`enemy: true`) no aparecen en escenarios: surgen en eventos.
## `battle_rect` = rectángulo de su imagen dentro del visor de combate.
##
## `faces` = retratos alternativos por gesto (ver ConversationView.FACES): el
## de `portrait` es el normal. Si falta un gesto, se usa el normal.
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
		"bio": "Estudia en el instituto de Leganés, última fila junto a la ventana. Perdió a su padre hace tiempo y le costó levantar cabeza; ahora vuelve a ser el de antes: bromista, despistado y con los cascos al cuello. Kenji no le ha soltado en ningún momento.",
		"combat": {"level": 1, "attack": "Corte rápido",
			"stats": {"FUE": 12, "TEC": 9, "INT": 9, "VOL": 10, "RES": 11, "AGI": 12},
			"skills": ["BIO-03", "bio_impulso_organico", "BIO-04", "BIO-05"]},
	},
	"kenji": {
		"name": "Kenji", "color": Color("27d8ff"),
		"portrait": "res://assets/characters/kenji.png",
		"faces": {"enfado": "res://assets/characters/kenji_enfado.png", "sorpresa": "res://assets/characters/kenji_sorpresa.png"},
		"scene": {"height": 740.0},
		# Combate y personalidad: src/data/characters/kenji.json
	},
	"shiori": {
		"name": "Shiori", "color": Color("b46bff"),
		"portrait": "res://assets/characters/shiori.png",
		"faces": {"enfado": "res://assets/characters/shiori_enfado.png", "sorpresa": "res://assets/characters/shiori_sorpresa.png"},
		"scene": {"height": 660.0},
		# Combate y personalidad: src/data/characters/shiori.json
	},
	"akane": {
		"name": "Akane", "color": Color("ff3d5a"),
		"portrait": "res://assets/characters/akane.png",
		"faces": {"enfado": "res://assets/characters/akane_enfado.png", "sorpresa": "res://assets/characters/akane_sorpresa.png"},
		"scene": {"height": 770.0},
		# Combate y personalidad: src/data/characters/akane.json
	},
	"rika": {
		"name": "Rika", "color": Color("ff7ad9"),
		"portrait": "res://assets/characters/rika.png",
		"faces": {"enfado": "res://assets/characters/rika_enfado.png", "sorpresa": "res://assets/characters/rika_sorpresa.png"},
		"scene": {"height": 780.0},
		# Combate y personalidad: src/data/characters/rika.json
	},
	# Novia de Kenji, de su misma clase. Personalidad: src/data/characters/yuna.json
	"yuna": {
		"name": "Yuna", "color": Color("c58cf0"),
		"portrait": "res://assets/characters/yuna.png",
		"faces": {"enfado": "res://assets/characters/yuna_enfado.png", "incomodo": "res://assets/characters/yuna_incomodo.png"},
		"face": Rect2(400, 140, 420, 420),
		"scene": {"height": 780.0},
	},
	"madre_ren": {
		"name": "Mamá", "color": Color("ff9e7a"),
		"portrait": "res://assets/characters/madre_ren.png",
		"face": Rect2(330, 110, 440, 440),
		"scene": {"height": 780.0},
		"talk_only": true,   # en el menú solo «Hablar»
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
		"combat": {"level": 1, "pv_mult": 1.6, "boss": true, "attack": "Dentellada",
			"stats": {"FUE": 13, "TEC": 10, "INT": 11, "VOL": 8, "RES": 12, "AGI": 8}, "tags": ["datos", "electronica", "materia", "vision", "oido"],
			"skills": ["dig_corrupcion_datos", "CYBER-03", "dig_depuracion"]},
	},
	"oni": {
		"name": "Oni", "color": Color("ff5a36"), "enemy": true,
		"nature": "mystic",
		"portrait": "res://assets/enemies/oni.png",
		# Más alto que el visor: se le cortan los pies.
		"battle_rect": Rect2(600, 150, 400, 740),
		"combat": {"level": 1, "pv_mult": 1.5, "attack": "Zarpazo",
			"stats": {"FUE": 11, "TEC": 7, "INT": 9, "VOL": 12, "RES": 11, "AGI": 10}, "tags": ["tejido", "materia", "mente", "vision", "oido"],
			"skills": ["mis_manifestacion_arcana", "ARQ-05", "ARQ-01"]},
	},
	"engendro": {
		"name": "Engendro", "color": Color("ff4a1c"), "enemy": true,
		"nature": "psychic",
		"portrait": "res://assets/enemies/engendro.png",
		"battle_rect": Rect2(510, 150, 560, 740),
		# Psíquico: una manifestación de la rabia. Tiene cuerpo, pero no tejido vivo.
		"combat": {"level": 1, "pv_mult": 1.5, "attack": "Zarpa larga",
			"stats": {"FUE": 11, "TEC": 6, "INT": 6, "VOL": 13, "RES": 11, "AGI": 9}, "tags": ["materia", "mente", "vision", "oido"],
			"skills": ["psi_choque_mental", "psi_disonancia", "PSY-02"]},
	},
	"turbina": {
		"name": "Turbina", "color": Color("4d8dff"), "enemy": true,
		"nature": "mechanical",
		"portrait": "res://assets/enemies/turbina.png",
		"battle_rect": Rect2(420, 170, 760, 620),
		"combat": {"level": 1, "pv_mult": 1.5, "attack": "Tijeretazo",
			"stats": {"FUE": 11, "TEC": 12, "INT": 8, "VOL": 6, "RES": 13, "AGI": 12},
			"skills": ["mec_impacto_cinetico", "MECH-04", "MECH-01"]},
	},
	# Mecánico: torreta cuadrúpeda.
	"crawler": {
		"name": "Crawler", "color": Color("f08a2c"), "enemy": true,
		"nature": "mechanical",
		"portrait": "res://assets/enemies/crawler.png",
		"battle_rect": Rect2(370, 130, 720, 650),
		"combat": {"level": 1, "pv_mult": 1.5, "attack": "Cañonazo",
			"stats": {"FUE": 10, "TEC": 13, "INT": 8, "VOL": 6, "RES": 13, "AGI": 7},
			"skills": ["mec_proyeccion_fragmentos", "CYBER-02", "MECH-05"]},
	},
	# ARQ: esqueleto rastrero con cola de demonio.
	"imp": {
		"name": "Imp", "color": Color("d0473f"), "enemy": true,
		"nature": "mystic",
		"portrait": "res://assets/enemies/imp.png",
		"battle_rect": Rect2(440, 80, 580, 720),
		"combat": {"level": 1, "pv_mult": 1.5, "attack": "Garra hueca",
			"stats": {"FUE": 10, "TEC": 7, "INT": 9, "VOL": 11, "RES": 9, "AGI": 13}, "tags": ["materia", "mente", "vision"],
			"skills": ["mis_marca_funesta", "ARQ-04", "ARQ-07"]},
	},
	# ARQ: querubín cabeza abajo con un ojo en el vientre. Flota.
	"querubin": {
		"name": "Querubín", "color": Color("f2d27a"), "enemy": true,
		"nature": "mystic",
		"portrait": "res://assets/enemies/querubin.png",
		"hover": 0.7,   # vuela: metros sobre el suelo en la mazmorra
		"battle_rect": Rect2(520, 40, 600, 660),
		"combat": {"level": 1, "pv_mult": 1.5, "attack": "Flechazo",
			"stats": {"FUE": 8, "TEC": 9, "INT": 11, "VOL": 13, "RES": 9, "AGI": 11}, "tags": ["tejido", "materia", "mente", "vision", "oido"],
			"skills": ["mis_manifestacion_arcana", "ARQ-06", "ARQ-08"]},
	},
	# Digital: caballo de Troya hecho de cables y glitch.
	"troyano": {
		"name": "Troyano", "color": Color("ff2d6a"), "enemy": true,
		"nature": "digital",
		"portrait": "res://assets/enemies/troyano.png",
		"battle_rect": Rect2(330, 100, 780, 700),
		"combat": {"level": 1, "pv_mult": 1.5, "attack": "Coz corrupta",
			"stats": {"FUE": 11, "TEC": 12, "INT": 11, "VOL": 7, "RES": 11, "AGI": 11}, "tags": ["datos", "electronica", "materia", "vision"],
			"skills": ["dig_corrupcion_datos", "CYBER-02", "CYBER-01"]},
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


## Altura (m) a la que flota una criatura voladora en la mazmorra; 0 = de pie.
static func hover(id: String) -> float:
	return float(get_character(id).get("hover", 0.0))


static func color(id: String) -> Color:
	return get_character(id).get("color", UIStyle.WHITE)


## Etiquetas de compatibilidad en combate (ver SkillDB.NATURE_TAGS).
static func combat_tags(id: String) -> Array:
	var data := get_character(id)
	return SkillDB.tags_for(data.get("combat", {}), data.get("nature", ""))


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


## `face`: gesto ("enfado", "sorpresa", "incomodo"…); vacío o sin retrato
## para ese gesto = el normal.
static func portrait(id: String, face: String = "") -> Texture2D:
	var path: String = get_character(id).get("faces", {}).get(face, "")
	if path == "":
		path = get_character(id).get("portrait", "")
	if not _portraits.has(path):
		if path == "":
			_portraits[path] = null
		elif ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_portraits[path] = ResourceLoader.load_threaded_get(path)   # ver preload_faces
		else:
			_portraits[path] = load(path)
	return _portraits[path]


## Empieza a cargar en segundo plano los gestos de `id`, para que el primer
## cambio de cara no dé un tirón (sobre todo en el móvil).
static func preload_faces(id: String) -> void:
	for path: String in get_character(id).get("faces", {}).values():
		if not _portraits.has(path) and not ResourceLoader.has_cached(path):
			ResourceLoader.load_threaded_request(path)


## ¿Tiene `id` retrato para el gesto `face`?
static func has_face(id: String, face: String) -> bool:
	return get_character(id).get("faces", {}).has(face)
