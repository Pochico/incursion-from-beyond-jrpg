class_name ToolTheme
extends RefCounted
## Tema para herramientas internas: controles estándar de Godot (Button,
## OptionButton, LineEdit, HSlider, PopupMenu…) con la estética del juego.

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = UIStyle.FONT_REGULAR
	t.default_font_size = 22

	t.set_color("font_color", "Label", UIStyle.WHITE)

	# Botones (también los usa OptionButton por herencia).
	var normal := _box(Color(UIStyle.NIGHT, 0.95), Color(UIStyle.WHITE, 0.45))
	var hover := _box(Color(UIStyle.NIGHT.lightened(0.08), 0.95), UIStyle.LIME)
	var pressed := _box(UIStyle.LIME, UIStyle.LIME)
	var disabled := _box(Color(UIStyle.NIGHT, 0.5), Color(UIStyle.WHITE, 0.15))
	var focus := _box(Color(0, 0, 0, 0), UIStyle.LIME, 2)
	for type in ["Button", "OptionButton"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("hover_pressed", type, pressed)
		t.set_stylebox("disabled", type, disabled)
		t.set_stylebox("focus", type, focus)
		t.set_color("font_color", type, UIStyle.WHITE)
		t.set_color("font_hover_color", type, UIStyle.LIME)
		t.set_color("font_pressed_color", type, UIStyle.INK)
		t.set_color("font_hover_pressed_color", type, UIStyle.INK)
		t.set_color("font_focus_color", type, UIStyle.WHITE)
		t.set_color("font_disabled_color", type, Color(UIStyle.WHITE, 0.3))
		t.set_font("font", type, UIStyle.FONT_MEDIUM)

	# Campos de texto.
	t.set_stylebox("normal", "LineEdit", _box(Color(UIStyle.INK, 0.9), Color(UIStyle.WHITE, 0.4)))
	t.set_stylebox("focus", "LineEdit", _box(Color(0, 0, 0, 0), UIStyle.LIME, 2))
	t.set_color("font_color", "LineEdit", UIStyle.WHITE)
	t.set_color("caret_color", "LineEdit", UIStyle.LIME)
	t.set_color("selection_color", "LineEdit", Color(UIStyle.VIOLET, 0.6))

	# Deslizadores.
	var track := StyleBoxFlat.new()
	track.bg_color = Color(UIStyle.WHITE, 0.15)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill := StyleBoxFlat.new()
	fill.bg_color = UIStyle.LIME
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _square_icon(18, UIStyle.WHITE))
	t.set_icon("grabber_highlight", "HSlider", _square_icon(18, UIStyle.LIME))
	t.set_icon("grabber_disabled", "HSlider", _square_icon(18, UIStyle.GRAY))

	# Menús desplegables.
	t.set_stylebox("panel", "PopupMenu", _box(Color(UIStyle.NIGHT.darkened(0.3), 0.98), Color(UIStyle.WHITE, 0.5)))
	t.set_stylebox("hover", "PopupMenu", _box(UIStyle.LIME, UIStyle.LIME))
	t.set_color("font_color", "PopupMenu", UIStyle.WHITE)
	t.set_color("font_hover_color", "PopupMenu", UIStyle.INK)
	t.set_font("font", "PopupMenu", UIStyle.FONT_MEDIUM)

	# Paneles y tooltips.
	t.set_stylebox("panel", "PanelContainer", _box(Color(UIStyle.NIGHT.darkened(0.4), 0.96), Color(UIStyle.WHITE, 0.35)))
	t.set_stylebox("panel", "TooltipPanel", _box(Color(UIStyle.INK, 0.95), UIStyle.LIME))
	t.set_color("font_color", "TooltipLabel", UIStyle.WHITE)

	_theme = t
	return t


static func _box(bg: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func _square_icon(size: int, color: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)
