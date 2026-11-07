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
## Semana em que vazou antes do lançamento oficial. O vazamento não gera receita.
var leak_week: int = NO_RELEASE_WEEK
## Atenção do público gerada pelo vazamento.
var leak_attention: int = 0


func is_released() -> bool:
	return status == STATUS_RELEASED


func mark_released(week: int) -> void:
	status = STATUS_RELEASED
	release_week = week


func is_leaked() -> bool:
	return leak_week != NO_RELEASE_WEEK


func status_label() -> String:
	return status


## Status com a informação de vazamento, para as telas.
func display_status() -> String:
	return status_label() + (" (vazou)" if is_leaked() and not is_released() else "")


## De 0 a 100, conforme a atenção do vazamento.
func leak_attention_score() -> int:
	return mini(leak_attention / 100, 100)


func to_dict() -> Dictionary:
	return {
		"id": id,
		"title": title,
		"production_cost": production_cost,
		"quality": quality,
		"status": status,
		"release_week": release_week,
		"cover_file": cover_file,
		"leak_week": leak_week,
		"leak_attention": leak_attention,
	}


func _load_common(data: Dictionary) -> void:
	id = data.get("id", "")
	title = data.get("title", "")
	production_cost = int(data.get("production_cost", 0))
	quality = int(data.get("quality", 0))
	status = data.get("status", STATUS_UNRELEASED)
	release_week = int(data.get("release_week", NO_RELEASE_WEEK))
	cover_file = data.get("cover_file", "")
	leak_week = int(data.get("leak_week", NO_RELEASE_WEEK))
	leak_attention = int(data.get("leak_attention", 0))
