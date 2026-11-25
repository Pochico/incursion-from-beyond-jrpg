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
| `flag NOMBRE` | El indicador está activo. `flag dia_N` es verdad si hoy es el día N de la partida (`dia_2` = martes); no se guarda. Planes (`ChapterDB.PLANS`, `Invites`): `flag plan_invitado:ID` (te lo propusieron), `flag por_proponer:ID` (te lo va a proponer en persona), `flag plan_si:ID` / `plan_no:ID` / `plan_otro:ID` (lo que contestaste), `flag plan_hecho:ID` (fuiste), `flag plan_plantado:ID` (dijiste que sí y no fuiste) y `flag reproche:ID` (reproche sin contestar). |
| `presente ID` | Ese personaje está en la escena. |
| `fase >= X` | Punto de la historia (`=`, `!=`, `<`, `>`, `<=`, `>=`): `rutina` → `incursion_1` (primera incursión) → `reunion` (reunión del grupo en las Cloacas). |
| `tramo >= X` | Relación con Ren: `hostil`, `fria`, `neutral`, `cercana`, `intima`. |
| `ánimo = a\|b` | Ánimo actual (`!=` para negar). |
| `hoy >= N` | Interacciones de cualquier tipo hoy con él o ella, incluida la actual. |
| `veces >= N` | Veces que se ha hecho hoy esta misma acción, incluida la actual. |
| `afecto >= N` | Cualquier dimensión de lo que siente por Ren. |
| `resultado = gana` | Dato del momento (combates). |

### Menciones: darse por aludido

- **Mecánica.** Una respuesta de Ren puede mencionar a alguien con la etiqueta `#alude=rika` (varios: `#alude=rika|kenji`). Si el mencionado está presente, se da por aludido: reacciona a los estilos y posturas de esa respuesta con peso completo, como el interlocutor, en vez de la mitad que reciben los oyentes. Si no está presente, no se entera. Se registra en el evento `choice` (`mentions`). Código: `Social.on_choice` y `MENTION_TAG`.
- **Guion.** Para que el aludido conteste, se pone debajo de la línea (o dentro de la rama de la respuesta) un bloque `if Story.present("rika")` con su réplica. Si no está, la conversación sigue sin ella.

```
- Pregúntale a Rika, que siempre dice que brillo. [#bromista, #alude=rika]
	if Story.present("rika")
		Rika: ¡Eh! Yo no he dicho eso nunca.
	Kenji: ¡Ja! Ese es mi Ren.
```

El editor de diálogos web hace las dos cosas con botones («Menciona a…» y «Si está presente, contesta…») y el simulador abre esa rama según los presentes marcados.

### Opciones por persona

Una respuesta de Ren puede repetirse una vez por cada personaje que cumpla unos filtros, con `{persona}` donde va el nombre:

```
- Pues sí la verdad. Tuve una cita con {persona}. [#persona, #afecto>=15]
	if Story.persona == "rika" and Story.present("rika")
		Rika: A ver, a ver. En ningún momento se habló de que eso fuese una cita.
	Kenji: ¡¿Qué me dices?!
```

- Salen de más a menos afecto por Ren. Nunca salen Ren, quien acaba de hablar (el que pregunta) ni el interlocutor. Si nadie cumple, la opción no aparece.
- Filtros (opcionales, se combinan): cualquier dimensión de lo que siente por Ren (`afecto>=15`, `confianza>30`…), `tramo>=cercana`, `genero=mujer|hombre`, `joven` / `adulto`, `edad<=45`, `entre=rika|akane`, `presente` / `ausente`. Salen de la ficha: `identity.gender`, `identity.generation` y `identity.age` (de momento solo las madres: Mamá 41, madre de Kenji 44; quien no tiene edad no cumple un filtro de edad).
- Al elegirla, `Story.persona` guarda a quién se eligió: `{persona}` sirve en las líneas siguientes y `if Story.persona == "rika"` para ramas propias. La persona elegida cuenta como mencionada (se da por aludida si está presente).
- Código: `Social.PERSON_TAG`, `Social.person_candidates`, `ConversationView._choices_from`.

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

## Invitaciones a planes

**[DEFINIDO]** (petición del usuario): los planes te los ofrecen en persona o por mensaje. Puedes aceptar o rechazar, sin que sea excluyente, y decir que ya tienes otro plan. Si dices que sí y luego no vas, te escriben y baja la relación; si no contestas al mensaje, te lo dicen cuando te ven. El jueves (día 4) no todo es a la vez, pero hay que elegir: a mediodía, por la tarde y por la noche coinciden dos planes.

**[PROPUESTA]** Cómo funciona (`src/systems/invites.gd`, valores provisionales):

- En `ChapterDB.PLANS`, `invite.via` = `mensaje` (por defecto) o `persona`; `invite.at` = franja en que llega el mensaje (o hasta cuándo se espera a verte en persona); `text_late` = mensaje si iba a decírtelo en persona y no os visteis; `missed_text` = el reproche.
- Propuesta en persona: una conversación con regla `hablar, flag por_proponer:ID, flag dia_N, una vez`, o dentro de otra escena. Las opciones llaman a `Story.plan_answer("ID", "si" | "no" | "otro")`. La de «ya he quedado» solo sale si hay otro plan aceptado a la misma hora: `- Ya he quedado para {{Story.conflict_title("ID")}}. [#franco] [if Story.has_conflict("ID") /]`.
- Aceptar: +1 afecto. Plantón (se comprueba al pasar de franja y cada mañana): afecto −5, confianza −4, resentimiento +3 (causa `plan_plantado`). Contestar al reproche por el móvil: *perdona* (resentimiento −2, afecto +1), *estaba en…* (resentimiento −1, confianza +1), *se me olvidó* (resentimiento +1).
- Reproche en persona: regla `hablar, flag reproche:ID, flag plan_plantado:ID, no flag plan_hecho:ID, una vez` (pesa más que las charlas normales), y la conversación quita el reproche con `$> Story.set_flag("reproche:ID", false)`. `Story.went_instead("ID")` dice a qué otro plan fuiste en su lugar.
- **Planes que propone Ren** (`Invites.ren_invite`, `GameState.ren_plans`): menú *Quedar* o *Proponer plan* en el móvil → actividad (`ChapterDB.REN_ACTIVITIES`) → franja (lo que queda de hoy o mañana). Acepta si 0,5·afecto + 0,3·confianza − 0,5·resentimiento + gusto por el sitio (`citas.lugares`) + ánimo (como en las citas) ≥ 8; quien es `talk_only` (Mamá), siempre que esté libre. Si tiene otro plan a esa hora (está en el `cast` de un plan del guion o ya aceptó otro de Ren), contesta «ya he quedado». El plan solo se crea si alguien dice que sí; los siguientes se suman. Respuesta en `<id>_quedar` (`Story.plan_reply()` = si / no / ocupado / ya; `Story.plan_title()`, `plan_when()`, `other_guests()`), escena en `quedada_<actividad>` + `<id>_quedada` (`Story.activity()`). Plantón: cada invitado escribe (`ChapterDB.REN_MISSED_TEXT`) y, si no le contestas, te lo dice en persona (`<id>_hablar_plantado`, `Story.plan_is_ren()`).
- El reproche en persona lo elige el código (`Invites.reproach_cue`) si el selector no ha elegido ya uno propio del plan (`<id>_hablar_plantado_<plan>` con su regla): así sale siempre la próxima vez que habléis.
- Si Ren es pareja de quien invitó, `Romance.morning` le resta además afecto por los planes suyos a los que dijo que sí y no fue.

## Citas y parejas

**[DEFINIDO]** (petición del usuario): a cualquier personaje se le puede pedir una cita. Acepta o no según sus gustos, lo que siente por Ren y su ánimo. Kenji y Yuna empiezan saliendo juntos: si uno de los dos siente bastante por Ren, puede dejar al otro. Si Ren tiene pareja y la descuida (no la ve, no va a sus planes, queda con otra persona), le pueden dejar.

**[PROPUESTA]** Cómo funciona ahora. Los valores son provisionales y están todos en `src/systems/romance.gd`:

- **Pedir la cita.** Menú del personaje → *Cita* → sitio (Westfield Parquesur, Bowls, Colinas, Egaleo, Cloacas). No se puede pedir durante el guion, de noche ni si ya has tenido una cita ese día.
- **Respuesta.** La puntuación es 0,4·afecto + 0,6·atracción + 0,2·confianza − 0,5·(resentimiento + asco), más el gusto por el sitio (`citas.lugares` de la ficha, de −10 a +15), más el ánimo (alegre +10 … irritado −20, según la intensidad), más 30 si ya es la pareja de Ren. Acepta con 30 o más.
  - Si dice que no, el motivo sale en `resultado` del momento `cita_pide`:
    - `pareja`: tiene pareja y no la dejaría;
    - `animo`: con otro ánimo habría dicho que sí;
    - `gustos`: en otro sitio habría dicho que sí, y propone su favorito con `Story.favourite_place`;
    - `afecto`: no siente lo suficiente;
    - `no`: es una persona adulta (las madres).
- **Dejar a su pareja por Ren** (`rompe`). Afecto por Ren ≥ 50 y atracción por Ren ≥ atracción por su pareja − 15. Rompen, se activa `flag kenji_yuna_rotos`, y quien se queda sin pareja tiene `flag dejado_por_ren_<id>`: le sube mucho el resentimiento hacia Ren y hacia su ex.
- **La cita.** Fundido al sitio y conversación del momento `cita`. Cada personaje la tiene con variantes:
  - si ya es pareja de Ren;
  - si le gusta el sitio (`Story.date_taste`).

  Al terminar suben afecto, confianza y atracción, y pasa la franja.
- **Salir en serio.** Al final de una cita, si `Story.can_be_partner(id)` (afecto ≥ 45, atracción ≥ 40, confianza ≥ 25 y al menos una cita), el personaje pregunta «¿qué somos?» y Ren puede pedirle salir (`Story.become_partner`). Se activa `flag pareja_<id>`. Si Ren ya tenía pareja, la deja.
- **Quedar a espaldas de la pareja.** Si tu pareja está delante cuando pides la cita, se entera en el momento. Si no, queda como secreto (ver «Mentiras y secretos») y activa `flag sospecha_<id>`: tu pareja te pregunta dónde estuviste.
- **Con pareja**, cada mañana (`Romance.morning`):
  - le escribe para proponer una cita (indicador `cita_propuesta:N`);
  - un día sin verse ni escribirse suma un día de descuido y baja el afecto; si os veis, el descuido baja uno;
  - no quedar el día que te lo pidió y no ir a sus planes también bajan el afecto;
  - cuando se entera de una cita con otra persona, son cuernos: bajan mucho la confianza y el afecto;
  - ligar con otra persona delante de tu pareja cuenta como media cita con otra.
- **Te deja** si se cumple alguna de estas:
  - tres días de descuido (`resultado = descuido`);
  - dos infidelidades o la confianza por debajo de 0 (`infiel`);
  - afecto < 25 o resentimiento ≥ 40 (`frio`).

  Al día siguiente, después del despertar, se juega el momento `deja_a_ren` y luego se activa `flag ex_<id>`.
- **Ren corta.** En la charla de pareja (`<id>_hablar_pareja`) hay una opción para dejarlo (`Story.break_up_with`).
- **Estado.** `GameState.partners` (id → id, en los dos sentidos) se guarda en la partida. Las citas quedan en el registro como `date` y las rupturas como `breakup`.

**[PENDIENTE]**:
- Las escenas de los planes de los días 2 y 3 todavía dan por hecho que Kenji y Yuna salen juntos.
- No hay celos entre otros personajes del grupo.

## Mentiras y secretos

**[DEFINIDO]** (petición del usuario): Ren puede mentir. Los presentes que saben la verdad le cubren si sienten más por Ren que por la persona engañada; si no, le delatan.

**[PROPUESTA]** Cómo funciona ahora. Los valores son provisionales y están en `src/systems/lies.gd`:

- **Mentir.** Una opción de Ren con `[#miente=TEMA]` es una mentira al interlocutor. El tema dice qué verdad se tapa:
  - `cita`: las citas de Ren con otra persona que el engañado no sabe;
  - `ayer` o `dia_N`: dónde estuvo Ren ese día, fuera de casa.

  Quién sabe la verdad sale del registro de acontecimientos: quien lo presenció o a quien se lo contaron.
- **Afinidad** de A por B: afecto + 0,5·confianza + 0,3·respeto − resentimiento − asco.
- **Testigos presentes que lo saben.**
  - Si alguno tiene más afinidad por el engañado que por Ren, le delata (`resultado = delatado`). El engañado se entera; Ren pierde confianza y afecto y gana resentimiento; el delator gana confianza.
  - Si no, el que más aprecia a Ren le cubre (`cubierto`).
  - Sin testigos, cuela (`creido`).
  - En el diálogo: `if Story.lie_result() == "delatado"` y `{{Story.lie_witness()}}: ...` para quien delata o cubre.
- **Secretos.** Lo que cuela, y las citas a espaldas de la pareja, quedan en `GameState.secrets`. Cada mañana (`Lies.morning`), quien lo sabe y prefiere al engañado por 10 puntos o más se lo cuenta:
  - el engañado le escribe a Ren y se activa `flag pillado_<id>`; su charla `<id>_hablar_pillado` usa `Story.snitch(id)` y `Story.lied_to(id)`;
  - si Ren había mentido, cuesta más que si solo calló;
  - quien le cubrió pierde la confianza del engañado.
- **Confesar** (`Story.confess(id)`): el engañado se entera de todo lo pendiente, sin el castigo de la mentira.
- **Dónde se usa ahora:**
  - la sospecha de la pareja (`<id>_hablar_sospecha`): confesar, mentir o evadir;
  - las conversaciones de «me dejaste plantado» de Kenji, Rika, Shiori y Akane: «me puse malo» con `#miente=dia_N`.

**[PENDIENTE]**: más situaciones de mentira en la historia; que los testigos ausentes hablen solo a veces (ahora es determinista).

## Sucesos de relación (registro)

[DEFINIDO] la mecánica de registro; los diálogos que reaccionan están **[PENDIENTE]**. Lógica en `src/systems/relation_events.gd` (`RelationEvents`). Umbrales provisionales.

- **Qué se registra** en el `EventLog`, con id fijo para usarlo en las reglas con `sabe`:
  - `pareja_<a>_<b>`: empiezan a salir (nombres en orden alfabético). `pareja_kenji_yuna` existe desde el principio y lo saben todos.
  - `ruptura_<a>_<b>`: lo dejan; `data.why` = por_ren, descuido, infiel, frio o ren_deja; `actor` es quien deja.
  - `enfado_<quien>_<con>`: enfado grave. Es un solo cambio de relación que empeora la suma de dimensiones en 25 puntos o más (`GRUDGE_POINTS`): bajar afecto, confianza, respeto o atracción, o subir miedo, asco o resentimiento. `data.cause` dice qué lo provocó: infiel, liga_delante, ruptura, dejado_por_ren, le_deja, descuido, plan_plantado, cita_plantada, mentira_delatada, mentira_descubierta, secreto_descubierto, encubridor, guion o la opción elegida.
  - Si se repite: `ruptura_kenji_yuna_2`, `enfado_yuna_ren_3`…
- **Quién lo sabe**: los implicados y los presentes en ese momento.
  - Cada mañana (`RelationEvents.morning`, antes que las mentiras y la pareja) la noticia avanza un salto: se entera quien tiene afinidad de 15 o más (`GOSSIP_AFFINITY`, `Lies.affinity`) con algún implicado y un amigo que ya lo sabe y le aprecia igual de bien.
  - Ren no lo va contando solo.
- **Enfado que sigue en pie**:
  - mientras dura, `flag enfadado_<quien>` (solo con Ren);
  - se pasa con `$> Story.reconcile("<quien>")` (registra `reconcile`) o a los 7 días (`GRUDGE_DAYS`).
- **Para los diálogos**:
  - reglas: `sabe ruptura_kenji_yuna`, `sabe enfado_yuna_ren`, `flag enfadado_yuna`;
  - en el texto: `Story.angry(id)`, `Story.grudge_cause(id)`, `Story.knows_breakup(quien, a, b)`, `Story.knows_couple(quien, a, b)` (lo último que pasó entre `a` y `b`).

**[PENDIENTE]**: los diálogos que reaccionan; quizá que las madres se enteren por sus hijos (ahora casi no tienen relaciones con el grupo, así que no les llega).
