class_name ChapterDB
extends RefCounted
## Guion del capítulo 1: los pasos del primer día.
##
## Cada paso tiene un objetivo (se avisa con un toast), un destino y las escenas
## que se reproducen al llegar. Mientras hay un paso activo
## (`GameState.story_step`), solo se puede viajar al destino, no aparecen
## personajes sueltos por el mapa y no hay combates.
##
## Escenas: {cue, npc} = conversación con `npc` a la derecha (y quien hable se
## turna en ese retrato); {cue, black = true} = narración sobre negro.
## `cast` = quién está en la escena: son los que reaccionan a las opciones de Ren.
## `advance_time` = al terminar pasa a la franja siguiente del día (es una actividad).
## `end_day` = al terminar, Ren se duerme y empieza el día siguiente.

## Cue con el que despierta Ren el primer día (en vez de la intro de rutina).
const START_CUE := "dia1_despertar"
const FIRST_STEP := "dia1_instituto"

const STEPS := {
	"dia1_instituto": {
		"objective": "Ve al instituto",
		"target": "instituto",
		"cast": ["kenji", "yuna", "rika", "shiori"],
		"scenes": [
			{"cue": "dia1_clase", "npc": "kenji"},
			{"cue": "dia1_clase_fundido", "black": true},
			{"cue": "dia1_clase_salida", "npc": "rika"},
		],
		"next": "dia1_parquesur",
		"advance_time": true,   # clase: mañana → día
	},
	"dia1_parquesur": {
		"objective": "Ve a Westfield Parquesur con el grupo",
		"target": "galeria",
		"cast": ["kenji", "yuna", "rika", "shiori"],
		"scenes": [
			{"cue": "dia1_camas", "npc": "kenji"},
			{"cue": "dia1_camas_fundido", "black": true},
			{"cue": "dia1_despedida", "npc": "kenji"},
		],
		"next": "dia1_casa",
		"advance_time": true,   # camas elásticas: día → tarde
	},
	"dia1_casa": {
		"objective": "Vuelve a casa",
		"target": "casa",
		"cast": ["madre_ren"],
		"scenes": [
			{"cue": "dia1_casa", "npc": ""},
		],
		"next": "",
		"end_day": true,
	},
}


static func step(id: String) -> Dictionary:
	return STEPS.get(id, {})
