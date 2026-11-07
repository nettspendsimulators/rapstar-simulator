class_name MusicVideo
extends RefCounted
## Videoclipe de uma música: escolhas de produção, notas, lançamento e desempenho.
## A qualidade da música nunca é alterada pelo videoclipe, e vice-versa.

const STATUS_PRODUCTION := "production"
const STATUS_READY := "ready"
const STATUS_RELEASED := "released"
const NO_WEEK := -1

var id: String = ""
var song_id: String = ""
## Opções escolhidas em cada etapa, por id da etapa.
var choices: Dictionary[String, Array] = {}
var cover_file: String = ""
var cost: int = 0
var production_weeks: int = 0
var start_week: int = 0
var ready_week: int = 0
var status: String = STATUS_PRODUCTION
var release_mode: String = VideoRules.MODE_WITH_SONG
var scheduled_week: int = NO_WEEK
var release_week: int = NO_WEEK
## Problema sorteado ao fim da produção. Vazio quando não houve.
var problem_note: String = ""
var problem_checked: bool = false

## Notas calculadas no início da produção.
var technical: int = 0
var visual: int = 0
var creativity: int = 0
var identity: int = 0
var coherence: int = 0
var commercial: int = 0
var discovery: int = 0
var viral: int = 0
var risk: int = 0
var score: int = 0

## Vazamento: visualizações não oficiais, separadas do desempenho oficial e sem receita.
var leak_week: int = NO_WEEK
var leak_views: int = 0
var leak_weekly_views: int = 0
## Multiplicador do lançamento oficial: abaixo de 1 prejudica, acima de 1 virou burburinho.
var leak_effect: float = 1.0

## Desempenho oficial, desde o lançamento.
var base_units: int = 0
var trajectory_id: String = ""
var surge_week: int = NO_WEEK
var total_views: int = 0
var weekly_views: Array[int] = []
var peak_week_views: int = 0
var likes: int = 0
var revenue: int = 0


func is_released() -> bool:
	return status == STATUS_RELEASED


func is_leaked() -> bool:
	return leak_week != NO_WEEK


func choice_ids() -> Array[String]:
	var ids: Array[String] = []
	for category_id in choices:
		for option_id: String in choices[category_id]:
			ids.append(option_id)
	return ids


func to_dict() -> Dictionary:
	return {
		"id": id,
		"song_id": song_id,
		"choices": choices,
		"cover_file": cover_file,
		"cost": cost,
		"production_weeks": production_weeks,
		"start_week": start_week,
		"ready_week": ready_week,
		"status": status,
		"release_mode": release_mode,
		"scheduled_week": scheduled_week,
		"release_week": release_week,
		"problem_note": problem_note,
		"problem_checked": problem_checked,
		"technical": technical,
		"visual": visual,
		"creativity": creativity,
		"identity": identity,
		"coherence": coherence,
		"commercial": commercial,
		"discovery": discovery,
		"viral": viral,
		"risk": risk,
		"score": score,
		"leak_week": leak_week,
		"leak_views": leak_views,
		"leak_weekly_views": leak_weekly_views,
		"leak_effect": leak_effect,
		"base_units": base_units,
		"trajectory_id": trajectory_id,
		"surge_week": surge_week,
		"total_views": total_views,
		"weekly_views": weekly_views,
		"peak_week_views": peak_week_views,
		"likes": likes,
		"revenue": revenue,
	}


static func from_dict(data: Dictionary) -> MusicVideo:
	var video := MusicVideo.new()
	video.id = data.get("id", "")
	video.song_id = data.get("song_id", "")
	var saved_choices: Dictionary = data.get("choices", {})
	for category_id: String in saved_choices:
		var ids: Array[String] = []
		ids.assign(saved_choices[category_id])
		video.choices[category_id] = ids
	video.cover_file = data.get("cover_file", "")
	for key in ["cost", "production_weeks", "start_week", "ready_week", "technical", "visual", "creativity", "identity",
			"coherence", "commercial", "discovery", "viral", "risk", "score", "leak_views", "leak_weekly_views",
			"base_units", "total_views", "peak_week_views", "likes", "revenue"]:
		video.set(key, int(data.get(key, 0)))
	for key in ["scheduled_week", "release_week", "leak_week", "surge_week"]:
		video.set(key, int(data.get(key, NO_WEEK)))
	video.status = data.get("status", STATUS_PRODUCTION)
	video.release_mode = data.get("release_mode", VideoRules.MODE_WITH_SONG)
	video.problem_note = data.get("problem_note", "")
	video.problem_checked = bool(data.get("problem_checked", false))
	video.leak_effect = float(data.get("leak_effect", 1.0))
	video.trajectory_id = data.get("trajectory_id", "")
	for views: Variant in data.get("weekly_views", []):
		video.weekly_views.append(int(views))
	return video
