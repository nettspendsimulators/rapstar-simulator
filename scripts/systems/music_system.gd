class_name MusicSystem
extends RefCounted

## Prévia da nota de uma música com determinados colaboradores.
class Preview:
	var attribute_values: Dictionary = {}
	var feat_value: int = 0
	var quality: int = 0


## Um colaborador a ser pago, com a função dele naquela música.
class Hire:
	var person: CollaboratorDefinition
	var role_label: String


var _balance: GameBalance
var _economy: EconomySystem
var _quality: SongQualitySystem
var _rng: RandomNumberGenerator


func _init(balance: GameBalance, economy: EconomySystem, quality: SongQualitySystem, rng: RandomNumberGenerator) -> void:
	_balance = balance
	_economy = economy
	_quality = quality
	_rng = rng


func create_song(career: CareerData, title: String, credits: SongCredits = null, cover_file: String = "", sample: SongSample = null) -> ActionResult:
	var clean_title := title.strip_edges()
	if clean_title.is_empty():
		return ActionResult.failure("Dê um nome para a música.")
	var song_credits := credits if credits != null else SongCredits.new()
	var credits_error := _validate_credits(song_credits)
	if not credits_error.is_empty():
		return ActionResult.failure(credits_error)
	var song_sample := sample if sample != null else SongSample.new()
	var sample_error := _validate_sample(career, song_sample, "")
	if not sample_error.is_empty():
		return ActionResult.failure(sample_error)
	var production_cost := _balance.song_production_cost
	var hires := _new_hires(song_credits, SongCredits.new())
	var total_cost := production_cost + _hires_cost(hires) + sample_cost(song_sample)
	if not _economy.can_afford(career, total_cost):
		return _economy.insufficient_funds(total_cost)

	_economy.spend(career, production_cost, "Produção de música: %s" % clean_title, FinanceEntry.CATEGORY_PRODUCTION)
	_pay_hires(career, hires, clean_title)
	_pay_sample(career, song_sample, clean_title)
	var song := SongData.new()
	song.id = career.new_id("song")
	song.title = clean_title
	song.cover_file = cover_file
	song.production_cost = total_cost
	song.beat_roll = _rng.randf_range(-1.0, 1.0)
	song.production_roll = _rng.randf_range(-1.0, 1.0)
	song.attribute_bases[SongData.ATTRIBUTE_VOCAL] = _quality.solo_score(_rng.randf_range(-1.0, 1.0))
	song.attribute_bases[SongData.ATTRIBUTE_LYRICS] = _quality.solo_score(_rng.randf_range(-1.0, 1.0))
	song.attribute_bases[SongData.ATTRIBUTE_BEAT] = _quality.beat_score(song_credits, song.beat_roll)
	song.attribute_bases[SongData.ATTRIBUTE_PRODUCTION] = _quality.production_score(song_credits, song.production_roll)
	song.feat_score = _quality.feats_score(song_credits)
	song.credits = song_credits
	song.sample = song_sample
	_update_quality(song)
	career.songs.append(song)
	return ActionResult.success("\"%s\" produzida. Nota: %d." % [song.title, song.quality], song)


## Só colaboradores novos são pagos, e remover alguém não gera reembolso.
## A nota só muda nas partes cujos colaboradores mudaram. As melhorias são mantidas.
## Sem informar sample, a música mantém o atual. Um SongSample vazio remove o sample.
func edit_song(career: CareerData, song_id: String, title: String, credits: SongCredits, cover_file: String, sample: SongSample = null) -> ActionResult:
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
	var new_sample := sample if sample != null else song.sample
	var sample_error := _validate_sample(career, new_sample, song.id)
	if not sample_error.is_empty():
		return ActionResult.failure(sample_error)
	var hires := _new_hires(credits, song.credits)
	var new_sample_cost := 0 if new_sample.equals(song.sample) else sample_cost(new_sample)
	var hires_cost := _hires_cost(hires) + new_sample_cost
	if not _economy.can_afford(career, hires_cost):
		return _economy.insufficient_funds(hires_cost)

	_pay_hires(career, hires, clean_title)
	if not new_sample.equals(song.sample):
		_pay_sample(career, new_sample, clean_title)
	song.sample = new_sample
	song.production_cost += hires_cost
	song.title = clean_title
	song.cover_file = cover_file
	_apply_credits_changes(song, credits)
	_update_quality(song)
	song.credits = credits
	career.refresh_album_qualities()
	return ActionResult.success("\"%s\" atualizada. Nota: %d." % [song.title, song.quality], song)


## Melhora um único atributo. Os demais não mudam.
func improve_song(career: CareerData, content_id: String, attribute_id: String) -> ActionResult:
	var content := career.find_content(content_id)
	if content == null:
		return ActionResult.failure("Música não encontrada.")
	if content is AlbumData:
		return ActionResult.failure("Projetos não recebem melhorias. Melhore as músicas antes de lançar.")
	var song: SongData = content
	if song.is_released():
		return ActionResult.failure("\"%s\" já foi lançada e não pode mais ser melhorada." % song.title)
	var rules := _balance.song_quality
	var attribute := rules.find_attribute(attribute_id)
	if attribute == null:
		return ActionResult.failure("Atributo inválido.")
	var room := improvement_room(song, attribute_id)
	if room <= 0:
		return ActionResult.failure("%s já atingiu o limite de melhorias." % attribute.display_name)
	if not _economy.can_spend_energy(career, attribute.energy_cost):
		return ActionResult.failure("Energia insuficiente: melhorar %s custa %d." % [attribute.display_name, attribute.energy_cost])

	_economy.spend_energy(career, attribute.energy_cost)
	var gain := mini(_rng.randi_range(rules.improvement_gain_min, rules.improvement_gain_max), room)
	song.attribute_points[attribute_id] = song.attribute_points.get(attribute_id, 0) + gain
	_update_quality(song)
	career.refresh_album_qualities()
	return ActionResult.success("%s de \"%s\" melhorou +%d. Nota geral: %d." % [attribute.display_name, song.title, gain, song.quality], song)


## Quantos pontos o atributo ainda pode ganhar com melhorias.
func improvement_room(song: SongData, attribute_id: String) -> int:
	return maxi(improvement_limit(song, attribute_id) - song.attribute_value(attribute_id), 0)


func improvement_limit(song: SongData, attribute_id: String) -> int:
	return _quality.attribute_limit(song.attribute_bases.get(attribute_id, 0))


func sample_cost(sample: SongSample) -> int:
	var definition := _balance.samples.find_sample(sample.sample_id)
	return definition.cost if definition != null else 0


## Quanto custariam os colaboradores novos em relação à música, sem alterar nada.
func hiring_cost(credits: SongCredits, song: SongData = null) -> int:
	var previous := song.credits if song != null else SongCredits.new()
	return _hires_cost(_new_hires(credits, previous))


## Nota que a música teria com estes colaboradores, sem alterar nada.
## Sem uma música existente, a prévia desconsidera a variação sorteada na produção.
func preview_quality(credits: SongCredits, song: SongData = null, sample: SongSample = null) -> Preview:
	var preview := Preview.new()
	var solo := _quality.solo_score(0.0)
	if song == null:
		preview.attribute_values[SongData.ATTRIBUTE_VOCAL] = solo
		preview.attribute_values[SongData.ATTRIBUTE_LYRICS] = solo
		preview.attribute_values[SongData.ATTRIBUTE_BEAT] = _quality.beat_score(credits, 0.0)
		preview.attribute_values[SongData.ATTRIBUTE_PRODUCTION] = _quality.production_score(credits, 0.0)
		preview.feat_value = _quality.feats_score(credits)
	else:
		for attribute in _balance.song_quality.attributes:
			preview.attribute_values[attribute.id] = song.attribute_value(attribute.id)
		preview.feat_value = song.feat_score
		if credits.beatmaker_ids != song.credits.beatmaker_ids:
			preview.attribute_values[SongData.ATTRIBUTE_BEAT] = mini(_quality.beat_score(credits, song.beat_roll) + song.attribute_points.get(SongData.ATTRIBUTE_BEAT, 0), 100)
		if credits.producer_ids != song.credits.producer_ids:
			preview.attribute_values[SongData.ATTRIBUTE_PRODUCTION] = mini(_quality.production_score(credits, song.production_roll) + song.attribute_points.get(SongData.ATTRIBUTE_PRODUCTION, 0), 100)
		if credits.feat_ids != song.credits.feat_ids:
			preview.feat_value = _quality.feats_score(credits)
	var preview_sample := sample if sample != null else (song.sample if song != null else SongSample.new())
	preview.quality = _with_sample(_quality.overall(preview.attribute_values, preview.feat_value), preview_sample)
	return preview


func _apply_credits_changes(song: SongData, credits: SongCredits) -> void:
	if credits.beatmaker_ids != song.credits.beatmaker_ids:
		song.attribute_bases[SongData.ATTRIBUTE_BEAT] = _quality.beat_score(credits, song.beat_roll)
	if credits.producer_ids != song.credits.producer_ids:
		song.attribute_bases[SongData.ATTRIBUTE_PRODUCTION] = _quality.production_score(credits, song.production_roll)
	if credits.feat_ids != song.credits.feat_ids:
		song.feat_score = _quality.feats_score(credits)


func _update_quality(song: SongData) -> void:
	var values := {}
	for attribute in _balance.song_quality.attributes:
		values[attribute.id] = song.attribute_value(attribute.id)
	song.quality = _with_sample(_quality.overall(values, song.feat_score), song.sample)


func _with_sample(quality: int, sample: SongSample) -> int:
	var definition := _balance.samples.find_sample(sample.sample_id)
	return clampi(quality + definition.quality_impact, 0, 100) if definition != null else quality


## Devolve a mensagem de erro, ou um texto vazio se o sample for válido.
## O sample próprio exige que o jogador escolha a música: nunca há seleção automática.
func _validate_sample(career: CareerData, sample: SongSample, own_song_id: String) -> String:
	if sample.is_empty():
		return ""
	var definition := _balance.samples.find_sample(sample.sample_id)
	if definition == null:
		return "Sample inválido."
	if not definition.is_own():
		return "" if sample.song_id.is_empty() else "Este sample não usa uma música própria."
	if sample.song_id.is_empty():
		return "Selecione qual música própria será sampleada."
	if career.find_song(sample.song_id) == null:
		return "A música selecionada para o sample não existe."
	if sample.song_id == own_song_id:
		return "Uma música não pode samplear a si mesma."
	return ""


func _pay_sample(career: CareerData, sample: SongSample, song_title: String) -> void:
	var definition := _balance.samples.find_sample(sample.sample_id)
	if definition != null and definition.cost > 0:
		var description := "Sample %s: %s" % [definition.display_name, song_title]
		_economy.spend(career, definition.cost, description, FinanceEntry.CATEGORY_SAMPLE)


func _new_hires(credits: SongCredits, previous: SongCredits) -> Array[Hire]:
	var catalog := _balance.collaborators
	var hires: Array[Hire] = []
	_collect_hires(hires, "Produtor", catalog.producers, credits.producer_ids, previous.producer_ids)
	_collect_hires(hires, "Beatmaker", catalog.beatmakers, credits.beatmaker_ids, previous.beatmaker_ids)
	_collect_hires(hires, "Feat", catalog.feats, credits.feat_ids, previous.feat_ids)
	return hires


func _collect_hires(hires: Array[Hire], role_label: String, pool: Array[CollaboratorDefinition], ids: Array[String], previous_ids: Array[String]) -> void:
	for person in CollaboratorCatalog.resolve(pool, ids):
		if String(person.id) not in previous_ids:
			var hire := Hire.new()
			hire.person = person
			hire.role_label = role_label
			hires.append(hire)


func _hires_cost(hires: Array[Hire]) -> int:
	var total := 0
	for hire in hires:
		total += hire.person.cost
	return total


## Cada contratação vira uma linha própria no histórico financeiro.
func _pay_hires(career: CareerData, hires: Array[Hire], song_title: String) -> void:
	for hire in hires:
		var description := "%s %s: %s" % [hire.role_label, hire.person.display_name, song_title]
		_economy.spend(career, hire.person.cost, description, FinanceEntry.CATEGORY_COLLABORATOR)


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
