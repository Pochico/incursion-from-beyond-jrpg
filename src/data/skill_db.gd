class_name SkillDB
extends RefCounted
## Catálogo de habilidades de naturaleza y sus fórmulas
## (ver docs/diseno/habilidades_1.md). Propuesta para prototipo, no balance final.
##
## De momento solo están las habilidades activas que usa alguien en el juego.
## Los ID son los estables del documento.
##
## Campos:
##   name, nature, role ("attack"/"support"), desc
##   cost     : [C0, k]  →  CostePM(L) = C0 + ceil(k × (L − 1))
##   cd       : turnos de reutilización tras usarla (0 = sin espera)
##   target   : "enemy" o "self"
##   effects  : componentes que se resuelven en orden:
##     {kind: "damage",  mult, attr, defense, label}   →  round(mult × D(L, attr, defense))
##     {kind: "restore", mult, attr, medium}           →  round(mult × C(L, attr))
##     {kind: "status",  status, chance, attr, resist, turns, [tick_mult, tick_attr, tick_defense]}
##     (sin tick_* el estado no hace daño periódico; ver STATUS_STAT_MODS)

const ALL := {
	# --- Biológico ---------------------------------------------------------------
	"bio_impulso_organico": {
		"name": "Impulso orgánico", "nature": "biological", "role": "attack", "icon": "slash",
		"desc": "Golpe cuerpo a cuerpo con toda la fuerza muscular. Daño físico ×1,10 (FUE).",
		"cost": [7, 0.22], "cd": 0, "target": "enemy",
		"effects": [{"kind": "damage", "mult": 1.10, "attr": "FUE", "defense": "RES", "label": "físico"}],
	},
	"bio_secrecion_caustica": {
		"name": "Secreción cáustica", "nature": "biological", "role": "attack", "icon": "flask",
		"desc": "Escupe una sustancia corrosiva. Daño ×0,82 (RES) y 60 % de corrosión: RES −8 % durante 2 turnos.",
		"cost": [10, 0.27], "cd": 0, "target": "enemy",
		"effects": [
			{"kind": "damage", "mult": 0.82, "attr": "RES", "defense": "RES", "label": "corrosivo"},
			{"kind": "status", "status": "corrosion", "chance": 60.0, "attr": "RES", "resist": "RES", "turns": 2},
		],
	},
	"bio_regeneracion_celular": {
		"name": "Regeneración celular", "nature": "biological", "role": "support", "icon": "heart",
		"desc": "Acelera la reparación de tus tejidos. Restaura PV ×0,85 (RES).",
		"cost": [11, 0.32], "cd": 2, "target": "self",
		"effects": [{"kind": "restore", "mult": 0.85, "attr": "RES", "medium": "tissue"}],
	},
	# --- Mecánico ----------------------------------------------------------------
	"mec_impacto_cinetico": {
		"name": "Impacto cinético", "nature": "mechanical", "role": "attack", "icon": "swords",
		"desc": "Acumula energía y la libera en un golpe. Daño físico ×1,18 (FUE).",
		"cost": [8, 0.25], "cd": 0, "target": "enemy",
		"effects": [{"kind": "damage", "mult": 1.18, "attr": "FUE", "defense": "RES", "label": "físico"}],
	},
	"mec_proyeccion_fragmentos": {
		"name": "Proyección de fragmentos", "nature": "mechanical", "role": "attack", "icon": "slash",
		"desc": "Dispara metralla a distancia. Daño físico ×0,90 (TEC).",
		"cost": [9, 0.24], "cd": 0, "target": "enemy",
		"effects": [{"kind": "damage", "mult": 0.90, "attr": "TEC", "defense": "RES", "label": "físico"}],
	},
	# --- Digital -----------------------------------------------------------------
	"dig_corrupcion_datos": {
		"name": "Corrupción de datos", "nature": "digital", "role": "attack", "icon": "antenna",
		"desc": "Inyecta datos corruptos en el objetivo. Daño informático ×1,03 (INT contra TEC).",
		"cost": [8, 0.24], "cd": 0, "target": "enemy",
		"effects": [{"kind": "damage", "mult": 1.03, "attr": "INT", "defense": "TEC", "label": "informático"}],
	},
	"dig_depuracion": {
		"name": "Depuración", "nature": "digital", "role": "support", "icon": "sparkle",
		"desc": "Restaura la integridad de sus propios sistemas. Restaura PV ×0,90 (INT).",
		"cost": [11, 0.30], "cd": 2, "target": "self",
		"effects": [{"kind": "restore", "mult": 0.90, "attr": "INT", "medium": "digital"}],
	},
	# --- Arquetípico (ARQ; id interno «mystic») ------------------------------------
	"mis_manifestacion_arcana": {
		"name": "Manifestación arcana", "nature": "mystic", "role": "attack", "icon": "sparkle",
		"desc": "Una fuerza sobrenatural golpea el cuerpo del objetivo. Daño ×1,00 (VOL contra RES).",
		"cost": [11, 0.27], "cd": 0, "target": "enemy",
		# Modo material: la defensa queda fijada en RES.
		"effects": [{"kind": "damage", "mult": 1.00, "attr": "VOL", "defense": "RES", "label": "sobrenatural"}],
	},
	"mis_marca_funesta": {
		"name": "Marca funesta", "nature": "mystic", "role": "attack", "icon": "alert",
		"desc": "Marca al objetivo con una maldición. Daño ×0,55 y 65 % de maldición: ×0,30 por turno durante 3 turnos.",
		"cost": [14, 0.35], "cd": 2, "target": "enemy",
		# Actúa sobre la voluntad: defensa VOL tanto para el daño como para resistir el estado.
		"effects": [
			{"kind": "damage", "mult": 0.55, "attr": "VOL", "defense": "VOL", "label": "sobrenatural"},
			{"kind": "status", "status": "curse", "chance": 65.0, "attr": "VOL", "resist": "VOL",
				"turns": 3, "tick_mult": 0.30, "tick_attr": "VOL", "tick_defense": "VOL"},
		],
	},
}

const NATURE_NAMES := {
	"biological": "Biológico", "mechanical": "Mecánico", "digital": "Digital",
	# «mystic» se muestra como ARQ (arquetípico): mitos, símbolos y leyendas encarnados.
	"psychic": "Psíquico", "mystic": "ARQ",
}

const NATURE_COLORS := {
	"biological": Color("c6f432"), "mechanical": Color("f5a623"), "digital": Color("27b4f5"),
	"psychic": Color("ff7ad9"), "mystic": Color("9b5cf0"),
}

const STATUS_NAMES := {"curse": "Maldición", "corrosion": "Corrosión"}
## Explicación para el tooltip de la ficha de estado.
const STATUS_DESC := {
	"curse": "Una fuerza arquetípica se aferra a tu voluntad. Al final de cada uno de tus turnos pierdes PV. Cuanta más VOL tengas, menos daño hace.",
	"corrosion": "Una sustancia cáustica debilita tu defensa: tu RES baja un 8 % mientras dure.",
}

## Estados que modifican atributos mientras duran: status -> {atributo: multiplicador}.
const STATUS_STAT_MODS := {"corrosion": {"RES": 0.92}}


static func get_skill(id: String) -> Dictionary:
	return ALL.get(id, {})


static func display_name(id: String) -> String:
	return get_skill(id).get("name", id)


static func nature_color(nature: String) -> Color:
	return NATURE_COLORS.get(nature, UIStyle.WHITE)


# --- Fórmulas (sección 2.2 del documento) ----------------------------------------------

## Daño base antes del multiplicador: D(L, A, R) = (18 + 2L + 2,6A) × 100 / (100 + R)
static func base_damage(level: int, attr: float, defense: float) -> float:
	return (18.0 + 2.0 * level + 2.6 * attr) * 100.0 / (100.0 + defense)


## Curación base: C(L, A) = 18 + 1,6L + 2,2A
static func base_restore(level: int, attr: float) -> float:
	return 18.0 + 1.6 * level + 2.2 * attr


## CostePM(L) = C0 + ceil(k × (L − 1)), calculado directamente desde el nivel.
static func cost(id: String, level: int) -> int:
	var c: Array = get_skill(id).get("cost", [0, 0.0])
	return int(c[0]) + ceili(float(c[1]) * (maxi(level, 1) - 1))


## P_estado = clamp(P0 + 0,35 × (A − R) − E, 5, 90), en %. Solo para objetivos susceptibles.
static func status_chance(p0: float, attr: float, resist: float, extra_resist: float = 0.0) -> float:
	return clampf(p0 + 0.35 * (attr - resist) - extra_resist, 5.0, 90.0)


## `n` habilidades distintas al azar de todo el catálogo, sin mirar la naturaleza.
static func random_skills(n: int) -> Array[String]:
	var ids: Array[String] = []
	ids.assign(ALL.keys())
	ids.shuffle()
	return ids.slice(0, mini(n, ids.size()))


## Redondeo al entero más cercano con mitades hacia arriba.
static func round_half_up(x: float) -> int:
	return floori(x + 0.5)
