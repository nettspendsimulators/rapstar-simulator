class_name LabelOffer
extends RefCounted
## Proposta de uma gravadora: os termos já calculados para esta carreira.

var id: String = ""
var label_id: String = ""
var week: int = 0
var expires_week: int = 0
var weeks: int = 52
var artist_share: float = 0.7
var advance: int = 0
var marketing_support: float = 0.0
var video_support: float = 0.0
var release_support: float = 0.0
var budget: int = 0
var discovery_bonus: float = 0.0
var show_bonus: float = 0.0
## Renovação de um contrato que terminou.
var renewal: bool = false


func to_dict() -> Dictionary:
	return {
		"id": id, "label_id": label_id, "week": week, "expires_week": expires_week, "weeks": weeks,
		"artist_share": artist_share, "advance": advance, "marketing_support": marketing_support,
		"video_support": video_support, "release_support": release_support, "budget": budget,
		"discovery_bonus": discovery_bonus, "show_bonus": show_bonus, "renewal": renewal,
	}


static func from_dict(data: Dictionary) -> LabelOffer:
	var offer := LabelOffer.new()
	offer.id = String(data.get("id", ""))
	offer.label_id = String(data.get("label_id", ""))
	offer.week = int(data.get("week", 0))
	offer.expires_week = int(data.get("expires_week", 0))
	offer.weeks = int(data.get("weeks", 52))
	offer.artist_share = float(data.get("artist_share", 0.7))
	offer.advance = int(data.get("advance", 0))
	offer.marketing_support = float(data.get("marketing_support", 0.0))
	offer.video_support = float(data.get("video_support", 0.0))
	offer.release_support = float(data.get("release_support", 0.0))
	offer.budget = int(data.get("budget", 0))
	offer.discovery_bonus = float(data.get("discovery_bonus", 0.0))
	offer.show_bonus = float(data.get("show_bonus", 0.0))
	offer.renewal = bool(data.get("renewal", false))
	return offer
