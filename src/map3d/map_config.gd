class_name MapConfig
extends RefCounted
## Ajustes del mapa 3D: vista, iluminación por horas, colores, capa gris y
## ubicaciones (posición, nombre y puntos nuevos). Se editan con la herramienta
## src/tools/editor_mapa y se guardan en PATH.

const PATH := "res://src/data/mapa3d.json"

## Tamaño en pantalla del mapa del juego (MapOverlay). El editor muestra la vista
## con esta misma proporción para que el encuadre sea el mismo.
const VIEW_SIZE := Vector2(1720, 700)

const DEFAULTS := {
	# En el juego el mapa sale siempre recto (con el norte arriba) y entero: la
	# distancia se calcula sola. Solo se guardan la inclinación y el campo de visión.
	"camera": {"pitch": 50.0, "fov": 40.0},
	# Iluminación según la hora: se interpola entre estos momentos (en círculo).
	# Luz: azimut 0 = norte, 90 = este; elevación sobre el horizonte. De noche es la luna.
	# `windows` = cuánto se ven las ventanas encendidas (0..1).
	"lighting": {
		"shadows": true,
		"keys": [
			{"name": "Amanecer", "hour": 7.0, "azimuth": 100.0, "elevation": 9.0, "color": "#fff3e6", "energy": 0.45,
				"ambient": "#c5d0e4", "ambient_energy": 0.3, "windows": 0.25},
			{"name": "Día", "hour": 13.0, "azimuth": 180.0, "elevation": 58.0, "color": "#ffffff", "energy": 0.5,
				"ambient": "#c9d3e0", "ambient_energy": 0.3, "windows": 0.0},
			{"name": "Atardecer", "hour": 19.5, "azimuth": 250.0, "elevation": 7.0, "color": "#ff9a42", "energy": 0.6,
				"ambient": "#b58fa6", "ambient_energy": 0.22, "windows": 0.35},
			{"name": "Noche", "hour": 23.0, "azimuth": 300.0, "elevation": 40.0, "color": "#7d97ff", "energy": 0.08,
				"ambient": "#24304f", "ambient_energy": 0.32, "windows": 1.0},
		],
	},
	# Capa gris sobre el modelo (0 = nada, 1 = todo gris).
	"veil": {"color": "#7c7f88", "amount": 0.22},
	"colors": {
		"ground": "#f5f0ef", "buildings": "#f1ece1", "roads": "#b0b4c0", "paths": "#d0d3db",
		"green": "#a9c98b", "water": "#98dcff", "rail": "#7d7a86", "base": "#5b5d66", "windows": "#ffd27a",
	},
	# id de ubicación -> [x, z] en metros.
	"points": {},
	# Nombres y descripciones cambiados en el editor (id -> texto).
	"names": {},
	"descs": {},
	# Ubicaciones nuevas creadas en el editor (ids).
	"custom": [],
	# Ubicaciones borradas del mapa en el editor (ids de LocationDB).
	"hidden": [],
}

const COLOR_NAMES := {
	"ground": "Suelo", "buildings": "Edificios", "roads": "Calles", "paths": "Aceras y caminos",
	"green": "Zonas verdes", "water": "Agua", "rail": "Vías del tren", "base": "Base de la maqueta",
	"windows": "Ventanas (noche)",
}

static var _current: Dictionary = {}
static var _mtime := 0


## La configuración guardada, completada con los valores por defecto.
static func load_config() -> Dictionary:
	var cfg: Dictionary = DEFAULTS.duplicate(true)
	if FileAccess.file_exists(PATH):
		var saved = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if saved is Dictionary:
			for key: String in saved:
				if not cfg.has(key):
					continue
				if cfg[key] is Dictionary and saved[key] is Dictionary and key in ["camera", "lighting", "veil", "colors"]:
					for sub: String in saved[key]:
						if cfg[key].has(sub):   # descarta claves antiguas (p. ej. el giro de la cámara)
							cfg[key][sub] = saved[key][sub]
				else:
					cfg[key] = saved[key]
	return cfg


## La configuración en uso (se lee una vez). El editor la sustituye con `set_current`.
static func current() -> Dictionary:
	if _current.is_empty():
		_current = load_config()
		_mtime = FileAccess.get_modified_time(PATH) if FileAccess.file_exists(PATH) else 0
	return _current


## Vuelve a leer el archivo si ha cambiado (p. ej. se ha guardado desde el
## editor con el juego abierto). Devuelve true si ha cambiado.
static func reload_if_changed() -> bool:
	if not FileAccess.file_exists(PATH):
		return false
	var t := FileAccess.get_modified_time(PATH)
	if t == _mtime and not _current.is_empty():
		return false
	_current = load_config()
	_mtime = t
	return true


static func set_current(cfg: Dictionary) -> void:
	_current = cfg


static func save_config(cfg: Dictionary) -> Error:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(cfg, "\t", false) + "\n")
	f.close()
	_current = cfg
	_mtime = FileAccess.get_modified_time(PATH)
	return OK


## Iluminación a una hora: interpola entre los dos momentos que la rodean.
static func light_at(cfg: Dictionary, hour: float) -> Dictionary:
	var keys: Array = cfg.lighting.keys.duplicate()
	keys.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.hour < b.hour)
	var prev: Dictionary = keys[-1]
	var next: Dictionary = keys[0]
	for k: Dictionary in keys:
		if k.hour <= hour:
			prev = k
	for i in range(keys.size() - 1, -1, -1):
		if keys[i].hour > hour:
			next = keys[i]
	var span := fposmod(next.hour - prev.hour, 24.0)
	var t := 0.0 if span == 0.0 else fposmod(hour - prev.hour, 24.0) / span
	t = smoothstep(0.0, 1.0, t)
	return {
		"azimuth": rad_to_deg(lerp_angle(deg_to_rad(prev.azimuth), deg_to_rad(next.azimuth), t)),
		"elevation": lerpf(prev.elevation, next.elevation, t),
		"color": Color(prev.color).lerp(Color(next.color), t),
		"energy": lerpf(prev.energy, next.energy, t),
		"ambient": Color(prev.ambient).lerp(Color(next.ambient), t),
		"ambient_energy": lerpf(prev.ambient_energy, next.ambient_energy, t),
		"windows": lerpf(prev.windows, next.windows, t),
		"name": prev.name if t < 0.5 else next.name,
	}
