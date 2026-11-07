class_name ReleasableContent
extends RefCounted
## Dados comuns a tudo que pode ser produzido e lançado (músicas e álbuns).

const STATUS_UNRELEASED := "unreleased"
const STATUS_RELEASED := "released"
const NO_RELEASE_WEEK := -1

var id: String = ""
var title: String = ""
var production_cost: int = 0
var quality: int = 0
var status: String = STATUS_UNRELEASED
var release_week: int = NO_RELEASE_WEEK
## Nome do arquivo da capa, gerenciado pelo CoverSystem. Vazio quando não há capa.
var cover_file: String = ""


func is_released() -> bool:
	return status == STATUS_RELEASED


func mark_released(week: int) -> void:
	status = STATUS_RELEASED
	release_week = week


func status_label() -> String:
	return status


func to_dict() -> Dictionary:
	return {
		"id": id,
		"title": title,
		"production_cost": production_cost,
		"quality": quality,
		"status": status,
		"release_week": release_week,
		"cover_file": cover_file,
	}


func _load_common(data: Dictionary) -> void:
	id = data.get("id", "")
	title = data.get("title", "")
	production_cost = int(data.get("production_cost", 0))
	quality = int(data.get("quality", 0))
	status = data.get("status", STATUS_UNRELEASED)
	release_week = int(data.get("release_week", NO_RELEASE_WEEK))
	cover_file = data.get("cover_file", "")
