class_name ItemDB
extends RefCounted
## Catálogo de objetos.
##   heal    PV que restaura a quien lo usa
##   pm      PM que restaura a quien lo usa
##   damage  daño al rival (solo en combate)
##   tool    herramienta que no se gasta (el escáner, en la mazmorra)
##   loot    caja: al cogerla se elige abrirla ya o guardarla (se abre cuando
##           quieras desde Objetos o el móvil). Da `loot_always` ([id, cantidad])
##           y una de `loot` ([id de objeto o "money", cantidad, peso])
##   charges cargas del escáner: las que trae en cada incursión (el escáner)
##           o las que añade al usarla (la batería)
##   image   imagen del objeto (si no tiene modelo 3D, se ve así en la mazmorra)
## El modelo 3D de la mazmorra, si existe, es assets/modelos/objetos/<id>.glb.

## El escáner (fase 6): Analizar en combate y pulso en la mazmorra. Ya no se lleva
## desde el principio: se encuentra en la grieta (ver DungeonScreen).
const SCANNER := "escaner"
const MODEL_DIR := "res://assets/modelos/objetos/"

const ALL := {
	"pochicola": {
		"name": "Pochicola",
		"desc": "Refresco con burbujas y un sabor difícil de describir. Restaura %d PV a quien la bebe.",
		"heal": 80,
		"icon": "can",
	},
	"batido": {
		"name": "Batido Chocopolved",
		"desc": "Batido espeso de chocolate en polvo. Despeja la cabeza: restaura %d PM a quien lo bebe.",
		"pm": 30,
		"icon": "flask",
	},
	"granada": {
		"name": "Granada táctica",
		"desc": "Granada de mano de origen dudoso. Solo en combate: hace %d de daño al rival.",
		"damage": 120,
		"icon": "sparkle",
	},
	"caja": {
		"name": "Caja misteriosa",
		"desc": "Una caja sellada. Siempre trae una batería para el escáner, y algo más. Ábrela cuando quieras.",
		"loot_always": [["bateria", 1]],
		"loot": [["pochicola", 2, 35], ["batido", 1, 30], ["granada", 1, 20], ["money", 500, 15]],
		"icon": "lock",
	},
	"escaner": {
		"name": "Escáner",
		"desc": "Aparato de bolsillo que se encuentra en la grieta. En combate analiza a las criaturas; en la mazmorra emite un pulso que recorre 5 casillas alrededor y hace brillar las paredes que esconden algo. Entra en cada incursión con %d cargas; las baterías le dan más.",
		"icon": "antenna",
		"tool": true,
		"charges": 3,
	},
	"bateria": {
		"name": "Batería del escáner",
		"desc": "Pila recargable que encaja en el escáner. En la mazmorra le da %d carga más.",
		"charges": 1,
		"icon": "sparkle",
	},
	"tarjeta_torre": {
		"name": "Tarjeta de acceso",
		"desc": "Tarjeta magnética con el logo de la Torre medio borrado. Abre alguna puerta de dentro.",
		"icon": "lock",
		"image": "res://assets/objetos/tarjeta.png",
	},
	"tarjeta_roja": {
		"name": "Tarjeta de acceso roja",
		"desc": "Tarjeta con una franja roja y un triángulo. La llevaba encima una criatura de lo alto de la Torre. Abre una puerta de las plantas de arriba.",
		"icon": "lock",
		"image": "res://assets/objetos/tarjeta.png",
	},
}


static func get_item(id: String) -> Dictionary:
	return ALL.get(id, {})


static func display_name(id: String) -> String:
	return get_item(id).get("name", id)


static func description(id: String) -> String:
	var item := get_item(id)
	var desc: String = item.get("desc", "")
	if not desc.contains("%d"):
		return desc
	return desc % item.get("heal", item.get("pm", item.get("damage", item.get("charges", 0))))


## ¿Es una caja que se abre? (ver `loot`)
static func is_box(id: String) -> bool:
	return get_item(id).has("loot")


## Cargas del escáner que da (al entrar, el escáner; al usarla, una batería).
static func charges(id: String) -> int:
	return int(get_item(id).get("charges", 0))


## ¿Se bebe o se toma? (cura PV o PM a alguien del grupo)
static func restores(id: String) -> bool:
	return get_item(id).get("heal", 0) > 0 or get_item(id).get("pm", 0) > 0


static func is_attack(id: String) -> bool:
	return get_item(id).get("damage", 0) > 0


## ¿Sirve en combate? (curar, recuperar PM o atacar)
static func usable_in_combat(id: String) -> bool:
	return restores(id) or is_attack(id)


## Modelo 3D para la mazmorra ("" si no hay).
static func model_path(id: String) -> String:
	var path := "%s%s.glb" % [MODEL_DIR, id]
	return path if ResourceLoader.exists(path) else ""


## Qué sale al abrir un objeto con `loot`: {item ("money" = dinero), count}.
static func roll_loot(id: String) -> Dictionary:
	var table: Array = get_item(id).get("loot", [])
	var total := 0
	for e: Array in table:
		total += int(e[2])
	var r := randi_range(1, maxi(total, 1))
	for e: Array in table:
		r -= int(e[2])
		if r <= 0:
			return {"item": e[0], "count": int(e[1])}
	return {}
