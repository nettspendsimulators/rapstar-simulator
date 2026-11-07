class_name LiveTour
extends RefCounted
## Uma turnê: datas, tipos, patrocínios e a evolução da carreira durante ela.

const STATUS_PLANNING := "planning"
const STATUS_CONFIRMED := "confirmed"
const STATUS_IN_PROGRESS := "in_progress"
const STATUS_PAUSED := "paused"
const STATUS_COMPLETED := "completed"
const STATUS_CANCELLED := "cancelled"
const STATUS_LABELS := {
	STATUS_PLANNING: "Em planejamento", STATUS_CONFIRMED: "Confirmada", STATUS_IN_PROGRESS: "Em andamento",
	STATUS_PAUSED: "Pausada", STATUS_COMPLETED: "Concluída", STATUS_CANCELLED: "Cancelada",
}

var id: String = ""
var name: String = ""
var goal: String = ""
var project_id: String = ""
var types: Array[String] = []
var status: String = STATUS_PLANNING
## Id do catálogo de feats do artista que divide a turnê. Vazio quando a turnê é solo.
var co_headliner_id: String = ""
## Patrocínios aceitos e propostas recebidas: {"sponsor_id", "value", "benefit", "benefit_value"}.
var sponsors: Array[Dictionary] = []
var sponsor_offers: Array[Dictionary] = []
var fame_start: int = 0
var followers_start: int = 0
var fame_end: int = 0
var followers_end: int = 0


func status_label() -> String:
	return STATUS_LABELS.get(status, status)


func is_open() -> bool:
	return status == STATUS_PLANNING


func is_running() -> bool:
	return status == STATUS_CONFIRMED or status == STATUS_IN_PROGRESS or status == STATUS_PAUSED


## Soma das reduções de um tipo de benefício entre os patrocinadores aceitos.
func sponsor_benefit(benefit: String) -> float:
	var total := 0.0
	for sponsor in sponsors:
		if sponsor.get("benefit", "") == benefit:
			total += float(sponsor.get("benefit_value", 0.0))
	return minf(total, 0.9)


func to_dict() -> Dictionary:
	return {
		"id": id, "name": name, "goal": goal, "project_id": project_id, "types": types, "status": status,
		"co_headliner_id": co_headliner_id, "sponsors": sponsors, "sponsor_offers": sponsor_offers,
		"fame_start": fame_start, "followers_start": followers_start, "fame_end": fame_end, "followers_end": followers_end,
	}


static func from_dict(data: Dictionary) -> LiveTour:
	var tour := LiveTour.new()
	for key in ["id", "name", "goal", "project_id", "status", "co_headliner_id"]:
		tour.set(key, data.get(key, tour.get(key)))
	for key in ["fame_start", "followers_start", "fame_end", "followers_end"]:
		tour.set(key, int(data.get(key, 0)))
	tour.types.assign(data.get("types", []))
	for item: Dictionary in data.get("sponsors", []):
		tour.sponsors.append(_sponsor_from_dict(item))
	for item: Dictionary in data.get("sponsor_offers", []):
		tour.sponsor_offers.append(_sponsor_from_dict(item))
	return tour


static func _sponsor_from_dict(item: Dictionary) -> Dictionary:
	var sponsor := LiveShow.whole_numbers(item)
	sponsor["benefit_value"] = float(item.get("benefit_value", 0.0))
	return sponsor
