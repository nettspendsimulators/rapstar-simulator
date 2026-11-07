class_name SongCredits
extends RefCounted
## Colaboradores escolhidos para uma música.

var producer_ids: Array[String] = []
var beatmaker_ids: Array[String] = []
var feat_ids: Array[String] = []


func equals(other: SongCredits) -> bool:
	return to_dict() == other.to_dict()


func to_dict() -> Dictionary:
	return {
		"producers": producer_ids,
		"beatmakers": beatmaker_ids,
		"feats": feat_ids,
	}


static func from_dict(data: Dictionary) -> SongCredits:
	var credits := SongCredits.new()
	credits.producer_ids.assign(data.get("producers", []))
	credits.beatmaker_ids.assign(data.get("beatmakers", []))
	credits.feat_ids.assign(data.get("feats", []))
	return credits
