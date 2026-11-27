# CLAUDE.md — Incursion From Beyond

Contexto para Claude (Claude Code en local o en la nube). Léelo entero antes de
trabajar. **Mantenlo al día**: no se puede subir nada al repositorio sin
actualizarlo (ver «Regla de contexto antes de subir»).

## Qué es

JRPG híbrido con novela visual y dungeon crawler, ambientado en un Leganés
cotidiano y ligeramente futurista atravesado por entidades de cinco naturalezas
(biológica, mecánica, digital, psíquica y ARQ/mística). Referencias: *Persona*,
*Shin Megami Tensei*, *Digimon*, cyberpunk; exploración tipo *Dragon Ruins*.
Protagonista: **Ren**. Capítulo 1 jugable, mundo libre por ubicaciones, combate
por turnos, móvil («Terminal»), relaciones, mapa 3D de la ciudad y modo
mazmorra en La Torre.

El **README.md** describe con detalle todo lo jugable, las herramientas y la
estructura: es la referencia de «qué hay». Este archivo es la de «cómo
trabajar».

## Motor y entorno

- **Godot 4.7** estable (versión estándar, sin .NET). `config/features` = 4.7, renderizador **GL Compatibility**.
- Ventana base 1920×1080, `stretch canvas_items` + `aspect expand`: las interfaces se maquetan sobre 1920×1080 con anclajes.
- **GDScript con tipos** e indentación con tabuladores (`.editorconfig`).
- Plugin **Dialogue Manager 4.2** en `addons/dialogue_manager/` (autoload `DialogueManager`). No modificar el addon.
- Autoloads: `App`, `GameState`, `Story`, `SceneRouter`, `DialogueManager`.
- Acciones de entrada propias en `project.godot`: `open_map` (M), `open_phone` (T).
- El usuario trabaja en **macOS** (atajos con Cmd: ejecutar proyecto Cmd+B, escena actual Cmd+R).

## Idioma y tono

- **Todo en español de España**: interfaz, diálogos, comentarios, documentación, mensajes de commit y respuestas al usuario.
- Textos del juego: naturales, coloquiales cuando toca, sin anglicismos innecesarios.
- En narración, «: » se escribe «\: » o Dialogue Manager lo toma por un personaje hablando. `ConversationView.play` pone `Story.speaker` (para `{{Story.speaker}}` en general.dialogue).
- **Estilo de los diálogos (el del usuario)**: frases cortas y reacciones reales («¿Y eso? ¿Ha pasado algo?») antes que remates ingeniosos; jerga de barrio («loco», «socio», «my brodel», «No me jodas», «echa el freno magdaleno», «Obvio»); sin detalles de más. Lo que el usuario escribe en el editor web (`dia1_despertar`, `dia1_clase`, `dia1_camas`) es la referencia: no lo reescribas.
- **Nombres** de personajes y secundarios: japoneses (Haruto, el abuelo Tetsuo, Mio, Natsuki, la señora Fumiko…), aunque la ciudad y los sitios son de Leganés.
- **Ren**: perdió a su padre hace tiempo y lo está superando. Es alegre, bromista y algo sarcástico; el padre sale poco y con cariño (la foto de la entrada, la gorra del Lega), sin dramatizar. Los demás **no** le tratan de ermitaño ni insisten en «sacarle de casa».

## Dónde va cada cosa

| Carpeta | Contenido | Reglas |
|---|---|---|
| `src/autoload/` | Singletons | Estado global en `GameState` (guardado en `user://partida.json`). |
| `src/data/` | Datos sin lógica: `*_db.gd`, fichas `characters/<id>.json`, `mazmorras/*.json`, `mapa3d.json` | Valores de balance **provisionales**; centralizados aquí, no repartidos por el código. |
| `src/dialogue/` | Diálogos `.dialogue` (uno por personaje + `general` + `capitulo1` + `mazmorra`). `capitulo1` tiene el día 1, los planes de los días 2 y 3 y la reunión de las Cloacas; `general` el despertar de cada día (`intro`) | Cada conversación con su regla `# cuando:` (ver `docs/diseno/personajes_y_relaciones.md`). `mazmorra` son los comentarios del compañero (sin reglas: los lee `DungeonBanter` por nombre de cue). Todo texto que diga un personaje va aquí, no en código. |
| `src/systems/` | Lógica sin interfaz (`battle.gd`, `social.gd`, `event_log.gd`, `romance.gd`: citas, parejas y rupturas, `GameState.partners`; momentos `cita_pide`/`cita`/`deja_a_ren` con `resultado`; ver «Citas y parejas» en `personajes_y_relaciones.md`; `lies.gd`: opciones `[#miente=cita\|ayer\|dia_N]`, testigos que cubren o delatan según afinidad, `GameState.secrets` que se descubren por la mañana; ver «Mentiras y secretos»; `invites.gd`: invitaciones a planes en persona o por mensaje, respuestas sí/no/«ya he quedado» no excluyentes, plantones con reproche por móvil o en persona; flags `por_proponer:`/`plan_si:`/`plan_no:`/`plan_otro:`/`plan_plantado:`/`reproche:` + id del plan; también los planes que propone Ren (`ren_invite`, ids `ren:N` en `GameState.ren_plans`, `ChapterDB.plan` y `all_ids` los incluyen; reproche en persona con `reproach_cue`); ver «Invitaciones a planes»; `acquaintance.gd`: gente que Ren no conoce (`stranger_name` en CharacterDB): desconocido → presentado → amigo en `GameState.acquaintance`; `CharacterDB.display_name` da el nombre genérico; el móvil, los mensajes (`GameState.add_message` los descarta), los planes con `invite` y `Social.person_candidates` filtran a los que no son amigos; cues `<id>_presentacion`/`_charla`/`_amistad`, `Story.introduce`/`befriend`/`is_friend`; `story_beats.gd`: sucesos de guion de `ChapterDB.BEATS` (condiciones fase, `min_day`, `on` talk/plan_end, `alone`, `with`; flag `suceso:<id>`) que reproduce `WorldScreen._run_beat` (incursión 1 a solas, con `CombatView` `rules.basic_only` y `GameState.level_up`; incursiones 2 y 3 al llegar a un sitio con alguien del grupo, `days_after_phase` con el flag `fase_dia:<fase>` que pone `GameState.set_phase`, `enemies`, escenas `<cue>_aparece`/`_despues`; `Story.incursion_with(n)` = con quién estaba Ren; los planes solo cuentan como presentes a los amigos); `training.gd` (`Training`): entrenar estadísticas con las actividades de `TrainingDB` (fase 5): primera vez = descubrirla sin subir, luego +1 por estadística y semana, solo o «Entrenar juntos» (menú del personaje; el compañero sube lo mismo y gana afecto), flags `entreno_visto:`/`entreno_semana:`, `Story.companion`/`companion_name()` en sus escenas `entreno_<id>[_descubre]`, tecla F en el sitio; `pressure.gd` (`Pressure`): días desde la grieta, flag exclusivo `grieta_etapa_N` cada mañana (para `# cuando:` sin tocar el selector), ánimos por carácter (`TEMPERS`), día límite 7 con `grieta_ultimatum` y flag `grieta_entrar` (también desde «La grieta»); `relation_events.gd`: parejas, rupturas y enfados graves en el `EventLog` con ids fijos `pareja_a_b`/`ruptura_a_b`/`enfado_quien_con` para `sabe`, `flag enfadado_<id>`; `Social.change` lleva `cause` y detecta el enfado; ver «Sucesos de relación») | Devuelven datos/eventos; la vista los anima. No mezclar UI aquí. |
| `src/dungeon/` | Mazmorras: `DungeonMap`, `DungeonBuilder`, `DungeonExplorer`, `DungeonTextures`, `EnemyModel` (modelo 3D `assets/modelos/<enemigo>.glb`, si existe, en vez del retrato plano; las voladoras flotan con `hover` en su ficha, `CharacterDB.hover`; objetos en 3D con `assets/modelos/objetos/<id>.glb` o `image` de `ItemDB`, girando con `ItemSpin`), punto de guardado (`DungeonMap.SAVE`, `DungeonBuilder._save_point`), criaturas que sueltan algo (`drop` en la cosa del mapa), resonador (`DungeonExplorer.pulse`, capa `pulse.gdshader` como `material_overlay`; paredes secretas `hidden` = solo con el pulso, `DungeonMap.is_hidden`) ; luces del mapa (`DungeonMap.lights` por planta: color, energy, range, decay, height; `DungeonBuilder.light_point`; el explorador enciende solo las `MAX_MAP_LIGHTS` más cercanas por el límite de luces por malla de Compatibility; herramienta «Luces» del editor); puertas de seguridad de dos hojas (`DungeonBuilder._door`: «Hoja»/«Izq»/«Der», vano invisible «Hueco» para el recuadro, consolas «ConsolaA/B» con `set_door_lock` rojo/verde que refresca `DungeonExplorer.update_door_locks`; `front()` de una puerta trae `console`, que `DungeonScreen` recuadra al pasar el cursor; hackear aún sin dispositivo); estilo visual (`DungeonLook`: normal/PS2/PS1 con `stretch_shrink` del SubViewportContainer, filtrado de texturas por `DungeonBuilder.texture_filter`, niebla y brillo; tecla V; el recuadro del objetivo se escala por `stretch_shrink`) | Compartido por el juego y el editor. Los GLB se reducen con `tools/modelos/reducir_glb.py` (texturas a 1024). |
| `src/screens/dungeon/` | `DungeonScreen`: incursión con PV/PM persistentes (`Battle.party_vitals`/`set_party_vitals`, `CombatView.setup(..., vitals)`), habilidades y objetos fuera del combate (`Battle.field_use_skill`/`field_use_item`, `is_field_skill`) y extracción (`DungeonMap.EXTRACTION`, `is_extraction`; salir fuera de una zona deshace lo ganado desde la entrada o el último punto de guardado con `_lose_run`; `_mark_run_start` marca lo que queda a salvo). Objetos: `ItemDB.restores`/`is_attack`/`roll_loot`; cajas (`ItemDB.is_box`, `loot_always` + `loot`) van al inventario y se abren con `GameState.open_box` (al cogerlas, «Abrir ya / Guardar»; también desde el inventario del móvil). Resonador con cargas por incursión (`ItemDB.charges`, `DungeonScreen._charges`; baterías `bateria`). No guardar la partida a mitad de incursión. | `ConfirmPopup` (`src/ui/components/`) para confirmaciones con el estilo del juego. |
| `src/data/chapter_db.gd` (planes) | `PLANS` (condiciones `phase`, `before_phase`, `min_day`, `days_after_phase`; `investigacion_colinas` = fase 4, pasa a `grieta`) con `invite` {from, text, via mensaje\|persona, at, text_late} y `missed_text`; `MORNINGS` (escena con Mamá tras el despertar de los días 4, 6 y 7), `REN_ACTIVITIES` (lo que Ren puede proponer), `REN_MISSED_TEXT` y `MESSAGES` (mensajes sueltos por día y franja, con `if`/`unless` de flag; o `phase` + `phase_day` = días después de empezar una fase) | Los textos de invitación y reproche viven aquí (llegan como mensajes); lo que se dice en persona o al contestar va en el `.dialogue` (`<id>_movil_plan`, `<id>_movil_plantado`, `<id>_hablar_invita_<plan>`, `<id>_hablar_plantado_<plan>`; de los planes de Ren: `<id>_quedar`, `<id>_quedada`, `<id>_hablar_plantado` y `quedada_<actividad>` en general). |
| `src/data/location_db.gd` | Ubicaciones. `from_phase` = cambios desde una fase (Colinas con la grieta: `desc`, fondo `backdrop` → `assets/backgrounds/plaza_grieta[_franja]`, `rift` = acción «La grieta», tecla G, cue `grieta_mirar`; la entrada a la mazmorra llega en la fase 6). `cast_when` = alguien solo está a ciertas franjas o desde un día (Mamá en casa por la mañana y la noche desde el día 4). `CharacterDB` `talk_only` = en el menú solo «Hablar» (Mamá) | |
| `src/map3d/` | Mapa 3D de Leganés (`CityBuilder`, `CityMap`, `MapConfig`). `MapConfig` guarda también nombres, descripciones y `capacity` (personajes a la vez) de las ubicaciones editadas | Datos OSM en `assets/map/` (ODbL, mantener el crédito). |
| `src/screens/` | Pantallas: `title`, `world` (escenario, conversación, combate, móvil), `dungeon` | En `world_screen`, los objetos (`Props`) y personajes (`Scenario`) van dentro de `Backdrop`: muestra u oculta con `_fade_room` (todo) y `_fade_cast` (solo personajes), nunca tocando `modulate` a mano. |
| `src/ui/` | `UIStyle` (paleta, fuentes, dibujo), `UIIcons`, `components/`, `shaders/` | Reutilizar componentes y `UIStyle` antes de crear estilos nuevos. |
| `src/rooms/` | Escenas `layout` de cada lugar (casa, cloacas, lago): sitio de los objetos y de las poses de personajes sobre el fondo (`RoomLayout`) | Poses en `assets/escenas/<lugar>/<personaje>.png` (`LocationDB.pose`); en `world_screen` van en `Scenario` como los demás personajes. Las del lago (`lago`, «Westlake») se recortaron de una ilustración de grupo con la segmentación de personas de macOS (Vision) y cortes a mano, y se llevaron al encuadre del fondo vacío (`assets/backgrounds/lago.png`) con una homografía: si se rehacen, el fondo y las poses deben seguir en el mismo encuadre. |
| `src/tools/` | **Herramientas que corren en Godot**: `texture_studio`, `editor_mazmorras` (vive en su rama, ver «Herramientas en ramas»), `editor_relieve`, `editor_mapa`; y `editor_dialogos/paridad.tscn` (prueba, no herramienta de usuario) | Se abren con F6 o desde el menú de inicio (solo desde el editor). Guardan dentro del proyecto. `editor_mapa` también pone los fondos de cada ubicación (copia a `assets/backgrounds/<id>[_<franja>]`; `LocationBackdrop` los lee sin importar si se ejecuta desde el editor). |
| `tools/` | Scripts **externos** (Python, Node, git…). `tools/assets/organizar.sh`: copia ordenada de las imágenes en `~/Documents/assets-game` del usuario (Personajes, Enemigos/<tipo>, Ubicaciones/<lugar>/<momento>) | Tiene `.gdignore`: Godot no lo ve. No poner escenas aquí. Si cambias nombres o rutas de imágenes, el organizador las clasifica por las convenciones del README. |
| `docs/editor-dialogos/` | **Editor de diálogos web** (HTML + JS, funciona en el móvil). Vive en su rama (ver «Herramientas en ramas») y se publica con la pipeline | `motor.js` replica el selector de `Story`: ver «Paridad». |
| `assets/` | Fuentes, retratos, fondos, texturas `textures/<tema>/<superficie>/`, mapa, móvil | Medidas de texturas en `src/data/texture_formats.gd`. Fondos `backgrounds/<id>.png` y, por franja, `<id>_<franja>.png` (`LocationBackdrop`). |
| `docs/` | Diseño, referencias de UI, capturas | Tiene `.gdignore`. |

## Documentos de diseño (`docs/diseno/`)

Léelos antes de tocar su área. Distinguen lo **[DEFINIDO]** de las propuestas y
lo **[PENDIENTE]**: no conviertas valores tentativos ni ideas abiertas en reglas
definitivas sin preguntar.

| Documento | Cuándo leerlo |
|---|---|
| `sistema_de_naturalezas_y_asimilacion_parte_1.md` | Naturalezas, subtipos, asimilación, compatibilidad de efectos. |
| `habilidades_1.md` | Habilidades, fórmulas de nivel 1–60, `SkillDB`. Cita `inicio_y_progresion_de_la_historia.md`, que **no está en el repo**. |
| `habilidades_tiers.md` | Las 32 habilidades por tipo (PSY, ARQ, BIO, CYBER, MECH) con tier 1–5, escalado por nivel, límites de acumulación y pruebas obligatorias. Efectos sincronizados con la tabla del usuario; números pendientes de prueba de combate. |
| `capitulo_1_hoja_de_ruta.md` | **Plan del capítulo 1** (roadmap del usuario): arco, calendario, fases de trabajo con lo que hay y lo que falta, arquitectura prevista (sucesos de guion, desbloqueos, grupo de 4, entrenamiento semanal, tienda, captura) y decisiones abiertas. Léelo antes de tocar historia o progresión, y marca lo que se haga. |
| `experiencia_y_niveles.md` | Progresión: curva de EXP, EXP por combate y exploración, crecimiento de atributos y nivel de las criaturas por zona (`ProgressionDB`, `GameState.levels`). Casi todo es [PROPUESTA] con valores provisionales. |
| `personajes_y_relaciones.md` | Fichas, relaciones, ánimo, cansancio, reglas `# cuando:` de los diálogos. |
| `Diseno_Dungeon_Crawler_Godot.md` | Mazmorras: movimiento por casillas, bordes, puertas, texturas, editor. |

Referencias visuales de interfaz en `docs/ui/referencias/` (combate, mapa,
conversación, estado, escenario, móvil…). La estética: grafito oscuro, lima
`#c6f432`, violeta `#9b5cf0`, cursivas, paralelogramos «/», marcas «///» y
líneas finas con quiebro (ver «Guía de estilo» del README).

El usuario guarda material de referencia local en `/context/` y `/refs/`
(ignorados por git): si te lo pasa, no lo subas.

## Herramientas en ramas y publicación (móvil, sin Godot ni PC)

- Cada herramienta con versión web vive **sola** en su rama:
  `herramientas/editor-dialogos` (`docs/editor-dialogos/`),
  `herramientas/editor-mazmorras` (`src/tools/editor_mazmorras/`) y
  `herramientas/captura-movimiento` (`tools/captura-movimiento/`). En `main`
  esas carpetas están en `.gitignore`.
- **Captura de movimiento** (`tools/captura-movimiento/`): app web en
  TypeScript + React + three.js + MediaPipe Holistic, basada en
  [MotionBridge](https://github.com/adonisglobal/motionbridge) (MIT: conservar
  `LICENSE` y `THIRD_PARTY_NOTICES.md`). Vídeo del móvil (grabar o galería) →
  esqueleto 3D → modelo `.glb`/`.fbx` con su esqueleto o con **rig automático**
  (`src/character3d/autorig.ts`: esqueleto estimado por la forma, pesos por
  distancia a los huesos, articulaciones editables en el modo «Esqueleto» de
  `src/ui3d/CharacterPreview3D.tsx`) → GLB animado para Godot. Solo el espacio
  3D de MotionBridge (`src/app/Workspace.tsx`). En local: `npm ci
  --ignore-scripts`, `npm run setup:assets`, `npm test`, `npm run dev`
  (`node_modules`, `dist` y el modelo no se suben; `EXCLUIR` en `lista.sh`).
  Dependencias revisadas (`npm audit` limpio, todo del registro de npm con
  integridad): si se añaden, revisarlas igual y no ejecutar scripts de
  instalación. La publicación la compila con Node 24 y pasa sus pruebas.
- **No se tocan en `main`**. Para tenerlas en local: `tools/herramientas/traer.sh`
  (no pisa cambios locales sin `--forzar`). Para subir cambios hechos en local:
  `tools/herramientas/llevar.sh <herramienta> "mensaje"` (commit y push a su
  rama desde una copia aparte; la rama no tiene CLAUDE.md: si el cambio afecta
  al contexto, actualiza este archivo en `main`). Lista en `tools/herramientas/lista.sh`.
- **Publicación** (`.github/workflows/publicar.yml`, al subir a `main` o, con
  `avisar.yml` de cada rama, al subir a una herramienta): junta cada
  herramienta con el código y los datos de `main`, regenera las miniaturas de
  las caras, exporta el editor de mazmorras a web con Godot 4.7 (preset
  `tools/herramientas/editor_mazmorras_web.cfg`, escena principal cambiada solo
  en la nube, ETC2/ASTC) y publica en GitHub Pages: `/` (portada
  `docs/index.html` y el resto de `docs/` de main), `/editor-dialogos/`,
  `/editor-mazmorras/`. Un trabajo aparte pasa la prueba de paridad (avisa, no
  frena). Requiere Pages con *Source: GitHub Actions*.
- **Datos**: los editores web leen y guardan directamente en `main` con la API
  de GitHub (un commit por guardado, con `[contexto-ok]`; mismo token en el
  navegador para los dos: `localStorage` «editor-dialogos:token»). El editor de
  mazmorras web usa `GithubStore` (`src/tools/editor_mazmorras/github_store.gd`
  en su rama): sin Estudio de texturas ni relieve; con barra táctil (Borrar =
  clic derecho, Mover plano, zoom, Deshacer) y cruceta al probar.
- Antes de trabajar en `main`, `git pull`: los guardados desde el móvil son commits en `main`.

## Comandos de escena (puesta en escena desde el diálogo)

`Story.fondo(id)` (otro fondo mientras dura la conversación; `""` vuelve al
del sitio), `Story.entra(id)` / `Story.sale(id)` (retrato de la derecha),
`Story.efecto(nombre)` (`Story.SCENE_EFFECTS`: temblor, destello, negro, vuelve)
y `Story.esperar(seg)`. Se escriben como `$> Story.efecto("temblor")` en los
`.dialogue` y Dialogue Manager espera a que terminen. Los ejecuta `Story.stage`
(WorldScreen se registra en `_ready`: `scene_background`, `scene_enter`,
`scene_leave`, `scene_effect`; `ConversationView.stage_enter/stage_leave`; el
fondo vuelve al cerrarse la vista, señal `closed`). Sin `stage` (mazmorra) no
hacen nada. Las incursiones ya tiemblan así (`temblor`, `incursion_2_aparece`).
Pon la puesta en escena en el diálogo, no en código: el editor de escenas la
muestra como bloques. Si añades un efecto, añádelo a `SCENE_EFFECTS` y a
`WorldScreen.scene_effect` (el editor lee la lista de `story.gd`).

## Editor de escenas (web) y paridad con el juego

El antiguo editor de diálogos (misma carpeta y rama) ahora es el **editor de
escenas**: lista con títulos legibles (`# titulo: …` en el cue, que solo usa
el editor: `motor.parseFile` lo lee en `cue.title`; si no hay, `humanize` del
nombre interno), agrupada por días y por tipo; pantalla de escena con
«Cuándo sale» en una frase, bloques (diagrama + barra para añadir líneas,
respuestas y comandos de escena) y «Avanzado» con lo técnico; y **▶ Ver
escena** (`openPlayer`, recorre el cue con `walkScene` y pinta fondos de
`assets/backgrounds`, retratos y efectos desde raw.githubusercontent).

`docs/editor-dialogos/` es una app web de una página (móvil y escritorio) que
lee los `.dialogue` de GitHub, edita las reglas `# cuando:` y el texto, simula
qué cue elige el juego y guarda en `main` con un commit (token de GitHub del
usuario, guardado solo en su navegador; el mensaje lleva `[contexto-ok]`).

- `motor.js` es una **réplica exacta** del selector de `src/autoload/story.gd`
  (`candidates`, `_check`, `_score`, `_parse_criterion`) y lee fases, ánimos,
  tramos, dimensiones, pesos y personajes del propio código (`game_state.gd`,
  `social.gd`, `story.gd`, `character_db.gd`): si cambias esas constantes, el
  editor las recoge solo.
- **Si cambias cómo elige Story** (condiciones, pesos, desempates, sintaxis de
  `# cuando:`), cambia `motor.js` igual y pasa la prueba de paridad, que
  compara ambos en cientos de situaciones al azar:
  ```bash
  GODOT=/ruta/a/godot tools/editor_dialogos/paridad.sh 1000
  ```
  Debe terminar en «diferencias: 0». Funciona también en macOS (usa `timeout`
  solo si existe). El lado Godot es la escena
  `src/tools/editor_dialogos/paridad.tscn` (escena y no `-s`, para que existan
  los autoloads).
- `motor.parseFile`/`serializeFile` reescriben solo los cues editados: un
  archivo sin cambios sale idéntico byte a byte.
- **Menciones**: `#alude=<id>` (o `id|id`) en una opción de Ren hace que el
  mencionado, si está presente, reaccione con peso completo
  (`Social.on_choice`, `Social.MENTION_TAG`; se lee en
  `ConversationView._choices_from`). Las réplicas del aludido van en bloques
  `if Story.present("<id>")`. Ver `personajes_y_relaciones.md`.
- **Opciones con condición** (Dialogue Manager): `- Texto [#tags] [if Story.has_conflict("plan") /]`
  solo sale si se cumple. `flujo.js` la separa en `cond` y el formulario de
  opción del editor la muestra como «Solo sale si…».
- **Opciones por persona**: `[#persona, #afecto>=15, ...]` + `{persona}` en el
  texto repite la opción por cada personaje con ficha que cumple los filtros
  (`Social.person_candidates`; excluye a Ren, a quien pregunta y al
  interlocutor). `Story.persona` guarda la elegida. El editor web replica los
  filtros en `personCandidates` (app.js): si cambias unos, cambia los otros.
  Las fichas tienen `identity.gender`, `identity.generation` y, las madres,
  `identity.age` (Mamá 41, madre de Kenji 44).
- `flujo.js` convierte el texto de un cue en un árbol por sangría (líneas,
  opciones `- `, variantes `%`, `if`, `$>`, `=>`) para el diagrama editable de
  la conversación, y lo reescribe cambiando solo las líneas editadas. Los 423
  cues actuales se reconstruyen idénticos; si añades sintaxis nueva de
  Dialogue Manager a los diálogos, comprueba que `Flujo.kind` la reconoce.

## Depuración en el juego

`DebugRelations` (`src/screens/world/debug_relations.gd`): en la app Relaciones
del móvil, tocar a un personaje abre barras para editar sus relaciones (hacia Ren
u otro) y su ánimo en directo. Solo con `OS.is_debug_build()` (editor o
exportación con depuración); al cerrar guarda la partida.

## Gestos de los retratos

`CharacterDB` `faces` = retratos alternativos (`<id>_<gesto>.png`); `ConversationView`
elige cara por etiqueta de línea `[#cara=…]`, reacción a la opción
(`Social.on_choice` devuelve los cambios por persona; `Social.displeasure`) o
ánimo (`MOOD_FACES`), y `CharacterSprite.change_texture` hace la transición.
Ren no tiene gestos (decisión del usuario, por ahora). Los personajes con gestos
hoy son Kenji, Shiori, Akane, Rika (enfado, sorpresa) y Yuna (enfado, incomodo).
`CharacterDB.preload_faces` los carga en segundo plano al aparecer en la charla.

En el editor web: `motor.js` lee `portrait`/`faces` de `character_db.gd` y
`FACES`/`FACE_TAG` de `conversation_view.gd`; el formulario de línea tiene un
selector de gesto con miniaturas de `docs/editor-dialogos/caras/`. Las genera
la publicación con `tools/editor_dialogos/miniaturas.sh` (en local, solo para
ver caras nuevas en el editor sin publicar). Las funciones de `Story` que valida el editor
también se leen de `story.gd` (`cfg.storyApi`): no hay lista a mano.

## Combate

- `SkillDB` (datos y fórmulas) + `Battle` (lógica, devuelve eventos) + `CombatView` (anima). Las habilidades son declarativas: `ops` (`damage`, `heal`, `status`, `self_damage`, `recover_pm`, `cleanse`, `reveal`) y los estados (`SkillDB.STATUSES`) llevan banderas y valores por aplicación. Si añades una habilidad, usa esas piezas antes de tocar `Battle`.
- Todo se calcula por fórmula para el nivel exacto (1..60): PV, PM, daño, curación, coste y valores escalables `[base, cada, paso]`. **Todos empiezan en el nivel 1** (decisión del usuario) y suben con EXP (`ProgressionDB`, `GameState.level_of`/`grant_xp`; ver `experiencia_y_niveles.md`). Los atributos de las fichas son los de nivel 1 y crecen con `ProgressionDB.stats_at` (referencia `10 + floor((L−1)/2)`, multiplicada por atributo con `combat.growth` de cada ficha: Yuna, taekwondo, FUE y AGI ×1,6; Shiori INT ×1,8…). **Ren** (`growth: "random"`) es equilibrado (11 en todo) y gana 2 puntos al azar por nivel (`levels[id].gains`, `GameState._roll_gains`) más lo entrenado (`GameState.stat_bonus`, fase de preparación); `Battle._make_fighter` suma `GameState.stat_extras`; las criaturas toman el nivel de la zona (`Battle.new(..., enemy_level)`, `DungeonMap.creature_level`).
- Vista: cada golpe se anima según su tipo con `AttackFx` (naturaleza de la habilidad, o la de la criatura en su ataque básico; «fisico» para el básico del grupo). Si añades una naturaleza, añade su dibujo ahí. Los estados se marcan con `StatusBadges` (color por `origin` del estado) en `EnemyPlate.statuses` y `CombatantCard.statuses`, que rellena `CombatView._update_status_tags`.
- **Pantallas anchas y táctil**: `DungeonScreen` y `CombatView` se maquetan sobre 1920×1080 y reparten el ancho de más (`_extra`, `_layout` al cambiar de tamaño): el visor crece, la columna derecha y la cabecera se pegan al borde. `App.is_touch()` (y `App.force_touch` para probar) muestra la cruceta de la mazmorra y quita la línea de teclas; en combate, elegir rival es `State.TARGET` con el marco lima (`_start_targeting`, `_set_target`, `_confirm_target`, `_draw_target`; rectángulo opaco con `CharacterSprite.content_rect`): un toque en un rival lo marca y otro en el marcado confirma; ningún toque actúa solo (los comandos siempre abren su fila de opciones).
- **Hasta 3 rivales** (`Battle.FOES` = `enemy`/`enemy2`/`enemy3`, `Battle.is_enemy`, `alive_foes`, `enemy_turn(who)` + `end_round`; `Battle.new(..., ids, ..., enemy_level, boss)`; `CombatView.setup(ids, ...)` los pone en fila con `_layout_foes` y pide objetivo con `_show_foe_targets`). En la mazmorra, la cosa del mapa lleva `group` (escolta) y `boss`.
- **Tiers de criaturas**: `combat.tier` en la ficha y `CharacterDB.ENEMY_TIERS` (PV, atributos, daño), `BOSS_PV_MULT`, `GROUP_SCALE` (menos PV y daño por criatura en grupo). Las habilidades de una criatura son de su tier o menos (las básicas sin tier = tier 1). Tier 2: Oni y Tiranosaurio. Ajustados con combates simulados a petición del usuario; si los tocas, vuelve a simular.
- Compatibilidad por etiquetas (`SkillDB.NATURE_TAGS`, o `combat.tags`): se comprueba antes que la probabilidad.
- Turnos: la vista llama a `Battle.start_turn(who)` antes de cada actuación (pierde el turno o acción forzada). Los estados puestos sobre quien actúa no cuentan su turno de uso (`fresh`).
- Comprobación (no balance): muestras N1/N20/N40/N60 y costes del documento contra `SkillDB`, reglas de la sección 4.C y combates al azar para ver que nada se rompe. No ajustes números por simulación sin que el usuario lo pida.

## Exportar (APK y web) y rama `pruebas-movil`

- Godot no exporta el archivo original de un recurso importado: los `.dialogue`
  viajarían solo compilados, sin las reglas `# cuando:`. El complemento
  `addons/incursion_export` (activado en `project.godot`) añade su texto al
  paquete. No lo quites o, en una versión exportada, no saldrá ninguna
  conversación del selector.
- La rama **`pruebas-movil`** tiene lo necesario para móvil: cruceta táctil en
  la mazmorra (`App.is_touch()`), «atrás» de Android = Esc, orientación
  horizontal, ETC2/ASTC y `export_presets.cfg` (Android arm64 sin Gradle y Web
  sin hilos, con aviso de «gira el móvil»). Firma por variables de entorno
  (`GODOT_ANDROID_KEYSTORE_RELEASE_*`), nunca claves en el repo.
- Publicación: la web exportada va en `docs/pruebas/web/` de `main` (la
  pipeline de Pages publica `main/docs` tal cual). **La APK no se sube al repositorio** (ni a la
  rama ni a `main`): se genera y se le pasa al usuario directamente (el
  usuario pidió borrar del historial la que se subió). Página:
  `docs/pruebas/index.html`. Cada exportación web nueva pesa ~85 MB en el
  historial: no la regeneres sin necesidad.
- En la nube no hay SDK de Android de Google: basta un SDK mínimo con `adb`,
  `apksigner` y `zipalign` de apt (`platform-tools/`, `build-tools/35.0.0/`)
  y las plantillas de 4.7 en `~/.local/share/godot/export_templates/4.7.stable/`.

## Cómo probar los cambios

- **En la nube (Linux)**: descarga Godot 4.7 si no está (`https://github.com/godotengine/godot/releases/download/4.7-stable/Godot_v4.7-stable_linux.x86_64.zip`) en el scratchpad, no en el repo.
  - `godot --headless --import` (dos veces si hay recursos nuevos: la primera puede dar errores de fuentes que desaparecen).
  - `godot --headless --quit-after 200` para ver errores de arranque.
  - Para ver la interfaz: `xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 -s <script>.gd`, con un `SceneTree` que cargue la escena, simule entrada (`Input.parse_input_event`) y guarde capturas (`root.get_texture().get_image().save_png`). Revisa las capturas antes de dar algo por bueno.
- No dejes archivos de prueba en el repo (texturas de prueba, partidas, capturas sueltas). Las capturas para el README van en `docs/capturas/` en `.webp`.
- Si un cambio afecta a lo jugable o a una herramienta, actualiza también el **README**.

## Git

- Rama principal `main`. Mensajes de commit en español, con un resumen y viñetas.
- El usuario también sube desde su Mac: antes de empezar, `git pull` (o `fetch` + rebase) para no trabajar sobre una versión vieja; si hay conflictos, conserva su trabajo.
- Hooks de git versionados en `.githooks/`. **Actívalos una vez en cada copia nueva**:
  ```bash
  git config core.hooksPath .githooks
  ```

### Regla de contexto antes de subir

**No se sube nada al repositorio sin actualizar este CLAUDE.md con lo último.**
Un push se bloquea si los commits que se suben cambian archivos y ninguno
modifica `CLAUDE.md`. Lo comprueba `tools/git/check_context.sh`, que se ejecuta:

- en Claude Code, con el hook `.claude/hooks/check_context_before_push.sh` (configurado en `.claude/settings.json`, se activa solo);
- en los push manuales, con `.githooks/pre-push` (si se activó `core.hooksPath`).

Qué actualizar: carpetas, sistemas, herramientas o escenas nuevas; cambios de
convenciones, versiones, autoloads o acciones de entrada; documentos de diseño
nuevos; cualquier cosa que una sesión nueva necesite saber para no equivocarse.

Si el cambio de verdad no afecta al contexto (un arreglo puntual, un texto),
añade **`[contexto-ok]`** al mensaje de un commit. No uses `--no-verify` ni
desactives los hooks para saltarte la regla.

## Estado y pendientes (resumen)

Hecho: editor de diálogos web (también móvil), capítulo 1 (día guiado, días 2-4 y fin de semana 5-7 con planes opcionales; Ren también propone planes a quien quiera (*Quedar* / *Proponer plan*); planes opcionales en `ChapterDB.PLANS`: se proponen en persona o por mensaje, se contestan, se juegan al llegar al sitio en su franja y, si dices que sí y no vas, te lo reprochan; el jueves coinciden planes y hay que elegir, con desayuno y cena con Mamá, que desde ese día está en casa por la mañana y por la noche; fases `rutina` → `incursion_1` → `reunion` tras la reunión en las Cloacas, y después `incursion_2` … `jefe_1`, ya declaradas pero sin contenido (ver `capitulo_1_hoja_de_ruta.md`); `flag dia_N` en las reglas; `GameState.scene_cast` = presentes en un plan), mundo libre, conversaciones con reglas,
relaciones y ánimo, móvil, combate en grupo con 42 habilidades (tiers, escalado
por nivel, estados y compatibilidades; todos en nivel 1), criaturas y
recompensas, guardado automático, mapa 3D con luz por franjas, mazmorra de La
Torre (cinco plantas de 260-300 casillas, encuentros de 1 a 3 criaturas por tiers con un Oni en la planta 2 y el Tiranosaurio de jefe en la 4, muros con grosor, palancas, puertas con tarjeta, paredes
secretas, compañero con comentarios),
editores de mazmorras, relieve, mapa y Estudio de texturas.

Pendiente: el resto del capítulo 1, por fases en `docs/diseno/capitulo_1_hoja_de_ruta.md`; opciones, misiones y criaturas del móvil, asimilación y naturalezas
completas, equipo con efecto en combate, fondos y mapas definitivos. El detalle
está en el README («Pendiente»).
