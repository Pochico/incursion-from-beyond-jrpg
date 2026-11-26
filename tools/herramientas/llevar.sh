#!/usr/bin/env bash
# Sube a su rama los cambios hechos en local a una herramienta (la copia que
# puso traer.sh): commit en herramientas/<herramienta> y push. La rama no tiene
# CLAUDE.md: si el cambio afecta al contexto del proyecto, actualízalo en main.
# Uso: tools/herramientas/llevar.sh editor-mazmorras|editor-dialogos "mensaje"
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
. tools/herramientas/lista.sh
h=${1:-}; msg=${2:-}
if [ -z "$msg" ] || [ -z "$(rama_de "$h")" ]; then
	echo "Uso: $0 <${HERRAMIENTAS[*]// /|}> \"mensaje\""; exit 1
fi
rama=$(rama_de "$h"); dir=$(carpeta_de "$h")
[ -d "$dir" ] || { echo "No hay $dir en local (tools/herramientas/traer.sh)."; exit 1; }
git fetch -q origin "$rama"
wt=$(mktemp -d)
git worktree add -q --detach "$wt" "origin/$rama"
trap 'git worktree remove --force "$wt"' EXIT
rsync -a --delete --exclude .DS_Store "$dir/" "$wt/$dir/"
git -C "$wt" add -A "$dir"
if git -C "$wt" diff --cached --quiet; then
	echo "Sin cambios respecto a $rama."; exit 0
fi
git -C "$wt" commit -q -m "$msg"
git -C "$wt" push -q origin "HEAD:$rama"
echo "Subido a $rama: se publicará en unos minutos."
