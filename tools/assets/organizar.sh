#!/bin/sh
# Organiza las imágenes del juego en ~/Documents/assets-game (ver organizar_assets.py).
exec python3 "$(dirname "$0")/organizar_assets.py" "$@"
