class_name DungeonTextures
extends RefCounted
## Texturas de las mazmorras: las que exporta el Estudio de texturas en
## assets/textures/<tema>/<superficie>/<nombre>.png (ver TextureFormats).
##
## Cada tema puede tener un tema.json con la textura predeterminada de cada
## superficie: {"suelo": "baldosa", "techo": "gris", "pared": "azulejo"}. Si
## falta, se usa la primera por orden alfabético, y si no hay ninguna, una
## provisional generada (damero, ladrillo, paneles).

## Superficie del mapa → carpeta del Estudio de texturas.
const SURFACE_DIR := {"floor": "suelo", "ceiling": "techo", "wall": "pared"}

static var _cache := {}


static func clear_cache() -> void:
	_cache.clear()


static func themes() -> Array[String]:
	var out: Array[String] = []
	if not DirAccess.dir_exists_absolute(TextureFormats.ROOT_DIR):
		return out
	for d in DirAccess.get_directories_at(TextureFormats.ROOT_DIR):
		out.append(d)
	out.sort()
	return out


## Nombres (sin extensión) de las texturas de un tema para una superficie.
static func list(theme: String, surface: String) -> Array[String]:
	var out: Array[String] = []
	var dir := "%s/%s/%s" % [TextureFormats.ROOT_DIR, theme, SURFACE_DIR[surface]]
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f in DirAccess.get_files_at(dir):
		# En un juego exportado los PNG aparecen como .png.import / .png.remap.
		f = f.trim_suffix(".import").trim_suffix(".remap")
		if f.ends_with(".png") and not f.get_basename() in out:
			out.append(f.get_basename())
	out.sort()
	return out


static func path(theme: String, surface: String, tex_name: String) -> String:
	return TextureFormats.output_path(theme, SURFACE_DIR[surface], tex_name)


static func _theme_file(theme: String) -> String:
	return "%s/%s/tema.json" % [TextureFormats.ROOT_DIR, theme]


static func defaults(theme: String) -> Dictionary:
	var f := _theme_file(theme)
	if not FileAccess.file_exists(f):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(f))
	return d if d is Dictionary else {}


static func set_default(theme: String, surface: String, tex_name: String) -> Error:
	var d := defaults(theme)
	d[SURFACE_DIR[surface]] = tex_name
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_theme_file(theme).get_base_dir()))
	var f := FileAccess.open(_theme_file(theme), FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(d, "\t"))
	return OK


## Predeterminada de una superficie: la de tema.json; si no la indica, la primera
## que haya. Con "" en tema.json no hay ninguna (se usa la provisional): útil si
## las texturas de esa superficie son solo para casillas concretas (p. ej. una
## flecha de salida).
static func default_name(theme: String, surface: String) -> String:
	var available := list(theme, surface)
	var d := defaults(theme)
	if d.get(SURFACE_DIR[surface], null) is String and d[SURFACE_DIR[surface]] == "":
		return ""
	var chosen: String = d.get(SURFACE_DIR[surface], "")
	if chosen in available:
		return chosen
	return available[0] if not available.is_empty() else ""


## Textura a usar: `tex_name` si existe en el tema; si no, la predeterminada.
static func resolve(theme: String, surface: String, tex_name: String) -> Texture2D:
	if tex_name == "" or not tex_name in list(theme, surface):
		tex_name = default_name(theme, surface)
	if tex_name == "":
		return placeholder(surface)
	return load_texture(path(theme, surface, tex_name))


## Con `live_files` (lo activa el editor de mazmorras) se lee el PNG directamente,
## para ver las texturas recién exportadas sin esperar a que Godot las importe.
## En el juego se usa la textura importada (la única que existe al exportar).
static var live_files := false


## Carga un PNG (ver `live_files`).
static func load_texture(p: String) -> Texture2D:
	if _cache.has(p):
		return _cache[p]
	var tex: Texture2D = null
	if not live_files and ResourceLoader.exists(p):
		tex = load(p)
	elif FileAccess.file_exists(p):
		var img := Image.load_from_file(p)
		if img and not img.is_empty():
			img.generate_mipmaps()
			tex = ImageTexture.create_from_image(img)
	elif ResourceLoader.exists(p):
		tex = load(p)
	_cache[p] = tex
	return tex


## Texturas provisionales generadas (mientras el tema no tenga las suyas).
static func placeholder(surface: String) -> Texture2D:
	var key := "placeholder:" + surface
	if _cache.has(key):
		return _cache[key]
	var img: Image
	match surface:
		"floor":
			img = Image.create(128, 128, false, Image.FORMAT_RGB8)
			img.fill(Color("3a3a48"))
			for i in 2:
				for j in 2:
					img.fill_rect(Rect2i(i * 64 + 2, j * 64 + 2, 60, 60), Color("4a4a5c") if (i + j) % 2 == 0 else Color("434354"))
		"ceiling":
			img = Image.create(128, 128, false, Image.FORMAT_RGB8)
			img.fill(Color("26262f"))
			img.fill_rect(Rect2i(0, 62, 128, 4), Color("1c1c24"))
			img.fill_rect(Rect2i(62, 0, 4, 128), Color("1c1c24"))
		_:
			# Ladrillo: 2 m × 2,5 m → 128 × 160.
			img = Image.create(128, 160, false, Image.FORMAT_RGB8)
			img.fill(Color("2b2a33"))
			for row in 8:
				var off := 0 if row % 2 == 0 else 16
				for col in 5:
					var x := col * 32 - off
					img.fill_rect(Rect2i(maxi(x + 2, 0), row * 20 + 2, mini(28, 28 + x) if x < 0 else 28, 16),
							Color("5a4e66") if (row + col) % 3 else Color("54495f"))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
