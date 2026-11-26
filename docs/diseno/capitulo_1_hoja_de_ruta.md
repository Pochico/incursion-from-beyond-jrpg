# Capítulo 1 — hoja de ruta

Plan para dejar el capítulo 1 completo: historia, progresión y lo que hay que
construir, por fases y en orden de trabajo. Cada fase dice **qué pasa en el
juego**, **qué hay ya**, **qué falta** y **cuándo está hecha**.

- **[DEFINIDO]**: lo ha decidido el usuario (su roadmap del 26-11-2026).
- **[PROPUESTA]**: lo propone Claude para poder trabajar; se puede cambiar.
- **[PENDIENTE]**: falta que el usuario lo decida (ver «Decisiones»).

Valores de balance (días, umbrales, niveles): provisionales, sin simular
combates salvo que el usuario lo pida.

---

## 1. El arco en una página [DEFINIDO]

1. **Intro y días normales.** Despertar, instituto, amigos de siempre. Se conoce
   a algún personaje nuevo.
2. **Primera incursión.** Aparece una criatura cuando Ren está tranquilamente
   **a solas con otra persona** (solo Ren y uno más). Pelea básica: sin objetos,
   solo ataques básicos. Al ganar, **los dos suben un nivel**.
3. **Lo comentan.** No se lo creen. La situación se calma.
4. **Incursiones 2 y 3**, en los días siguientes.
5. **Investigan** y encuentran una **grieta** en un sitio apartado del barrio.
   Cinemática; entran un momento, ven un mundo extraño, se asustan y salen.
6. **Preparación.** Investigan y entrenan: aquí entra **subir estadísticas**
   (cada una, una vez por semana, según las actividades que haya). Cuanto más
   tiempo pasa, unos se impacientan por entrar y otros se asustan más; al final
   **obligan** a Ren a entrar si no lo ha decidido antes.
7. **Primera exploración.** Equipo de hasta 4, elegido antes de entrar. Sin
   escáner, con lo puesto; los protagonistas tienen habilidades básicas de
   orgánicos. Sin curación: cuando van a perder, alguien dice que mejor huir y
   **salen a la fuerza**. Según hasta dónde lleguen, el **escáner** sale en esta
   incursión o en la siguiente.
8. **El Pidl** se desbloquea: tienda de curación y apoyo. Se sigue entrenando y
   se puede aprender algo nuevo en un sitio por definir.
9. **Siguiente incursión.** Pueden llegar al jefe. Encuentran un **dispositivo
   de captura**: atrapa una criatura por incursión y hay que repararlo o
   recargarlo antes de volver a entrar. Potente; no se usa a la ligera.
10. **Primera captura.** La criatura cuenta un poco de lo que sabe: el caos, las
    criaturas extrañas…
11. **Jefe final de la primera mazmorra**, al nivel justo para ganarte si no
    juegas bien tus cartas.

---

## 2. Calendario [PROPUESTA]

La partida empieza el **lunes 16 de noviembre de 2026** (`GameState.START_DATE`).

| Días | Fechas | Qué pasa | Fase al terminar |
|---|---|---|---|
| 1 | lun 16 | Día guiado (ya hecho) | `rutina` |
| 2–7 | mar 17 – dom 22 | Días normales con planes (ya hechos). Akane es una desconocida hasta que Ren habla con ella; dos compañeros de instituto nuevos salen en las imágenes | `rutina` |
| 8–9 | lun 23 – mar 24 | Primera ocasión a solas con alguien → **incursión 1**. Si el martes por la noche no ha pasado, un plan a solas la provoca | `incursion_1` |
| día siguiente | | **Reunión en las Cloacas** (ya existe; se reescribe un poco): no se lo creen | `reunion` |
| +1 a +2 días | | **Incursión 2** | `incursion_2` |
| +1 a +2 días | | **Incursión 3** | `incursion_3` |
| día siguiente | | Investigación → **la grieta, en Colinas**: cinemática, entran, salen asustados | `grieta` |
| hasta 7 días | | **Preparación**: entrenar, investigar, presión del grupo. Al 7.º día, entrada obligada | `grieta` |
| | | **Exploración 1** (retirada forzada) | `exploracion_1` |
| | | Escáner (en la 1.ª o la 2.ª exploración) → **el Pidl** | `escaner` |
| | | Exploración 2/3: **dispositivo de captura**, primera captura | `captura` |
| | | **Jefe** de la primera mazmorra → fin del capítulo 1 | `jefe_1` |

Las fases nuevas ya están en `GameState.PHASES`, así que se pueden usar en
`# cuando: fase >= grieta`, y el editor web las recoge solo.

---

## 3. Fases de trabajo

El orden está pensado para que el juego se pueda jugar de principio a fin cuanto
antes: primero la estructura con escenas provisionales, después el contenido.

### Fase 0 — Cimientos (arquitectura)

Lo que hace falta para un juego de este tamaño, antes de escribir más contenido.
Detalle en la sección 4.

- [x] Fases de historia del capítulo en `GameState.PHASES`.
- [x] **Sucesos de guion** (`StoryBeats`): una lista de datos con condiciones
  (fase, día mínimo, días desde un flag, franja, sitio, quién está presente,
  cuántos hay) y lo que pasa (escenas, combate, subir de nivel, poner fase,
  desbloquear, obligar a ir a un sitio). `world_screen` la consulta al llegar a
  un sitio, tras cada interacción y por la mañana. Sustituye al disparo fijo de
  la incursión por «segunda persona con la que hablas» (`GameState.talked_to`).
- [ ] **Desbloqueos** (al llegar a la fase 4: grieta, escáner) (`GameState.unlocks`): ubicaciones (grieta, Pidl),
  herramientas (escáner, capturador) y comandos de combate (Analizar, Capturar).
  Se guardan con la partida.
- [x] **Conocidos** (`Acquaintance`): ver fase 1.
- [ ] **Separar el guion por capítulos** (cuando haga falta: antes de añadir los planes de la fase 3): `src/data/chapters/capitulo1.gd` con
  `STEPS`, `PLANS`, `MORNINGS`, `MESSAGES` y `BEATS`; `ChapterDB` queda como
  fachada. Hoy `chapter_db.gd` ya tiene 433 líneas y va a triplicarse.
- [ ] **Grupo fijo** (en la fase 6): habilidades de cada compañero conocidas (no al azar) y
  grupo de hasta 4 (`Battle` hoy admite Ren + 1).

**Hecha cuando**: la incursión 1 sale de un suceso de datos y el juego guarda y
carga fases, desbloqueos y grupo sin romper las partidas viejas.

### Fase 1 — Días normales y personaje nuevo (Akane hecha; faltan los dos compañeros)

- **Hay**: día 1 guiado, planes de los días 2–7, mensajes, citas, mentiras,
  invitaciones, Westlake.
- **Falta**:
  - Que la incursión 1 **no** pueda saltar antes del día 8 (hoy puede pasar el
    día 2).
  - Repasar que ninguna escena de los días 2–7 dé por sabidas las criaturas.
  - **Desconocidos** [DEFINIDO]: Akane, los dos compañeros de instituto nuevos
    y los que vengan (vendedores, etc.) empiezan sin que Ren los conozca. Tres
    estados por personaje:
    1. **Desconocido**: sale en la imagen con un nombre genérico («Chica de la
       chupa», «Compañero de clase»…). Se puede ignorar. **No aparece en el
       móvil** (Mensajes, Relaciones, Proponer plan) ni te escribe.
    2. **Presentado**: Ren le saluda o le pregunta el nombre cuando quiera; desde
       ahí sale su nombre. Las charlas son escuetas y genéricas un tiempo.
    3. **Amigo**: Ren decide hacerse su amigo; intercambian contactos y ya
       sale en Mensajes y Relaciones, con planes y conversaciones normales.
    Hace falta: `GameState.acquaintance` (id → estado) que lean
    `CharacterDB.display_name`, el menú del personaje y el móvil; y revisar las
    escenas que nombran a Akane antes (`dia2_bowls`: Kenji la conoce, Ren no) y
    sus mensajes y planes previos.
  - **Dos compañeros de instituto nuevos**: salen en las imágenes del
    instituto; el usuario prepara las imágenes.
- **Hecha cuando**: los días 1–7 se juegan sin ninguna criatura y Akane no se
  nombra antes de conocerla.

### Fase 2 — Incursión 1 ✅ (escenas provisionales)

Hecho: `ChapterDB.BEATS.incursion_1`, plan `kenji_a_solas` (día 10), combate
`basic_only`, subida de nivel de los dos. Las escenas de alarma y de después ya
sirven para el «a solas».

- **Disparo**: suceso `incursion_1`. Fase `rutina`, día ≥ 8, en un sitio donde
  están **Ren y exactamente una persona** (cast presente = 1, o plan o quedada
  con un solo invitado). Si el día 9 por la noche no ha saltado, al día
  siguiente alguien propone un plan a solas (mensaje) y salta allí.
- **Combate básico**: opciones nuevas en `Battle`/`CombatView`:
  - `basic_only`: Atacar, Defender y Huir (sin Habilidad, Objeto ni Analizar);
  - criatura de nivel 1, la de la partida (`GameState.incursion_enemy`);
  - el compañero es quien estaba con Ren (hoy se le dan 2 habilidades al azar:
    quitar).
- **Al ganar**: +1 nivel a Ren y al compañero (`GameState.add_xp` hasta el
  siguiente nivel, o un `level_up(id)` nuevo), con aviso en pantalla.
- **Si pierden** [DEFINIDO]: la historia sigue, sin la subida de nivel.
- **Escenas**: hay `temblor`, `alarma`, `aparece_<criatura>`,
  `derrota_<criatura>_<resultado>` y `tras_incursion`; revisarlas para el
  «a solas».
- **Hecha cuando**: salta solo a solas, a partir del día 8, con combate básico,
  y sube un nivel a los dos.

### Fase 3 — Lo comentan (reunión) e incursiones 2 y 3 ✅ (criaturas provisionales)

Hecho: reunión reescrita (los que no estaban no se lo creen, quien estaba lo
confirma, se calman; Akane solo si es amiga; Cloacas `friends_only`); sucesos
`incursion_2` (Engendro) e `incursion_3` (dos Imps) al llegar a un sitio con
alguien del grupo, un día después como mínimo; pistas `pista_barro` y
`pista_colinas`; charlas de después de la reunión sin «entrar en La Torre».
Yuna tiene datos de combate. Las escenas de alarma y de después de la primera
incursión ya existían para los cuatro.

- **Reunión en las Cloacas**: existe (`reunion_cloacas`). Reescribir para «no se
  lo creen» y que la situación se calme. Quien estuvo en la incursión lo cuenta
  con su versión.
- **Incursiones 2 y 3**: sucesos `incursion_2` e `incursion_3`, 1–2 días
  después de la anterior, en la calle y con quien esté con Ren (no
  necesariamente a solas). Criatura distinta cada vez. Combate normal, ya con
  habilidades. Cada una deja una pista para la investigación (un objeto, una
  foto, un ruido, el mismo sitio en el mapa…).
- **Hecha cuando**: las tres incursiones salen en días distintos y quedan en el
  `EventLog` con quién lo vio.

### Fase 4 — La grieta

> **Hecho**: plan `investigacion_colinas` (Shiori lo propone por mensaje al día
> siguiente de la incursión 3; no caduca), escenas `investigacion_colinas`,
> `grieta_aparece`, `grieta_asomarse` y `grieta_fin` en `capitulo1.dialogue`
> con la puesta en escena en comandos `Story.efecto`; fase `grieta` al acabar.
> Colinas cambia con la fase (`LocationDB` `from_phase`: descripción, fondo
> `plaza_grieta[_franja]` si existe, `rift`) y tiene «La grieta» (tecla G, cue
> `grieta_mirar`). Falta la imagen del usuario del fondo con la grieta.

- **Investigación**: un plan obligatorio tras la incursión 3 (paso de guion,
  como el día 1) que junta las pistas y apunta a un sitio apartado del barrio.
- **La grieta está en Colinas** [DEFINIDO] (la ubicación `plaza`, que el editor
  del mapa ya llama «Colinas»). No es una ubicación nueva: desde la fase
  `grieta`, Colinas tiene la entrada a la mazmorra (como hoy La Torre:
  `LocationDB` `dungeon`/`dungeon_map`, pero dependiendo de la fase) y un fondo
  propio con la grieta (imagen del usuario). Los planes de vóley de Colinas
  siguen funcionando.
- **Cinemática**: una secuencia de escenas sobre negro, fondos y temblor
  (`_black_scene`, `_quake`, fondos por franja). Si hace falta algo más
  (zoom, paneo de imagen), un `CutscenePlayer` sencillo que lea una lista de
  planos.
- **Primera entrada**: una escena (no la mazmorra jugable): ven el otro lado, se
  asustan, salen. Fase `grieta`; empieza la cuenta de días.
- **Hecha cuando**: tras la incursión 3 se llega a la grieta, se ve la
  cinemática y la grieta queda en el mapa.

### Fase 5 — Preparación: estadísticas y presión del grupo

- **Subir estadísticas** [DEFINIDO]: cada estadística, una vez por semana,
  haciendo una actividad disponible.
  - Sistema `Training` + datos `TrainingDB`: actividad → estadística, sitio,
    franjas, requisitos (fase, desbloqueo). La semana va de lunes a domingo.
  - [PROPUESTA] La sube Ren (+1) y también quien entrene con él (si va con
    alguien, ese personaje sube la misma estadística y gana afecto).
  - [PROPUESTA] Actividades con los sitios que ya hay:

    | Estadística | Actividad | Sitio |
    |---|---|---|
    | FUE | Gimnasio al aire libre | Parque de la Ribera |
    | AGI | Patinar en Bowls / vóley | Parque / Plaza Mayor |
    | RES | Correr junto al lago | Westlake |
    | INT | Estudiar | Campus (biblioteca) |
    | TEC | Trastear en las recreativas | Westfield Parquesur |
    | VOL | Aguantar en las Cloacas (meditar con la cascada) | Cloacas |

  - Los bonos se suman a `ProgressionDB.stats_at` (`GameState.stat_bonus`).
  - En la interfaz: una opción «Entrenar» en el menú del sitio, y en la pantalla
    de estado la estadística entrenada esta semana marcada.
- **Presión del grupo** [DEFINIDO]: con los días desde la grieta, unos se
  impacientan y otros se asustan.
  - [PROPUESTA] Por carácter de la ficha: impacientes **Akane y Kenji**;
    asustados **Rika y Yuna**; **Shiori** curiosa pero prudente.
  - Mensajes por día (`MESSAGES` con `if` de fase y día), ánimos (`set_mood`) y
    frases en sus conversaciones (`# cuando: fase >= grieta, ...`).
  - [PROPUESTA] Límite de 7 días: la mañana del 7.º, el grupo se planta en casa
    y entráis (paso de guion obligatorio). Antes, Ren puede decidir entrar
    desde la grieta.
- **Hecha cuando**: se puede entrenar cada estadística una vez por semana, el
  grupo cambia de tono con los días y el 7.º día te obligan.

### Fase 6 — Primera exploración

- **Elegir equipo** [DEFINIDO]: pantalla antes de entrar. El equipo es de hasta
  4 contando **siempre a Ren**: Ren y hasta 3 más (Ren no se puede quitar). En el
  capítulo 1 solo pueden ir los que Ren ya conoce [DEFINIDO]: **Rika, Yuna, Kenji
  y Shiori** (Akane no). La lista sale de datos del capítulo, no del código.
- **Con lo puesto**: sin escáner, sin objetos de curación (solo lo que
  encuentren, que no cura).
- **El escáner hace las dos cosas** [DEFINIDO]: el comando *Analizar* del
  combate y el pulso de la mazmorra. Sustituye al resonador: hoy
  `GameState.ALWAYS_CARRIED` da el resonador desde el principio; pasa a ser el
  escáner, que se consigue en la mazmorra. Las baterías siguen dando cargas al
  pulso. Sin escáner, *Analizar* no sale en combate.
- **Habilidades** [DEFINIDO]: básicas de orgánicos para los protagonistas.
  [PROPUESTA] Ren y los compañeros empiezan con 1–2 habilidades BIO de tier 1;
  las demás de su naturaleza se aprenden luego.
- **Retirada forzada**: cuando el grupo va a perder (propuesta: en combate,
  cuando caiga el primero o el grupo baje del 35 % de PV total; fuera de
  combate, al empezar un combate con el grupo por debajo de ese umbral), alguien
  del equipo dice que mejor huir, el combate acaba sin derrota y salís
  (`DungeonScreen`, sin deshacer lo ganado). La historia sigue como debe
  [DEFINIDO]: no pasa nada.
- **Experiencia del grupo** [DEFINIDO]:
  - los que **no van** a la mazmorra ganan entre un 15 % y un 40 % de la EXP
    que ganan los del equipo [PROPUESTA: al salir, al azar en ese rango, o
    según la relación con Ren];
  - los que **caen en un combate** ganan el 60 % de la EXP de ese combate y al
    terminarlo vuelven con 1 PV.
- **Perder en la mazmorra** [DEFINIDO]: en cualquier momento, si el grupo cae,
  se vuelve a empezar **desde la entrada** de la mazmorra. Hoy `_lose_run`
  vuelve al último punto de guardado: cambia a la entrada (todo lo ganado en esa
  incursión se pierde y el grupo vuelve a estar como al entrar).
- **Escáner**: objeto en el mapa a cierta profundidad. Si en la primera no
  llegas, en la segunda aparece antes o queda garantizado.
- **Hecha cuando**: se elige equipo, se entra sin herramientas, la retirada
  salta sola y el escáner se consigue como muy tarde en la segunda.

### Fase 7 — El Pidl, entrenamiento y aprender habilidades

- **Ubicación nueva** `pidl` (supermercado), desbloqueada al conseguir el
  escáner.
- **Tienda**: `ShopDB` (qué vende cada sitio, precios) + pantalla de compra con
  el estilo del juego (cantidades y dinero). Productos: los de `ItemDB`
  (Pochicola, batido…) y los nuevos de apoyo.
- **Aprender habilidades**: en pausa [DEFINIDO]; el usuario lo pensará. Por
  ahora solo `GameState.skills` por personaje (las que conoce).
- **Hecha cuando**: se compra en el Pidl, los objetos sirven en la mazmorra y se
  puede aprender al menos una habilidad.

### Fase 8 — Dispositivo de captura y primera captura

- **Dispositivo**: objeto en la mazmorra (antes del jefe). Una captura por
  incursión; después queda descargado y hay que repararlo antes de volver a
  entrar [DEFINIDO]:
  - **en casa**: cuesta dinero y una franja del día;
  - **pidiéndoselo a alguien** para que lo lleve a reparar: cuesta el doble de
    dinero y no gasta tiempo de Ren. [PROPUESTA] Está listo a la mañana
    siguiente; se pide desde su menú o por el móvil.
  - Precio y detalles: provisionales, se ajustan sobre la marcha.
- **En combate**: comando «Capturar» (con el dispositivo cargado). Probabilidad
  según PV que le queden a la criatura [PROPUESTA]; si falla, se gasta igual.
- **Capturadas**: `GameState.captured`. Qué hacen después (asimilación,
  invocarlas, info) queda para el sistema de naturalezas.
- **Primera captura**: escena con la criatura que cuenta un poco: el caos, las
  criaturas extrañas… (texto por escribir con el usuario).
- **Hecha cuando**: se captura una criatura, el dispositivo queda descargado
  hasta repararlo y sale la escena de la primera captura.

### Fase 9 — Jefe y cierre del capítulo

- **Jefe**: hoy el Tiranosaurio, en la planta 4 de La Torre. El jefe del
  capítulo 1 y qué criaturas salen en cada sitio los decide el usuario más
  adelante [PENDIENTE]: no tocarlos.
- **Nivel justo**: que gane si juegas mal. Ajustarlo exige simular combates:
  **solo si el usuario lo pide** (regla del proyecto).
- **Cierre**: escena final, fase `jefe_1`, guardado y aviso de fin de capítulo.
- **Hecha cuando**: se puede jugar del día 1 al jefe sin bloqueos.

---

## 4. Arquitectura: qué cambia

| Pieza | Dónde | Qué hace |
|---|---|---|
| Fases del capítulo | `GameState.PHASES` | `rutina → incursion_1 → reunion → incursion_2 → incursion_3 → grieta → exploracion_1 → escaner → captura → jefe_1`. ✅ Hecho |
| Guion por capítulos | `src/data/chapters/capitulo1.gd` + fachada `ChapterDB` | Pasos, planes, mañanas, mensajes y sucesos de cada capítulo en su archivo |
| Sucesos de guion | `src/systems/story_beats.gd` (`StoryBeats`) | Comprueba condiciones de los `BEATS` y devuelve qué suceso toca; `world_screen` lo reproduce. Un suceso se hace una vez (`GameState.beats_done`) |
| Desbloqueos | `GameState.unlocks` + `GameState.unlock(id)`, `is_unlocked(id)` | Ubicaciones (`LocationDB` mira `requires`), herramientas y comandos de combate |
| Grupo | `GameState.party` (hasta 4) + `GameState.skills` (por personaje) | Sustituye al compañero al azar de `DungeonScreen` y a las habilidades al azar. EXP de los que no van y de los caídos |
| Conocidos | `GameState.acquaintance` (desconocido / presentado / amigo) | Nombre genérico, charlas escuetas, y quién sale en el móvil |
| Combate | `Battle`: varios aliados, `rules` {`basic_only`, `no_items`, `no_analyze`, `retreat_at`}; `CombatView` oculta o bloquea comandos según `rules` | Primera pelea básica, retirada forzada |
| Niveles | `GameState.level_up(id)` (o EXP justa) | La subida de nivel de la incursión 1 |
| Entrenamiento | `src/systems/training.gd` + `src/data/training_db.gd`; `GameState.stat_bonus`, `GameState.trained` (semana → estadísticas) | Subir estadísticas una vez por semana |
| Presión | Datos en `capitulo1.gd` (mensajes por día desde la grieta) + `Story.days_since(flag)` para los diálogos | Impaciencia o miedo de cada uno |
| Tienda | `src/data/shop_db.gd` + `src/ui/components/shop_panel.gd` | El Pidl |
| Captura | `ItemDB` `capturador` + `GameState.capture_ready`, `GameState.captured`; comando en `CombatView` | Dispositivo de captura |
| Cinemáticas | `src/screens/world/cutscene_player.gd` (si hace falta más que `_black_scene` y `_quake`) | La grieta |
| Mazmorra del capítulo | `src/data/mazmorras/<mapa>.json` | Escáner, capturador y jefe como «cosas» del mapa; `DungeonMap` ya admite objetos, cajas y jefe |

Reglas para no perder el control con el tamaño:

- **Datos en `src/data/`, lógica en `src/systems/`, vista en `src/screens/`.**
  `world_screen.gd` ya pasa de 1.000 líneas: lo nuevo va en sistemas, y la
  pantalla solo lo reproduce.
- **Partidas viejas**: todo campo nuevo del guardado lleva un valor por defecto
  en `load_game`; si cambia el formato, sube `SAVE_VERSION`.
- **Los textos que dice alguien, en `.dialogue`**: los sucesos solo nombran cues.
  Si se añaden funciones a `Story` (p. ej. `days_since`), el editor web las lee
  solo; si cambia **cómo elige** Story, hay que tocar `motor.js` y pasar la
  prueba de paridad.

---

## 5. Decisiones

Tomadas por el usuario (26-11-2026):

- **Escáner**: hace las dos cosas, *Analizar* y el pulso; sustituye al resonador.
- **Grieta**: en Colinas (`plaza`).
- **Mazmorra**: mapa de La Torre como el mundo de la grieta (propuesta sin
  objeción; confirmar al llegar a la fase 6).
- **Akane**: desconocida hasta que Ren habla con ella. Dos compañeros de
  instituto nuevos en las imágenes, sin interacción al principio (imágenes del
  usuario).
- **Equipo**: Ren siempre, más hasta 3. En el capítulo 1, de entre Rika, Yuna,
  Kenji y Shiori.
- **Huida obligada**: no pasa nada, la historia sigue.
- **Derrota en la mazmorra**: se reinicia desde la entrada.
- **Capturador**: se repara en casa (dinero y tiempo) o se le pide a alguien
  (doble de dinero).
- **Jefe y criaturas por zona**: los ajusta el usuario más adelante.

Segunda tanda (26-11-2026):

- **Perder la incursión 1**: la historia sigue, sin la subida de nivel.
- **Desconocidos** (Akane, compañeros nuevos, vendedores…): nombre genérico
  hasta presentarse; charlas escuetas hasta hacerse amigos; solo entonces
  contacto, mensajes y relaciones. No salen en el móvil hasta entonces.
- **EXP**: los que no van, 15–40 % de la del equipo; los que caen, 60 % de la
  de ese combate y vuelven con 1 PV.
- **Habilidades**: en pausa.
- **Capturador y detalles**: se ajustan sobre la marcha.
- **Imagen de la grieta**: la pasa el usuario.

No queda nada abierto que bloquee el trabajo. Lo que cambie sobre la marcha se
apunta aquí.

---

## 6. Orden de trabajo

1. Fase 0: sucesos de guion, desbloqueos y grupo fijo (sin contenido nuevo).
2. Fase 2 con escenas provisionales → se puede jugar la incursión 1 nueva.
3. Fases 3 y 4 con escenas provisionales → se llega a la grieta.
4. Fase 5 (entrenamiento y presión) → la parte larga de juego libre.
5. Fase 6 → primera exploración con retirada.
6. Fases 7, 8 y 9.
7. Contenido: diálogos definitivos fase a fase, con el estilo del usuario.

Tras cada fase: probar desde una partida nueva hasta donde llegue y actualizar
este documento, el README y el CLAUDE.md.
