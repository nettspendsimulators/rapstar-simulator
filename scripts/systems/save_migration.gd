class_name SaveMigration
extends RefCounted
## Atualiza saves antigos, versão por versão, até o formato atual.


static func migrate(payload: Dictionary, balance: GameBalance) -> void:
	var version := int(payload.get("version", 1))
	if version < 2:
		_migrate_to_v2(payload["career"], balance)
	if version < 3:
		_migrate_to_v3(payload["career"], balance)
	if version < 4:
		_migrate_to_v4(payload["career"])
	if version < 5:
		_migrate_to_v5(payload["career"], balance)
	if version < 6:
		_migrate_to_v6(payload["career"], balance)
	if version < 7:
		_migrate_to_v7(payload["career"])
	if version < 8:
		_migrate_to_v8(payload["career"], balance)
	if version < 9:
		_migrate_to_v9(payload["career"])
	if version < 10:
		_migrate_to_v10(payload["career"])
	if version < 11:
		_migrate_to_v11(payload["career"], balance)
	if version < 12:
		_migrate_to_v12(payload["career"])


## v12: gravadoras. Toda carreira antiga começa independente, sem propostas nem selo próprio.
static func _migrate_to_v12(career: Dictionary) -> void:
	career["label"] = {"contract": null, "own": null, "offers": [], "history": [], "catalog": [], "periods": [], "next_offer": 1}


## v11: sexo, corpo e maquiagem entram no padrão (masculino, médio, sem maquiagem) e o guarda-roupa
## começa com as peças que o personagem já veste, para ninguém perder o visual.
static func _migrate_to_v11(career: Dictionary, balance: GameBalance) -> void:
	var appearance: Dictionary = career.get("appearance", {})
	var choices: Dictionary = appearance.get("choices", {})
	for category: String in ["sex", "build", "makeup"]:
		if not choices.has(category):
			choices[category] = balance.character.defaults.get(category, "")
	appearance["choices"] = choices
	career["appearance"] = appearance
	var worn: Array = choices.values() + Array(appearance.get("accessories", []))
	var wardrobe: Array = []
	for option in balance.character.options:
		if option.id in worn and CharacterRules.is_wear(option.category) and option.price > 0 and not option.id in wardrobe:
			wardrobe.append(option.id)
	career["wardrobe"] = wardrobe


## v10: garagem vazia. Energia Infinita ausente fica desligada; nada mais muda.
static func _migrate_to_v10(career: Dictionary) -> void:
	career["vehicles"] = []
	if not career.has("infinite_energy"):
		career["infinite_energy"] = false


## v9: rede social. Ninguém se conhece ainda; nada mais da carreira muda.
static func _migrate_to_v9(career: Dictionary) -> void:
	career["social"] = {"relations": {}, "npc_relations": {}, "beefs": [], "invites": []}


## v8: identidade, aparência e energia infinita. O nome artístico continua o mesmo; o resto
## recebe os valores padrão, e todo o progresso é mantido.
static func _migrate_to_v8(career: Dictionary, balance: GameBalance) -> void:
	var rules := balance.character
	career["real_name"] = ""
	career["age"] = rules.default_age
	career["country"] = rules.default_country
	career["city"] = ""
	career["appearance"] = {"choices": rules.defaults.duplicate(), "accessories": []}
	career["infinite_energy"] = false


## v7: carreira ao vivo. Começa vazia; os festivais criam suas edições na primeira semana.
static func _migrate_to_v7(career: Dictionary) -> void:
	for key in ["live_shows", "live_tours", "merch_items", "festival_editions"]:
		career[key] = []


## v6: videoclipes viram um sistema próprio, então a antiga ação "Videoclipe" sai das campanhas.
## O que já foi pago continua no histórico financeiro; só a ação deixa de existir.
static func _migrate_to_v6(career: Dictionary, balance: GameBalance) -> void:
	career["music_videos"] = []
	for campaign: Dictionary in career.get("marketing_campaigns", []):
		var kept: Array = []
		for action: Dictionary in campaign.get("actions", []):
			if balance.marketing.find_action(action.get("action_id", "")) != null:
				kept.append(action)
		campaign["actions"] = kept


## v5: plataformas. Músicas já lançadas entram nas plataformas com a curva antiga, e os streams
## já acumulados são distribuídos entre elas. Faixas de projetos lançados passam a tocar.
## Campanhas agora podem ser de projetos, então passam a guardar o id do conteúdo.
static func _migrate_to_v5(career: Dictionary, balance: GameBalance) -> void:
	for campaign: Dictionary in career.get("marketing_campaigns", []):
		campaign["content_id"] = campaign.get("song_id", "")
	var rules := balance.streaming
	var midpoint := (balance.song_performance.units_min + balance.song_performance.units_max) / 2
	var performances: Array[Dictionary] = []
	var with_own_release := {}
	for release: Dictionary in career.get("releases", []):
		if release.get("content_type", "") == ReleaseData.TYPE_SONG:
			with_own_release[release.get("content_id", "")] = true
	var stats := {}
	for platform in rules.platforms:
		stats[platform.id] = {"platform_id": platform.id, "total_plays": 0, "followers": 0, "revenue": 0}
	for release: Dictionary in career.get("releases", []):
		var content_id: String = release.get("content_id", "")
		if release.get("content_type", "") == ReleaseData.TYPE_SONG:
			var plays := int(release.get("total_streams", 0))
			var platform_plays := {}
			for platform in rules.platforms:
				if platform.kind == PlatformDefinition.KIND_STREAMING:
					var share := roundi(plays * platform.audience_share)
					platform_plays[platform.id] = share
					stats[platform.id]["total_plays"] += share
					stats[platform.id]["followers"] += roundi(share * platform.followers_per_play)
					stats[platform.id]["revenue"] += roundi(share * platform.money_per_play)
			performances.append(_legacy_performance(content_id, content_id, midpoint, rules, plays, platform_plays, int(release.get("total_money", 0))))
		else:
			stats["digital_store"]["total_plays"] += int(release.get("total_sales", 0))
			stats["digital_store"]["revenue"] += int(release.get("total_money", 0))
			for album: Dictionary in career.get("albums", []):
				if album.get("id", "") != content_id:
					continue
				for song_id: String in album.get("song_ids", []):
					if not with_own_release.has(song_id):
						performances.append(_legacy_performance(song_id, content_id, midpoint, rules, 0, {}, 0))
	career["song_performances"] = performances
	career["platform_stats"] = stats.values()


static func _legacy_performance(song_id: String, release_id: String, base_units: int, rules: StreamingRules, plays: int, platform_plays: Dictionary, revenue: int) -> Dictionary:
	return {
		"song_id": song_id,
		"release_id": release_id,
		"trajectory_id": rules.legacy_trajectory_id,
		"base_units": base_units,
		"total_plays": plays,
		"platform_plays": platform_plays,
		"revenue": revenue,
	}


## v4: campanhas de marketing. Lançamentos antigos ficam sem bônus de campanha.
static func _migrate_to_v4(career: Dictionary) -> void:
	career["marketing_campaigns"] = []


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
