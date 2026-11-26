# Herramienta: editor de diálogos (web)

Rama con **solo** el editor de diálogos web (`docs/editor-dialogos/`) de
*Incursion From Beyond*. El juego y los diálogos viven en `main`.

- Se publica con el resto de herramientas desde `main`
  (`.github/workflows/publicar.yml`) en
  `https://pochico.github.io/incursion-from-beyond-jrpg/editor-dialogos/`.
  Las miniaturas de las caras (`caras/`) las regenera la publicación con
  `tools/editor_dialogos/miniaturas.sh` de `main`.
- Lee y guarda los `.dialogue` de `main` con la API de GitHub.
- `motor.js` replica el selector de `Story` del juego: la publicación pasa la
  prueba de paridad (`tools/editor_dialogos/paridad.sh` de `main`) en cada
  cambio.
- Para tenerlo en local: `tools/herramientas/traer.sh` (en `main`). Para subir
  cambios: `tools/herramientas/llevar.sh editor-dialogos "mensaje"`.
- Al subir a esta rama, `avisar.yml` relanza la publicación.
