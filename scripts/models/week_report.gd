class_name WeekReport
extends RefCounted

var week: int = 0
var entries: Array[WeekReportEntry] = []
## Balanço da semana: diferença entre o fim e o começo (inclui gastos e ganhos de tudo).
var money_change: int = 0
var fame_change: int = 0
var fans_change: int = 0
var plays: int = 0
## Id da fase alcançada nesta semana, ou vazio.
var stage_reached: String = ""


func total_money() -> int:
	var total := 0
	for entry in entries:
		total += entry.money
	return total


func total_fame() -> int:
	var total := 0
	for entry in entries:
		total += entry.fame
	return total


func to_dict() -> Dictionary:
	var entry_dicts: Array[Dictionary] = []
	for entry in entries:
		entry_dicts.append(entry.to_dict())
	return {
		"week": week, "entries": entry_dicts, "money_change": money_change, "fame_change": fame_change,
		"fans_change": fans_change, "plays": plays, "stage_reached": stage_reached,
	}


static func from_dict(data: Dictionary) -> WeekReport:
	var report := WeekReport.new()
	report.week = int(data.get("week", 0))
	report.money_change = int(data.get("money_change", 0))
	report.fame_change = int(data.get("fame_change", 0))
	report.fans_change = int(data.get("fans_change", 0))
	report.plays = int(data.get("plays", 0))
	report.stage_reached = data.get("stage_reached", "")
	for entry_data: Dictionary in data.get("entries", []):
		report.entries.append(WeekReportEntry.from_dict(entry_data))
	return report
