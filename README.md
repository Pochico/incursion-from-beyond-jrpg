# Herramienta: editor de mazmorras

Rama con **solo** el editor de mazmorras (`src/tools/editor_mazmorras/`) de
*Incursion From Beyond*. El juego y sus datos viven en `main`.

- **Web (móvil y escritorio)**: la publicación de `main`
  (`.github/workflows/publicar.yml`) junta esta carpeta con el código de `main`,
  exporta el editor con Godot para web y lo publica en
  `https://pochico.github.io/incursion-from-beyond-jrpg/editor-mazmorras/`.
  En web abre y guarda las mazmorras de `main` (`src/data/mazmorras/`) con la
  API de GitHub y el mismo token que el editor de diálogos (`GithubStore`).
- **En Godot (Mac)**: `tools/herramientas/traer.sh` (en `main`) copia esta
  carpeta al proyecto, ignorada por git. Para subir cambios del editor:
  `tools/herramientas/llevar.sh editor-mazmorras "mensaje"`.
- Al subir a esta rama, `avisar.yml` relanza la publicación.

No dejes aquí otra cosa que la herramienta: lo que comparte con el juego
(`src/dungeon/`, `CombatView`…) está en `main`.
