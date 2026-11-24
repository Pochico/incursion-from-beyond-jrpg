# Fondos de ubicación

Si existe `<id>.png`, `<id>.jpg` o `<id>.webp` (p. ej. `plaza.png`), se usa como fondo
de esa ubicación (escenario y conversación) a cualquier hora. Para una franja del día
concreta, `<id>_<franja>.png` (franjas: `manana`, `dia`, `tarde`, `noche`; p. ej.
`instituto_noche.png`) tiene prioridad en esa franja. Si no hay ninguno, se genera un
fondo provisional por código (`src/screens/world/location_backdrop.gd`).

Ids actuales: ver `src/data/location_db.gd`. Resolución recomendada: 1920×1080.
Copia organizada fuera del proyecto: `tools/assets/organizar.sh` (ver README).
