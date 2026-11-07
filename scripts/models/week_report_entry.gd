class_name WeekReportEntry
extends RefCounted
## Uma linha do relatório. Eventos, despesas e shows podem virar novas entradas.

var title: String = ""
var streams: int = 0
var sales: int = 0
var money: int = 0
var fame: int = 0
## Informação extra em texto, como o resultado de um lançamento agendado.
var note: String = ""
var cover_file: String = ""


func to_dict() -> Dictionary:
	return {
		"title": title,
		"note": note,
		"cover_file": cover_file,
		"streams": streams,
		"sales": sales,
		"money": money,
		"fame": fame,
	}


static func from_dict(data: Dictionary) -> WeekReportEntry:
	var entry := WeekReportEntry.new()
	entry.title = data.get("title", "")
	entry.note = data.get("note", "")
	entry.cover_file = data.get("cover_file", "")
	entry.streams = int(data.get("streams", 0))
	entry.sales = int(data.get("sales", 0))
	entry.money = int(data.get("money", 0))
	entry.fame = int(data.get("fame", 0))
	return entry
