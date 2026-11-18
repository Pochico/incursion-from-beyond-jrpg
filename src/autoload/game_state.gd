extends Node
## Estado global de la partida en curso.
##
## Por ahora solo guarda lo que muestran las cabeceras de interfaz
## (región, fecha y dinero). Las mecánicas de naturalezas/asimilación
## (ver docs/diseno) vivirán en sistemas propios más adelante.

signal changed

const WEEKDAYS_SHORT := ["DOM", "LUN", "MAR", "MIÉ", "JUE", "VIE", "SÁB"]
const MONTHS_SHORT := ["ENE", "FEB", "MAR", "ABR", "MAY", "JUN", "JUL", "AGO", "SEP", "OCT", "NOV", "DIC"]

const START_REGION := "Leganés"
const START_DATE := {"year": 2026, "month": 11, "day": 17}
const START_MONEY := 12460

var region_name: String = START_REGION
var date: Dictionary = START_DATE.duplicate()
var money: int = START_MONEY


func new_game() -> void:
	region_name = START_REGION
	date = START_DATE.duplicate()
	money = START_MONEY
	changed.emit()


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
