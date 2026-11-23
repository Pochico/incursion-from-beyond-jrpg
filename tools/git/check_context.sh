#!/usr/bin/env bash
# Comprueba que el contexto del proyecto (CLAUDE.md) se ha actualizado en los
# commits que se van a subir.
#
# Uso: tools/git/check_context.sh [BASE] [HEAD]
#   BASE: lo que ya hay en el remoto (por defecto, origin/main).
#   HEAD: lo que se va a subir (por defecto, HEAD).
#
# Pasa si:
#   - no hay commits nuevos, o no cambian ningún archivo;
#   - alguno de los commits nuevos modifica CLAUDE.md;
#   - algún mensaje de los commits nuevos contiene [contexto-ok]
#     (revisado: el cambio no afecta al contexto).
# Si no, falla (código 1) y explica qué hacer.

set -u
ZERO=0000000000000000000000000000000000000000
base="${1:-}"
head="${2:-HEAD}"

if [ -z "$base" ] || [ "$base" = "$ZERO" ]; then
	base=$(git rev-parse -q --verify origin/main 2>/dev/null) || {
		echo "check_context: no hay referencia remota con la que comparar; se omite la comprobación." >&2
		exit 0
	}
fi

# Commits que se van a subir.
if [ -z "$(git rev-list "$base..$head" 2>/dev/null)" ]; then
	exit 0
fi

from=$(git merge-base "$base" "$head" 2>/dev/null || echo "$base")
files=$(git diff --name-only "$from" "$head")
[ -z "$files" ] && exit 0

if printf '%s\n' "$files" | grep -qx "CLAUDE.md"; then
	exit 0
fi
if git log --format=%B "$base..$head" | grep -qF "[contexto-ok]"; then
	exit 0
fi

cat >&2 <<MSG
✗ Push bloqueado: CLAUDE.md no se ha actualizado en los commits que vas a subir.

Archivos cambiados:
$(printf '%s\n' "$files" | sed 's/^/  - /' | head -20)

Antes de subir:
  1. Revisa si el cambio afecta al contexto del proyecto (sistemas, carpetas,
     herramientas, convenciones, documentos de diseño, versiones...) y
     actualiza CLAUDE.md en un commit.
  2. Si de verdad no afecta (un arreglo pequeño, un texto...), añade
     [contexto-ok] al mensaje de un commit (p. ej. con git commit --amend).
MSG
exit 1
