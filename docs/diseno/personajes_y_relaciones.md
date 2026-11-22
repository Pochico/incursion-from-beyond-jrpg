# Personajes, relaciones y diálogos (borrador)

Cómo deciden los personajes qué decir y cómo les sienta lo que hace Ren.
Nada de esto son valores definitivos: los números se ajustan jugando.

## Tres fuentes de datos

| Fuente | Qué guarda | Dónde |
|---|---|---|
| **Ficha** | Quién es: rasgos, valores, gustos, miedos, forma de hablar, reacciones, relaciones iniciales, combate. No cambia. | `src/data/characters/<id>.json` |
| **Estado de partida** | Cómo está ahora: relaciones, ánimo, cansancio, PV, inventario. | `GameState` → `user://partida.json` |
| **Registro de acontecimientos** | Qué ha pasado, cuándo, dónde y quién lo sabe. | `EventLog` (`src/systems/event_log.gd`) |

## Fases del plan

1. ✅ Punto de la historia (`GameState.phase`), indicadores (`flags`), registro de acontecimientos y guardado.
2. ✅ Estilos de respuesta, estado de relaciones, ánimo, cansancio y motor de reglas (`Social`). Fichas de Rika, Kenji, Shiori y Akane.
3. ✅ Diálogos en archivos `.dialogue` (Dialogue Manager 4.2) con selector de conversaciones (`Story`).
4. ⬜ Ánimo diario y expresiones en las ilustraciones.
5. ⬜ Regalos.

## Contexto de partida

Todos son compañeros del instituto: mayores de edad, pero siguen estudiando.
Ren, Rika y Shiori van a la misma clase. Kenji y Akane van a otras clases. Kenji es el mejor amigo de Ren desde siempre.

## Cómo se escriben las reacciones en la ficha

Bloque `reactions`:

- `styles`: qué cambia en lo que siente por Ren cuando responde con ese estilo. `{"afecto": 2}`.
- `stances`: igual, para las posturas sobre un tema. `{"tema": {"postura": {...}}}`.
- `actions`: cómo le sienta que Ren inicie *Hablar*, *Ligar* o *Luchar*.
- `fed_up`: qué sube cuando se harta de una acción, y a qué ánimo pasa.

Cualquier entrada puede depender del ánimo: `{"default": {...}, "triste": {...}, "irritado": {...}}`. Rika, por ejemplo, se toma bien lo *sarcástico*, salvo si está triste o irritada.

Rasgos que usa el motor:
- `paciencia`: cuántas veces aguanta la misma acción en un día.
- `sensibilidad`: cuánto pesa lo malo cuando está de mal ánimo.

El resto de rasgos, valores y matices son una guía para escribir sus diálogos.

## Diálogos

Están en `src/dialogue/`: un archivo por personaje y `general.dialogue`, que tiene las escenas fijas y las frases de respaldo. Usan la sintaxis de [Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager), y se pueden editar y probar desde la pestaña *Dialogue* del editor.

```
~ rika_hablar_tras_incursion
# cuando: hablar, fase >= incursion_1, sabe incursion_1, una vez
Rika: Ren. No he dormido nada.
- Alguien tenía que hacerlo. [#decidido, #proteger_a_otros=si]
	Rika: Ya... Pero no tenías por qué ser tú.
	$> Story.change("rika", "afecto", 2)
- Si vuelven, las echaremos. [#decidido, #criaturas=rechazar]
if Story.mood("rika") == "triste"
	Rika: ...
=> END
```

- Las líneas sin `Nombre: ` son del narrador. Si una narración necesita `: `, se escribe `\: `.
- **Opciones:** las etiquetas son los estilos de Ren (`#franco`) y, con `=`, las posturas (`#criaturas=acoger`). No se muestran en el juego.
- **Dentro de los diálogos** se puede usar `Story`:
  - Consultas: `tier`, `mood`, `knows`, `phase`, `flag`, `present`, `today`, `value`, `seen`.
  - Cambios: `change`, `set_mood`, `set_flag`, `tell` (Ren le cuenta algo a alguien).
  - También `GameState`.

### Selector de conversaciones

Cuando Ren interactúa con alguien, `Story.pick(personaje, momento)` elige el cue. Lo hace con las reglas `# cuando:` que van justo debajo de cada `~ cue`. Gana la regla que cumple más condiciones y, si empatan, se elige una al azar. «una vez» pesa 3 y el ánimo 2: las escenas únicas mandan sobre las variantes de ánimo, y estas sobre las conversaciones genéricas.

Momentos:
- `hablar`, `ligar`, `luchar`
- `luchar_fin` (con `resultado = gana|pierde`)
- `harto_hablar`, `harto_ligar`, `harto_luchar`
- `no_quiere`
- `alarma`
- `tras_incursion` (con `resultado`)
- `movil`: Ren saluda por el móvil. El cue debe empezar con la línea de Ren y seguir con la respuesta, sin opciones. Cada saludo se registra como evento `message`, así que `veces` cuenta los mensajes de hoy. No cansa ni cuenta para la fatiga.

| Condición | Significado |
|---|---|
| `una vez` | No se ha visto este cue nunca. |
| `visto CUE` | Ya se vio ese cue. |
| `sabe EVENTO` | El personaje conoce ese acontecimiento. |
| `flag NOMBRE` | El indicador está activo. |
| `presente ID` | Ese personaje está en la escena. |
| `fase >= X` | Punto de la historia (`=`, `!=`, `<`, `>`, `<=`, `>=`). |
| `tramo >= X` | Relación con Ren: `hostil`, `fria`, `neutral`, `cercana`, `intima`. |
| `ánimo = a\|b` | Ánimo actual (`!=` para negar). |
| `hoy >= N` | Interacciones de cualquier tipo hoy con él o ella, incluida la actual. |
| `veces >= N` | Veces que se ha hecho hoy esta misma acción, incluida la actual. |
| `afecto >= N` | Cualquier dimensión de lo que siente por Ren. |
| `resultado = gana` | Dato del momento (combates). |

Cualquier condición acepta `no` delante. Los cues ya mostrados se guardan en los indicadores como `visto:<cue>`.

Al exportar el juego hay que incluir `*.dialogue` en «Filtros para exportar archivos que no son recursos»: el selector lee las reglas de los archivos originales.

## Relaciones

Siempre tienen dirección: lo que A siente por B no tiene por qué ser lo que B siente por A. Se guardan para **cualquier par** de personajes, Ren incluido en los dos sentidos.

| Dimensión | Rango | Inicio habitual |
|---|---|---|
| Afecto | −100 … 100 | según historia |
| Confianza | −100 … 100 | según historia |
| Respeto | −100 … 100 | según historia |
| Atracción | 0 … 100 | 0 |
| Miedo | 0 … 100 | 0 |
| Asco | 0 … 100 | 0 |
| Resentimiento | 0 … 100 | 0 |

Los diálogos no leen los números, sino tramos (`hostil / fría / neutral / cercana / íntima`) y umbrales que disparan escenas (p. ej. resentimiento > 70 → discusión o abandono del grupo).

El **enfado** es un estado de ánimo, que pasa. El **resentimiento** es lo que queda.

## Estilos de respuesta de Ren

Las opciones de diálogo no se etiquetan como buenas o malas («humillar», «controlar»), sino con **cómo** responde Ren. Cada personaje valora cada estilo a su manera según su ficha: a Rika lo *directo* le gusta y lo *dominante* le choca; a otro personaje puede ser al revés.

Cada opción lleva 1 o 2 estilos. Si la decisión toma partido sobre un tema (criaturas, una persona, un grupo), lleva además una **postura** neutral sobre ese tema (p. ej. `criaturas: acoger` / `criaturas: rechazar`): así un personaje que tema a las criaturas reacciona al contenido aunque el tono sea amable.

| Grupo | Estilos |
|---|---|
| Iniciativa | decidido · dubitativo · impulsivo · prudente |
| Trato | cariñoso · reservado · formal · desenfadado |
| Sinceridad | franco · diplomático · evasivo |
| Humor | bromista · sarcástico · serio |
| Social | tímido · atrevido · coqueto |
| Ante los demás | protector · complaciente · dominante · independiente |
| Ante el conflicto | conciliador · provocador · testarudo |
| Forma de pensar | empático · pragmático · idealista · curioso |

## Cansancio (contra el grindeo)

Las relaciones no pueden subirse repitiendo la misma acción. El registro ya permite contar cuántas veces ha pasado algo y cuándo, por ejemplo `events.count({kind: "flirt", target: "rika", date: hoy})`.

- **Repetición en el mismo día.** Cada acción repetida con la misma persona rinde menos: efecto completo, la mitad, nada. A partir de ahí, la persona se satura.
- **Tolerancia.** El número de intentos que aguanta depende del ánimo y de los rasgos. Con buen humor y paciencia, unos 3 intentos de ligar («bueno, ya, ¿no?»); de mal humor, uno o ninguno.
- **Saturación.** Seguir insistiendo empeora la relación. Cada ficha dice qué sube en ese caso: resentimiento, asco, miedo o enfado.
- **Mal día.** Con un ánimo negativo intenso, el personaje puede negarse a hablar. Insistir lo enfada más.
- **Regalos.** El mismo regalo a la misma persona solo cuenta la primera vez.
- **Recuperación.** El cansancio de cada día se borra al día siguiente. Lo que ya ha cambiado en la relación se queda.

## Ánimo

Lista común para todos los personajes, enlazada con las expresiones de las ilustraciones: alegre, tranquilo, curioso, irritado, ansioso, triste. Tiene una intensidad de 0 a 100. Cada día se sortea según los pesos de la ficha, y los acontecimientos importantes tienen prioridad sobre el sorteo.

El ánimo multiplica las reacciones. Si alguien está triste, lo *sarcástico* duele más. Si está alegre y confía en Ren, puede tomarlo como broma. Ligar con alguien enfadado suele empeorarlo.
