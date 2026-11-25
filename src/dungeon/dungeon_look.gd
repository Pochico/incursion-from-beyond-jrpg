class_name DungeonLook
extends RefCounted
## Estilo visual de la mazmorra (solo la vista 3D de la mazmorra), con lo que
## trae Godot, sin shaders: resolución interna (stretch_shrink del
## SubViewportContainer), filtrado al reescalar y de las texturas, antialiasing,
## niebla y brillo. Prueba: tecla V en la mazmorra va pasando de uno a otro.
##
##   normal  como siempre
##   ps2     ~media resolución reescalada suave, filtrado bilineal sin anisotrópico,
##           sin antialiasing, niebla algo azulada y un poco de brillo
##   ps1     ~320×200 con píxeles nítidos, texturas sin filtrar ni mipmaps,
##           sin antialiasing y niebla cerrada
## Valores de prueba.

const ORDER: Array[String] = ["normal", "ps2", "ps1"]
const PRESETS := {
	"normal": {"name": "Normal", "shrink": 1, "upscale": CanvasItem.TEXTURE_FILTER_LINEAR,
		"msaa": Viewport.MSAA_4X, "textures": BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC,
		"fog": 0.09, "fog_color": Color("0b0b0d"), "glow": false},
	"ps2": {"name": "PS2", "shrink": 2, "upscale": CanvasItem.TEXTURE_FILTER_LINEAR,
		"msaa": Viewport.MSAA_DISABLED, "textures": BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,
		"fog": 0.12, "fog_color": Color("161530"), "glow": true},
	"ps1": {"name": "PS1", "shrink": 4, "upscale": CanvasItem.TEXTURE_FILTER_NEAREST,
		"msaa": Viewport.MSAA_DISABLED, "textures": BaseMaterial3D.TEXTURE_FILTER_NEAREST,
		"fog": 0.16, "fog_color": Color("0b0b0d"), "glow": false},
}

## Estilo en uso (dura lo que la sesión).
static var current := "normal"


static func next() -> String:
	current = ORDER[(ORDER.find(current) + 1) % ORDER.size()]
	return current


## Aplica `current` a la vista: contenedor, su SubViewport y el explorador (entorno
## y materiales de la planta ya construida; las siguientes salen ya así).
static func apply(container: SubViewportContainer, explorer: DungeonExplorer) -> void:
	var p: Dictionary = PRESETS[current]
	container.stretch_shrink = p.shrink
	container.texture_filter = p.upscale
	for ch in container.get_children():
		if ch is SubViewport:
			(ch as SubViewport).msaa_3d = p.msaa
	DungeonBuilder.texture_filter = p.textures
	if explorer == null:
		return
	var e := explorer.environment
	if e:
		e.fog_density = p.fog
		e.fog_light_color = p.fog_color
		e.glow_enabled = p.glow
		e.glow_intensity = 0.9
		e.glow_bloom = 0.15
		e.glow_hdr_threshold = 0.8
	for mi in explorer.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).material_override as StandardMaterial3D
		# Solo suelo, techo y paredes (los materiales de DungeonBuilder.material).
		if m and m.albedo_texture and mi.get_parent() and mi.get_parent().name in ["Estructura", "Techos"]:
			m.texture_filter = p.textures


## «PS1 · 353×194»: para avisar del cambio.
static func label(container: SubViewportContainer) -> String:
	var size := Vector2i(container.size) / int(PRESETS[current].shrink)
	return "%s · %d×%d" % [PRESETS[current].name, size.x, size.y]
