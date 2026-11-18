@tool
class_name HintBar
extends HBoxContainer
## Fila de atajos con separadores «/» lima y línea inferior fina con remate violeta.
## Se rellena con `set_items([{ "id": "map", "key": "M", "label": "Mapa", "icon": "" }, ...])`.

signal item_pressed(id: String)


func _ready() -> void:
	add_theme_constant_override("separation", 20)
	alignment = BoxContainer.ALIGNMENT_END


func set_items(items: Array) -> void:
	for child in get_children():
		child.queue_free()
	for i in items.size():
		if i > 0:
			var sep := Control.new()
			sep.custom_minimum_size = Vector2(16, 44)
			sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sep.draw.connect(func() -> void:
				sep.draw_line(Vector2(2, 38), Vector2(16, 6), UIStyle.LIME, 2.0, true))
			add_child(sep)
		var b := KeyHintButton.new()
		b.key_text = items[i].get("key", "")
		b.label = items[i].label
		b.icon_name = items[i].get("icon", "")
		b.pressed.connect(func() -> void: item_pressed.emit(items[i].id))
		add_child(b)


func _draw() -> void:
	var y := size.y + 10.0
	var w := size.x
	draw_line(Vector2(-40, y), Vector2(w - 50, y), Color(UIStyle.WHITE, 0.85), 1.5)
	draw_line(Vector2(w - 44, y), Vector2(w + 6, y), UIStyle.VIOLET, 4.0)
