class_name Pressure
## Presión del grupo tras encontrar la grieta (capítulo 1, fase 5): con los días,
## unos se impacientan y otros se asustan. Cada mañana (WorldScreen, al despertar)
## `on_new_day` pone la etapa como flag exclusivo `grieta_etapa_N` (para las
## reglas `# cuando:` de los diálogos, sin tocar el selector de Story) y el ánimo
## de cada uno. El día `LIMIT_DAYS` el grupo se planta en casa: `forced_today`.
## Valores provisionales.

const PHASE := "grieta"
const LIMIT_DAYS := 7
const STAGE := "grieta_etapa_"
const DECIDED := "grieta_entrar"      # Ren ha dicho que entran (o se lo han impuesto)
## Etapa por días desde la grieta: 1 (días 1-2), 2 (3-4), 3 (5-6).
const STAGE_FROM_DAYS := [1, 3, 5]

## Carácter de cada uno ante la grieta: ánimo que se le pone y cómo sube.
const TEMPERS := {
	"akane": {"mood": "irritado", "base": 25.0, "per_stage": 15.0},
	"kenji": {"mood": "irritado", "base": 20.0, "per_stage": 15.0},
	"rika": {"mood": "ansioso", "base": 25.0, "per_stage": 15.0},
	"yuna": {"mood": "ansioso", "base": 20.0, "per_stage": 15.0},
	"shiori": {"mood": "curioso", "base": 40.0, "per_stage": 10.0},
}


## Días desde que encontraron la grieta (-1 si aún no).
static func days_since() -> int:
	if not GameState.phase_at_least(PHASE):
		return -1
	return GameState.day_number() - int(GameState.get_flag(GameState.PHASE_DAY + PHASE, GameState.day_number()))


## 0 sin presión; 1..3 según los días.
static func stage() -> int:
	var d := days_since()
	var s := 0
	for i in STAGE_FROM_DAYS.size():
		if d >= STAGE_FROM_DAYS[i]:
			s = i + 1
	return s


## Al empezar un día: etapa (flag exclusivo) y ánimos, mientras no hayan entrado.
static func on_new_day() -> void:
	if GameState.phase_at_least("exploracion_1") or GameState.get_flag(DECIDED):
		return
	var s := stage()
	for i in range(1, STAGE_FROM_DAYS.size() + 1):
		GameState.flags.erase(STAGE + str(i))
	if s == 0:
		return
	GameState.set_flag(STAGE + str(s))
	for id: String in TEMPERS:
		var t: Dictionary = TEMPERS[id]
		Social.set_mood(id, t.mood, t.base + t.per_stage * (s - 1))


## El día límite, por la mañana: el grupo se planta en casa.
static func forced_today() -> bool:
	return days_since() >= LIMIT_DAYS and not GameState.get_flag(DECIDED) \
			and not GameState.phase_at_least("exploracion_1")
