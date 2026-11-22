class_name UIStyle
extends RefCounted
## Paleta, tipografías y utilidades de dibujo compartidas por toda la interfaz.
##
## La estética se basa en las referencias de `docs/ui/referencias/`:
## fondos grafito oscuros, acento verde lima, violeta secundario,
## líneas blancas finas, texto en cursiva y marcas diagonales «///».

# --- Paleta ------------------------------------------------------------------
const LIME := Color("c6f432")
const VIOLET := Color("9b5cf0")
const MAGENTA := Color("c23cf0")
const RED := Color("ff3b47")
const CYAN := Color("27b4f5")

const INK := Color("0b0b0d")            ## Negro de paneles y texto sobre lima.
const PANEL := Color(0.035, 0.035, 0.043, 0.9)
const GRAPHITE := Color("3e3e44")       ## Fondo grafito (pantalla de mapa).
const WHITE := Color("f2f2f4")
const GRAY := Color("8d8d96")
const GRAY_DARK := Color("2a2a30")
const NIGHT := Color("16152a")           ## Relleno de paneles de diálogo (azul noche).
const LINE := Color(0.95, 0.95, 0.97, 0.85)  ## Líneas finas de marco.

# --- Tipografía --------------------------------------------------------------
const FONT_REGULAR := preload("res://assets/fonts/inter/InterDisplay-Regular.otf")
const FONT_MEDIUM := preload("res://assets/fonts/inter/InterDisplay-Medium.otf")
const FONT_SEMIBOLD := preload("res://assets/fonts/inter/InterDisplay-SemiBold.otf")
const FONT_BOLD := preload("res://assets/fonts/inter/InterDisplay-Bold.otf")
const FONT_LIGHT_ITALIC := preload("res://assets/fonts/inter/InterDisplay-LightItalic.otf")
const FONT_REGULAR_ITALIC := preload("res://assets/fonts/inter/InterDisplay-Italic.otf")
const FONT_MEDIUM_ITALIC := preload("res://assets/fonts/inter/InterDisplay-MediumItalic.otf")
const FONT_ITALIC := preload("res://assets/fonts/inter/InterDisplay-SemiBoldItalic.otf")
const FONT_BOLD_ITALIC := preload("res://assets/fonts/inter/InterDisplay-BoldItalic.otf")
const FONT_HEAVY_ITALIC := preload("res://assets/fonts/inter/InterDisplay-ExtraBoldItalic.otf")

static var _theme: Theme


## Tema por defecto para los Control estándar (Label, Button...).
## «12460» -> «12,460».
static func format_money(value: int) -> String:
	var s := str(value)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


static func get_theme() -> Theme:
	if _theme == null:
		_theme = Theme.new()
		_theme.default_font = FONT_SEMIBOLD
		_theme.default_font_size = 26
		_theme.set_color("font_color", "Label", WHITE)
	return _theme


# --- Utilidades de dibujo ----------------------------------------------------

## Paralelogramo inclinado hacia la derecha («/»). `slant` es el desplazamiento
## horizontal entre la base y la parte superior.
static func slanted_rect(rect: Rect2, slant: float) -> PackedVector2Array:
	var p := rect.position
	var s := rect.size
	return PackedVector2Array([
		p + Vector2(slant, 0.0),
		p + Vector2(s.x, 0.0),
		p + Vector2(s.x - slant, s.y),
		p + Vector2(0.0, s.y),
	])


## Dibuja el contorno cerrado de un polígono.
static func draw_outline(ci: CanvasItem, points: PackedVector2Array, color: Color, width := 2.0) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	ci.draw_polyline(closed, color, width, true)


## Marca «///»: `count` barras diagonales a partir de `origin` (esquina inferior izquierda).
static func draw_stripes(ci: CanvasItem, origin: Vector2, count := 3, bar_size := Vector2(10.0, 16.0),
		gap := 6.0, color := WHITE, colors: Array = []) -> void:
	var slant := bar_size.y * 0.6
	for i in count:
		var x := origin.x + i * (bar_size.x + gap)
		var rect := Rect2(Vector2(x, origin.y - bar_size.y), bar_size)
		var c: Color = colors[i] if i < colors.size() else color
		ci.draw_colored_polygon(slanted_rect(rect, slant), c)


## Polígono a partir de un rectángulo con esquinas achaflanadas.
## `cuts` = [arriba-izq, arriba-der, abajo-der, abajo-izq] (0 = esquina recta).
static func chamfer_rect(rect: Rect2, cuts: Array) -> PackedVector2Array:
	var p := rect.position
	var e := rect.end
	var corners := [
		[Vector2(p.x, p.y), Vector2(0, 1), Vector2(1, 0)],    # arriba-izq
		[Vector2(e.x, p.y), Vector2(-1, 0), Vector2(0, 1)],   # arriba-der
		[Vector2(e.x, e.y), Vector2(0, -1), Vector2(-1, 0)],  # abajo-der
		[Vector2(p.x, e.y), Vector2(1, 0), Vector2(0, -1)],   # abajo-izq
	]
	var pts := PackedVector2Array()
	for i in 4:
		var c: float = cuts[i]
		var corner: Vector2 = corners[i][0]
		if c <= 0.0:
			pts.append(corner)
		else:
			pts.append(corner + corners[i][1] * c)
			pts.append(corner + corners[i][2] * c)
	return pts


## Píldora hexagonal «< >» (extremos en punta), como los botones Saltar/Auto.
static func hex_pill(rect: Rect2, tip: float) -> PackedVector2Array:
	var p := rect.position
	var e := rect.end
	var cy := p.y + rect.size.y * 0.5
	return PackedVector2Array([
		Vector2(p.x + tip, p.y), Vector2(e.x - tip, p.y), Vector2(e.x, cy),
		Vector2(e.x - tip, e.y), Vector2(p.x + tip, e.y), Vector2(p.x, cy),
	])


## Texto con espaciado entre letras (para rótulos tipo «R E G I Ó N»).
static func draw_spaced(ci: CanvasItem, font: Font, pos: Vector2, text: String, size: int,
		spacing: float, color: Color) -> float:
	var x := pos.x
	for ch in text:
		ci.draw_string(font, Vector2(x, pos.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
		x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + spacing
	return x - pos.x - spacing


static func spaced_width(font: Font, text: String, size: int, spacing: float) -> float:
	var w := 0.0
	for ch in text:
		w += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + spacing
	return maxf(w - spacing, 0.0)
