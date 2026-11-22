class_name TextureFormats
extends RefCounted
## Formatos de textura para las superficies del dungeon crawler.
##
## Lo comparten el Estudio de texturas (src/tools/texture_studio) y, más adelante,
## el editor y el generador de mapas. Ver docs/diseno/Diseno_Dungeon_Crawler_Godot.md.
##
## Medidas PROVISIONALES: el documento propone empezar con casillas de 2 × 2 m
## y ajustar alturas al probar el pasillo. Cambiarlas aquí cambia todo.

## Lado de una casilla, en metros.
const TILE_SIZE_M := 2.0
## Altura de la pared, en metros (sin decidir en el diseño: valor de prueba).
const WALL_HEIGHT_M := 2.5
## Densidades de píxeles por metro disponibles. 512 px/m → suelo de 1024 × 1024.
const DENSITIES := [256, 512, 1024]
const DEFAULT_DENSITY := 512

## Carpeta raíz de las texturas: assets/textures/<tema>/<superficie>/<nombre>.png
const ROOT_DIR := "res://assets/textures"

enum Repeat { NONE, HORIZONTAL, BOTH }

const SURFACES := {
	"suelo": {
		"name": "Suelo",
		"desc": "Superficie horizontal de una casilla. Cuadrada; se repite en ambos ejes.",
		"size_m": Vector2(TILE_SIZE_M, TILE_SIZE_M),
		"repeat": Repeat.BOTH,
	},
	"techo": {
		"name": "Techo",
		"desc": "Igual que el suelo, vista desde abajo. Cuadrada; se repite en ambos ejes.",
		"size_m": Vector2(TILE_SIZE_M, TILE_SIZE_M),
		"repeat": Repeat.BOTH,
	},
	"pared": {
		"name": "Pared",
		"desc": "Una cara de un borde: ancho de casilla × altura de pared. Se repite en horizontal.",
		"size_m": Vector2(TILE_SIZE_M, WALL_HEIGHT_M),
		"repeat": Repeat.HORIZONTAL,
	},
}

const SURFACE_ORDER: Array[String] = ["suelo", "techo", "pared"]


static func pixel_size(surface: String, density: int = DEFAULT_DENSITY) -> Vector2i:
	var m: Vector2 = SURFACES[surface].size_m
	return Vector2i(roundi(m.x * density), roundi(m.y * density))


static func output_path(theme: String, surface: String, file_name: String) -> String:
	return "%s/%s/%s/%s.png" % [ROOT_DIR, theme, surface, file_name]
