class_name ItemDB
extends RefCounted
## Catálogo de objetos. `heal` = PV que restaura a quien lo usa.

const ALL := {
	"pochicola": {
		"name": "Pochicola",
		"desc": "Refresco con burbujas y un sabor difícil de describir. Restaura %d PV a quien la bebe.",
		"heal": 80,
		"icon": "can",
	},
}


static func get_item(id: String) -> Dictionary:
	return ALL.get(id, {})


static func description(id: String) -> String:
	var item := get_item(id)
	var desc: String = item.get("desc", "")
	return desc % item.get("heal", 0) if desc.contains("%d") else desc
