class_name StatusBadges
extends RefCounted
## Marcas de estados alterados en combate (placa del rival y fichas del grupo).
##
## Cada estado es una pastilla con el color de su origen (biológico, tecnológico,
## psíquico o arquetípico): rellena si es perjudicial, solo con borde si es una
## mejora. La barra o el retrato de quien tiene un estado perjudicial late con ese color.

const ORIGIN_COLORS := {
	"bio": Color("c6f432"), "tech": Color("27b4f5"), "psy": Color("ff7ad9"), "arcane": Color("9b5cf0"),
}


## [{id, turns}] a partir de los estados de un luchador (Battle).
static func from_fighter(fighter: Dictionary) -> Array:
	var out := []
	var statuses: Dictionary = fighter.get("statuses", {})
	for id: String in statuses:
		out.append({"id": id, "turns": int(statuses[id].get("turns", 0))})
	return out


static func color_of(id: String) -> Color:
	return ORIGIN_COLORS.get(SkillDB.status(id).get("origin", ""), UIStyle.WHITE)


static func is_debuff(id: String) -> bool:
	return SkillDB.status(id).get("debuff", false)


## Color del primer estado perjudicial (para el latido) o transparente si no hay.
static func debuff_color(list: Array) -> Color:
	for s: Dictionary in list:
		if is_debuff(s.id):
			return color_of(s.id)
	return Color.TRANSPARENT


## Intensidad del latido (0..1) en este instante.
static func pulse() -> float:
	return 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 1.2)


## Pastillas en fila desde `pos` (esquina superior izquierda) hasta `max_w` de ancho.
## Devuelve el ancho usado.
static func draw_row(ci: CanvasItem, pos: Vector2, list: Array, font_size: int = 14, max_w: float = 1e9) -> float:
	var x := pos.x
	var h := font_size + 8.0
	for s: Dictionary in list:
		var label := "%s %d" % [String(SkillDB.STATUS_NAMES.get(s.id, s.id)).to_upper(), s.turns]
		var tw := UIStyle.FONT_SEMIBOLD.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var w := tw + 22.0
		if x + w - pos.x > max_w:
			break
		var col := color_of(s.id)
		var shape := UIStyle.slanted_rect(Rect2(x, pos.y, w, h), 6)
		if is_debuff(s.id):
			ci.draw_colored_polygon(shape, col)
			ci.draw_string(UIStyle.FONT_SEMIBOLD, Vector2(x + 11, pos.y + h - 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UIStyle.INK)
		else:
			ci.draw_colored_polygon(shape, Color(UIStyle.INK, 0.85))
			UIStyle.draw_outline(ci, shape, col, 1.5)
			ci.draw_string(UIStyle.FONT_SEMIBOLD, Vector2(x + 11, pos.y + h - 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
		x += w + 4.0
	return x - pos.x


## Rombos pequeños (uno por estado) centrados en `center`, para encima de un retrato.
static func draw_dots(ci: CanvasItem, center: Vector2, list: Array, r: float = 6.0) -> void:
	var n := list.size()
	var step := r * 2.6
	var x0 := center.x - (n - 1) * step * 0.5
	for i in n:
		var c := Vector2(x0 + i * step, center.y)
		var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
		var col := color_of(list[i].id)
		ci.draw_colored_polygon(pts, col if is_debuff(list[i].id) else Color(UIStyle.INK, 0.9))
		pts.append(pts[0])
		ci.draw_polyline(pts, UIStyle.INK if is_debuff(list[i].id) else col, 1.5, true)
