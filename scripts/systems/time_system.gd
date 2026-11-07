class_name TimeSystem
extends RefCounted
## Único ponto que mexe no calendário. Meses, anos e temporadas nascem daqui.


func advance(career: CareerData) -> void:
	career.current_week += 1


func weeks_since(career: CareerData, week: int) -> int:
	return career.current_week - week
