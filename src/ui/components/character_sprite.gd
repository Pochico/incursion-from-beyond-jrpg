@tool
class_name CharacterSprite
extends Control
## Imagen de personaje alineada abajo y centrada en su rectángulo.
##
## - En escenarios: interactivo, con silueta y brillo del color del personaje.
##   Solo responde al ratón sobre píxeles opacos.
## - En conversación: sin brillo, con `dim` para atenuar a quien no habla, y
##   `change_texture` para cambiar de gesto con un fundido breve.

signal activated

const SHADER := preload("res://src/ui/shaders/character_glow.gdshader")
## Margen extra (px de pantalla) alrededor de la imagen para que quepa el brillo.
const GLOW_MARGIN := 40.0

@export var texture: Texture2D:
	set(value):
		texture = value
		_image = null
		_head_px = Vector2(-1, -1)
		queue_redraw()

@export var glow_color: Color = UIStyle.LIME:
	set(value):
		glow_color = value
		_update_shader()

## Brillo en reposo (0..1). Al pasar el ratón o seleccionarlo sube a `glow_active`.
@export_range(0.0, 1.0) var glow_idle: float = 0.0:
	set(value):
		glow_idle = value
		_glow = value
		_update_shader()

@export_range(0.0, 1.0) var glow_active: float = 1.0
@export var outline_screen_px: float = 2.5
## Alcance del halo en reposo; al seleccionarlo crece hasta `glow_screen_px * 1.8`.
@export var glow_screen_px: float = 12.0

@export_range(0.0, 1.0) var dim: float = 0.0:
	set(value):
		dim = value
		_update_shader()

## Si es true, la imagen ocupa exactamente el rectángulo del control aunque
## eso cambie sus proporciones (objetos encajados sobre un fondo).
@export var stretch: bool = false:
	set(value):
		stretch = value
		queue_redraw()

## Desplazamiento horizontal del dibujo (para animar entradas).
@export var slide: float = 0.0:
	set(value):
		slide = value
		queue_redraw()

@export var interactive: bool = false:
	set(value):
		interactive = value
		focus_mode = Control.FOCUS_ALL if value else Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if value else Control.CURSOR_ARROW

## Desplazamientos breves al cambiar de gesto (salto, sacudida).
enum Motion { NONE, HOP, SHAKE }

var _glow := 0.0
var _time := 0.0
var _image: Image
var _head_px := Vector2(-1, -1)
var _tween: Tween
## Gesto anterior mientras dura el fundido (`_fade` de 0 a 1).
var _old_texture: Texture2D
var _fade := 1.0
var _jolt := Vector2.ZERO
var _change_tween: Tween


func _init() -> void:
	material = ShaderMaterial.new()
	material.shader = SHADER
	interactive = interactive


func _ready() -> void:
	focus_entered.connect(_refresh_glow)
	focus_exited.connect(_refresh_glow)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_refresh_glow)
	_update_shader()


func _process(delta: float) -> void:
	if not interactive or Engine.is_editor_hint():
		return
	# Pulso suave mientras está seleccionado.
	_time += delta
	if has_focus():
		_set_shader("glow_strength", _glow * (0.85 + 0.15 * sin(_time * 5.0)))


func _on_mouse_entered() -> void:
	if interactive and not Engine.is_editor_hint() and not has_focus():
		grab_focus()
	_refresh_glow()


func _refresh_glow() -> void:
	var target := glow_active if (has_focus() and interactive) else glow_idle
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(func(v: float) -> void:
		_glow = v
		_update_shader(), _glow, target, 0.18)


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Diferido: Godot asigna el foco del clic después de este evento, y
		# así quien reaccione a `activated` (p. ej. un menú) se queda el foco.
		activated.emit.call_deferred()
		accept_event()
	elif event.is_action_pressed("ui_accept"):
		activated.emit()
		accept_event()


# --- Cambio de gesto -----------------------------------------------------------

## Cambia la imagen con un fundido corto y, si se pide, un salto o una sacudida.
func change_texture(tex: Texture2D, motion: Motion = Motion.NONE) -> void:
	if tex == texture:
		return
	if _change_tween:
		_change_tween.kill()
	_old_texture = texture
	texture = tex
	_jolt = Vector2.ZERO
	_change_tween = create_tween().set_parallel(true)
	_change_tween.tween_method(_set_fade, 0.0, 1.0, 0.22)
	match motion:
		Motion.HOP:
			_change_tween.tween_method(_set_jolt, Vector2.ZERO, Vector2(0, -22), 0.1) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_change_tween.tween_method(_set_jolt, Vector2(0, -22), Vector2.ZERO, 0.16).set_delay(0.1) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		Motion.SHAKE:
			var steps: Array[float] = [10.0, -8.0, 5.0, -2.0, 0.0]
			for i in steps.size():
				var from := Vector2(steps[i - 1] if i > 0 else 0.0, 0)
				_change_tween.tween_method(_set_jolt, from, Vector2(steps[i], 0), 0.05).set_delay(i * 0.05)
	_change_tween.chain().tween_callback(func() -> void: _old_texture = null)


func _set_fade(v: float) -> void:
	_fade = v
	queue_redraw()


func _set_jolt(v: Vector2) -> void:
	_jolt = v
	queue_redraw()


# --- Geometría -----------------------------------------------------------------

## Rectángulo (en coordenadas locales) donde se dibuja la imagen, sin margen.
## Ocupa toda la altura salvo que la imagen sea más ancha que el control
## (p. ej. criaturas apaisadas): entonces se ajusta al ancho, apoyada abajo.
func image_rect(tex: Texture2D = texture) -> Rect2:
	if tex == null:
		return Rect2()
	if stretch:
		return Rect2(Vector2(slide, 0.0) + _jolt, size)
	var tex_size := tex.get_size()
	var s := _scale(tex)
	var w := tex_size.x * s
	var h := tex_size.y * s
	return Rect2(Vector2((size.x - w) * 0.5 + slide, size.y - h) + _jolt, Vector2(w, h))


## Escala por eje entre la textura y la pantalla.
func _scale2(tex: Texture2D = texture) -> Vector2:
	if stretch and tex:
		return size / tex.get_size()
	return Vector2.ONE * _scale(tex)


func _scale(tex: Texture2D = texture) -> float:
	if tex == null:
		return 1.0
	var tex_size := tex.get_size()
	return minf(size.y / tex_size.y, size.x / tex_size.x) if size.x > 0.0 else size.y / tex_size.y


func _draw() -> void:
	# Durante un cambio de gesto, el anterior se desvanece mientras aparece el nuevo.
	if _old_texture != null and _fade < 1.0:
		_draw_image(_old_texture, clampf(2.0 * (1.0 - _fade), 0.0, 1.0))
		_draw_image(texture, clampf(2.0 * _fade, 0.0, 1.0))
	else:
		_draw_image(texture, 1.0)


func _draw_image(tex: Texture2D, alpha: float) -> void:
	if tex == null:
		return
	var rect := image_rect(tex)
	var s := _scale2(tex)
	var m := GLOW_MARGIN
	# Dibujamos un rectángulo más grande (salvo por abajo) con UV fuera de rango:
	# el shader los trata como transparentes y ahí pinta el halo.
	var draw_rect_big := Rect2(rect.position - Vector2(m, m), rect.size + Vector2(m * 2.0, m))
	var src := Rect2(Vector2(-m, -m) / s, (rect.size + Vector2(m * 2.0, m)) / s)
	draw_texture_rect_region(tex, draw_rect_big, src, Color(1, 1, 1, alpha), false, false)


## Punto aproximado de la coronilla (en coordenadas locales), calculado a partir
## de los píxeles opacos de la parte superior de la imagen. Sirve para colocar
## indicadores encima de la cabeza aunque no esté centrada en el retrato.
func head_point() -> Vector2:
	var rect := image_rect()
	var img := _get_image()
	if img == null:
		return Vector2(rect.get_center().x, rect.position.y)
	if _head_px == Vector2(-1, -1):
		_head_px = _find_head(img)
	return rect.position + _head_px * _scale2()


func _find_head(img: Image) -> Vector2:
	var w := img.get_width()
	var h := img.get_height()
	var top := -1
	# Primera fila con suficientes píxeles opacos.
	for y in range(0, h, 4):
		var count := 0
		for x in range(0, w, 4):
			if img.get_pixel(x, y).a > 0.5:
				count += 1
		if count >= 4:
			top = y
			break
	if top < 0:
		return Vector2(w * 0.5, 0)
	# Centro horizontal de la masa opaca en una franja bajo esa fila.
	var band := int(h * 0.08)
	var sum := 0.0
	var n := 0
	for y in range(top, mini(top + band, h), 6):
		for x in range(0, w, 6):
			if img.get_pixel(x, y).a > 0.5:
				sum += x
				n += 1
	return Vector2(sum / maxf(n, 1), top)


func _get_image() -> Image:
	if _image == null and texture != null:
		_image = texture.get_image()
		if _image != null and _image.is_compressed():
			_image.decompress()
	return _image


func _has_point(point: Vector2) -> bool:
	if not interactive or texture == null:
		return false
	var rect := image_rect()
	if not rect.has_point(point):
		return false
	if _get_image() == null:
		return true
	var px := Vector2i((point - rect.position) / _scale2())
	px = px.clamp(Vector2i.ZERO, _image.get_size() - Vector2i.ONE)
	return _image.get_pixelv(px).a > 0.3


func _update_shader() -> void:
	if material == null:
		return
	var s := _scale()
	_set_shader("glow_color", glow_color)
	_set_shader("glow_strength", _glow)
	_set_shader("outline_px", outline_screen_px / s)
	_set_shader("glow_px", glow_screen_px * (1.0 + 0.8 * _focus_amount()) / s)
	_set_shader("halo_gain", 0.8 + 0.4 * _focus_amount())
	_set_shader("dim", dim)


## 0 en reposo, 1 con el brillo activo al máximo.
func _focus_amount() -> float:
	if glow_active <= glow_idle:
		return 0.0
	return clampf((_glow - glow_idle) / (glow_active - glow_idle), 0.0, 1.0)


func _set_shader(param: String, value: Variant) -> void:
	(material as ShaderMaterial).set_shader_parameter(param, value)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_shader()
