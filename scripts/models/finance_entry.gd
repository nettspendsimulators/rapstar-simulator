class_name FinanceEntry
extends RefCounted

const CATEGORY_WORK := "work"
const CATEGORY_PRODUCTION := "production"
const CATEGORY_COLLABORATOR := "collaborator"
const CATEGORY_MARKETING := "marketing"
const CATEGORY_SAMPLE := "sample"
const CATEGORY_VIDEO := "video"
const CATEGORY_LIVE := "live"
const CATEGORY_MERCH := "merch"
const CATEGORY_SPONSOR := "sponsor"
const CATEGORY_SOCIAL := "social"
const CATEGORY_VEHICLE := "vehicle"
const CATEGORY_STYLE := "style"
const CATEGORY_LABEL := "label"
const CATEGORY_RELEASE := "release"
const CATEGORY_STREAMS := "streams"
const CATEGORY_SALES := "sales"

var week: int = 0
## Positivo para ganhos, negativo para gastos.
var amount: int = 0
var description: String = ""
var category: String = ""


func to_dict() -> Dictionary:
	return {
		"week": week,
		"amount": amount,
		"description": description,
		"category": category,
	}


static func from_dict(data: Dictionary) -> FinanceEntry:
	var entry := FinanceEntry.new()
	entry.week = int(data.get("week", 0))
	entry.amount = int(data.get("amount", 0))
	entry.description = data.get("description", "")
	entry.category = data.get("category", "")
	return entry
