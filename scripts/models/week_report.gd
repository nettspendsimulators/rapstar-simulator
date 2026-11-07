class_name WeekReport
extends RefCounted

var week: int = 0
var entries: Array[WeekReportEntry] = []


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
	return {"week": week, "entries": entry_dicts}


static func from_dict(data: Dictionary) -> WeekReport:
	var report := WeekReport.new()
	report.week = int(data.get("week", 0))
	for entry_data: Dictionary in data.get("entries", []):
		report.entries.append(WeekReportEntry.from_dict(entry_data))
	return report
