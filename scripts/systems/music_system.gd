class_name MusicSystem
extends RefCounted

var _balance: GameBalance
var _economy: EconomySystem
var _quality: SongQualitySystem
var _rng: RandomNumberGenerator


func _init(balance: GameBalance, economy: EconomySystem, quality: SongQualitySystem, rng: RandomNumberGenerator) -> void:
	_balance = balance
	_economy = economy
	_quality = quality
	_rng = rng


func create_song(career: CareerData, title: String, credits: SongCredits = null, cover_file: String = "") -> ActionResult:
	var clean_title := title.strip_edges()
	if clean_title.is_empty():
		return ActionResult.failure("Dê um nome para a música.")
	var song_credits := credits if credits != null else SongCredits.new()
	var credits_error := _validate_credits(song_credits)
	if not credits_error.is_empty():
		return ActionResult.failure(credits_error)
	var cost := _balance.song_production_cost
	if not _economy.can_afford(career, cost):
		return _economy.insufficient_funds(cost)

	_economy.spend(career, cost, "Produção de música: %s" % clean_title, FinanceEntry.CATEGORY_PRODUCTION)
	var song := SongData.new()
	song.id = career.new_id("song")
	song.title = clean_title
	song.cover_file = cover_file
	song.production_cost = cost
	song.beat_roll = _rng.randf_range(-1.0, 1.0)
	song.production_roll = _rng.randf_range(-1.0, 1.0)
	_apply_credits(song, song_credits)
	career.songs.append(song)
	return ActionResult.success("\"%s\" produzida. Nota: %d." % [song.title, song.quality], song)


## A nota só é recalculada se os colaboradores mudarem. As melhorias já feitas são mantidas.
func edit_song(career: CareerData, song_id: String, title: String, credits: SongCredits, cover_file: String) -> ActionResult:
	var song := career.find_song(song_id)
	if song == null:
		return ActionResult.failure("Música não encontrada.")
	if song.is_released():
		return ActionResult.failure("\"%s\" já foi lançada e não pode mais ser editada." % song.title)
	var clean_title := title.strip_edges()
	if clean_title.is_empty():
		return ActionResult.failure("Dê um nome para a música.")
	var credits_error := _validate_credits(credits)
	if not credits_error.is_empty():
		return ActionResult.failure(credits_error)

	song.title = clean_title
	song.cover_file = cover_file
	if not song.credits.equals(credits):
		_apply_credits(song, credits)
		career.refresh_album_qualities()
	return ActionResult.success("\"%s\" atualizada. Nota: %d." % [song.title, song.quality], song)


func improve_song(career: CareerData, content_id: String) -> ActionResult:
	var content := career.find_content(content_id)
	if content == null:
		return ActionResult.failure("Música não encontrada.")
	if content is AlbumData:
		return ActionResult.failure("Projetos não recebem melhorias. Melhore as músicas antes de lançar.")
	var song: SongData = content
	if song.is_released():
		return ActionResult.failure("\"%s\" já foi lançada e não pode mais ser melhorada." % song.title)
	var room := improvement_room(song)
	if room <= 0:
		return ActionResult.failure("\"%s\" já atingiu o limite de melhorias." % song.title)
	var rules := _balance.song_quality
	if not _economy.can_spend_energy(career, rules.improvement_energy_cost):
		return ActionResult.failure("Energia insuficiente: melhorar custa %d." % rules.improvement_energy_cost)

	_economy.spend_energy(career, rules.improvement_energy_cost)
	var gain := mini(_rng.randi_range(rules.improvement_gain_min, rules.improvement_gain_max), room)
	song.improvement_points += gain
	_update_quality(song)
	career.refresh_album_qualities()
	return ActionResult.success("\"%s\" melhorou +%d. Nota: %d." % [song.title, gain, song.quality], song)


## Quantos pontos a música ainda pode ganhar com melhorias.
func improvement_room(song: SongData) -> int:
	return maxi(_quality.improvement_limit(song.base_quality) - song.quality, 0)


func improvement_limit(song: SongData) -> int:
	return _quality.improvement_limit(song.base_quality)


## Nota que a música teria com estes colaboradores, sem alterar nada.
## Sem uma música existente, a prévia desconsidera a variação sorteada na produção.
func preview_quality(credits: SongCredits, song: SongData = null) -> SongQualitySystem.Result:
	var beat_roll := song.beat_roll if song != null else 0.0
	var production_roll := song.production_roll if song != null else 0.0
	var result := _quality.calculate(credits, beat_roll, production_roll)
	if song != null and song.credits.equals(credits):
		result.base = song.base_quality
	return result


func _apply_credits(song: SongData, credits: SongCredits) -> void:
	var result := _quality.calculate(credits, song.beat_roll, song.production_roll)
	song.credits = credits
	song.beat_quality = result.beat
	song.production_quality = result.production
	song.feat_score = result.feats
	song.base_quality = result.base
	_update_quality(song)


func _update_quality(song: SongData) -> void:
	song.quality = mini(song.base_quality + song.improvement_points, _quality.improvement_limit(song.base_quality))


## Devolve a mensagem de erro, ou um texto vazio se os créditos forem válidos.
func _validate_credits(credits: SongCredits) -> String:
	var rules := _balance.song_quality
	var catalog := _balance.collaborators
	var checks := [
		["produtores", credits.producer_ids, catalog.producers, rules.max_producers],
		["beatmakers", credits.beatmaker_ids, catalog.beatmakers, rules.max_beatmakers],
		["participações", credits.feat_ids, catalog.feats, rules.max_feats],
	]
	for check: Array in checks:
		var ids: Array[String] = check[1]
		if ids.size() > check[3]:
			return "Escolha no máximo %d %s." % [check[3], check[0]]
		var unique := {}
		for id in ids:
			unique[id] = true
		if unique.size() != ids.size():
			return "Há nomes repetidos em %s." % check[0]
		var pool: Array[CollaboratorDefinition] = check[2]
		if CollaboratorCatalog.resolve(pool, ids).size() != ids.size():
			return "Há nomes desconhecidos em %s." % check[0]
	return ""
