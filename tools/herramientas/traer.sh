#!/usr/bin/env bash
# Trae a esta copia de main las herramientas que viven en su propia rama
# (herramientas/*), ignoradas por git: el editor de mazmorras, para abrirlo en
# Godot, y el editor de diálogos web, para la prueba de paridad o abrirlo en local.
# Si la copia local tiene cambios que no están en la rama, no la pisa (usa
# llevar.sh para subirlos, o --forzar para descartarlos).
# Uso: tools/herramientas/traer.sh [--forzar]
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
. tools/herramientas/lista.sh
forzar=${1:-}
for h in "${HERRAMIENTAS[@]}"; do
	rama=$(rama_de "$h"); dir=$(carpeta_de "$h")
	git fetch -q origin "$rama"
	tmp=$(mktemp -d)
	git archive "origin/$rama" "$dir" | tar -x -C "$tmp"
	if [ -d "$dir" ] && [ "$forzar" != "--forzar" ] && ! diff -rq -x .DS_Store -x node_modules -x dist -x mediapipe -x "*.task" "$tmp/$dir" "$dir" >/dev/null; then
		echo "$dir tiene cambios que no están en $rama: no se toca (llevar.sh para subirlos, --forzar para descartarlos)."
		diff -rq -x .DS_Store -x node_modules -x dist -x mediapipe -x "*.task" "$tmp/$dir" "$dir" | sed 's/^/  /' | head -10
	else
		# Conserva lo generado en local (node_modules, dist…): solo se sustituye lo versionado.
		mkdir -p "$dir"
		rsync -a --delete "${EXCLUIR[@]}" "$tmp/$dir/" "$dir/"
		echo "$dir ← $rama"
	fi
	rm -rf "$tmp"
done
