class_name DungeonBanter
extends RefCounted
## Comentarios del compañero durante la mazmorra (salen en el registro del visor).
##
## Momentos: enter (al entrar), idle (de vez en cuando al andar), enemy (criatura
## delante), victory, defeat, item (al coger algo), level_up / level_down
## (escaleras), secret_hint (junto a una pared falsa sin descubrir),
## secret_found, locked (puerta que no se abre), switch (palanca).
##
## Cada personaje habla con su voz (ver su ficha en src/data/characters/).
## `line()` no repite una frase hasta haber dicho las demás del mismo momento.

const LINES := {
	"kenji": {
		"enter": [
			"Vale, tío, entramos. Si esto fuera un disco, sería la intro rara que nadie entiende.",
			"La Torre… Siempre pensé que aquí dentro habría oficinas aburridas, no esto.",
			"Tú delante, que yo pongo la banda sonora mental.",
		],
		"idle": [
			"Este zumbido de fondo está en si bemol. No me preguntes cómo lo sé.",
			"Si salimos de aquí, me grabo el ruido de las tuberías para una base.",
			"Oye, ¿tú también notas que las paredes respiran? Vale, igual soy yo.",
			"Tío, cuéntame algo, que el silencio aquí da mal rollo.",
			"Me estoy quedando sin batería en el móvil. Y en el alma.",
			"Juraría que ya hemos pasado por aquí. Esto es un loop de cuatro compases.",
		],
		"enemy": [
			"Eh, eh, eh. Eso de ahí delante no es un becario.",
			"Tío, mira eso. Ni se te ocurra hacerle una foto.",
			"Vale, eso respira. Prepárate.",
		],
		"victory": [
			"¡Toma! Eso ha sonado mejor que mi último directo.",
			"Uf. Vale. Seguimos vivos. Me vale.",
			"Ni un fallo de ritmo, tío. Bueno, alguno.",
		],
		"defeat": [
			"Retirada táctica. Lo llamaremos así.",
			"Vale, eso ha salido fatal. Respira y lo volvemos a intentar.",
		],
		"item": [
			"¿Pochicola? Aquí dentro sabe a gloria.",
			"Guárdalo, que luego lo echamos de menos.",
			"Bien visto, tío.",
		],
		"level_up": [
			"Arriba. Cuanto más subimos, peor me suena todo.",
			"Otra planta. Esto ya parece un ascensor sin música.",
		],
		"level_down": [
			"Bajamos. Al menos ya conocemos el camino.",
			"De vuelta abajo. Respiro un poco mejor.",
		],
		"secret_hint": [
			"Espera. Esa pared suena hueca. Como un bajo sin cuerdas.",
			"Tío, ¿lo notas? Por aquí corre aire, y no veo de dónde viene.",
		],
		"secret_found": [
			"¡Hala! Un pasadizo. Es como encontrar un track oculto al final del disco.",
			"Lo sabía. Las paredes no suenan así porque sí.",
		],
		"locked": [
			"Cerrado. Típico. Algo tendrá que abrirlo.",
			"Ni a patadas, tío. Habrá que buscar otra forma.",
		],
		"switch": [
			"Ese ruido ha sonado lejos. Algo se ha movido.",
			"Clac. Me encanta ese sonido.",
		],
	},
	"shiori": {
		"enter": [
			"Según las leyendas del barrio, nadie que entra en la Torre sale igual. Comprobémoslo.",
			"Toma nota de los giros. No pienso perderme aquí dentro.",
			"Interesante. Por dentro es más grande de lo que debería.",
		],
		"idle": [
			"Las paredes no coinciden con los planos del ayuntamiento. Los consulté el año pasado.",
			"Hay un patrón en las tuberías: rojo, azul, rojo. Todavía no sé qué significa.",
			"Hace tres grados menos que fuera. Lo he medido con el móvil.",
			"Hay un libro de 1974 que describe un edificio así. Lo catalogaron como ficción.",
			"Silencio, por favor. Quiero oír si algo nos sigue.",
			"No toques nada que brille sin preguntarme antes.",
		],
		"enemy": [
			"Delante. No es humano, y no parece amistoso.",
			"Criatura a una casilla. Te recomiendo no darle la espalda.",
			"Eso coincide con una descripción que leí. No terminaba bien.",
		],
		"victory": [
			"Correcto. Ahora sabemos que se les puede vencer.",
			"Bien. Anoto sus puntos débiles para la próxima.",
			"Eficaz. Algo torpe, pero eficaz.",
		],
		"defeat": [
			"Retirarse también es una estrategia. Una mala, pero lo es.",
			"Necesitamos otro planteamiento.",
		],
		"item": [
			"Útil. Guárdalo.",
			"Alguien estuvo aquí antes que nosotros y se dejó cosas.",
			"Lo apunto en el inventario mental.",
		],
		"level_up": [
			"Planta nueva. El aire es distinto aquí arriba.",
			"Subimos. Cuenta los escalones; luego te lo pregunto.",
		],
		"level_down": [
			"Volvemos a la planta anterior.",
			"Bajamos. Recuerdo el camino, tranquilo.",
		],
		"secret_hint": [
			"Esa pared tiene las juntas distintas a las demás. Examínala.",
			"Fíjate: hay marcas de arrastre en el suelo. Van hacia la pared.",
		],
		"secret_found": [
			"Lo sospechaba. En los edificios así siempre dejaban pasadizos.",
			"Un pasadizo oculto. Esto merece una nota a pie de página.",
		],
		"locked": [
			"Cerrada. La llave suele estar en algún sitio del mismo edificio.",
			"No se abre. Busquemos el mecanismo.",
		],
		"switch": [
			"Mecanismo accionado. Ha sonado a nuestra izquierda… o arriba. Aquí es difícil saberlo.",
			"Algo ha cambiado en el edificio.",
		],
	},
	"akane": {
		"enter": [
			"Venga, Ren. Entra de una vez, que no tengo toda la noche.",
			"Qué sitio más chungo. Me encanta.",
			"Si algo nos salta encima, le parto la cara. Tú mira y aprende.",
		],
		"idle": [
			"¿Esto es lo que haces en tu tiempo libre? Joder, y yo pensando que eras aburrido.",
			"Este pasillo me recuerda al almacén de las recreativas. Pero con menos ratas. Creo.",
			"Como vuelvas a girar sin avisar, te empujo.",
			"Ni una máquina de refrescos en toda la torre. Vaya mierda de sitio.",
			"¿Oyes eso? No. Pues mejor.",
			"Estoy pensando una canción sobre este sitio. Se va a llamar «Pasillo de mierda».",
		],
		"enemy": [
			"Eso de ahí quiere bronca. Pues bronca va a tener.",
			"Mira qué bicho más feo. Déjamelo a mí.",
			"Tú delante, que yo te cubro. O al revés, me da igual.",
		],
		"victory": [
			"¡Ja! ¿Eso es todo lo que tenía?",
			"Bah. He tenido peleas peores en un pogo.",
			"Toma ya. Siguiente.",
		],
		"defeat": [
			"Esto no se queda así, joder.",
			"Vale, nos ha pillado. La próxima, no.",
		],
		"item": [
			"Eh, eso para mí. Es broma. O no.",
			"Algo es algo.",
			"Cógelo antes de que se lo coma algo.",
		],
		"level_up": [
			"Más arriba. A ver qué nos tiene preparado este sitio.",
			"Subiendo. Como no haya nada interesante, me piro.",
		],
		"level_down": [
			"Para abajo. Ni nos hemos despedido.",
			"Bajamos. Que no se diga que huimos.",
		],
		"secret_hint": [
			"Oye. Esta pared tiene algo raro. Dale un empujón.",
			"Aquí hay corriente. Y no hay ventanas. Mmm.",
		],
		"secret_found": [
			"¡Lo sabía! Ya decía yo que esto olía a escondite.",
			"Un pasadizo secreto. Vale, esto ya mola.",
		],
		"locked": [
			"Cerrada. ¿Le doy una patada? ¿No? Qué aburrido.",
			"Pues nada, otra puerta que no se abre. Genial.",
		],
		"switch": [
			"Eso ha sonado a que algo se ha abierto. O a que hemos cabreado a alguien.",
			"Clac. Ojalá haya sido algo bueno.",
		],
	},
	"rika": {
		"enter": [
			"Bueno, cielo, ¿vamos? Prometo no gritar. Mucho.",
			"Qué mal rollo da esto… pero qué fotos más guapas saldrían.",
			"Tú abre camino, que yo me fijo en todo, ¿vale?",
		],
		"idle": [
			"Cielo, tienes una telaraña en el pelo. No, la otra… vale, ya.",
			"¿Te has fijado en que las luces rojas parpadean a la vez? Raro, raro.",
			"Si salimos vivos, me debes un crepe. Uno grande.",
			"Este sitio necesita urgentemente un poco de color. Y de wifi.",
			"Shh. Me ha parecido oír pasos. ¿Eran los tuyos? Ay, sí.",
			"Me estoy cargando el móvil con la mirada. Es broma. Ojalá.",
		],
		"enemy": [
			"Ay, ay, ay. Cielo, eso de ahí delante no tiene buena cara.",
			"Mira eso. Mira. Pero no mucho rato.",
			"Vale, prepárate. Yo te animo. Y le doy un bolsazo.",
		],
		"victory": [
			"¡Bien, cielo! ¡Qué bien te ha quedado!",
			"¡Ha sido increíble! Bueno, un poco asqueroso, pero increíble.",
			"Chócala. Eso, así.",
		],
		"defeat": [
			"Uy. Vale, no pasa nada. Respira.",
			"Nos vamos un momentito y volvemos más fuertes, ¿sí?",
		],
		"item": [
			"¡Uy, mira! Esto nos viene genial.",
			"Bien visto, cielo.",
			"Guárdalo, que nunca se sabe.",
		],
		"level_up": [
			"Planta nueva, look nuevo. Bueno, no, todo igual de gris.",
			"¡Arriba! Ya me duelen las piernas, que lo sepas.",
		],
		"level_down": [
			"Para abajo otra vez. Qué paseo nos estamos dando.",
			"Volvemos abajo. Yo me acuerdo de dónde estaba todo.",
		],
		"secret_hint": [
			"Cielo, ¿no ves algo raro en esa pared? Tiene el borde más limpio que las demás.",
			"Espera, espera. Por aquí entra aire fresquito. ¿De dónde?",
		],
		"secret_found": [
			"¡Te lo dije! Yo me fijo en todo.",
			"¡Un pasadizo secreto! Esto es como en las pelis.",
		],
		"locked": [
			"Cerrada. Habrá que buscar la llave, cielo.",
			"Ni se mueve. Seguro que hay algo por ahí que la abre.",
		],
		"switch": [
			"¿Has oído? Algo se ha movido por ahí.",
			"Ese ruidito me da buena espina.",
		],
	},
}

static var _bags := {}


## Una frase de `who` para el momento `event` ("" si no tiene).
static func line(who: String, event: String) -> String:
	var all: Array = LINES.get(who, {}).get(event, [])
	if all.is_empty():
		return ""
	var key := who + "|" + event
	var bag: Array = _bags.get(key, [])
	if bag.is_empty():
		bag = all.duplicate()
		bag.shuffle()
		_bags[key] = bag
	return bag.pop_back()
