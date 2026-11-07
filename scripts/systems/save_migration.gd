class_name SaveMigration
extends RefCounted
## Atualiza saves antigos, versão por versão, até o formato atual.


static func migrate(payload: Dictionary, balance: GameBalance) -> void:
	var version := int(payload.get("version", 1))
	if version < 2:
		_migrate_to_v2(payload["career"], balance)
	if version < 3:
		_migrate_to_v3(payload["career"], balance)


## v3: Vocal, Letra, Beat e Produção independentes na música.
## A nota geral de cada música fica exatamente como estava: Beat, Produção e feats
## antigos são mantidos, e Vocal e Letra recebem o valor que completa a mesma nota.
static func _migrate_to_v3(career: Dictionary, balance: GameBalance) -> void:
	var rules := balance.song_quality
	var vocal_weight := rules.find_attribute(SongData.ATTRIBUTE_VOCAL).weight
	var lyrics_weight := rules.find_attribute(SongData.ATTRIBUTE_LYRICS).weight
	var beat_weight := rules.find_attribute(SongData.ATTRIBUTE_BEAT).weight
	var production_weight := rules.find_attribute(SongData.ATTRIBUTE_PRODUCTION).weight
	for song: Dictionary in career.get("songs", []):
		var quality := int(song.get("quality", 0))
		var beat := int(song.get("beat_quality", -1))
		var production := int(song.get("production_quality", -1))
		var feats := int(song.get("feat_score", -1))
		var known_total := beat * beat_weight + production * production_weight + feats * rules.feats_weight
		var solo := (quality - known_total) / (vocal_weight + lyrics_weight)
		# Músicas sem notas parciais, ou cuja nota não fecha com elas, usam a nota em tudo.
		if beat < 0 or production < 0 or feats < 0 or solo < 0.0 or solo > 100.0:
			beat = quality
			production = quality
			feats = quality
			solo = quality
		song["attribute_bases"] = {
			SongData.ATTRIBUTE_VOCAL: roundi(solo),
			SongData.ATTRIBUTE_LYRICS: roundi(solo),
			SongData.ATTRIBUTE_BEAT: beat,
			SongData.ATTRIBUTE_PRODUCTION: production,
		}
		song["attribute_points"] = {}
		song["feat_score"] = feats


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
