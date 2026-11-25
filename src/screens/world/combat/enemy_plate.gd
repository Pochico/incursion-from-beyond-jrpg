class_name EnemyPlate
extends Control
## Placa del rival dentro del visor: nombre, nivel, barra de PV y, si se ha
## analizado, los PV numéricos y su ataque. Con estados alterados, pastillas bajo
## la placa y la barra late con el color del estado perjudicial (StatusBadges).

var character_id := ""
var level := 1
var pv := 0.0:
	set(value):
		pv = value
		queue_redraw()
var pv_max := 1
var analyzed := false:
	set(value):
		analyzed = value
		queue_redraw()
var attack_text := ""
var tag := "RIVAL"
## Estados alterados: [{id, turns}] (StatusBadges.from_fighter).
var statuses: Array = []:
	set(value):
		statuses = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(560, 120)


func setup(fighter: Dictionary) -> void:
	character_id = fighter.id
	level = fighter.level
	pv_max = fighter.pv_max
	pv = fighter.pv
	attack_text = fighter.attack
	for skill_id: String in fighter.get("skills", []):
		attack_text += " · " + SkillDB.display_name(skill_id)
	var nature: String = fighter.get("nature", "")
	tag = SkillDB.NATURE_NAMES.get(nature, "RIVAL").to_upper() if CharacterDB.is_enemy(character_id) else "RIVAL"


func _process(_delta: float) -> void:
	if StatusBadges.debuff_color(statuses).a > 0.0:
		queue_redraw()


func animate_pv(value: int) -> void:
	create_tween().tween_property(self, "pv", float(value), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var color := CharacterDB.color(character_id)
	var shape := UIStyle.chamfer_rect(Rect2(Vector2.ZERO, size), [0.0, 22.0, 0.0, 22.0])
	draw_colored_polygon(shape, Color(UIStyle.INK, 0.82))
	UIStyle.draw_outline(self, shape, UIStyle.LINE, 1.5)

	# Fila 1: barra de color, nombre, etiqueta RIVAL y nivel.
	draw_colored_polygon(UIStyle.slanted_rect(Rect2(20, 16, 12, 40), 6), color)
	var name_text := CharacterDB.display_name(character_id)
	draw_string(UIStyle.FONT_BOLD_ITALIC, Vector2(46, 50), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, UIStyle.WHITE)
	var nw := UIStyle.FONT_BOLD_ITALIC.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 36).x
	UIStyle.draw_spaced(self, UIStyle.FONT_MEDIUM, Vector2(46 + nw + 16, 48), tag, 14, 3.0, color)
	draw_string(UIStyle.FONT_REGULAR, Vector2(0, 46), "Nivel %d" % level, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 36, 20, UIStyle.WHITE)

	# Fila 2: PV (los números solo tras analizar).
	var bx := 46.0
	var bw := size.x - bx - 36
	var pv_txt := ("%d / %d" % [roundi(pv), pv_max]) if analyzed else "??? / ???"
	draw_string(UIStyle.FONT_MEDIUM, Vector2(bx, 80), "PV", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, color)
	draw_string(UIStyle.FONT_MEDIUM, Vector2(bx, 80), pv_txt, HORIZONTAL_ALIGNMENT_RIGHT, bw, 18, UIStyle.WHITE)
	var bar := Rect2(Vector2(bx, 88), Vector2(bw, 7))
	draw_rect(bar, Color(UIStyle.WHITE, 0.15))
	draw_rect(Rect2(bar.position, Vector2(bw * clampf(pv / pv_max, 0.0, 1.0), 7)), color)
	var bad := StatusBadges.debuff_color(statuses)
	if bad.a > 0.0:
		# Marco que late alrededor de la barra y rayas del color del estado.
		var p := StatusBadges.pulse()
		draw_rect(bar.grow(3.0), Color(bad, 0.45 + 0.55 * p), false, 2.0)
		for i in int(bw / 18.0):
			var sx := bx + i * 18.0
			draw_line(Vector2(sx, bar.end.y), Vector2(sx + 6, bar.position.y), Color(bad, 0.35 + 0.3 * p), 2.0)

	# Estados: pastillas justo debajo de la placa.
	if not statuses.is_empty():
		StatusBadges.draw_row(self, Vector2(20, size.y + 6), statuses, 15, size.x - 20)

	# Fila 3: ataque (tras analizar).
	if analyzed:
		draw_string(UIStyle.FONT_REGULAR_ITALIC, Vector2(bx, 113), attack_text, HORIZONTAL_ALIGNMENT_LEFT, bw, 17, Color(UIStyle.WHITE, 0.75))
