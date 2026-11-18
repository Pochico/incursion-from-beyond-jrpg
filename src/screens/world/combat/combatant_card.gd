class_name CombatantCard
extends Control
## Ficha de un miembro del grupo en combate (columna derecha de la referencia):
## miniatura, «01 Aiden», «Nivel 14», barras de PV (lima) y PM (cian) y emblema.
## Sin datos (`character_id` vacío) se dibuja como hueco libre.

const PM_COLOR := Color("27b4f5")
const CUT := 14.0

var character_id := ""
var slot := 1
var level := 1
var pv := 0.0:
	set(value):
		pv = value
		queue_redraw()
var pv_max := 1
var pm := 0.0:
	set(value):
		pm = value
		queue_redraw()
var pm_max := 1
var guarding := false:
	set(value):
		guarding = value
		queue_redraw()

var _flash := 0.0
var _texture: Texture2D
## Región de la cara dentro del retrato (px de textura) para la miniatura.
var _face_region := Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(id: String, slot_index: int, fighter: Dictionary = {}) -> void:
	character_id = id
	slot = slot_index
	if id == "":
		queue_redraw()
		return
	_texture = CharacterDB.portrait(id)
	_face_region = CharacterDB.get_character(id).get("face", Rect2(Vector2.ZERO, _texture.get_size() * 0.4))
	level = fighter.get("level", 1)
	pv_max = fighter.get("pv_max", 1)
	pm_max = maxi(fighter.get("pm_max", 1), 1)
	pv = fighter.get("pv", 0)
	pm = fighter.get("pm", 0)


## Anima la barra de PV hasta `value`.
func animate_pv(value: int) -> void:
	create_tween().tween_property(self, "pv", float(value), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func flash(color: Color = UIStyle.RED) -> void:
	var t := create_tween()
	t.tween_method(func(v: float) -> void:
		_flash = v
		queue_redraw(), 1.0, 0.0, 0.5)
	_flash_color = color


var _flash_color := UIStyle.RED


func _draw() -> void:
	var s := size
	var shape := UIStyle.chamfer_rect(Rect2(Vector2.ZERO, s), [CUT, 0.0, CUT, 0.0])
	if character_id == "":
		draw_colored_polygon(shape, Color(UIStyle.NIGHT, 0.45))
		UIStyle.draw_outline(self, shape, Color(UIStyle.WHITE, 0.25), 1.5)
		UIStyle.draw_spaced(self, UIStyle.FONT_REGULAR, Vector2(s.x * 0.5 - 40, s.y * 0.5 + 8), "LIBRE", 18, 4.0, Color(UIStyle.WHITE, 0.3))
		return

	var color := CharacterDB.color(character_id)
	draw_colored_polygon(shape, Color(UIStyle.INK, 0.92))
	if _flash > 0.0:
		draw_colored_polygon(shape, Color(_flash_color, 0.35 * _flash))
	UIStyle.draw_outline(self, shape, UIStyle.LINE, 1.5)
	# Esquina de color.
	draw_colored_polygon(PackedVector2Array([Vector2(0, CUT), Vector2(CUT, 0), Vector2(CUT + 26, 0), Vector2(0, CUT + 26)]), color)

	# Miniatura.
	var thumb := Rect2(Vector2(14, 10), Vector2(s.y - 20, s.y - 20))
	draw_rect(thumb, Color(UIStyle.GRAPHITE, 1.0))
	if _texture:
		draw_texture_rect_region(_texture, thumb, _face_region)
	draw_rect(thumb, Color(UIStyle.WHITE, 0.35), false, 1.0)

	# Textos.
	var x := thumb.end.x + 18
	var right := s.x - 70
	draw_string(UIStyle.FONT_MEDIUM, Vector2(x, 30), "%02d" % slot, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(UIStyle.WHITE, 0.8))
	draw_string(UIStyle.FONT_MEDIUM, Vector2(x + 30, 31), CharacterDB.display_name(character_id), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UIStyle.WHITE)
	draw_string(UIStyle.FONT_REGULAR, Vector2(x, 31), "Nivel %d" % level, HORIZONTAL_ALIGNMENT_RIGHT, right - x, 19, UIStyle.WHITE)

	_bar(Vector2(x, 44), right - x, "PV", pv, pv_max, UIStyle.LIME)
	_bar(Vector2(x, 72), right - x, "PM", pm, pm_max, PM_COLOR)

	# Emblema (escudo; resaltado si está en guardia).
	UIIcons.shield(self, Vector2(s.x - 34, s.y * 0.5), 34, UIStyle.LIME if guarding else Color(UIStyle.WHITE, 0.85))


func _bar(pos: Vector2, width: float, label: String, value: float, max_value: int, color: Color) -> void:
	draw_string(UIStyle.FONT_MEDIUM, pos + Vector2(0, 14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, color)
	var txt := "%d / %d" % [roundi(value), max_value]
	draw_string(UIStyle.FONT_MEDIUM, pos + Vector2(0, 14), txt, HORIZONTAL_ALIGNMENT_RIGHT, width, 17, UIStyle.WHITE)
	var bar := Rect2(pos + Vector2(0, 19), Vector2(width, 5))
	draw_rect(bar, Color(UIStyle.WHITE, 0.15))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(value / max_value, 0.0, 1.0), bar.size.y)), color)
