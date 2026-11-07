class_name SongSample
extends RefCounted
## Sample usado em uma música. song_id só é preenchido em samples de música própria.

var sample_id: String = ""
var song_id: String = ""


func is_empty() -> bool:
	return sample_id.is_empty()


func equals(other: SongSample) -> bool:
	return sample_id == other.sample_id and song_id == other.song_id


func to_dict() -> Dictionary:
	return {"sample_id": sample_id, "song_id": song_id}


static func from_dict(data: Dictionary) -> SongSample:
	var sample := SongSample.new()
	sample.sample_id = data.get("sample_id", "")
	sample.song_id = data.get("song_id", "")
	return sample
