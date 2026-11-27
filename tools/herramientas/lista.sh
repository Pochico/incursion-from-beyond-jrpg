# Herramientas con rama propia: nombre → rama y carpeta (la misma ruta en la
# rama y en main, donde está ignorada por git). Lo usan traer.sh y llevar.sh;
# si añades una, añádela también a .gitignore y a .github/workflows/publicar.yml.
HERRAMIENTAS=(editor-mazmorras editor-dialogos captura-movimiento)
rama_de() { case "$1" in editor-mazmorras|editor-dialogos|captura-movimiento) echo "herramientas/$1" ;; esac; }
carpeta_de() {
	case "$1" in
		editor-mazmorras) echo src/tools/editor_mazmorras ;;
		editor-dialogos) echo docs/editor-dialogos ;;
		captura-movimiento) echo tools/captura-movimiento ;;
	esac
}
# Lo que se genera en local y no va a la rama (dependencias y compilados de la
# captura de movimiento): ni se compara al traer ni se copia al llevar.
EXCLUIR=(--exclude .DS_Store --exclude node_modules --exclude /dist --exclude /public/mediapipe --exclude '*.task')
