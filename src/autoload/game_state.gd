extends Node
## Estado global de la partida en curso.
##
## Región, fecha, dinero, ubicación actual y afinidades. Las mecánicas de
## naturalezas/asimilación (ver docs/diseno) vivirán en sistemas propios.

signal changed
signal affinity_changed(character_id: String, value: int, delta: int)

const WEEKDAYS_SHORT := ["DOM", "LUN", "MAR", "MIÉ", "JUE", "VIE", "SÁB"]
const MONTHS_SHORT := ["ENE", "FEB", "MAR", "ABR", "MAY", "JUN", "JUL", "AGO", "SEP", "OCT", "NOV", "DIC"]

const START_REGION := "Leganés"
const START_DATE := {"year": 2026, "month": 11, "day": 17}
const START_MONEY := 12460

var region_name: String = START_REGION
var date: Dictionary = START_DATE.duplicate()
var money: int = START_MONEY
## Ubicación actual (ver LocationDB). Empieza en casa.
var location_id: String = LocationDB.HOME
## Afinidad del protagonista con cada personaje. Sin umbrales ni efectos automáticos.
var affinity: Dictionary = {}


func new_game() -> void:
	region_name = START_REGION
	date = START_DATE.duplicate()
	money = START_MONEY
	location_id = LocationDB.HOME
	affinity = {}
	changed.emit()


func set_location(id: String) -> void:
	location_id = id
	changed.emit()


func get_affinity(character_id: String) -> int:
	return affinity.get(character_id, 0)


func add_affinity(character_id: String, delta: int) -> void:
	if delta == 0:
		return
	affinity[character_id] = get_affinity(character_id) + delta
	affinity_changed.emit(character_id, affinity[character_id], delta)


func has_save() -> bool:
	# Todavía no hay sistema de guardado.
	return false


func set_region(new_region: String) -> void:
	region_name = new_region
	changed.emit()


func advance_days(days: int = 1) -> void:
	var unix := _date_to_unix(date) + days * 86400
	var d := Time.get_datetime_dict_from_unix_time(unix)
	date = {"year": d.year, "month": d.month, "day": d.day}
	changed.emit()


func weekday_short() -> String:
	var d := Time.get_datetime_dict_from_unix_time(_date_to_unix(date))
	return WEEKDAYS_SHORT[d.weekday]


func month_short() -> String:
	return MONTHS_SHORT[int(date.month) - 1]


func _date_to_unix(d: Dictionary) -> int:
	# Mediodía para evitar sorpresas en los límites del día.
	return Time.get_unix_time_from_datetime_dict({
		"year": d.year, "month": d.month, "day": d.day,
		"hour": 12, "minute": 0, "second": 0,
	})
