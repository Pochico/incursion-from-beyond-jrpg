@tool
extends EditorPlugin
## Godot nunca exporta el archivo original de un recurso importado: de los
## .dialogue solo viaja la versión compilada por Dialogue Manager, que no
## conserva los comentarios. Story lee las reglas «# cuando:» del texto original
## (Story._load_rules), así que sin esto ninguna conversación saldría en una
## versión exportada (APK, web...). Este complemento añade ese texto al paquete
## en su ruta de siempre.

const DIALOGUE_DIR := "res://src/dialogue/"

var _export: DialogueSources


func _enter_tree() -> void:
	_export = DialogueSources.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null


class DialogueSources extends EditorExportPlugin:
	func _get_name() -> String:
		return "IncursionDialogueSources"

	func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
		for f in DirAccess.get_files_at(DIALOGUE_DIR):
			if f.get_extension() == "dialogue":
				add_file(DIALOGUE_DIR + f, FileAccess.get_file_as_bytes(DIALOGUE_DIR + f), false)
