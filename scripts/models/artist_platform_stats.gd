class_name ArtistPlatformStats
extends RefCounted
## Perfil do artista em uma plataforma: público atual e acumulados.

var platform_id: String = ""
var listeners: int = 0
var peak_listeners: int = 0
var followers: int = 0
var total_plays: int = 0
var revenue: int = 0
## Reproduções das últimas semanas, usadas para calcular os ouvintes.
var recent_plays: Array[int] = []
## Reproduções da semana em andamento.
var week_plays: int = 0


func to_dict() -> Dictionary:
	return {
		"platform_id": platform_id,
		"listeners": listeners,
		"peak_listeners": peak_listeners,
		"followers": followers,
		"total_plays": total_plays,
		"revenue": revenue,
		"recent_plays": recent_plays,
		"week_plays": week_plays,
	}


static func from_dict(data: Dictionary) -> ArtistPlatformStats:
	var stats := ArtistPlatformStats.new()
	stats.platform_id = data.get("platform_id", "")
	stats.listeners = int(data.get("listeners", 0))
	stats.peak_listeners = int(data.get("peak_listeners", 0))
	stats.followers = int(data.get("followers", 0))
	stats.total_plays = int(data.get("total_plays", 0))
	stats.revenue = int(data.get("revenue", 0))
	stats.week_plays = int(data.get("week_plays", 0))
	for plays: Variant in data.get("recent_plays", []):
		stats.recent_plays.append(int(plays))
	return stats
