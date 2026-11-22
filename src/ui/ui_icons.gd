class_name UIIcons
extends RefCounted
## Iconos vectoriales sencillos dibujados por código (sin fuentes de iconos).
## Todos se dibujan centrados en `c` dentro de un cuadrado de lado `s`.


## «»»» Tres chevrons (Saltar).
static func chevrons(ci: CanvasItem, c: Vector2, s: float, color: Color, width := 3.0) -> void:
	var h := s * 0.32
	for i in 3:
		var x := c.x - s * 0.36 + i * s * 0.26
		ci.draw_polyline(PackedVector2Array([Vector2(x, c.y - h), Vector2(x + h, c.y), Vector2(x, c.y + h)]), color, width, true)


## ▶ Triángulo (Auto / reproducir).
static func play(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	var h := s * 0.38
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - h * 0.8, c.y - h), Vector2(c.x + h, c.y), Vector2(c.x - h * 0.8, c.y + h),
	]), color)


## ≡ Hamburguesa (Menú).
static func menu(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	for i in 3:
		var y := c.y + (i - 1) * s * 0.28
		ci.draw_line(Vector2(c.x - s * 0.42, y), Vector2(c.x + s * 0.42, y), color, 2.5, true)


## Calendario.
static func calendar(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	var r := Rect2(c - Vector2(s * 0.45, s * 0.38), Vector2(s * 0.9, s * 0.82))
	ci.draw_rect(r, color, false, 2.5)
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, s * 0.2)), color)
	for i in 2:
		var x := r.position.x + r.size.x * (0.3 + i * 0.4)
		ci.draw_line(Vector2(x, r.position.y - s * 0.1), Vector2(x, r.position.y + s * 0.08), color, 3.0)
	for gy in 2:
		for gx in 3:
			ci.draw_rect(Rect2(r.position + Vector2(s * (0.14 + gx * 0.22), s * (0.34 + gy * 0.2)), Vector2(s * 0.12, s * 0.1)), color)


## Bocadillo de diálogo con «...» (Hablar / indicador sobre personajes).
static func speech(ci: CanvasItem, c: Vector2, s: float, fill: Color, dots: Color, outline: Color = Color(0, 0, 0, 0)) -> void:
	var body := Rect2(c - Vector2(s * 0.5, s * 0.36), Vector2(s, s * 0.6))
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(int(s * 0.3))
	if outline.a > 0.0:
		sb.border_color = outline
		sb.set_border_width_all(2)
	ci.draw_style_box(sb, body)
	var tail := PackedVector2Array([
		Vector2(c.x - s * 0.22, body.end.y - 2), Vector2(c.x - s * 0.04, body.end.y - 2), Vector2(c.x - s * 0.3, body.end.y + s * 0.2),
	])
	ci.draw_colored_polygon(tail, fill)
	for i in 3:
		ci.draw_circle(Vector2(c.x + (i - 1) * s * 0.22, body.get_center().y), s * 0.07, dots)


## Espadas cruzadas (Luchar).
static func swords(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	var h := s * 0.42
	for sgn in [-1.0, 1.0]:
		var a := c + Vector2(-h * sgn, -h)
		var b := c + Vector2(h * sgn, h)
		ci.draw_line(a, b, color, 3.0, true)
		# Guarda
		var g := c + Vector2(h * 0.55 * sgn, h * 0.55)
		var perp := Vector2(1.0 * sgn, -1.0).normalized() * s * 0.14
		ci.draw_line(g - perp, g + perp, color, 3.0, true)


## Corazón (Ligar).
static func heart(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	var r := s * 0.22
	ci.draw_circle(c + Vector2(-r * 0.95, -r * 0.4), r, color)
	ci.draw_circle(c + Vector2(r * 0.95, -r * 0.4), r, color)
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-r * 1.95, -r * 0.15), c + Vector2(r * 1.95, -r * 0.15), c + Vector2(0, s * 0.42),
	]), color)


## «!» en círculo (aviso / misión).
static func alert(ci: CanvasItem, c: Vector2, s: float, fill: Color, mark: Color) -> void:
	ci.draw_circle(c, s * 0.5, fill)
	ci.draw_line(c + Vector2(0, -s * 0.26), c + Vector2(0, s * 0.08), mark, s * 0.12)
	ci.draw_circle(c + Vector2(0, s * 0.24), s * 0.07, mark)


## ✦ Destello de cuatro puntas (Habilidad).
static func sparkle(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	var r := s * 0.48
	var k := s * 0.1
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -r), c + Vector2(k, -k), c + Vector2(r, 0), c + Vector2(k, k),
		c + Vector2(0, r), c + Vector2(-k, k), c + Vector2(-r, 0), c + Vector2(-k, -k),
	]), color)


## Matraz (Objeto).
static func flask(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	var w := s * 0.16
	var top := c.y - s * 0.44
	var neck := c.y - s * 0.08
	var bot := c.y + s * 0.44
	ci.draw_polyline(PackedVector2Array([
		Vector2(c.x - w, top), Vector2(c.x - w, neck), Vector2(c.x - s * 0.4, bot),
		Vector2(c.x + s * 0.4, bot), Vector2(c.x + w, neck), Vector2(c.x + w, top),
	]), color, 2.5, true)
	ci.draw_line(Vector2(c.x - w * 1.6, top), Vector2(c.x + w * 1.6, top), color, 2.5)
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - s * 0.26, c.y + s * 0.18), Vector2(c.x + s * 0.26, c.y + s * 0.18),
		Vector2(c.x + s * 0.36, bot - 2), Vector2(c.x - s * 0.36, bot - 2),
	]), color)


## Escudo (Defender).
static func shield(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	var w := s * 0.4
	var pts := PackedVector2Array([
		c + Vector2(0, -s * 0.46), c + Vector2(w, -s * 0.3), c + Vector2(w * 0.9, s * 0.12),
		c + Vector2(0, s * 0.48), c + Vector2(-w * 0.9, s * 0.12), c + Vector2(-w, -s * 0.3),
	])
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, color, 2.5, true)
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -s * 0.32), c + Vector2(w * 0.62, -s * 0.2), c + Vector2(w * 0.55, s * 0.08), c + Vector2(0, s * 0.33),
	]), color)


## Antena con ondas (Analizar).
static func antenna(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	var base := c + Vector2(0, s * 0.05)
	ci.draw_circle(base, s * 0.08, color)
	ci.draw_colored_polygon(PackedVector2Array([
		base + Vector2(-s * 0.05, 0), base + Vector2(s * 0.05, 0),
		base + Vector2(s * 0.14, s * 0.44), base + Vector2(-s * 0.14, s * 0.44),
	]), color)
	for i in 2:
		var r := s * (0.22 + i * 0.16)
		ci.draw_arc(base, r, -PI * 0.8, -PI * 0.2, 12, color, 2.5, true)
		ci.draw_arc(base, r, PI * 1.2, PI * 1.8, 12, color, 2.5, true)


## Figura corriendo (Huir).
static func run(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	ci.draw_circle(c + Vector2(s * 0.14, -s * 0.34), s * 0.1, color)
	var hip := c + Vector2(-s * 0.04, s * 0.06)
	var neck := c + Vector2(s * 0.08, -s * 0.2)
	ci.draw_line(neck, hip, color, s * 0.11, true)
	ci.draw_polyline(PackedVector2Array([neck + Vector2(0, s * 0.04), c + Vector2(s * 0.3, -s * 0.06), c + Vector2(s * 0.42, -s * 0.18)]), color, s * 0.07, true)
	ci.draw_polyline(PackedVector2Array([neck + Vector2(0, s * 0.04), c + Vector2(-s * 0.2, -s * 0.12), c + Vector2(-s * 0.36, s * 0.0)]), color, s * 0.07, true)
	ci.draw_polyline(PackedVector2Array([hip, c + Vector2(s * 0.24, s * 0.22), c + Vector2(s * 0.2, s * 0.46)]), color, s * 0.08, true)
	ci.draw_polyline(PackedVector2Array([hip, c + Vector2(-s * 0.16, s * 0.3), c + Vector2(-s * 0.42, s * 0.34)]), color, s * 0.08, true)


## Candado (bloqueado).
static func lock(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	ci.draw_arc(c + Vector2(0, -s * 0.08), s * 0.2, PI, TAU, 12, color, 2.5, true)
	ci.draw_line(c + Vector2(-s * 0.2, -s * 0.08), c + Vector2(-s * 0.2, s * 0.02), color, 2.5)
	ci.draw_line(c + Vector2(s * 0.2, -s * 0.08), c + Vector2(s * 0.2, s * 0.02), color, 2.5)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.32, 0), Vector2(s * 0.64, s * 0.44)), color)


## Tajo diagonal (ataque básico).
static func slash(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	var a := c + Vector2(-s * 0.4, s * 0.4)
	var b := c + Vector2(s * 0.42, -s * 0.42)
	ci.draw_colored_polygon(PackedVector2Array([a, b, b + Vector2(-s * 0.06, s * 0.16), a + Vector2(s * 0.12, -s * 0.02)]), color)
	ci.draw_line(a + Vector2(s * 0.04, s * 0.0), a + Vector2(-s * 0.06, -s * 0.12), color, 2.5)


## Lata de refresco (Pochicola).
static func can(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	var r := Rect2(c - Vector2(s * 0.24, s * 0.42), Vector2(s * 0.48, s * 0.84))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(s * 0.1))
	ci.draw_style_box(sb, r)
	ci.draw_rect(Rect2(r.position + Vector2(0, s * 0.3), Vector2(r.size.x, s * 0.24)), color)
	ci.draw_line(r.position + Vector2(s * 0.14, -s * 0.06), r.position + Vector2(s * 0.34, -s * 0.06), color, 2.5)


static func moon(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	# Media luna: arco exterior y arco interior desplazado.
	var r := s * 0.42
	var pts := PackedVector2Array()
	for i in 25:
		var a := lerpf(-PI * 0.75, PI * 0.75, i / 24.0) + PI
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	var inner_c := c + Vector2(-r * 0.45, -r * 0.1)
	for i in 25:
		var a := lerpf(PI * 0.62, -PI * 0.62, i / 24.0) + PI
		pts.append(inner_c + Vector2(cos(a), sin(a)) * r * 0.82)
	ci.draw_colored_polygon(pts, color)


static func clock(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	var r := s * 0.42
	ci.draw_arc(c, r, 0, TAU, 32, color, 2.5, true)
	ci.draw_line(c, c + Vector2(0, -r * 0.62), color, 2.5, true)
	ci.draw_line(c, c + Vector2(r * 0.5, 0), color, 2.5, true)


## Dibuja el icono por nombre.
static func draw_named(ci: CanvasItem, icon: String, c: Vector2, s: float, color: Color) -> void:
	match icon:
		"chevrons": chevrons(ci, c, s, color)
		"moon": moon(ci, c, s, color)
		"clock": clock(ci, c, s, color)
		"play": play(ci, c, s, color)
		"menu": menu(ci, c, s, color)
		"calendar": calendar(ci, c, s, color)
		"speech": speech(ci, c, s, Color(0, 0, 0, 0), color, color)
		"swords": swords(ci, c, s, color)
		"heart": heart(ci, c, s, color)
		"sparkle": sparkle(ci, c, s, color)
		"flask": flask(ci, c, s, color)
		"shield": shield(ci, c, s, color)
		"antenna": antenna(ci, c, s, color)
		"run": run(ci, c, s, color)
		"lock": lock(ci, c, s, color)
		"slash": slash(ci, c, s, color)
		"can": can(ci, c, s, color)
		"alert": alert(ci, c, s, color, UIStyle.INK)
