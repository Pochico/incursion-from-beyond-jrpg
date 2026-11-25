class_name AttackFx
extends Control
## Animación de un golpe según su tipo, dibujada sobre quien lo recibe.
##
## Tipos: "fisico" (ataque básico) y las naturalezas de SkillDB: "biological"
## (zarpazos y salpicadura), "mechanical" (impacto, onda y chispas), "digital"
## (fallo de imagen: bloques y franjas), "psychic" (anillos que se cierran y
## estallan) y "mystic" (sello que se dibuja y columna de luz).
##
## Uso: await AttackFx.play(capa, centro, tipo, escala).done

signal done

const DURATION := {
	"fisico": 0.34, "biological": 0.5, "mechanical": 0.45, "digital": 0.5, "psychic": 0.6, "mystic": 0.7,
}
const KINDS: Array[String] = ["fisico", "biological", "mechanical", "digital", "psychic", "mystic"]

var kind := "fisico"
var color := UIStyle.LIME
var k := 1.0                ## escala (1 = sobre el rival; menos sobre una ficha)
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _bits: Array = []       ## datos al azar fijos durante la animación


## Tipo de animación de un golpe: la naturaleza de la habilidad o, en un ataque
## básico, la del atacante si es una criatura (los del grupo, físico).
static func kind_for(skill_id: String, source_nature: String = "") -> String:
	var nature: String = SkillDB.get_skill(skill_id).get("nature", "") if skill_id != "" else source_nature
	return nature if nature in KINDS else "fisico"


static func play(layer: Control, center: Vector2, fx_kind: String, scale_k: float = 1.0) -> AttackFx:
	var fx := AttackFx.new()
	fx.kind = fx_kind if fx_kind in KINDS else "fisico"
	fx.color = UIStyle.LIME if fx.kind == "fisico" else SkillDB.nature_color(fx.kind)
	fx.k = scale_k
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.position = center
	layer.add_child(fx)
	fx._start()
	return fx


func _start() -> void:
	_rng.randomize()
	for i in 24:
		_bits.append(Vector4(_rng.randf(), _rng.randf(), _rng.randf(), _rng.randf()))
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		_t = v
		queue_redraw(), 0.0, 1.0, DURATION[kind])
	tw.finished.connect(func() -> void:
		done.emit()
		queue_free())


func _draw() -> void:
	match kind:
		"biological":
			_draw_bio()
		"mechanical":
			_draw_mech()
		"digital":
			_draw_digital()
		"psychic":
			_draw_psychic()
		"mystic":
			_draw_mystic()
		_:
			_draw_slash()


# --- Físico: tajo doble en aspa ------------------------------------------------------------

func _draw_slash() -> void:
	for i in 2:
		var p := clampf(_t * 1.6 - i * 0.35, 0.0, 1.0)
		if p <= 0.0:
			continue
		var dir := Vector2(1, -0.77) if i == 0 else Vector2(1, 0.77)
		var a := -dir * 260 * k
		var b := dir * 260 * k
		var head := a.lerp(b, minf(p * 1.4, 1.0))
		var tail := a.lerp(b, maxf(p * 1.4 - 0.5, 0.0))
		draw_line(tail, head, Color(color, 0.9), 18.0 * k, true)
		draw_line(tail, head, UIStyle.WHITE, 6.0 * k, true)


# --- Biológico: tres zarpazos y salpicadura ---------------------------------------------------

func _draw_bio() -> void:
	for i in 3:
		var p := clampf(_t * 2.2 - i * 0.18, 0.0, 1.0)
		if p <= 0.0:
			continue
		var off := Vector2((i - 1) * 46.0, (i - 1) * -14.0) * k
		var a := off + Vector2(-110, -170) * k
		var b := off + Vector2(70, 170) * k
		var head := a.lerp(b, minf(p * 1.3, 1.0))
		var tail := a.lerp(b, maxf(p * 1.3 - 0.6, 0.0))
		var fade := clampf((1.0 - _t) * 2.5, 0.0, 1.0)
		draw_line(tail, head, Color(color.darkened(0.3), 0.85 * fade), 14.0 * k, true)
		draw_line(tail, head, Color(UIStyle.WHITE, 0.8 * fade), 4.0 * k, true)
	# Gotas que salen despedidas.
	var sp := clampf((_t - 0.25) / 0.75, 0.0, 1.0)
	if sp > 0.0:
		for b: Vector4 in _bits.slice(0, 14):
			var ang := b.x * TAU
			var dist := (60.0 + b.y * 200.0) * sp * k
			var pos := Vector2.from_angle(ang) * dist + Vector2(0, 120 * sp * sp * k)
			var r := (4.0 + b.z * 9.0) * k * (1.0 - sp * 0.6)
			draw_circle(pos, r, Color(color, 1.0 - sp))


# --- Mecánico: impacto, onda expansiva y chispas -----------------------------------------------

func _draw_mech() -> void:
	# Destello del impacto.
	var flash := clampf(1.0 - _t * 4.0, 0.0, 1.0)
	if flash > 0.0:
		draw_circle(Vector2.ZERO, 90.0 * k, Color(UIStyle.WHITE, 0.8 * flash))
	# Dos ondas.
	for i in 2:
		var p := clampf(_t * 1.4 - i * 0.2, 0.0, 1.0)
		if p <= 0.0 or p >= 1.0:
			continue
		var r := (40.0 + 260.0 * p) * k
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(color, 1.0 - p), (14.0 - 10.0 * p) * k, true)
	# Chispas en línea recta.
	for b: Vector4 in _bits.slice(0, 16):
		var ang := b.x * TAU
		var p := clampf(_t * (1.2 + b.y), 0.0, 1.0)
		var d0 := (30.0 + 240.0 * p) * k
		var d1 := d0 + (30.0 + b.z * 40.0) * (1.0 - p) * k
		var dir := Vector2.from_angle(ang)
		draw_line(dir * d0, dir * d1, Color(UIStyle.WHITE.lerp(color, b.w), 1.0 - p), 3.0 * k, true)


# --- Digital: fallo de imagen ---------------------------------------------------------------

func _draw_digital() -> void:
	var on := 1.0 - _t
	# Franjas horizontales desplazadas.
	for i in 8:
		var b: Vector4 = _bits[i]
		if fmod(_t * 14.0 + b.x * 3.0, 1.0) < 0.35:
			continue
		var y := (b.y - 0.5) * 420.0 * k
		var w := (120.0 + b.z * 300.0) * k
		var x := (b.w - 0.5) * 220.0 * k + sin(_t * 40.0 + i) * 30.0 * k
		draw_rect(Rect2(x - w * 0.5, y, w, (4.0 + b.x * 10.0) * k), Color(color, 0.75 * on))
	# Bloques de píxeles cian y magenta.
	for i in range(8, 24):
		var b: Vector4 = _bits[i]
		if fmod(_t * 10.0 + b.w * 5.0, 1.0) < 0.4:
			continue
		var s := (14.0 + b.z * 30.0) * k
		var pos := Vector2((b.x - 0.5) * 380.0, (b.y - 0.5) * 420.0) * k
		var col := color if i % 2 == 0 else UIStyle.MAGENTA
		draw_rect(Rect2(pos, Vector2(s, s * 0.6)), Color(col, 0.85 * on))
	# Retícula que se cierra al principio.
	var lock := clampf(_t * 3.0, 0.0, 1.0)
	var half := lerpf(220.0, 70.0, lock) * k
	var a := clampf((1.0 - _t) * 2.0, 0.0, 1.0)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var c := Vector2(sx * half, sy * half)
			draw_line(c, c - Vector2(sx * 30.0 * k, 0), Color(UIStyle.WHITE, a), 3.0 * k)
			draw_line(c, c - Vector2(0, sy * 30.0 * k), Color(UIStyle.WHITE, a), 3.0 * k)


# --- Psíquico: anillos que se cierran y estallan -----------------------------------------------

func _draw_psychic() -> void:
	if _t < 0.55:
		var p := _t / 0.55
		for i in 4:
			var q := fmod(p + i * 0.25, 1.0)
			var r := lerpf(300.0, 20.0, q) * k
			var wob := 0.0
			var pts := PackedVector2Array()
			for s in 41:
				var ang := s / 40.0 * TAU
				wob = sin(ang * 6.0 + p * 20.0 + i) * 8.0 * k
				pts.append(Vector2.from_angle(ang) * (r + wob))
			draw_polyline(pts, Color(color, 0.25 + 0.6 * q), 4.0 * k, true)
	else:
		var p := (_t - 0.55) / 0.45
		draw_circle(Vector2.ZERO, lerpf(40.0, 320.0, p) * k, Color(color, 0.35 * (1.0 - p)))
		draw_arc(Vector2.ZERO, lerpf(40.0, 340.0, p) * k, 0.0, TAU, 64, Color(UIStyle.WHITE, 1.0 - p), 6.0 * k, true)


# --- ARQ: sello que se dibuja y columna de luz ----------------------------------------------

func _draw_mystic() -> void:
	var r := 190.0 * k
	var draw_p := clampf(_t / 0.5, 0.0, 1.0)
	var fade := clampf((1.0 - _t) / 0.3, 0.0, 1.0)
	var rot := _t * 1.5
	var col := Color(color, 0.9 * fade)
	# Círculo exterior que se traza.
	draw_arc(Vector2.ZERO, r, rot, rot + TAU * draw_p, 64, col, 4.0 * k, true)
	draw_arc(Vector2.ZERO, r * 0.82, -rot, -rot - TAU * draw_p, 64, Color(col, col.a * 0.6), 2.0 * k, true)
	# Estrella de cinco puntas.
	var star := PackedVector2Array()
	for i in 6:
		star.append(Vector2.from_angle(rot - PI / 2 + i * TAU * 2.0 / 5.0) * r * 0.82)
	var segs := draw_p * 5.0
	for i in 5:
		var f := clampf(segs - i, 0.0, 1.0)
		if f > 0.0:
			draw_line(star[i], star[i].lerp(star[i + 1], f), col, 3.0 * k, true)
	# Columna de luz al completarse.
	var beam := clampf((_t - 0.45) / 0.55, 0.0, 1.0)
	if beam > 0.0:
		var w := 120.0 * k * sin(beam * PI)
		draw_rect(Rect2(-w * 0.5, -600.0 * k, w, 1200.0 * k), Color(UIStyle.WHITE, 0.35 * sin(beam * PI)))
		draw_rect(Rect2(-w * 0.2, -600.0 * k, w * 0.4, 1200.0 * k), Color(UIStyle.WHITE, 0.6 * sin(beam * PI)))
