class_name ReleaseData
extends RefCounted
## Um lançamento ativo no mercado e o desempenho acumulado dele.

const TYPE_SONG := "song"
const TYPE_ALBUM := "album"

var content_type: String = TYPE_SONG
var content_id: String = ""
var release_week: int = 0
var total_streams: int = 0
var total_sales: int = 0
var total_money: int = 0
var total_fame: int = 0


func to_dict() -> Dictionary:
	return {
		"content_type": content_type,
		"content_id": content_id,
		"release_week": release_week,
		"total_streams": total_streams,
		"total_sales": total_sales,
		"total_money": total_money,
		"total_fame": total_fame,
	}


static func from_dict(data: Dictionary) -> ReleaseData:
	var release := ReleaseData.new()
	release.content_type = data.get("content_type", TYPE_SONG)
	release.content_id = data.get("content_id", "")
	release.release_week = int(data.get("release_week", 0))
	release.total_streams = int(data.get("total_streams", 0))
	release.total_sales = int(data.get("total_sales", 0))
	release.total_money = int(data.get("total_money", 0))
	release.total_fame = int(data.get("total_fame", 0))
	return release
