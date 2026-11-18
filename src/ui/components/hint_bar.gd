@tool
class_name HintBar
extends HBoxContainer
## Fila de atajos con separadores «/» y una línea inferior (lima → violeta).
## Se rellena con `set_items([{ "id": "map", "key": "M", "label": "Mapa" }, ...])`.

signal item_pressed(id: String)


func _ready() -> void:
	add_theme_constant_override("separation", 22)
	alignment = BoxContainer.ALIGNMENT_END


func set_items(items: Array) -> void:
	for child in get_children():
		child.queue_free()
	for i in items.size():
		if i > 0:
			var sep := Label.new()
			sep.text = "/"
			var ls := LabelSettings.new()
			ls.font = UIStyle.FONT_ITALIC
			ls.font_size = 30
			ls.font_color = Color(UIStyle.WHITE, 0.6)
			sep.label_settings = ls
			add_child(sep)
		var b := KeyHintButton.new()
		b.key_text = items[i].key
		b.label = items[i].label
		b.pressed.connect(func() -> void: item_pressed.emit(items[i].id))
		add_child(b)


func _draw() -> void:
	var y := size.y + 8.0
	var w := size.x
	draw_line(Vector2(-30, y), Vector2(w * 0.8, y), Color(UIStyle.WHITE, 0.7), 2.0)
	draw_line(Vector2(w * 0.8, y), Vector2(w + 10, y), UIStyle.VIOLET, 4.0)
