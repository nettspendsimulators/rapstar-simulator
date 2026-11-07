class_name PerformanceSnapshot
extends RefCounted
## Fotografia semanal do artista nas plataformas, usada na evolução e no histórico.

var week: int = 0
var plays: int = 0
var listeners: int = 0
var followers: int = 0
var revenue: int = 0


func to_dict() -> Dictionary:
	return {"week": week, "plays": plays, "listeners": listeners, "followers": followers, "revenue": revenue}


static func from_dict(data: Dictionary) -> PerformanceSnapshot:
	var snapshot := PerformanceSnapshot.new()
	snapshot.week = int(data.get("week", 0))
	snapshot.plays = int(data.get("plays", 0))
	snapshot.listeners = int(data.get("listeners", 0))
	snapshot.followers = int(data.get("followers", 0))
	snapshot.revenue = int(data.get("revenue", 0))
	return snapshot
