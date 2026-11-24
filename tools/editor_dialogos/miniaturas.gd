extends SceneTree
## Miniaturas de las caras para el editor de diálogos web
## (docs/editor-dialogos/caras/<retrato>.webp): un recorte cuadrado de la cabeza
## de cada retrato y gesto de CharacterDB. Ver miniaturas.sh.

const OUT := "res://docs/editor-dialogos/caras/"
const SIZE := 128


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var n := 0
	for id: String in CharacterDB.ALL:
		var c: Dictionary = CharacterDB.ALL[id]
		if c.get("enemy", false) or not c.has("portrait"):
			continue
		var paths: Array = [c.portrait]
		paths.append_array(c.get("faces", {}).values())
		for path: String in paths:
			var img := Image.load_from_file(ProjectSettings.globalize_path(path))
			img.convert(Image.FORMAT_RGBA8)
			var thumb := img.get_region(_head_square(img))
			thumb.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
			thumb.save_webp(ProjectSettings.globalize_path(OUT + path.get_file().get_basename() + ".webp"), true, 0.8)
			n += 1
	print("miniaturas: ", n)
	quit()


## Cuadrado alrededor de la cabeza: desde la primera fila con píxeles opacos,
## centrado en la masa opaca a la altura de la cara.
func _head_square(img: Image) -> Rect2i:
	var w := img.get_width()
	var h := img.get_height()
	var top := 0
	for y in range(0, h, 4):
		var count := 0
		for x in range(0, w, 4):
			if img.get_pixel(x, y).a > 0.5:
				count += 1
		if count >= 4:
			top = y
			break
	var side := int(w * 0.42)
	var sum := 0.0
	var k := 0
	# Franja a la altura de la cara (no la del pelo, que tira hacia los lados).
	for y in range(top + int(side * 0.45), mini(top + int(side * 0.8), h), 6):
		for x in range(0, w, 6):
			if img.get_pixel(x, y).a > 0.5:
				sum += x
				k += 1
	var cx := int(sum / maxf(k, 1))
	var x0 := clampi(cx - side / 2, 0, w - side)
	var y0 := clampi(top + int(side * 0.12), 0, h - side)
	return Rect2i(x0, y0, side, side)
