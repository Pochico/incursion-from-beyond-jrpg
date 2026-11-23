#!/usr/bin/env bash
# Hook de Claude Code (PreToolUse, Bash): antes de cualquier «git push»
# comprueba que CLAUDE.md se ha actualizado (tools/git/check_context.sh).
# Código 2 = bloquear la orden y mostrar el motivo a Claude.
input=$(cat)
printf '%s' "$input" | grep -Eq 'git( +-[cC] +[^ ]+)* +push' || exit 0
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
base=$(git rev-parse -q --verify '@{u}' 2>/dev/null || git rev-parse -q --verify origin/main 2>/dev/null || true)
if ! out=$(tools/git/check_context.sh "$base" HEAD 2>&1); then
	printf '%s\n' "$out" >&2
	exit 2
fi
exit 0
