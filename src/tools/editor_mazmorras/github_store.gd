class_name GithubStore
extends Node
## Guardado del editor de mazmorras en la versión web (móvil, sin Godot ni PC):
## lee y escribe los mapas de `main` en GitHub con la API, como el editor de
## diálogos. El token es el mismo que guarda el editor de diálogos en el
## navegador (localStorage «editor-dialogos:token»: misma web, mismo origen).
## Cada guardado es un commit en main; la publicación vuelve a montar las
## herramientas y el juego lee el mapa nuevo.

const OWNER := "Pochico"
const REPO := "incursion-from-beyond-jrpg"
const BRANCH := "main"
const API := "https://api.github.com/repos/" + OWNER + "/" + REPO
const TOKEN_KEY := "editor-dialogos:token"


## Solo en la versión web; en Godot se guarda en el proyecto (DungeonMap.save).
static func enabled() -> bool:
	return OS.has_feature("web")


static func repo_path(map_id: String) -> String:
	return DungeonMap.path_for(map_id).trim_prefix("res://")


func token() -> String:
	var v: Variant = JavaScriptBridge.eval("localStorage.getItem('%s') || ''" % TOKEN_KEY, true)
	return str(v) if v != null else ""


func set_token(t: String) -> void:
	JavaScriptBridge.eval("localStorage.setItem('%s', %s)" % [TOKEN_KEY, JSON.stringify(t.strip_edges())], true)


## Ids de las mazmorras de main, en orden alfabético (vacío si falla).
func list_maps() -> Array[String]:
	var out: Array[String] = []
	var r := await _request("/contents/" + DungeonMap.DIR.trim_prefix("res://") + _ref())
	var data: Variant = JSON.parse_string(r.text) if r.ok else null
	if data is Array:
		for f: Dictionary in data:
			if str(f.get("name", "")).ends_with(".json"):
				out.append(str(f.name).get_basename())
	out.sort()
	return out


## Mapa `map_id` tal como está en main (null si no se puede leer).
func load_map(map_id: String) -> DungeonMap:
	var r := await _request("/contents/" + repo_path(map_id) + _ref(), HTTPClient.METHOD_GET, "", true)
	var data: Variant = JSON.parse_string(r.text) if r.ok else null
	return DungeonMap.from_dict(data) if data is Dictionary else null


## Sube el mapa a main en un commit. Devuelve "" si va bien o el error.
func save_map(map: DungeonMap) -> String:
	if token() == "":
		return "falta el token de GitHub"
	var path := repo_path(map.id)
	var body := {
		"message": "Mazmorra: %s (editor web) [contexto-ok]" % map.id,
		"content": Marshalls.utf8_to_base64(JSON.stringify(map.to_dict(), "\t")),
		"branch": BRANCH,
	}
	var cur := await _request("/contents/" + path + _ref())
	if cur.ok:
		var info: Variant = JSON.parse_string(cur.text)
		if info is Dictionary:
			body["sha"] = info.get("sha", "")
	var r := await _request("/contents/" + path, HTTPClient.METHOD_PUT, JSON.stringify(body))
	if r.ok:
		return ""
	match r.code:
		401, 403:
			return "GitHub no acepta el token (%d)" % r.code
		409, 422:
			return "alguien ha cambiado el mapa a la vez; vuelve a abrirlo (%d)" % r.code
	return "error %d" % r.code


## Rama y un número para que el navegador no sirva una copia vieja.
func _ref() -> String:
	return "?ref=%s&t=%d" % [BRANCH, Time.get_ticks_msec()]


## {ok, code, text}
func _request(path: String, method := HTTPClient.METHOD_GET, body := "", raw := false) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)
	var headers := PackedStringArray(["Accept: " + ("application/vnd.github.raw+json" if raw else "application/vnd.github+json")])
	var t := token()
	if t != "":
		headers.append("Authorization: Bearer " + t)
	if body != "":
		headers.append("Content-Type: application/json")
	var err := http.request(API + path, headers, method, body)
	if err != OK:
		http.queue_free()
		return {"ok": false, "code": 0, "text": error_string(err)}
	var res: Array = await http.request_completed
	http.queue_free()
	var code: int = res[1]
	return {"ok": code >= 200 and code < 300, "code": code, "text": (res[3] as PackedByteArray).get_string_from_utf8()}
