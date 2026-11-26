# Herramientas con rama propia: nombre → rama y carpeta (la misma ruta en la
# rama y en main, donde está ignorada por git). Lo usan traer.sh y llevar.sh;
# si añades una, añádela también a .gitignore y a .github/workflows/publicar.yml.
HERRAMIENTAS=(editor-mazmorras editor-dialogos)
rama_de() { case "$1" in editor-mazmorras|editor-dialogos) echo "herramientas/$1" ;; esac; }
carpeta_de() {
	case "$1" in
		editor-mazmorras) echo src/tools/editor_mazmorras ;;
		editor-dialogos) echo docs/editor-dialogos ;;
	esac
}
