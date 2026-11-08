class_name SignedArtist
extends RefCounted
## Artista do catálogo do jogo contratado pela gravadora do jogador. Usa o mesmo id do artista
## (CollaboratorDefinition); aqui fica só a situação contratual e o que ele rendeu.

var artist_id: String = ""
var signed_week: int = 0
var end_week: int = 0
var signing_fee: int = 0
var weekly_cost: int = 0
var label_share: float = 0.5
var revenue_total: int = 0
var label_revenue_total: int = 0
var last_week_revenue: int = 0
var releases: int = 0


func is_active(week: int) -> bool:
	return week < end_week


func to_dict() -> Dictionary:
	return {
		"artist_id": artist_id, "signed_week": signed_week, "end_week": end_week, "signing_fee": signing_fee,
		"weekly_cost": weekly_cost, "label_share": label_share, "revenue_total": revenue_total,
		"label_revenue_total": label_revenue_total, "last_week_revenue": last_week_revenue, "releases": releases,
	}


static func from_dict(data: Dictionary) -> SignedArtist:
	var artist := SignedArtist.new()
	artist.artist_id = String(data.get("artist_id", ""))
	artist.signed_week = int(data.get("signed_week", 0))
	artist.end_week = int(data.get("end_week", 0))
	artist.signing_fee = int(data.get("signing_fee", 0))
	artist.weekly_cost = int(data.get("weekly_cost", 0))
	artist.label_share = float(data.get("label_share", 0.5))
	artist.revenue_total = int(data.get("revenue_total", 0))
	artist.label_revenue_total = int(data.get("label_revenue_total", 0))
	artist.last_week_revenue = int(data.get("last_week_revenue", 0))
	artist.releases = int(data.get("releases", 0))
	return artist
