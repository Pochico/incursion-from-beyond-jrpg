# Mapa 3D (Leganés)

`leganes.maps3d.json` es el proyecto guardado de maps3d.io: solo guarda el área,
las capas y los colores, no la geometría. La geometría sale de OpenStreetMap.

Para regenerar `assets/map/leganes.json`:

1. Descargar de Overpass los `way` de `building`, `highway`, `natural=water`,
   `leisure=park`, `landuse~grass|forest|recreation_ground` y `railway=rail`
   del rectángulo del proyecto (`params.areaSelected`), con `out geom;`.
   Si overpass-api.de está saturado, `https://overpass.private.coffee/api/interpreter`.
2. `python3 -I convert.py leganes.maps3d.json osm.json ../../assets/map/leganes.json`

Coordenadas: metros desde el centro del área; x = este, y = sur (el eje Z de Godot).

Datos © colaboradores de OpenStreetMap (ODbL): hay que acreditarlo en el juego.
