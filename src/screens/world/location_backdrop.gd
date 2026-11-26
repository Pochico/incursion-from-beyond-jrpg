class_name LocationBackdrop
extends Control
## Fondo de la ubicación actual. Lo comparten el escenario y la conversación.
##
## Si existe `res://assets/backgrounds/<id>_<franja>.(png|jpg|webp)` (franja de
## GameState.TIME_SLOTS: manana, dia, tarde, noche), se usa esa imagen; si no,
## `<id>.(png|jpg|webp)`, la de cualquier momento. Si la ubicación trae `backdrop`
## (LocationDB `from_phase`, p. ej. Colinas con la grieta), se prueba antes ese
## nombre (también por franja); si aún no hay imagen, la de siempre.
## Si no, se genera un fondo PROVISIONAL por código: ciudad nocturna con la
## paleta de la ubicación (ver LocationDB). Sin imagen, la ubicación vacía o
## «casa» es negro.

const BACKGROUND_DIR := "res://assets/backgrounds/"

var location_id := ""
var _texture: Texture2D
var _loc: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_location(id: String) -> void:
	location_id = id
	_loc = LocationDB.get_location(id)
	_texture = null
	if id != "":
		var names: Array[String] = []
		if _loc.has("backdrop"):
			names.append_array([str(_loc.backdrop) + "_" + GameState.slot_id(), str(_loc.backdrop)])
		names.append_array([id + "_" + GameState.slot_id(), id])
		for name in names:
			for ext in ["png", "jpg", "webp"]:
				var path := "%s%s.%s" % [BACKGROUND_DIR, name, ext]
				if _texture == null and ResourceLoader.exists(path):
					_texture = load(path)
				elif _texture == null and OS.has_feature("editor") and FileAccess.file_exists(path):
					# Recién puesto desde el editor del mapa y aún sin importar.
					_texture = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(path)))
	queue_redraw()


## Fondo concreto, sin depender de la ubicación (p. ej. el de los combates de una mazmorra).
func set_texture(tex: Texture2D) -> void:
	_texture = tex
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), UIStyle.INK)

	if _texture:
		_draw_cover(_texture)
		return

	if location_id == "" or location_id == LocationDB.HOME:
		return

	_draw_procedural(w, h)


func _draw_cover(tex: Texture2D) -> void:
	var ts := tex.get_size()
	draw_texture_rect(tex, Rect2(image_to_local(Vector2.ZERO), ts * cover_scale()), false)


## Escala del fondo con imagen (cubre todo el control, recortando lo que sobre).
func cover_scale() -> float:
	if _texture == null:
		return 1.0
	var ts := _texture.get_size()
	return maxf(size.x / ts.x, size.y / ts.y)


## Convierte un punto en píxeles de la imagen de fondo a coordenadas locales.
func image_to_local(p: Vector2) -> Vector2:
	if _texture == null:
		return p
	var s := cover_scale()
	return (size - _texture.get_size() * s) * 0.5 + p * s


# --- Generación procedural ---------------------------------------------------------

func _draw_procedural(w: float, h: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(location_id)

	var sky_top: Color = _loc.get("sky_top", Color("15112a"))
	var sky_bottom: Color = _loc.get("sky_bottom", Color("7a64b4"))
	var horizon := h * 0.56

	# Cielo
	_vgradient(Rect2(0, 0, w, horizon + 40), sky_top, sky_bottom)

	# Torre con anillo luminoso
	if _loc.get("tower", false):
		_draw_tower(w * rng.randf_range(0.55, 0.7), horizon, h, sky_top, sky_bottom)

	# Rascacielos lejanos (dos capas)
	_skyline(rng, w, horizon, 90.0, 360.0, sky_bottom.lerp(sky_top, 0.45), 0.12, sky_bottom)
	_skyline(rng, w, horizon, 50.0, 220.0, sky_bottom.lerp(sky_top, 0.7), 0.2, sky_bottom)

	# Neblina en el horizonte
	_vgradient(Rect2(0, horizon - 140, w, 140), Color(sky_bottom, 0.0), Color(sky_bottom, 0.45))

	# Pasarela elevada
	var bridge_y := h * 0.30
	var bridge_col := sky_top.lerp(Color.BLACK, 0.3)
	draw_rect(Rect2(w * 0.2, bridge_y, w * 0.62, 30), bridge_col)
	draw_rect(Rect2(w * 0.2, bridge_y + 30, w * 0.62, 4), Color(UIStyle.WHITE, 0.25))
	for i in 7:
		var px := w * 0.22 + i * w * 0.1
		draw_rect(Rect2(px, bridge_y + 34, 14, horizon - bridge_y - 34), bridge_col.lightened(0.05))
	for i in 40:
		var rx := w * 0.2 + i * (w * 0.62 / 40.0)
		draw_line(Vector2(rx, bridge_y - 22), Vector2(rx, bridge_y), Color(UIStyle.WHITE, 0.18), 1.0)
	draw_line(Vector2(w * 0.2, bridge_y - 22), Vector2(w * 0.82, bridge_y - 22), Color(UIStyle.WHITE, 0.3), 2.0)

	# Edificios cercanos a los lados (fachadas con escaparates)
	_side_building(rng, Rect2(-20, h * 0.05, w * 0.17, horizon + h * 0.2), sky_top, true)
	_side_building(rng, Rect2(w * 0.83, h * 0.02, w * 0.19, horizon + h * 0.25), sky_top, false)

	# Suelo
	var ground := sky_top.lerp(Color("2b2540"), 0.6)
	_vgradient(Rect2(0, horizon, w, h - horizon), ground.lightened(0.08), ground.darkened(0.35))
	if _loc.get("water", false):
		_draw_water(w, h, horizon, sky_bottom)
	_ground_grid(w, h, horizon)

	# Farolas con banderolas
	var lamp_xs := [0.24, 0.38, 0.62, 0.76]
	for k in lamp_xs.size():
		var x: float = w * lamp_xs[k]
		var depth: float = 0.55 + absf(lamp_xs[k] - 0.5) * 1.6
		_lamp(Vector2(x, horizon + 30 * depth), 260.0 * depth, sky_bottom, k)

	# Gente lejana
	for i in 14:
		var px := rng.randf_range(w * 0.18, w * 0.82)
		var py := horizon + rng.randf_range(10, 60)
		var ph := rng.randf_range(34, 52)
		draw_rect(Rect2(px, py - ph, ph * 0.28, ph), Color(sky_top.darkened(0.4), 0.85))
		draw_circle(Vector2(px + ph * 0.14, py - ph - 5), ph * 0.13, Color(sky_top.darkened(0.4), 0.85))

	# Árboles en primer plano
	if _loc.get("trees", false):
		_tree_cluster(rng, Vector2(w * 0.04, h * 0.12), 260.0, sky_bottom)
		_tree_cluster(rng, Vector2(w * 0.97, h * 0.18), 200.0, sky_bottom)

	# Viñeta superior e inferior
	_vgradient(Rect2(0, 0, w, h * 0.22), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.0))
	_vgradient(Rect2(0, h * 0.7, w, h * 0.3), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.6))


func _vgradient(rect: Rect2, top: Color, bottom: Color) -> void:
	var p := rect.position
	var s := rect.size
	draw_polygon(
		PackedVector2Array([p, p + Vector2(s.x, 0), p + s, p + Vector2(0, s.y)]),
		PackedColorArray([top, top, bottom, bottom]))


func _skyline(rng: RandomNumberGenerator, w: float, base: float, min_h: float, max_h: float,
		color: Color, lit_chance: float, sky_bottom: Color) -> void:
	var x := -30.0
	while x < w:
		var bw := rng.randf_range(50, 150)
		var bh := rng.randf_range(min_h, max_h)
		var rect := Rect2(x, base - bh, bw, bh + 20)
		draw_rect(rect, color)
		# Ventanas
		var win := Color(sky_bottom.lightened(0.5), 0.55)
		var yy := rect.position.y + 10
		while yy < base - 10:
			var xx := rect.position.x + 8
			while xx < rect.end.x - 10:
				if rng.randf() < lit_chance:
					draw_rect(Rect2(xx, yy, 6, 4), win)
				xx += 14
			yy += 12
		if rng.randf() < 0.25:
			draw_line(Vector2(x + bw * 0.5, base - bh), Vector2(x + bw * 0.5, base - bh - 40), color, 2.0)
		x += bw + rng.randf_range(-10, 16)


func _draw_tower(x: float, horizon: float, h: float, sky_top: Color, sky_bottom: Color) -> void:
	var top := h * 0.06
	var col := sky_bottom.lerp(sky_top, 0.55)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 70, horizon), Vector2(x - 40, top + 40), Vector2(x - 10, top),
		Vector2(x + 10, top), Vector2(x + 40, top + 40), Vector2(x + 70, horizon),
	]), col)
	# Franjas de luz verticales
	for k in 3:
		draw_line(Vector2(x - 20 + k * 20, top + 60), Vector2(x - 26 + k * 26, horizon),
				Color(UIStyle.LIME, 0.35), 3.0)
	# Anillo (elipse) luminoso
	draw_set_transform(Vector2(x, top + 170), 0.0, Vector2(1.0, 0.16))
	for i in 4:
		draw_arc(Vector2.ZERO, 260.0 + i * 2.0, 0, TAU, 96, Color(Color("8ff7ff"), 0.5 - i * 0.1), 6.0 - i, true)
	draw_arc(Vector2.ZERO, 262.0, 0, TAU, 96, Color(Color("8ff7ff"), 0.12), 26.0, true)
	draw_set_transform(Vector2.ZERO)


func _side_building(rng: RandomNumberGenerator, rect: Rect2, sky_top: Color, left: bool) -> void:
	var col := sky_top.lerp(Color.BLACK, 0.45)
	draw_rect(rect, col)
	# Escaparate iluminado en la base
	var shop_h := rect.size.y * 0.22
	var shop := Rect2(rect.position.x + 10, rect.end.y - shop_h - 40, rect.size.x - 20, shop_h)
	_vgradient(shop, Color("fff1d6", 0.55), Color("e8a8ff", 0.25))
	draw_rect(shop, Color(UIStyle.WHITE, 0.4), false, 2.0)
	# Toldo
	var aw := rect.size.x + 20
	var ax := rect.position.x - (0 if left else 20)
	draw_colored_polygon(PackedVector2Array([
		Vector2(ax, shop.position.y - 30), Vector2(ax + aw, shop.position.y - 30),
		Vector2(ax + aw + (20 if left else -20), shop.position.y), Vector2(ax + (20 if left else -20), shop.position.y),
	]), col.darkened(0.3))
	# Ventanas superiores
	var yy := rect.position.y + 40
	while yy < shop.position.y - 70:
		var xx := rect.position.x + 20
		while xx < rect.end.x - 40:
			var lit := rng.randf() < 0.35
			draw_rect(Rect2(xx, yy, 34, 46), Color("d9c8ff", 0.35) if lit else Color(UIStyle.WHITE, 0.04))
			xx += 52
		yy += 74
	# Rótulo con «//»
	var sign_rect := Rect2(rect.position.x + rect.size.x * 0.25, rect.position.y + rect.size.y * 0.3, rect.size.x * 0.5, 90)
	draw_rect(sign_rect, Color(UIStyle.INK, 0.8))
	draw_rect(sign_rect, Color(UIStyle.WHITE, 0.5), false, 2.0)
	UIStyle.draw_stripes(self, sign_rect.position + Vector2(sign_rect.size.x * 0.28, 66), 2,
			Vector2(16, 42), 10, Color(UIStyle.WHITE, 0.85))


func _draw_water(w: float, h: float, horizon: float, sky_bottom: Color) -> void:
	var top := horizon + (h - horizon) * 0.12
	var bottom := horizon + (h - horizon) * 0.38
	_vgradient(Rect2(0, top, w, bottom - top), Color(sky_bottom.darkened(0.2), 0.9), Color(sky_bottom.darkened(0.55), 0.9))
	for i in 18:
		var y := lerpf(top + 6, bottom - 6, i / 18.0)
		var x0 := fmod(i * 337.0, w * 0.8)
		draw_line(Vector2(x0, y), Vector2(x0 + 120 + i * 6, y), Color(UIStyle.WHITE, 0.12), 2.0)
	draw_line(Vector2(0, top), Vector2(w, top), Color(UIStyle.WHITE, 0.3), 2.0)


func _ground_grid(w: float, h: float, horizon: float) -> void:
	var vp := Vector2(w * 0.5, horizon - 40)
	var line_col := Color(UIStyle.WHITE, 0.07)
	for i in range(-12, 13):
		var bx := w * 0.5 + i * 170.0
		var t := (horizon - vp.y) / (h - vp.y)
		draw_line(vp.lerp(Vector2(bx, h), t), Vector2(bx, h), line_col, 1.5)
	for k in 10:
		var t := pow((k + 1) / 10.0, 2.0)
		var y := lerpf(horizon, h, t)
		draw_line(Vector2(0, y), Vector2(w, y), line_col, 1.5)
	# Reflejo central
	_vgradient(Rect2(w * 0.35, horizon, w * 0.3, (h - horizon) * 0.8), Color(UIStyle.WHITE, 0.08), Color(UIStyle.WHITE, 0.0))


func _lamp(base: Vector2, height: float, sky_bottom: Color, index: int) -> void:
	var top := base - Vector2(0, height)
	draw_line(base, top, Color("15121c"), 5.0)
	# Luz
	for r in [60.0, 40.0, 24.0]:
		draw_circle(top + Vector2(0, 8), r * height / 260.0, Color(Color("fff4e0"), 0.07))
	draw_rect(Rect2(top + Vector2(-5, 0), Vector2(10, 22 * height / 260.0)), Color("fff4e0"))
	# Reflejo en el suelo
	_vgradient(Rect2(base.x - 6, base.y, 12, height * 0.35), Color(Color("fff4e0"), 0.25), Color(Color("fff4e0"), 0.0))
	# Banderola alternando lima / violeta
	var accent := UIStyle.LIME if index % 2 == 0 else UIStyle.VIOLET
	var bw := 46.0 * height / 260.0
	var bh := 120.0 * height / 260.0
	var banner := Rect2(top + Vector2(6, 30 * height / 260.0), Vector2(bw, bh))
	draw_rect(banner, Color(accent, 0.85))
	UIStyle.draw_stripes(self, banner.position + Vector2(bw * 0.18, bh * 0.62), 2,
			Vector2(bw * 0.18, bh * 0.3), bw * 0.1, Color(UIStyle.WHITE, 0.8))


func _tree_cluster(rng: RandomNumberGenerator, center: Vector2, radius: float, sky_bottom: Color) -> void:
	var dark := Color("120d1c")
	var leaf := sky_bottom.lerp(Color("e6a6d8"), 0.5)
	draw_line(center + Vector2(0, radius * 0.3), center + Vector2(rng.randf_range(-30, 30), radius * 3.2), dark, 26.0)
	for i in 34:
		var off := Vector2(rng.randf_range(-1, 1), rng.randf_range(-0.7, 0.8)) * radius
		draw_circle(center + off, rng.randf_range(radius * 0.18, radius * 0.38), dark)
	for i in 26:
		var off := Vector2(rng.randf_range(-1, 1), rng.randf_range(-0.6, 0.9)) * radius
		draw_circle(center + off, rng.randf_range(radius * 0.06, radius * 0.14), Color(leaf, 0.35))
