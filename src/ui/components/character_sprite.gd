@tool
class_name CharacterSprite
extends Control
## Imagen de personaje alineada abajo y centrada en su rectángulo.
##
## - En escenarios: interactivo, con silueta y brillo del color del personaje.
##   Solo responde al ratón sobre píxeles opacos.
## - En conversación: sin brillo, con `dim` para atenuar a quien no habla.

signal activated

const SHADER := preload("res://src/ui/shaders/character_glow.gdshader")
## Margen extra (px de pantalla) alrededor de la imagen para que quepa el brillo.
const GLOW_MARGIN := 40.0

@export var texture: Texture2D:
	set(value):
		texture = value
		_image = null
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
@export var outline_screen_px: float = 3.0
@export var glow_screen_px: float = 18.0

@export_range(0.0, 1.0) var dim: float = 0.0:
	set(value):
		dim = value
		_update_shader()

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

var _glow := 0.0
var _time := 0.0
var _image: Image
var _tween: Tween


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


# --- Geometría -----------------------------------------------------------------

## Rectángulo (en coordenadas locales) donde se dibuja la imagen, sin margen.
func image_rect() -> Rect2:
	if texture == null:
		return Rect2()
	var tex_size := texture.get_size()
	var h := size.y
	var w := h * tex_size.x / tex_size.y
	return Rect2(Vector2((size.x - w) * 0.5 + slide, 0.0), Vector2(w, h))


func _scale() -> float:
	return size.y / texture.get_size().y if texture else 1.0


func _draw() -> void:
	if texture == null:
		return
	var rect := image_rect()
	var s := _scale()
	var m := GLOW_MARGIN
	# Dibujamos un rectángulo más grande (salvo por abajo) con UV fuera de rango:
	# el shader los trata como transparentes y ahí pinta el halo.
	var draw_rect_big := Rect2(rect.position - Vector2(m, m), rect.size + Vector2(m * 2.0, m))
	var src := Rect2(Vector2(-m, -m) / s, (rect.size + Vector2(m * 2.0, m)) / s)
	draw_texture_rect_region(texture, draw_rect_big, src, Color.WHITE, false, false)


func _has_point(point: Vector2) -> bool:
	if not interactive or texture == null:
		return false
	var rect := image_rect()
	if not rect.has_point(point):
		return false
	if _image == null:
		_image = texture.get_image()
		if _image == null:
			return true
		if _image.is_compressed():
			_image.decompress()
	var px := Vector2i((point - rect.position) / _scale())
	px = px.clamp(Vector2i.ZERO, _image.get_size() - Vector2i.ONE)
	return _image.get_pixelv(px).a > 0.3


func _update_shader() -> void:
	if material == null:
		return
	var s := _scale()
	_set_shader("glow_color", glow_color)
	_set_shader("glow_strength", _glow)
	_set_shader("outline_px", outline_screen_px / s)
	_set_shader("glow_px", glow_screen_px / s)
	_set_shader("dim", dim)


func _set_shader(param: String, value: Variant) -> void:
	(material as ShaderMaterial).set_shader_parameter(param, value)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_shader()
