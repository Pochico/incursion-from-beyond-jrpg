class_name TrainingDB
## Entrenamiento de la fase de preparación (capítulo 1, fase 5): cada actividad
## sube una estadística, una vez por semana (lunes a domingo). Desde la fase
## `FROM_PHASE`, en su sitio y en sus franjas. La primera vez que Ren hace cada
## actividad solo cae en que le puede venir bien (`cue` + "_descubre"); desde la
## segunda, entrena (`cue`). Quien entrene con él sube lo mismo y gana afecto.
## Valores provisionales.

const FROM_PHASE := "grieta"
const STAT_GAIN := 1
const PARTNER_AFFECTION := 2

const STAT_NAMES := {
	"FUE": "Fuerza", "AGI": "Agilidad", "RES": "Resistencia",
	"INT": "Inteligencia", "TEC": "Técnica", "VOL": "Voluntad",
}

## id → stat, name (acción del menú), target (ubicación), slots, cue (escena).
const ACTIVITIES := {
	"voley": {"stat": "FUE", "name": "Jugar al vóley", "target": "plaza",
		"slots": ["manana", "dia", "tarde"], "cue": "entreno_voley"},
	"camas": {"stat": "AGI", "name": "Camas elásticas", "target": "galeria",
		"slots": ["dia", "tarde"], "cue": "entreno_camas"},
	"grotesco": {"stat": "RES", "name": "Ver «La mazmorra de lo grotesco»", "target": "casa",
		"slots": ["tarde", "noche"], "cue": "entreno_grotesco"},
	"egaleo": {"stat": "INT", "name": "Leer en Egaleo", "target": "campus",
		"slots": ["manana", "dia", "tarde"], "cue": "entreno_egaleo"},
	"nerf": {"stat": "TEC", "name": "Guerra de nerf", "target": "parque",
		"slots": ["dia", "tarde"], "cue": "entreno_nerf"},
	"zombis": {"stat": "VOL", "name": "Zombis en tinieblas", "target": "cloacas",
		"slots": ["tarde", "noche"], "cue": "entreno_zombis"},
}


static func activity(id: String) -> Dictionary:
	return ACTIVITIES.get(id, {})
