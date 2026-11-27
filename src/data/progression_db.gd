class_name ProgressionDB
extends RefCounted
## Experiencia y niveles: curva, recompensas y crecimiento. Sin estado (el nivel y
## la EXP de cada personaje están en GameState.levels). Valores provisionales:
## ver docs/diseno/experiencia_y_niveles.md.

const MAX_LEVEL := 60

# --- Curva ---------------------------------------------------------------------------------

## EXP para pasar del nivel `level` al siguiente: 3·L² + 30·L + 27.
## (N1→2: 60 · N10→11: 627 · N30→31: 3.627 · N59→60: 12.240)
static func xp_to_next(level: int) -> int:
	if level >= MAX_LEVEL:
		return 0
	return 3 * level * level + 30 * level + 27


## EXP total acumulada para llegar a `level` desde el nivel 1.
static func xp_total(level: int) -> int:
	var t := 0
	for l in range(1, mini(level, MAX_LEVEL)):
		t += xp_to_next(l)
	return t


# --- Recompensas -----------------------------------------------------------------------------

## Combate: XP_BASE + XP_PER_LEVEL × nivel de la criatura, corregido por la
## diferencia con el nivel del grupo (más si está por encima, menos si por debajo).
const XP_BASE := 20
const XP_PER_LEVEL := 10
const XP_LEVEL_STEP := 0.15
const XP_MIN_FACTOR := 0.2
const XP_MAX_FACTOR := 2.0
const XP_BOSS_MULT := 1.5     ## criaturas con `boss` en su ficha de combate
const XP_DUEL_MULT := 0.5     ## duelos con personas (no criaturas): entrenar enseña menos
## Los que no van (combate o exploración) ganan hasta esta parte de la EXP de los
## que van, según su afecto por Ren (100 de afecto = todo; ver bench_share).
const BENCH_MAX_SHARE := 0.5
## Los que caen en un combate se llevan esta parte de su EXP (y vuelven con 1 PV).
const FALLEN_SHARE := 0.6


## Parte de la EXP para quien no ha ido: según lo que quiere a Ren, hasta BENCH_MAX_SHARE.
static func bench_share(id: String) -> float:
	return BENCH_MAX_SHARE * clampf(Social.value(id, CharacterDB.PROTAGONIST, "afecto") / 100.0, 0.0, 1.0)


static func battle_xp(enemy_level: int, party_level: int, boss := false, duel := false) -> int:
	var factor := clampf(1.0 + (enemy_level - party_level) * XP_LEVEL_STEP, XP_MIN_FACTOR, XP_MAX_FACTOR)
	var xp := (XP_BASE + XP_PER_LEVEL * maxi(enemy_level, 1)) * factor
	if boss:
		xp *= XP_BOSS_MULT
	if duel:
		xp *= XP_DUEL_MULT
	return maxi(roundi(xp), 1)


## Exploración, según el nivel de las criaturas de la planta.
static func secret_xp(area_level: int) -> int:
	return 15 + 5 * area_level


static func new_floor_xp(area_level: int) -> int:
	return 10 + 5 * area_level


# --- Crecimiento ---------------------------------------------------------------------------

## Atributos al nivel `level`: los de la ficha son los de nivel 1. La referencia
## (habilidades_1.md: 10 + floor((L−1)/2)) es 1 punto cada 2 niveles; `growth`
## (combat.growth de la ficha) lo multiplica por atributo: {"FUE": 1.6, "INT": 0.6}
## (sin dato, ×1). Con `growth` = RANDOM_GROWTH (Ren) no sube nada por fórmula:
## gana RANDOM_GAINS_PER_LEVEL puntos al azar al subir de nivel (GameState.add_xp),
## y además lo que entrene (GameState.stat_bonus). Ver GameState.stat_extras.
## PV, PM, daño, curación y costes ya salen del nivel por fórmula (SkillDB).
const RANDOM_GROWTH := "random"
const RANDOM_GAINS_PER_LEVEL := 2

static func stats_at(base: Dictionary, level: int, growth: Variant = null) -> Dictionary:
	var out := {}
	for k: String in base:
		var mult := 1.0
		if growth is String and growth == RANDOM_GROWTH:
			mult = 0.0
		elif growth is Dictionary:
			mult = float(growth.get(k, 1.0))
		out[k] = int(base[k]) + floori((level - 1) * mult / 2.0)
	return out


# --- Nivel de las criaturas ----------------------------------------------------------------

## Mazmorras: nivel de las criaturas de cada planta = 1 + FLOOR_LEVEL_STEP × planta
## (planta 0 = 1, planta 1 = 3...; las de debajo de la 0, nivel 1).
const FLOOR_LEVEL_STEP := 2


static func floor_creature_level(floor_number: int) -> int:
	return maxi(1, 1 + FLOOR_LEVEL_STEP * floor_number)


## Fuera de las mazmorras (incursiones en la calle): al nivel de Ren.
static func street_creature_level(protagonist_level: int) -> int:
	return maxi(1, protagonist_level)
