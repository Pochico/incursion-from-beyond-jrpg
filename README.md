# Herramienta: captura de movimiento (web)

Rama con **solo** la herramienta de captura de movimiento
(`tools/captura-movimiento/`) de *Incursion From Beyond*. El juego vive en `main`.

- Graba o elige un vídeo, saca el esqueleto del cuerpo con MediaPipe, lo aplica
  a un modelo 3D (con su esqueleto o con un rig automático editable) y exporta
  un GLB animado para Godot. Detalles en `tools/captura-movimiento/README.md`.
- Basada en [MotionBridge](https://github.com/adonisglobal/motionbridge) (MIT).
- Se publica con el resto de herramientas desde `main`
  (`.github/workflows/publicar.yml`, que la compila con Node) en
  `https://pochico.github.io/incursion-from-beyond-jrpg/captura-movimiento/`.
- Para tenerla en local: `tools/herramientas/traer.sh` (en `main`). Para subir
  cambios: `tools/herramientas/llevar.sh captura-movimiento "mensaje"`.
- Al subir a esta rama, `avisar.yml` relanza la publicación.
