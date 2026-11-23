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

## Dónde va cada cosa

| Carpeta | Contenido | Reglas |
|---|---|---|
| `src/autoload/` | Singletons | Estado global en `GameState` (guardado en `user://partida.json`). |
| `src/data/` | Datos sin lógica: `*_db.gd`, fichas `characters/<id>.json`, `mazmorras/*.json`, `mapa3d.json` | Valores de balance **provisionales**; centralizados aquí, no repartidos por el código. |
| `src/dialogue/` | Diálogos `.dialogue` (uno por personaje + `general` + `capitulo1`) | Cada conversación con su regla `# cuando:` (ver `docs/diseno/personajes_y_relaciones.md`). |
| `src/systems/` | Lógica sin interfaz (`battle.gd`, `social.gd`, `event_log.gd`) | Devuelven datos/eventos; la vista los anima. No mezclar UI aquí. |
| `src/dungeon/` | Mazmorras: `DungeonMap`, `DungeonBuilder`, `DungeonExplorer`, `DungeonTextures` | Compartido por el juego y el editor. |
| `src/map3d/` | Mapa 3D de Leganés (`CityBuilder`, `CityMap`, `MapConfig`) | Datos OSM en `assets/map/` (ODbL, mantener el crédito). |
| `src/screens/` | Pantallas: `title`, `world` (escenario, conversación, combate, móvil), `dungeon` | |
| `src/ui/` | `UIStyle` (paleta, fuentes, dibujo), `UIIcons`, `components/`, `shaders/` | Reutilizar componentes y `UIStyle` antes de crear estilos nuevos. |
| `src/rooms/` | Distribución de habitaciones interactivas (casa) | |
| `src/tools/` | **Herramientas que corren en Godot**: `texture_studio`, `editor_mazmorras`, `editor_relieve`, `editor_mapa`; y `editor_dialogos/paridad.tscn` (prueba, no herramienta de usuario) | Se abren con F6 o desde el menú de inicio (solo desde el editor). Guardan dentro del proyecto. |
| `tools/` | Scripts **externos** (Python, Node, git…) | Tiene `.gdignore`: Godot no lo ve. No poner escenas aquí. |
| `docs/editor-dialogos/` | **Editor de diálogos web** (HTML + JS, funciona en el móvil). Se publica con GitHub Pages desde `docs/` | `motor.js` replica el selector de `Story`: ver «Paridad». |
| `assets/` | Fuentes, retratos, fondos, texturas `textures/<tema>/<superficie>/`, mapa, móvil | Medidas de texturas en `src/data/texture_formats.gd`. |
| `docs/` | Diseño, referencias de UI, capturas | Tiene `.gdignore`. |

## Documentos de diseño (`docs/diseno/`)

Léelos antes de tocar su área. Distinguen lo **[DEFINIDO]** de las propuestas y
lo **[PENDIENTE]**: no conviertas valores tentativos ni ideas abiertas en reglas
definitivas sin preguntar.

| Documento | Cuándo leerlo |
|---|---|
| `sistema_de_naturalezas_y_asimilacion_parte_1.md` | Naturalezas, subtipos, asimilación, compatibilidad de efectos. |
| `habilidades_1.md` | Habilidades, fórmulas de nivel 1–60, `SkillDB`. Cita `inicio_y_progresion_de_la_historia.md`, que **no está en el repo**. |
| `personajes_y_relaciones.md` | Fichas, relaciones, ánimo, cansancio, reglas `# cuando:` de los diálogos. |
| `Diseno_Dungeon_Crawler_Godot.md` | Mazmorras: movimiento por casillas, bordes, puertas, texturas, editor. |

Referencias visuales de interfaz en `docs/ui/referencias/` (combate, mapa,
conversación, estado, escenario, móvil…). La estética: grafito oscuro, lima
`#c6f432`, violeta `#9b5cf0`, cursivas, paralelogramos «/», marcas «///» y
líneas finas con quiebro (ver «Guía de estilo» del README).

El usuario guarda material de referencia local en `/context/` y `/refs/`
(ignorados por git): si te lo pasa, no lo subas.

## Editor de diálogos (web) y paridad con el juego

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
  Debe terminar en «diferencias: 0». El lado Godot es la escena
  `src/tools/editor_dialogos/paridad.tscn` (escena y no `-s`, para que existan
  los autoloads).
- `motor.parseFile`/`serializeFile` reescriben solo los cues editados: un
  archivo sin cambios sale idéntico byte a byte.
- **Menciones**: `#alude=<id>` (o `id|id`) en una opción de Ren hace que el
  mencionado, si está presente, reaccione con peso completo
  (`Social.on_choice`, `Social.MENTION_TAG`; se lee en
  `ConversationView._choices_from`). Las réplicas del aludido van en bloques
  `if Story.present("<id>")`. Ver `personajes_y_relaciones.md`.
- **Opciones por persona**: `[#persona, #afecto>=15, ...]` + `{persona}` en el
  texto repite la opción por cada personaje con ficha que cumple los filtros
  (`Social.person_candidates`; excluye a Ren, a quien pregunta y al
  interlocutor). `Story.persona` guarda la elegida. El editor web replica los
  filtros en `personCandidates` (app.js): si cambias unos, cambia los otros.
  Las fichas tienen `identity.gender`, `identity.generation` y, las madres,
  `identity.age` (Mamá 41, madre de Kenji 44).
- `flujo.js` convierte el texto de un cue en un árbol por sangría (líneas,
  opciones `- `, variantes `%`, `if`, `$>`, `=>`) para el diagrama editable de
  la conversación, y lo reescribe cambiando solo las líneas editadas. Los 162
  cues actuales se reconstruyen idénticos; si añades sintaxis nueva de
  Dialogue Manager a los diálogos, comprueba que `Flujo.kind` la reconoce.

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
- Publicación: la web exportada va en `docs/pruebas/web/` de `main` (GitHub
  Pages solo sirve `main/docs`); la APK en `descargas/incursion.apk` de la rama
  `pruebas-movil` (esta sesión no puede crear *releases*). Página:
  `docs/pruebas/index.html`. Cada exportación nueva pesa ~85 MB (web) y ~64 MB
  (APK) en el historial: no las regeneres sin necesidad.
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

Hecho: editor de diálogos web (también móvil), capítulo 1 (día guiado), mundo libre, conversaciones con reglas,
relaciones y ánimo, móvil, combate en grupo con habilidades, criaturas y
recompensas, guardado automático, mapa 3D con luz por franjas, mazmorra de La
Torre (palancas, puertas con tarjeta, paredes secretas, plantas, compañero),
editores de mazmorras, relieve, mapa y Estudio de texturas.

Pendiente: opciones, misiones y criaturas del móvil, asimilación y naturalezas
completas, equipo con efecto en combate, fondos y mapas definitivos. El detalle
está en el README («Pendiente»).
