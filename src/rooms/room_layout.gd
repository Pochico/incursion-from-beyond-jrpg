@tool
class_name RoomLayout
extends Control
## Plantilla para encajar a mano, en el editor, los objetos examinables de una
## ubicación sobre su imagen de fondo.
##
## - `Fondo` es la imagen de la ubicación a su tamaño real (1 unidad = 1 píxel).
## - Cada otro hijo es un TextureRect cuyo nombre es el id del objeto (ver
##   LocationDB `props`). Muévelo y redimensiónalo con el ratón; el juego usa
##   su rectángulo tal cual (se estira si cambias las proporciones).
## - El orden de los hijos no importa: el de dibujo lo marca LocationDB.
## - `opacidad_objetos` solo sirve para comparar con el fondo mientras editas.

## Transparencia de los objetos en el editor, para ver el fondo de debajo.
@export_range(0.0, 1.0) var opacidad_objetos: float = 1.0:
	set(value):
		opacidad_objetos = value
		for child in get_children():
			if child is CanvasItem and child.name != "Fondo":
				(child as CanvasItem).modulate.a = value


## Rectángulos (en píxeles del fondo) de los objetos de la plantilla `path`:
## id del objeto -> Rect2.
static func load_rects(path: String) -> Dictionary:
	var rects := {}
	if path == "" or not ResourceLoader.exists(path):
		return rects
	var root := (load(path) as PackedScene).instantiate()
	for child in root.get_children():
		if child is Control and child.name != "Fondo":
			var c := child as Control
			rects[String(c.name)] = Rect2(c.offset_left, c.offset_top,
					c.offset_right - c.offset_left, c.offset_bottom - c.offset_top)
	root.free()
	return rects
