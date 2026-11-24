#!/usr/bin/env bash
# Regenera las miniaturas de las caras del editor de diálogos web
# (docs/editor-dialogos/caras/). Ejecútalo al añadir retratos o gestos.
# Uso: tools/editor_dialogos/miniaturas.sh   (variable GODOT o «godot» en el PATH)
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
"${GODOT:-godot}" --headless --path . --script tools/editor_dialogos/miniaturas.gd
