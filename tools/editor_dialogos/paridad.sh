#!/usr/bin/env bash
# Comprueba que el editor de diálogos (docs/editor-dialogos/motor.js, de la rama
# herramientas/editor-dialogos; tools/herramientas/traer.sh lo trae) elige
# exactamente los mismos diálogos que el juego (Story.candidates).
# Uso: tools/editor_dialogos/paridad.sh [N_CASOS] [SEMILLA]
# Necesita node y Godot 4.7 (variable GODOT o «godot» en el PATH).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
GODOT="${GODOT:-godot}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
d=tools/editor_dialogos
# macOS no trae «timeout» (con Homebrew coreutils es «gtimeout»).
LIMIT=$(command -v timeout || command -v gtimeout || true)
[ -n "$LIMIT" ] && LIMIT="$LIMIT 300"
[ -f docs/editor-dialogos/motor.js ] || { echo "Falta el editor de diálogos (vive en la rama herramientas/editor-dialogos): tools/herramientas/traer.sh"; exit 2; }
node $d/paridad.mjs generar "${1:-400}" "${2:-7}" > "$tmp/casos.json"
node $d/paridad.mjs evaluar "$tmp/casos.json" > "$tmp/js.json"
$LIMIT "$GODOT" --headless --path . res://src/tools/editor_dialogos/paridad.tscn -- "$tmp/casos.json" "$tmp/godot.json" > "$tmp/godot.log" 2>&1 || true
[ -s "$tmp/godot.json" ] || { echo "Godot no produjo resultados:"; tail -20 "$tmp/godot.log"; exit 2; }
node $d/paridad.mjs comparar "$tmp/js.json" "$tmp/godot.json"
