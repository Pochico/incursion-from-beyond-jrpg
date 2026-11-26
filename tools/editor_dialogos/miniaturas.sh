#!/usr/bin/env bash
# Regenera las miniaturas de las caras del editor de diálogos web
# (docs/editor-dialogos/caras/). La publicación (.github/workflows/publicar.yml)
# lo ejecuta sola: en local solo hace falta para ver el editor con caras nuevas.
# Uso: tools/editor_dialogos/miniaturas.sh   (variable GODOT o «godot» en el PATH)
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
"${GODOT:-godot}" --headless --path . --script tools/editor_dialogos/miniaturas.gd
