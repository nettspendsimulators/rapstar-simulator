class_name SongPerformance
extends RefCounted
## Desempenho de uma música nas plataformas. Existe desde o lançamento oficial.

var song_id: String = ""
## Conteúdo que levou a música às plataformas: ela mesma ou um projeto.
var release_id: String = ""
var trajectory_id: String = ""
var spotlight_platform: String = ""
## Tamanho do público da música, sorteado uma vez no lançamento.
var base_units: int = 0
## Semana após o lançamento em que a música tem seu surto. -1 quando não há.
var surge_week: int = -1
var launch_factor: float = 1.0
var recommendation_weeks_left: int = 0
var recommendations: int = 0
var total_plays: int = 0
var revenue: int = 0
var peak_week_plays: int = 0
## Reproduções de cada semana desde o lançamento.
var weekly_plays: Array[int] = []
var platform_plays: Dictionary[String, int] = {}


func to_dict() -> Dictionary:
	return {
		"song_id": song_id,
		"release_id": release_id,
		"trajectory_id": trajectory_id,
		"spotlight_platform": spotlight_platform,
		"base_units": base_units,
		"surge_week": surge_week,
		"launch_factor": launch_factor,
		"recommendation_weeks_left": recommendation_weeks_left,
		"recommendations": recommendations,
		"total_plays": total_plays,
		"revenue": revenue,
		"peak_week_plays": peak_week_plays,
		"weekly_plays": weekly_plays,
		"platform_plays": platform_plays,
	}


static func from_dict(data: Dictionary) -> SongPerformance:
	var performance := SongPerformance.new()
	performance.song_id = data.get("song_id", "")
	performance.release_id = data.get("release_id", "")
	performance.trajectory_id = data.get("trajectory_id", "")
	performance.spotlight_platform = data.get("spotlight_platform", "")
	performance.base_units = int(data.get("base_units", 0))
	performance.surge_week = int(data.get("surge_week", -1))
	performance.launch_factor = float(data.get("launch_factor", 1.0))
	performance.recommendation_weeks_left = int(data.get("recommendation_weeks_left", 0))
	performance.recommendations = int(data.get("recommendations", 0))
	performance.total_plays = int(data.get("total_plays", 0))
	performance.revenue = int(data.get("revenue", 0))
	performance.peak_week_plays = int(data.get("peak_week_plays", 0))
	for plays: Variant in data.get("weekly_plays", []):
		performance.weekly_plays.append(int(plays))
	var plays_by_platform: Dictionary = data.get("platform_plays", {})
	for platform_id: String in plays_by_platform:
		performance.platform_plays[platform_id] = int(plays_by_platform[platform_id])
	return performance
