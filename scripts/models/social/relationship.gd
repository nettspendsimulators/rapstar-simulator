class_name Relationship
extends RefCounted
## Relação do jogador com um artista do catálogo (referenciado pelo id). O valor vai de -100 a 100;
## o status vem do valor (SocialSystem.status_of) e o histórico conta como a relação chegou ali.

var artist_id: String = ""
var value: int = 0
## Se o jogador já conhece o artista. Sem isso, o status é "Desconhecido".
var met: bool = false
## Entradas {"week": int, "text": String}, da mais antiga para a mais nova.
var history: Array[Dictionary] = []
## Ganho positivo acumulado na semana gain_week (a confiança cresce aos poucos).
var gain_week: int = 0
var week_gain: int = 0
## Interação -> última semana em que foi usada com este artista.
var used: Dictionary[String, int] = {}
var last_free_feat_week: int = -999
var feats: int = 0
var shows: int = 0


func add_history(week: int, text: String) -> void:
	history.append({"week": week, "text": text})
	if history.size() > 60:
		history = history.slice(history.size() - 60)


func to_dict() -> Dictionary:
	return {
		"artist_id": artist_id, "value": value, "met": met, "history": history, "gain_week": gain_week,
		"week_gain": week_gain, "used": used, "last_free_feat_week": last_free_feat_week, "feats": feats, "shows": shows,
	}


static func from_dict(data: Dictionary) -> Relationship:
	var relation := Relationship.new()
	relation.artist_id = data.get("artist_id", "")
	relation.value = int(data.get("value", 0))
	relation.met = bool(data.get("met", false))
	for item: Dictionary in data.get("history", []):
		relation.history.append({"week": int(item.get("week", 0)), "text": String(item.get("text", ""))})
	relation.gain_week = int(data.get("gain_week", 0))
	relation.week_gain = int(data.get("week_gain", 0))
	var used_data: Dictionary = data.get("used", {})
	for key: String in used_data:
		relation.used[key] = int(used_data[key])
	relation.last_free_feat_week = int(data.get("last_free_feat_week", -999))
	relation.feats = int(data.get("feats", 0))
	relation.shows = int(data.get("shows", 0))
	return relation
