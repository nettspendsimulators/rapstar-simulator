class_name SaveMigration
extends RefCounted
## Atualiza saves antigos, versão por versão, até o formato atual.


static func migrate(payload: Dictionary, balance: GameBalance) -> void:
	if int(payload.get("version", 1)) < 2:
		_migrate_to_v2(payload["career"], balance)


## v2: energia, créditos e nota base nas músicas, capas, agenda e formatos EP/Mixtape.
static func _migrate_to_v2(career: Dictionary, balance: GameBalance) -> void:
	career["energy"] = balance.max_energy
	career["scheduled_releases"] = []
	for song: Dictionary in career.get("songs", []):
		song["base_quality"] = song.get("quality", 0)
	# Na v1 um álbum podia ter 3 músicas. Os lançados ficam como estão, para não
	# mudar a história; os não lançados com menos faixas viram EP e continuam lançáveis.
	var album_format := balance.find_album_format(&"album")
	var ep_format := balance.find_album_format(&"ep")
	for album: Dictionary in career.get("albums", []):
		var is_unreleased: bool = album.get("status", "") != ReleasableContent.STATUS_RELEASED
		var song_count: int = album.get("song_ids", []).size()
		if is_unreleased and song_count < album_format.min_songs and ep_format.accepts_song_count(song_count):
			album["format_id"] = "ep"
