class_name AlbumData
extends ReleasableContent

var format_id: String = "album"
var song_ids: Array[String] = []


func status_label() -> String:
	return "Lançado" if is_released() else "Não lançado"


func to_dict() -> Dictionary:
	var data := super()
	data["format_id"] = format_id
	data["song_ids"] = song_ids
	return data


static func from_dict(data: Dictionary) -> AlbumData:
	var album := AlbumData.new()
	album._load_common(data)
	album.format_id = data.get("format_id", "album")
	album.song_ids.assign(data.get("song_ids", []))
	return album
