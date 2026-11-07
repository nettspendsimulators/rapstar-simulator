extends SceneTree
## Testes de atributos, custos de colaboradores e projetos em construção. Para rodar:
##   godot --headless --path . --script res://tests/test_song_attributes.gd

const GameManagerScript := preload("res://scripts/core/game_manager.gd")
const TEST_SAVE_DIR := "user://test_saves_attributes"
const V2_FIXTURE := "res://tests/fixtures/save_v2.json"
const ATTRIBUTES: Array[String] = ["vocal", "lyrics", "beat", "production"]

var _failures := 0
var _checks := 0


func _init() -> void:
	_clean_saves()
	_test_independent_attributes()
	_test_attribute_costs()
	_test_release_locks_attributes()
	_test_collaborator_catalog_costs()
	_test_collaborator_payment()
	_test_hiring_on_edit()
	_test_not_enough_money()
	_test_empty_projects()
	_test_gradual_project()
	_test_release_gate()
	_test_project_maximum()
	_test_scheduled_project_keeps_minimum()
	_test_round_trip()
	_test_v2_migration()
	_clean_saves()
	print("%d verificações, %d falhas" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FALHOU: ", label)


func _make_game(money: int = 100000000) -> Node:
	var game: Node = GameManagerScript.new()
	game.rng.seed = 7
	game.saves.save_dir = TEST_SAVE_DIR
	game.new_career("MC Teste")
	game.career.money = money
	return game


func _credits(producers: Array[String] = [], beatmakers: Array[String] = [], feats: Array[String] = []) -> SongCredits:
	var credits := SongCredits.new()
	credits.producer_ids = producers
	credits.beatmaker_ids = beatmakers
	credits.feat_ids = feats
	return credits


func _add_songs(game: Node, count: int) -> Array[String]:
	var ids: Array[String] = []
	for i in count:
		ids.append(game.create_song("Faixa %d" % i).value.id)
	return ids


func _test_independent_attributes() -> void:
	var game := _make_game()
	var rules: SongQualityRules = game.balance.song_quality
	_check(rules.attributes.size() == 4, "quatro atributos configurados")
	var total: float = rules.feats_weight
	for attribute in rules.attributes:
		total += attribute.weight
	_check(is_equal_approx(total, 1.0), "pesos somam 1")
	var names := rules.attributes.map(func(item: SongAttributeDefinition) -> String: return item.display_name)
	_check(names == ["Vocal", "Letra", "Beat", "Produção"], "nomes dos atributos")

	var song: SongData = game.create_song("Independente").value
	for improved in ATTRIBUTES:
		game.career.energy = game.balance.max_energy
		var before := {}
		for attribute_id in ATTRIBUTES:
			before[attribute_id] = song.attribute_value(attribute_id)
		_check(game.improve_song(song.id, improved).ok, "melhora %s" % improved)
		for attribute_id in ATTRIBUTES:
			if attribute_id == improved:
				_check(song.attribute_value(attribute_id) > before[attribute_id], "%s subiu" % attribute_id)
			else:
				_check(song.attribute_value(attribute_id) == before[attribute_id], "%s não mudou ao melhorar %s" % [attribute_id, improved])

	var values := {}
	for attribute_id in ATTRIBUTES:
		values[attribute_id] = song.attribute_value(attribute_id)
	_check(song.quality == game.song_quality.overall(values, song.feat_score), "nota geral vem dos quatro atributos")

	# Cada atributo tem seu próprio limite.
	game.career.energy = 100000
	var guard := 0
	while game.improve_song(song.id, "vocal").ok and guard < 100:
		guard += 1
	_check(game.music.improvement_room(song, "vocal") == 0, "vocal no limite")
	_check(game.music.improvement_room(song, "beat") > 0, "beat ainda pode melhorar")
	_check(game.improve_song(song.id, "beat").ok, "limite de um não trava o outro")
	_check(not game.improve_song(song.id, "inventado").ok, "atributo inválido")
	game.free()


func _test_attribute_costs() -> void:
	var game := _make_game(1000)
	var rules: SongQualityRules = game.balance.song_quality
	var seen_costs := {}
	for attribute in rules.attributes:
		seen_costs["%d/%d" % [attribute.energy_cost, attribute.money_cost]] = true
		var song: SongData = game.create_song("Custo %s" % attribute.id).value
		game.career.energy = 100
		game.career.money = 1000
		_check(game.improve_song(song.id, attribute.id).ok, "melhora %s" % attribute.id)
		_check(game.career.energy == 100 - attribute.energy_cost, "energia de %s" % attribute.id)
		_check(game.career.money == 1000 - attribute.money_cost, "dinheiro de %s" % attribute.id)
		var entry: FinanceEntry = game.career.finance_history.back()
		_check(entry.amount == -attribute.money_cost and entry.category == FinanceEntry.CATEGORY_IMPROVEMENT, "histórico de %s" % attribute.id)
	_check(seen_costs.size() == 4, "cada atributo tem custo próprio")

	var broke: SongData = game.create_song("Sem dinheiro").value
	game.career.energy = 100
	game.career.money = 0
	var points_before: int = broke.attribute_points.get("beat", 0)
	_check(not game.improve_song(broke.id, "beat").ok, "sem dinheiro não melhora")
	_check(game.career.energy == 100, "recusa não gasta energia")
	_check(broke.attribute_points.get("beat", 0) == points_before, "recusa não melhora")
	game.free()


func _test_release_locks_attributes() -> void:
	var game := _make_game()
	var song: SongData = game.create_song("Travada").value
	game.improve_song(song.id, "vocal")
	game.release_content(song.id)
	var quality := song.quality
	for attribute_id in ATTRIBUTES:
		var before := song.attribute_value(attribute_id)
		_check(not game.improve_song(song.id, attribute_id).ok, "%s bloqueado após lançar" % attribute_id)
		_check(song.attribute_value(attribute_id) == before, "%s não muda após lançar" % attribute_id)
	_check(song.quality == quality, "nota geral congelada")
	game.free()


func _test_collaborator_catalog_costs() -> void:
	var game := _make_game()
	var catalog: CollaboratorCatalog = game.balance.collaborators
	var expected := [
		[catalog.feats, "drake", 500000], [catalog.feats, "jid", 100000], [catalog.feats, "tyler_the_creator", 250000],
		[catalog.feats, "a_ap_rocky", 250000], [catalog.feats, "lil_uzi_vert", 250000],
		[catalog.producers, "dr_dre", 200000], [catalog.producers, "apollo_brown", 35000], [catalog.producers, "pi_erre_bourne", 40000],
		[catalog.beatmakers, "metro_boomin", 60000], [catalog.beatmakers, "knxwledge", 30000], [catalog.beatmakers, "j_dilla", 50000],
	]
	for item: Array in expected:
		var pool: Array[CollaboratorDefinition] = item[0]
		var ids: Array[String] = [item[1]]
		var people := CollaboratorCatalog.resolve(pool, ids)
		_check(people.size() == 1 and people[0].cost == item[2], "custo de %s" % item[1])
	# A mesma pessoa pode custar diferente em cada função.
	var metro_producer: CollaboratorDefinition = CollaboratorCatalog.resolve(catalog.producers, ["metro_boomin"])[0]
	var metro_beatmaker: CollaboratorDefinition = CollaboratorCatalog.resolve(catalog.beatmakers, ["metro_boomin"])[0]
	_check(metro_producer.cost == 100000 and metro_beatmaker.cost == 60000, "custo por função")
	for pool: Array[CollaboratorDefinition] in [catalog.producers, catalog.beatmakers, catalog.feats]:
		for person in pool:
			_check(person.cost > 0, "%s tem custo" % person.display_name)
	game.free()


func _test_collaborator_payment() -> void:
	var game := _make_game(2000000)
	var credits := _credits(["metro_boomin"], ["j_dilla"], ["drake"])
	_check(game.music.hiring_cost(credits) == 650000, "custo mostrado antes de confirmar")
	_check(game.career.money == 2000000, "ver o custo não cobra")
	var result: ActionResult = game.create_song("Cara", credits)
	_check(result.ok, "contrata os três")
	_check(game.career.money == 2000000 - 100 - 650000, "desconta produção e contratações")
	var song: SongData = result.value
	_check(song.production_cost == 650100, "investimento registrado na música")
	var lines: Array = game.career.finance_history.filter(func(item: FinanceEntry) -> bool: return item.category == FinanceEntry.CATEGORY_COLLABORATOR)
	_check(lines.size() == 3, "uma linha por contratação")
	_check(lines[0].amount == -100000 and "Metro Boomin" in lines[0].description, "linha do produtor")
	_check(lines[1].amount == -50000 and "J Dilla" in lines[1].description, "linha do beatmaker")
	_check(lines[2].amount == -500000 and "Drake" in lines[2].description, "linha do feat")
	game.free()


func _test_hiring_on_edit() -> void:
	var game := _make_game(2000000)
	var song: SongData = game.create_song("Edição", _credits(["cardo"])).value
	var money: int = game.career.money
	_check(game.music.hiring_cost(_credits(["cardo"]), song) == 0, "quem já foi pago não custa de novo")
	_check(game.edit_song(song.id, "Edição", _credits(["cardo"]), "").ok and game.career.money == money, "manter não cobra")
	_check(game.music.hiring_cost(_credits(["cardo", "madlib"]), song) == 50000, "só o novo custa")
	game.edit_song(song.id, "Edição", _credits(["cardo", "madlib"]), "")
	_check(game.career.money == money - 50000, "cobra só o novo")
	money = game.career.money
	game.edit_song(song.id, "Edição", _credits(["madlib"]), "")
	_check(game.career.money == money, "remover não reembolsa")
	game.edit_song(song.id, "Edição", _credits(["madlib", "cardo"]), "")
	_check(game.career.money == money - 40000, "recontratar paga de novo")
	game.free()


func _test_not_enough_money() -> void:
	var game := _make_game(30099)
	var credits := _credits([], ["knxwledge"])
	var result: ActionResult = game.create_song("Sem saldo", credits)
	_check(not result.ok and "insuficiente" in result.message, "falta $1: não contrata")
	_check(game.career.songs.is_empty() and game.career.money == 30099, "recusa não cobra nem cria")
	_check(game.career.finance_history.is_empty(), "recusa não vai para o histórico")
	game.career.money = 30100
	_check(game.create_song("Exato", credits).ok and game.career.money == 0, "valor exato contrata")

	game.career.money = 100
	var song: SongData = game.create_song("Base").value
	game.career.money = 10
	var before := song.credits.to_dict().duplicate(true)
	_check(not game.edit_song(song.id, "Novo", _credits(["cardo"]), "").ok, "editar sem dinheiro é recusado")
	_check(song.title == "Base" and song.credits.to_dict() == before, "recusa mantém a música")
	game.free()


func _test_empty_projects() -> void:
	for format_id: StringName in [&"album", &"ep", &"mixtape"]:
		var game := _make_game(10000)
		var result: ActionResult = game.create_album("Vazio", format_id)
		_check(result.ok, "%s vazio é criado" % format_id)
		var album: AlbumData = result.value
		var album_format: AlbumFormatDefinition = game.balance.find_album_format(format_id)
		_check(album.song_ids.is_empty() and album.quality == 0, "%s sem músicas" % format_id)
		_check(game.career.money == 10000 - album_format.base_cost, "%s cobra só a base" % format_id)
		_check(not album.is_released(), "%s não lançado" % format_id)
		_check(not game.release_content(album.id).ok, "%s vazio não lança" % format_id)
		_check(not game.schedule_release(album.id, 5).ok, "%s vazio não agenda" % format_id)
		game.next_week()
		game.next_week()
		_check(game.career.find_content(album.id) == album, "%s continua existindo" % format_id)
		_check(game.career.last_report().entries.is_empty(), "%s não gera relatório" % format_id)
		game.free()
	var game := _make_game()
	_check(not game.create_album("  ", &"ep").ok, "nome continua obrigatório")
	game.free()


func _test_gradual_project() -> void:
	var game := _make_game()
	var ids := _add_songs(game, 8)
	var album: AlbumData = game.create_album("Aos poucos", &"album").value
	var album_format: AlbumFormatDefinition = game.balance.find_album_format(&"album")
	var money: int = game.career.money
	var tracks: Array[String] = []
	for i in 7:
		tracks.append(ids[i])
		_check(game.update_album(album.id, album.title, &"album", tracks, "").ok, "adiciona faixa %d" % (i + 1))
		_check(album_format.progress_text(album.song_ids.size()) == "Álbum — %d/7 músicas" % (i + 1), "progresso %d" % (i + 1))
		_check(game.career.money == money - album_format.cost_per_song * (i + 1), "cobra faixa %d" % (i + 1))
		game.next_week()
		_check(not album.is_released(), "continua sem lançar")

	tracks.reverse()
	game.update_album(album.id, album.title, &"album", tracks, "")
	_check(album.song_ids == tracks, "reorganiza a tracklist")
	var shorter: Array[String] = tracks.slice(0, 2)
	_check(game.update_album(album.id, album.title, &"album", shorter, "").ok, "remove músicas abaixo do mínimo")
	_check(album.song_ids.size() == 2 and game.career.find_album_of_song(tracks[3]) == null, "músicas removidas ficam livres")
	game.update_album(album.id, album.title, &"album", tracks, "")

	# Melhorar uma faixa inédita continua possível dentro do projeto.
	var quality_before := album.quality
	var track := game.career.find_song(tracks[0]) as SongData
	game.career.energy = 100000
	var guard := 0
	while game.improve_song(track.id, "beat").ok and guard < 100:
		guard += 1
	_check(track.attribute_value("beat") > track.attribute_bases["beat"], "melhora faixa do projeto")
	_check(album.quality == game.career.average_quality(album.song_ids) and album.quality >= quality_before, "média acompanha")
	game.free()


func _test_release_gate() -> void:
	var cases := [[&"album", 7, 150], [&"ep", 3, 75], [&"mixtape", 3, 40]]
	for item: Array in cases:
		var game := _make_game()
		var format_id: StringName = item[0]
		var minimum: int = item[1]
		var ids := _add_songs(game, minimum)
		var album: AlbumData = game.create_album("Portão", format_id).value
		var below: Array[String] = ids.slice(0, minimum - 1)
		game.update_album(album.id, album.title, format_id, below, "")
		var money: int = game.career.money
		_check(not game.releases.release_error(game.career, album).is_empty(), "%s abaixo do mínimo bloqueado" % format_id)
		_check(not game.release_content(album.id).ok, "%s abaixo do mínimo não lança" % format_id)
		_check(not game.schedule_release(album.id, 9).ok, "%s abaixo do mínimo não agenda" % format_id)
		_check(game.career.money == money, "%s recusa não cobra" % format_id)
		game.update_album(album.id, album.title, format_id, ids, "")
		_check(game.releases.release_error(game.career, album).is_empty(), "%s no mínimo liberado" % format_id)
		money = game.career.money
		_check(game.release_content(album.id).ok, "%s no mínimo lança" % format_id)
		_check(game.career.money == money - item[2], "%s cobra o lançamento" % format_id)
		_check(not game.update_album(album.id, "Tarde", format_id, ids, "").ok, "%s lançado trava" % format_id)
		var report: WeekReport = game.next_week()
		_check(report.entries.size() == 1 and report.entries[0].sales > 0, "%s rende" % format_id)
		game.free()
	var progress: AlbumFormatDefinition = _make_format(&"mixtape")
	_check(progress.progress_text(5) == "Mixtape — 5/3 músicas", "progresso acima do mínimo")


func _make_format(format_id: StringName) -> AlbumFormatDefinition:
	var game := _make_game()
	var result: AlbumFormatDefinition = game.balance.find_album_format(format_id)
	game.free()
	return result


func _test_project_maximum() -> void:
	var cases := [[&"album", 20], [&"ep", 6], [&"mixtape", 20]]
	for item: Array in cases:
		var game := _make_game()
		var format_id: StringName = item[0]
		var maximum: int = item[1]
		var ids := _add_songs(game, maximum + 1)
		var at_limit: Array[String] = ids.slice(0, maximum)
		var album: AlbumData = game.create_album("Limite", format_id, at_limit).value
		_check(album != null and album.song_ids.size() == maximum, "%s aceita o máximo" % format_id)
		var money: int = game.career.money
		var result: ActionResult = game.update_album(album.id, album.title, format_id, ids, "")
		_check(not result.ok and str(maximum) in result.message, "%s informa o limite" % format_id)
		_check(album.song_ids.size() == maximum and game.career.money == money, "%s recusa não altera" % format_id)
		_check(not game.create_album("Demais", format_id, ids).ok, "%s não cria acima do máximo" % format_id)
		_check(game.release_content(album.id).ok, "%s no máximo lança" % format_id)
		game.free()


func _test_scheduled_project_keeps_minimum() -> void:
	var game := _make_game()
	var ids := _add_songs(game, 4)
	var album: AlbumData = game.create_album("Agendado", &"ep", ids).value
	game.schedule_release(album.id, 3)
	var short: Array[String] = ids.slice(0, 2)
	_check(not game.update_album(album.id, album.title, &"ep", short, "").ok, "agendado não fica abaixo do mínimo")
	var three: Array[String] = ids.slice(0, 3)
	_check(game.update_album(album.id, album.title, &"ep", three, "").ok, "agendado pode perder faixa acima do mínimo")
	game.cancel_schedule(album.id)
	_check(game.update_album(album.id, album.title, &"ep", short, "").ok, "cancelado pode ficar abaixo do mínimo")
	game.free()


func _test_round_trip() -> void:
	_clean_saves()
	var game := _make_game()
	var song: SongData = game.create_song("Salva", _credits(["cardo"], ["bangladesh"], ["jid"])).value
	game.improve_song(song.id, "vocal")
	game.improve_song(song.id, "lyrics")
	var ids := _add_songs(game, 2)
	game.create_album("Em construção", &"album", ids)
	game.create_album("Vazio", &"ep")
	var expected := JSON.stringify(game.career.to_dict())
	_check(game.save_game().ok and game.load_game().ok, "salva e carrega")
	_check(JSON.stringify(game.career.to_dict()) == expected, "save idêntico")
	var loaded: SongData = game.career.find_song(song.id)
	_check(loaded.attribute_points["vocal"] > 0 and loaded.attribute_points["lyrics"] > 0, "melhorias salvas")
	_check(not loaded.attribute_points.has("beat"), "atributo não melhorado segue sem pontos")
	_check(loaded.attribute_value("vocal") is int, "valores continuam inteiros")
	_check(game.career.albums[1].song_ids.is_empty(), "projeto vazio salvo")
	var hires: Array = game.career.finance_history.filter(func(item: FinanceEntry) -> bool: return item.category == FinanceEntry.CATEGORY_COLLABORATOR)
	_check(hires.size() == 3, "contratações salvas no histórico")
	_check(game.improve_song(song.id, "beat").ok, "continua melhorando")
	game.free()


func _test_v2_migration() -> void:
	_clean_saves()
	DirAccess.make_dir_recursive_absolute(TEST_SAVE_DIR)
	var save_path := TEST_SAVE_DIR.path_join("career.json")
	var fixture_text := FileAccess.get_file_as_string(V2_FIXTURE)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(fixture_text)
	file.close()
	var old_payload: Dictionary = JSON.parse_string(fixture_text)
	var old: Dictionary = old_payload["career"]
	_check(int(old_payload["version"]) == 2, "fixture é v2")

	var game: Node = GameManagerScript.new()
	game.rng.seed = 3
	game.saves.save_dir = TEST_SAVE_DIR
	_check(game.load_game().ok, "carrega save v2 real")
	var career: CareerData = game.career
	_check(FileAccess.get_file_as_string(save_path + ".v2.bak") == fixture_text, "cópia v2 guardada")

	_check(career.money == int(old["money"]) and career.fame == int(old["fame"]), "dinheiro e fama preservados")
	_check(career.reputation == int(old["reputation"]) and career.energy == 40, "reputação e energia preservadas")
	_check(career.current_week == int(old["current_week"]), "semana preservada")
	_check(career.finance_history.size() == old["finance_history"].size(), "histórico preservado")
	_check(career.releases.size() == old["releases"].size(), "lançamentos preservados")
	_check(career.scheduled_releases.size() == old["scheduled_releases"].size(), "agenda preservada")
	_check(career.albums.size() == 2 and career.albums[0].cover_file == "capa_c.webp", "projetos e capas preservados")
	_check(career.songs.size() == old["songs"].size(), "músicas preservadas")

	for index in career.songs.size():
		var song := career.songs[index]
		var old_song: Dictionary = old["songs"][index]
		var values := {}
		for attribute_id in ATTRIBUTES:
			values[attribute_id] = song.attribute_value(attribute_id)
			_check(values[attribute_id] >= 0 and values[attribute_id] <= 100, "%s de %s na faixa" % [attribute_id, song.title])
		_check(song.quality == int(old_song["quality"]), "nota de %s intacta" % song.title)
		_check(game.song_quality.overall(values, song.feat_score) == song.quality, "atributos de %s fecham a nota" % song.title)
		_check(song.title == old_song["title"] and song.cover_file == old_song["cover_file"], "dados de %s" % song.title)
		_check(song.credits.to_dict() == old_song["credits"], "créditos de %s" % song.title)
		var old_beat := int(old_song["beat_quality"])
		var old_production := int(old_song["production_quality"])
		if song.attribute_value("beat") != song.quality:
			_check(song.attribute_value("beat") == old_beat, "beat antigo de %s" % song.title)
			_check(song.attribute_value("production") == old_production, "produção antiga de %s" % song.title)

	# Colaboradores antigos não são cobrados de novo.
	var top: SongData = career.songs[1]
	_check(top.title == "Inédita top", "música esperada")
	_check(game.music.hiring_cost(top.credits, top) == 0, "créditos antigos já estão pagos")
	var money_before: int = career.money
	var quality_before := top.quality
	_check(game.edit_song(top.id, "Top renomeada", top.credits, top.cover_file).ok, "edita música migrada")
	_check(career.money == money_before and top.quality == quality_before, "editar não cobra nem muda a nota")

	var solo: SongData = career.songs[3]
	_check(solo.title == "Solo", "música solo esperada")
	var solo_value := solo.attribute_value("lyrics")
	career.money = 100000
	_check(game.improve_song(solo.id, "lyrics").ok and solo.attribute_value("lyrics") > solo_value, "melhora atributo migrado")
	_check(not game.improve_song(career.songs[0].id, "beat").ok, "lançada migrada segue bloqueada")

	# Agendamento antigo continua saindo sozinho.
	var scheduled_ep: AlbumData = career.albums[0]
	while career.current_week < 6:
		game.next_week()
	_check(scheduled_ep.is_released(), "agendamento v2 acontece")

	_check(game.save_game().ok, "salva migrado")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	_check(int(saved["version"]) == SaveSystem.SAVE_VERSION, "arquivo agora é v3")
	var expected := JSON.stringify(game.career.to_dict())
	_check(game.load_game().ok and JSON.stringify(game.career.to_dict()) == expected, "migrado recarrega igual")
	game.free()


func _clean_saves() -> void:
	if not DirAccess.dir_exists_absolute(TEST_SAVE_DIR):
		return
	for file_name in DirAccess.get_files_at(TEST_SAVE_DIR):
		DirAccess.remove_absolute(TEST_SAVE_DIR.path_join(file_name))
	DirAccess.remove_absolute(TEST_SAVE_DIR)
