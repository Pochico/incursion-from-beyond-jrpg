class_name DialogueDB
extends RefCounted
## Guiones de conversación.
##
## Cada guion es un Array de líneas (Dictionary):
##   who      : id de personaje ("aiden", "kael"...) o "narrador".
##   text     : texto de la línea.
##   id       : (opcional) etiqueta para saltar a esta línea.
##   goto     : (opcional) etiqueta a la que saltar después de esta línea.
##   end      : (opcional) true para terminar tras esta línea.
##   choices  : (opcional) opciones mostradas tras la línea:
##              [{ "text": ..., "goto": etiqueta (opcional), "affinity": int (opcional) }]
## Si no hay goto/end, se continúa con la línea siguiente.

const N := "narrador"
const A := "aiden"

const INTRO := [
	{"who": N, "text": "Despiertas un día más."},
	{"who": N, "text": "El mismo techo. La misma grieta junto a la lámpara. El mismo zumbido del frigorífico al otro lado de la pared."},
	{"who": N, "text": "Anodino. Sin interés. Rutinario."},
	{"who": N, "text": "Sigue con tu vida."},
]

# ---------------------------------------------------------------------------
# KAEL
# ---------------------------------------------------------------------------
const KAEL_TALK := [
	{"who": "kael", "text": "¡Aiden! Cuánto tiempo, tío. ¿Sigues vivo o eres un holograma con muy buena resolución?"},
	{"who": A, "text": "...", "choices": [
		{"text": "Más o menos vivo.", "goto": "k_vivo", "affinity": 1},
		{"text": "Holograma. Bájame el brillo, que deslumbro.", "goto": "k_broma", "affinity": 2},
		{"text": "(Encogerte de hombros.)", "goto": "k_silencio"},
	]},

	{"id": "k_vivo", "who": "kael", "text": "«Más o menos». Me vale. Es más de lo que dice la mitad del barrio un martes.", "goto": "k_tema"},
	{"id": "k_broma", "who": "kael", "text": "¡Ja! Ese es mi Aiden. Sabía que seguías ahí dentro, debajo de tanta capucha.", "goto": "k_tema"},
	{"id": "k_silencio", "who": "kael", "text": "Vale, vale. Modo ahorro de energía. Lo respeto.", "goto": "k_tema"},

	{"id": "k_tema", "who": "kael", "text": "Oye, ya que estás aquí... ¿Te puedo contar una cosa rara sin que me mires como si estuviera mal de la cabeza?"},
	{"who": A, "text": "Depende de lo rara que sea."},
	{"who": "kael", "text": "Llevo semanas grabando de noche. Bases, samples, lo de siempre. Y a las 3:33 los cascos pillan algo."},
	{"who": "kael", "text": "No es ruido. No es una radio. Es como... una voz metida entre los datos. Comprimida. Como si alguien hablara desde dentro del archivo."},
	{"who": A, "text": "...", "choices": [
		{"text": "Será una interferencia.", "goto": "k_esceptico"},
		{"text": "¿Y qué dice esa voz?", "goto": "k_voz", "affinity": 2},
		{"text": "Duerme más, Kael.", "goto": "k_duerme", "affinity": -1},
	]},

	{"id": "k_esceptico", "who": "kael", "text": "Eso pensé yo. Cambié de cables, de portátil, hasta de enchufe. Sigue ahí. Misma hora. Mismo segundo.", "goto": "k_final"},
	{"id": "k_voz", "who": "kael", "text": "Al principio nada. Ahora la limpio un poco y se entiende una palabra. Solo una."},
	{"who": "kael", "text": "«Abre».", "goto": "k_final"},
	{"id": "k_duerme", "who": "kael", "text": "Ya, ya... Tú también estás a una mala noche de oír cosas, no te creas.", "goto": "k_final"},

	{"id": "k_final", "who": "kael", "text": "En fin. Si un día te da por aburrirte un poco menos, pásate por el estudio y lo escuchas tú mismo."},
	{"who": "kael", "text": "Y tráete algo de comer. El genio creativo no se alimenta del aire."},
]

const KAEL_FIGHT := [
	{"who": A, "text": "¿Echamos un combate?"},
	{"who": "kael", "text": "¿Tú y yo? ¿Aquí? Venga, hombre... Si quieres pelea, te reto al Tekken. Y pierdes. Como siempre."},
	{"who": N, "text": "(El sistema de combate todavía no está disponible.)"},
]

const KAEL_FLIRT := [
	{"who": A, "text": "Hoy estás especialmente guapo, Kael."},
	{"who": "kael", "text": "Tío, me halagas. De verdad. Pero mi corazón pertenece a mis vinilos y a una cafetera italiana."},
	{"who": "kael", "text": "...Aunque gracias. Necesitaba oírlo. Las rastas no se mantienen solas."},
]

# ---------------------------------------------------------------------------
# ELARA
# ---------------------------------------------------------------------------
const ELARA_TALK := [
	{"who": "elara", "text": "...Aiden. De la clase de los jueves. Creo."},
	{"who": A, "text": "Creo que sí."},
	{"who": "elara", "text": "Si vienes a pedirme los apuntes, la respuesta es no. Si vienes a otra cosa, tienes un minuto."},
	{"who": A, "text": "...", "choices": [
		{"text": "¿Qué estás leyendo?", "goto": "e_libro", "affinity": 2},
		{"text": "Solo pasaba por aquí.", "goto": "e_pasaba"},
		{"text": "¿Un minuto exacto?", "goto": "e_minuto", "affinity": 1},
	]},

	{"id": "e_pasaba", "who": "elara", "text": "Todo el mundo «solo pasa por aquí». Es la frase más repetida de la ciudad. Aun así, te quedan cincuenta segundos.", "goto": "e_libro"},
	{"id": "e_minuto", "who": "elara", "text": "Más o menos. Es una unidad de cortesía, no de tiempo. ...Está bien, me has hecho gracia. Dos minutos.", "goto": "e_libro"},

	{"id": "e_libro", "who": "elara", "text": "«Leyendas urbanas del sur de Madrid». Edición de 1987. La encontré en un contenedor de papel, cosa que ya me parece una leyenda en sí misma."},
	{"who": "elara", "text": "Hay una teoría en el prólogo que no me quito de la cabeza: las ciudades también tienen mitos. Y los mitos necesitan que alguien crea en ellos para existir."},
	{"who": "elara", "text": "Cuanta más gente los cuenta, más reales se vuelven. Y cuando nadie los recuerda... se mueren de hambre."},
	{"who": A, "text": "...", "choices": [
		{"text": "Suena a cuento para asustar críos.", "goto": "e_critico"},
		{"text": "¿Y cuál es el mito de Leganés?", "goto": "e_mito", "affinity": 2},
		{"text": "Me lo creo.", "goto": "e_creo", "affinity": 1},
	]},

	{"id": "e_critico", "who": "elara", "text": "Lo es. Los cuentos para críos son los mitos que mejor han sobrevivido. Eso no los hace falsos; los hace eficaces.", "goto": "e_torre"},
	{"id": "e_creo", "who": "elara", "text": "No deberías decir eso tan rápido. Creer es justo lo que les da de comer.", "goto": "e_torre"},
	{"id": "e_mito", "who": "elara", "text": "Tiene varios. Pero uno se repite en ediciones distintas, con décadas de diferencia.", "goto": "e_torre"},

	{"id": "e_torre", "who": "elara", "text": "La Torre. Dicen que, a medianoche, desde el andén de la estación se ve un piso más de los que tiene. Uno con la luz encendida."},
	{"who": "elara", "text": "Lo conté anoche desde el tren. Catorce plantas. Hoy, a plena luz, he contado trece."},
	{"who": A, "text": "Te habrás equivocado."},
	{"who": "elara", "text": "Probablemente. Por eso pienso volver a contarlas esta noche."},
	{"who": "elara", "text": "Se te ha acabado el minuto, Aiden. ...Pero no ha estado mal."},
]

const ELARA_FIGHT := [
	{"who": A, "text": "¿Te apetece pelear?"},
	{"who": "elara", "text": "...No."},
	{"who": "elara", "text": "Si buscas pelea, has elegido mal sitio, mal momento y, sobre todo, mal rival. Tengo un libro de tapa dura y no dudaría en usarlo."},
	{"who": N, "text": "(El sistema de combate todavía no está disponible.)"},
]

const ELARA_FLIRT := [
	{"who": A, "text": "Las gafas te quedan genial."},
	{"who": "elara", "text": "Interesante estrategia. Directa, sin preámbulos y completamente ineficaz."},
	{"who": "elara", "text": "...Son graduadas, por cierto. No son un accesorio. Pero gracias."},
]

# ---------------------------------------------------------------------------
# MISAKI
# ---------------------------------------------------------------------------
const MISAKI_TALK := [
	{"who": "misaki", "text": "Anda. El de las recreativas. El que nunca juega, solo mira."},
	{"who": A, "text": "Mirar también cuenta."},
	{"who": "misaki", "text": "No para la máquina. La máquina solo entiende monedas y gente con ritmo."},
	{"who": "misaki", "text": "Hablando de eso. Ayer pasó algo raro en el turno de noche, y tú eres el único cliente que no me parece un pirado. Así que te lo cuento a ti."},
	{"who": A, "text": "...", "choices": [
		{"text": "Soy todo oídos.", "goto": "m_cuenta", "affinity": 1},
		{"text": "¿Gracias... supongo?", "goto": "m_gracias", "affinity": 1},
		{"text": "Tengo prisa.", "goto": "m_prisa", "affinity": -1},
	]},

	{"id": "m_prisa", "who": "misaki", "text": "Nadie en este barrio tiene prisa. Escucha, que es corto.", "goto": "m_cuenta"},
	{"id": "m_gracias", "who": "misaki", "text": "Era un cumplido. No te acostumbres.", "goto": "m_cuenta"},

	{"id": "m_cuenta", "who": "misaki", "text": "La máquina de baile del fondo. Esa que lleva dos años con la pantalla de récords congelada."},
	{"who": "misaki", "text": "A las tres de la mañana se encendió sola, puso una canción que no está en su lista y marcó una puntuación perfecta. Sin nadie encima."},
	{"who": "misaki", "text": "Y en la tabla, arriba del todo, apareció un nombre."},
	{"who": "misaki", "text": "AIDEN."},
	{"who": A, "text": "...", "choices": [
		{"text": "Será una broma de alguien.", "goto": "m_broma"},
		{"text": "Yo no estaba allí.", "goto": "m_coartada", "affinity": 1},
		{"text": "¿Sigue ahí el nombre?", "goto": "m_sigue", "affinity": 2},
	]},

	{"id": "m_broma", "who": "misaki", "text": "Eso dije yo. Luego revisé las cámaras. La sala estaba vacía. Bueno... casi. Había algo en la imagen. Como estática con forma.", "goto": "m_final"},
	{"id": "m_coartada", "who": "misaki", "text": "Ya lo sé. Si hubieras estado, te habría visto. Nadie entra en mi turno sin que me entere.", "goto": "m_final"},
	{"id": "m_sigue", "who": "misaki", "text": "Esta mañana he desenchufado la máquina. Al volver, la tabla seguía encendida. Sin cable.", "goto": "m_final"},

	{"id": "m_final", "who": "misaki", "text": "No sé qué es. Pero si alguien quiere jugar con tu nombre, a lo mejor te interesa averiguarlo antes que yo."},
	{"who": "misaki", "text": "Esta noche cierro yo. Si te pasas, igual te dejo echar una partida gratis. Igual."},
]

const MISAKI_FIGHT := [
	{"who": A, "text": "¿Un combate?"},
	{"who": "misaki", "text": "Ja. Me gusta la actitud. Te iba a caer la del pulpo, pero me gusta."},
	{"who": "misaki", "text": "Hoy no. Tengo ensayo con la banda y no quiero romperme una uña con tu cara."},
	{"who": N, "text": "(El sistema de combate todavía no está disponible.)"},
]

const MISAKI_FLIRT := [
	{"who": A, "text": "Ese tatuaje es casi tan bonito como tú."},
	{"who": "misaki", "text": "..."},
	{"who": "misaki", "text": "Ese ha sido malo. Muy malo. Probablemente el peor intento de esta semana, y eso que es martes."},
	{"who": "misaki", "text": "...Vale, me he reído un poco. No se lo cuentes a nadie."},
]

const SCRIPTS := {
	"kael": {"talk": KAEL_TALK, "fight": KAEL_FIGHT, "flirt": KAEL_FLIRT},
	"elara": {"talk": ELARA_TALK, "fight": ELARA_FIGHT, "flirt": ELARA_FLIRT},
	"misaki": {"talk": MISAKI_TALK, "fight": MISAKI_FIGHT, "flirt": MISAKI_FLIRT},
}


static func intro() -> Array:
	return INTRO


## `action`: "talk", "fight" o "flirt".
static func for_interaction(character_id: String, action: String) -> Array:
	var by_action: Dictionary = SCRIPTS.get(character_id, {})
	return by_action.get(action, [
		{"who": character_id, "text": "..."},
	])
