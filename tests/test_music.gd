extends SceneTree
## Testes da expansão musical, sem interface. Para rodar:
##   godot --headless --path . --script res://tests/test_music.gd

const GameManagerScript := preload("res://scripts/core/game_manager.gd")
const TEST_SAVE_DIR := "user://test_saves_music"
const V1_FIXTURE := "res://tests/fixtures/save_v1.json"

var _failures := 0
var _checks := 0


func _init() -> void:
	_clean_saves()
	_test_catalog()
	_test_credit_limits()
	_test_quality_formula()
	_test_edit_rules()
	_test_improvements()
	_test_energy_week()
	_test_project_formats()
	_test_project_editing()
	_test_project_quality_follows_songs()
	_test_format_multipliers()
	_test_schedule_flow()
	_test_schedule_edge_cases()
	_test_covers()
	_test_v2_round_trip()
	_test_v1_migration()
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
	game.rng.seed = 42
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


func _test_catalog() -> void:
	var game := _make_game()
	var catalog: CollaboratorCatalog = game.balance.collaborators
	_check(catalog.producers.size() == 20, "20 produtores")
	_check(catalog.beatmakers.size() == 20, "20 beatmakers")
	_check(catalog.feats.size() == 20, "20 feats")
	var feat_names := CollaboratorCatalog.names(catalog.feats, ["tyler_the_creator", "a_ap_rocky"])
	_check(feat_names == PackedStringArray(["Tyler, The Creator", "A$AP Rocky"]), "nomes com vírgula e símbolo")
	game.free()


func _test_credit_limits() -> void:
	var game := _make_game()
	var ok := _credits(
		["metro_boomin", "dr_dre", "madlib"],
		["j_dilla", "nujabes", "rza"],
		["drake", "nas", "sza", "eminem", "jid"]
	)
	_check(game.create_song("Cheia", ok).ok, "3 produtores, 3 beatmakers, 5 feats")
	var money_after_ok: int = game.career.money
	_check(not game.create_song("P", _credits(["metro_boomin", "dr_dre", "madlib", "cardo"])).ok, "4 produtores recusados")
	_check(not game.create_song("B", _credits([], ["j_dilla", "nujabes", "rza", "cardo"])).ok, "4 beatmakers recusados")
	_check(not game.create_song("F", _credits([], [], ["drake", "nas", "sza", "eminem", "jid", "future"])).ok, "6 feats recusados")
	_check(not game.create_song("D", _credits(["dr_dre", "dr_dre"])).ok, "colaborador repetido recusado")
	_check(not game.create_song("X", _credits(["inventado"])).ok, "colaborador desconhecido recusado")
	_check(not game.create_song("R", _credits(["j_dilla"])).ok, "beatmaker não vale como produtor")
	_check(game.career.songs.size() == 1, "recusas não criam música")
	_check(game.career.money == money_after_ok, "recusas não cobram")
	game.free()


func _test_quality_formula() -> void:
	var game := _make_game()
	var quality: SongQualitySystem = game.song_quality
	_check(quality.beat_score(SongCredits.new(), 0.0) == 50, "beat sem colaboradores vale 50")
	_check(quality.production_score(SongCredits.new(), 0.0) == 50, "produção sem colaboradores vale 50")
	_check(quality.feats_score(SongCredits.new()) == 50, "feats sem colaboradores valem 50")
	_check(quality.solo_score(0.0) == 50, "vocal e letra partem de 50")

	_check(quality.production_score(_credits(["dr_dre"]), 0.0) == 98, "produtor define a produção")
	_check(quality.beat_score(_credits(["dr_dre"]), 0.0) == 50, "produtor não afeta o beat")
	_check(quality.beat_score(_credits([], ["j_dilla"]), 0.0) == 98, "beatmaker define o beat")
	_check(quality.production_score(_credits([], ["j_dilla"]), 0.0) == 50, "beatmaker não afeta a produção")
	_check(quality.feats_score(_credits([], [], ["kendrick_lamar"])) == 98, "feat define as participações")

	_check(quality.production_score(_credits(["dr_dre", "kanye_west"]), 0.0) == 100, "bônus de equipe limitado a 100")
	_check(quality.production_score(_credits(["dr_dre", "cardo"]), 0.0) == 92, "média de 98 e 81 + bônus de 2")

	var steady := quality.production_score(_credits(["dr_dre"]), 1.0)
	var erratic := quality.production_score(_credits(["madlib"]), 1.0)
	_check(steady - 98 < erratic - 91, "consistência menor varia mais")
	var worst := quality.production_score(_credits(["madlib"]), -1.0)
	_check(worst < 91 and worst >= 0, "variação negativa dentro de 0 a 100")

	# Vocal 20%, Letra 15%, Beat 30%, Produção 25%, feats 10%.
	var all_50 := {"vocal": 50, "lyrics": 50, "beat": 50, "production": 50}
	_check(quality.overall(all_50, 50) == 50, "pesos somam 1")
	var all_100 := {"vocal": 100, "lyrics": 100, "beat": 100, "production": 100}
	_check(quality.overall(all_100, 100) == 100, "nota máxima")
	_check(quality.overall({"vocal": 100, "lyrics": 50, "beat": 50, "production": 50}, 50) == 60, "peso do vocal")
	_check(quality.overall({"vocal": 50, "lyrics": 100, "beat": 50, "production": 50}, 50) == 58, "peso da letra")
	_check(quality.overall({"vocal": 50, "lyrics": 50, "beat": 100, "production": 50}, 50) == 65, "peso do beat")
	_check(quality.overall({"vocal": 50, "lyrics": 50, "beat": 50, "production": 100}, 50) == 63, "peso da produção")
	_check(quality.overall(all_50, 100) == 55, "peso das participações")
	game.free()


func _test_edit_rules() -> void:
	var game := _make_game()
	var song: SongData = game.create_song("Original", _credits(["dr_dre"], ["j_dilla"])).value
	var quality_before := song.quality
	var rolls := [song.beat_roll, song.production_roll]

	_check(game.edit_song(song.id, "Novo nome", song.credits, "").ok, "edita antes de lançar")
	_check(song.title == "Novo nome" and song.quality == quality_before, "renomear não muda a nota")
	var unchanged_money: int = game.career.money
	_check(game.edit_song(song.id, "Novo nome", song.credits, "capa.webp").ok, "editar nome e capa")
	_check(game.career.money == unchanged_money, "editar sem contratar é gratuito")
	_check(game.edit_song(song.id, "Pior", _credits(["cardo"], ["bangladesh"]), "").ok, "troca colaboradores")
	_check(song.quality < quality_before, "colaboradores piores baixam a nota")
	_check(rolls == [song.beat_roll, song.production_roll], "editar não sorteia a nota de novo")
	game.edit_song(song.id, "Pior", _credits(["dr_dre"], ["j_dilla"]), "")
	_check(song.quality == quality_before, "voltar aos colaboradores restaura a nota")
	_check(not game.edit_song(song.id, "  ", song.credits, "").ok, "nome vazio recusado")

	var title_before := song.title
	game.release_content(song.id)
	_check(not game.edit_song(song.id, "Depois", _credits(), "").ok, "lançada não edita")
	_check(song.title == title_before and song.credits.producer_ids == ["dr_dre"], "dados bloqueados")
	_check(not game.improve_song(song.id, "vocal").ok, "lançada não melhora")
	game.free()


func _test_improvements() -> void:
	var game := _make_game()
	var rules: SongQualityRules = game.balance.song_quality
	var attribute := rules.find_attribute("beat")
	var song: SongData = game.create_song("Melhorável").value
	var base := song.attribute_value("beat")
	var limit := mini(base + rules.max_improvement_points, 100)

	_check(game.career.energy == game.balance.max_energy, "começa com energia cheia")
	var energy_before: int = game.career.energy
	_check(game.improve_song(song.id, "beat").ok, "melhoria")
	var gained := song.attribute_value("beat") - base
	_check(gained >= rules.improvement_gain_min and gained <= rules.improvement_gain_max, "ganho na faixa")
	_check(game.career.energy == energy_before - attribute.energy_cost, "gasta energia")

	game.career.energy = 0
	var value_before := song.attribute_value("beat")
	_check(not game.improve_song(song.id, "beat").ok, "sem energia não melhora")
	_check(song.attribute_value("beat") == value_before, "falha não altera a nota")

	game.career.energy = 100000
	var guard := 0
	while game.improve_song(song.id, "beat").ok and guard < 100:
		guard += 1
	_check(song.attribute_value("beat") == limit, "melhorias param no limite")
	var energy_at_limit: int = game.career.energy
	_check(not game.improve_song(song.id, "beat").ok, "no limite é recusado")
	_check(game.career.energy == energy_at_limit, "recusa no limite não gasta energia")

	var points: int = song.attribute_points["beat"]
	game.edit_song(song.id, song.title, _credits([], ["cardo"]), "")
	_check(song.attribute_points["beat"] == points, "editar mantém as melhorias")
	_check(song.attribute_value("beat") == song.attribute_bases["beat"] + points, "atributo soma base e melhorias")

	# O limite absoluto de 100 vale mesmo para atributos de base alta.
	var top: SongData = game.create_song("Topo", _credits(["dr_dre", "kanye_west"], ["j_dilla", "dj_premier"], ["kendrick_lamar", "nas"])).value
	guard = 0
	while game.improve_song(top.id, "beat").ok and guard < 100:
		guard += 1
	_check(top.attribute_value("beat") <= 100 and top.quality <= 100, "nota nunca passa de 100")
	game.free()


func _test_energy_week() -> void:
	var game := _make_game()
	game.career.energy = 5
	game.next_week()
	_check(game.career.energy == game.balance.max_energy, "energia volta com a semana")
	game.career.energy = 5
	game.work_job(&"delivery")
	_check(game.career.energy == game.balance.max_energy, "trabalhar também passa a semana e repõe energia")
	game.free()


func _test_project_formats() -> void:
	var game := _make_game()
	var ids := _add_songs(game, 21)
	_check(not game.create_album("EP", &"ep", ids.slice(0, 7)).ok, "EP com 7 recusado")
	_check(not game.create_album("Álbum", &"album", ids).ok, "álbum com 21 recusado")
	_check(not game.create_album("Mix", &"mixtape", ids).ok, "mixtape com 21 recusada")
	_check(not game.create_album("Mix", &"nao_existe", ids.slice(0, 3)).ok, "formato inválido")
	_check(game.create_album("EP", &"ep", ids.slice(0, 6)).ok, "EP com 6")
	_check(game.create_album("Mix", &"mixtape", ids.slice(6, 9)).ok, "mixtape com 3")
	_check(game.create_album("Álbum", &"album", ids.slice(9, 16)).ok, "álbum com 7")
	_check(not game.create_album("Repete", &"ep", ids.slice(0, 3)).ok, "música em dois projetos recusada")
	var album: AlbumData = game.career.albums[2]
	_check(game.releases.content_type_label(album) == "Álbum", "tipo do projeto")
	_check(game.releases.content_type_label(game.career.songs[0]) == "Single", "música sozinha é single")
	_check(not game.balance.find_album_format(&"mixtape").summary().is_empty(), "formato se explica")
	_check(not game.improve_song(album.id, "beat").ok, "projeto não recebe melhoria")
	game.free()


func _test_project_editing() -> void:
	var game := _make_game()
	var ids := _add_songs(game, 8)
	game.release_content(ids[0])
	var result: ActionResult = game.create_album("Misto", &"ep", ids.slice(0, 3), "capa.webp")
	_check(result.ok, "projeto com música já lançada e inéditas")
	var album: AlbumData = result.value
	_check(album.cover_file == "capa.webp", "capa do projeto")
	var paid := album.production_cost
	var money_before: int = game.career.money

	var reordered: Array[String] = [ids[2], ids[0], ids[1]]
	_check(game.update_album(album.id, "Misto 2", &"ep", reordered, "").ok, "reordena")
	_check(album.song_ids == reordered and album.title == "Misto 2", "ordem e nome salvos")
	_check(game.career.money == money_before, "reordenar é gratuito")

	var bigger: Array[String] = [ids[2], ids[0], ids[1], ids[3]]
	_check(game.update_album(album.id, "Misto 2", &"ep", bigger, "").ok, "adiciona música")
	_check(game.career.money == money_before - 20, "cobra só a faixa extra")
	_check(album.production_cost == paid + 20, "custo acumulado")
	money_before = game.career.money
	_check(game.update_album(album.id, "Misto 2", &"ep", reordered, "").ok, "remove música")
	_check(game.career.money == money_before, "remover não reembolsa nem cobra")
	_check(game.career.find_album_of_song(ids[3]) == null, "música removida fica livre")

	game.create_album("Outro", &"mixtape", ids.slice(3, 6))
	var stolen: Array[String] = [ids[2], ids[0], ids[3]]
	_check(not game.update_album(album.id, "Misto 2", &"ep", stolen, "").ok, "não pega música de outro projeto")

	_check(game.release_content(album.id).ok, "lança")
	_check(not game.update_album(album.id, "Tarde", &"ep", reordered, "").ok, "lançado não edita")
	_check(album.title == "Misto 2", "nome bloqueado")
	_check(game.career.find_song(ids[1]).is_released(), "faixa inédita sai com o projeto")
	game.free()


func _test_project_quality_follows_songs() -> void:
	var game := _make_game()
	var ids := _add_songs(game, 3)
	var album: AlbumData = game.create_album("Média", &"ep", ids).value
	var songs: Array = ids.map(func(id: String) -> SongData: return game.career.find_song(id))
	var expected := roundi((songs[0].quality + songs[1].quality + songs[2].quality) / 3.0)
	_check(album.quality == expected, "nota é a média")
	game.improve_song(ids[0], "beat")
	game.improve_song(ids[0], "production")
	expected = roundi((songs[0].quality + songs[1].quality + songs[2].quality) / 3.0)
	_check(album.quality == expected, "melhorar uma faixa atualiza a média")
	game.edit_song(ids[1], "Faixa", _credits(["dr_dre"]), "")
	expected = roundi((songs[0].quality + songs[1].quality + songs[2].quality) / 3.0)
	_check(album.quality == expected, "editar uma faixa atualiza a média")
	game.release_content(album.id)
	var frozen := album.quality
	game.career.refresh_album_qualities()
	_check(album.quality == frozen, "nota do lançado fica congelada")
	game.free()


func _test_format_multipliers() -> void:
	var game := _make_game()
	var rules: PerformanceRules = game.balance.album_performance
	var fixed := PerformanceRules.new()
	fixed.units_min = 1000
	fixed.units_max = 1000
	fixed.money_per_unit = rules.money_per_unit
	fixed.units_per_fame = rules.units_per_fame
	var album: PerformanceSystem.Result = game.performance.calculate_week(fixed, 50, 0, 0)
	var ep: AlbumFormatDefinition = game.balance.find_album_format(&"ep")
	var ep_result: PerformanceSystem.Result = game.performance.calculate_week(fixed, 50, 0, 0, ep.units_multiplier, ep.fame_multiplier)
	var mix: AlbumFormatDefinition = game.balance.find_album_format(&"mixtape")
	var mix_result: PerformanceSystem.Result = game.performance.calculate_week(fixed, 50, 0, 0, mix.units_multiplier, mix.fame_multiplier)
	_check(album.units == 1000 and ep_result.units == 600 and mix_result.units == 400, "vendas por formato")
	_check(album.fame == 10 and ep_result.fame == 8 and mix_result.fame == 12, "fama por formato")
	_check(game.performance.reputation_change(70, mix.reputation_multiplier) == 1, "mixtape pesa menos na reputação")
	_check(game.performance.reputation_change(70) == 2, "álbum pesa inteiro na reputação")
	game.free()


func _test_schedule_flow() -> void:
	var game := _make_game()
	var song: SongData = game.create_song("Agendada").value
	var money_before: int = game.career.money
	_check(not game.schedule_release(song.id, 1).ok, "não agenda para a semana atual")
	_check(not game.schedule_release(song.id, 1000).ok, "não agenda além do limite")
	_check(game.schedule_release(song.id, 3).ok, "agenda para a semana 3")
	_check(game.career.money == money_before - 50, "paga ao agendar")
	_check(not song.is_released(), "ainda não saiu")
	_check(game.releases.unreleased_content(game.career).is_empty(), "sai da lista de prontos")
	_check(not game.schedule_release(song.id, 4).ok, "não agenda duas vezes")
	_check(not game.release_content(song.id).ok, "agendada não lança na hora")

	_check(game.reschedule_release(song.id, 2).ok, "remarca para a semana 2")
	_check(not game.reschedule_release(song.id, 1).ok, "não remarca para o passado")
	var entry: ScheduledRelease = game.career.find_active_schedule(song.id)
	_check(entry.scheduled_week == 2, "semana remarcada")

	var money_at_release: int = game.career.money
	var report: WeekReport = game.next_week()
	_check(song.is_released() and song.release_week == 2, "sai sozinha na semana marcada")
	_check(entry.status_label() == "Lançado", "status lançado")
	_check(game.career.find_release(song.id) != null, "entra nos lançamentos")
	_check(game.career.money == money_at_release, "não cobra de novo nem rende antes da hora")
	_check(report.entries.size() == 1 and not report.entries[0].note.is_empty(), "relatório avisa do lançamento")

	var fame_before: int = game.career.fame
	var next: WeekReport = game.next_week()
	var music_lines := next.entries.filter(func(entry: WeekReportEntry) -> bool: return not entry.title.contains("proposta(s) de show"))
	_check(music_lines.size() == 1 and music_lines[0].streams > 0, "rende na semana seguinte")
	_check(game.career.money == money_at_release + next.total_money(), "dinheiro entra pelo sistema existente")
	_check(game.career.fame == fame_before + next.total_fame(), "fama entra pelo sistema existente")
	_check(game.career.find_active_schedule(song.id) == null, "agendamento encerrado")

	var other: SongData = game.create_song("Cancelada").value
	game.schedule_release(other.id, game.career.current_week + 2)
	money_before = game.career.money
	_check(game.cancel_schedule(other.id).ok, "cancela")
	_check(game.career.money == money_before + 50, "devolve o custo")
	_check(game.career.scheduled_releases.back().status_label() == "Cancelado", "status cancelado")
	game.next_week()
	game.next_week()
	game.next_week()
	_check(not other.is_released(), "cancelada não sai")
	_check(game.release_content(other.id).ok, "cancelada pode ser lançada depois")
	game.free()


func _test_schedule_edge_cases() -> void:
	var game := _make_game(1000)
	var song: SongData = game.create_song("Sem saldo").value
	game.career.money = 10
	_check(not game.schedule_release(song.id, 5).ok, "sem dinheiro não agenda")
	_check(game.career.scheduled_releases.is_empty(), "recusa não cria agendamento")

	game.career.money = 100000
	var ids := _add_songs(game, 3)
	var album: AlbumData = game.create_album("Projeto", &"ep", ids).value
	_check(game.schedule_release(ids[0], 5).ok, "single de uma faixa")
	_check(game.schedule_release(album.id, 3).ok, "projeto agendado")
	_check(not game.update_album(album.id, album.title, &"mixtape", ids, "").ok, "não muda formato agendado")
	_check(game.update_album(album.id, "Projeto novo", &"ep", ids, "").ok, "agendado ainda pode ser editado")

	game.next_week()
	var money_before: int = game.career.money
	var reputation_before: int = game.career.reputation
	var report: WeekReport = game.next_week()
	_check(album.is_released() and album.release_week == 3, "projeto sai na semana marcada")
	_check(game.career.find_song(ids[0]).is_released(), "faixa sai com o projeto")
	_check(game.career.find_active_schedule(ids[0]) == null, "single da faixa cancelado")
	_check(game.career.money == money_before + 50, "custo do single devolvido")
	_check(report.total_money() == 50, "relatório mostra o reembolso")
	var expected_reputation: int = game.performance.reputation_change(album.quality)
	_check(game.career.reputation == reputation_before + expected_reputation, "reputação do projeto aplicada")
	_check(game.career.releases.size() == 1, "só o projeto vira lançamento")

	var due_a: SongData = game.create_song("A").value
	var due_b: SongData = game.create_song("B").value
	var week: int = game.career.current_week + 1
	game.schedule_release(due_a.id, week)
	game.schedule_release(due_b.id, week)
	var both: WeekReport = game.work_job(&"delivery").value
	_check(due_a.is_released() and due_b.is_released(), "dois lançamentos na mesma semana, inclusive trabalhando")
	_check(both.week == week, "relatório da semana certa")
	game.free()


func _test_covers() -> void:
	_clean_saves()
	var game := _make_game()
	var covers: CoverSystem = game.covers
	var size: int = game.balance.cover_size

	# Imagem larga: metade esquerda azul, metade direita vermelha, com o centro no meio das duas.
	var wide := Image.create(400, 100, false, Image.FORMAT_RGBA8)
	wide.fill_rect(Rect2i(0, 0, 200, 100), Color.BLUE)
	wide.fill_rect(Rect2i(200, 0, 200, 100), Color.RED)
	var result: ActionResult = covers.import_image(wide)
	_check(result.ok and result.value.ends_with(".webp"), "imagem importada")
	var texture: Texture2D = covers.get_texture(result.value)
	_check(texture != null and texture.get_width() == size and texture.get_height() == size, "capa quadrada no tamanho configurado")
	var stored := texture.get_image()
	stored.convert(Image.FORMAT_RGB8)
	_check(stored.get_pixel(5, size / 2).b > 0.6 and stored.get_pixel(size - 5, size / 2).r > 0.6, "recorta pelo centro")
	_check(covers.import_image(wide).value == result.value, "mesma imagem não duplica")

	# Área de transferência do Windows pode entregar DIB de 32 bits com alfa zerado.
	var zero_alpha := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	zero_alpha.fill(Color(0.1, 0.8, 0.2, 0.0))
	var opaque: Texture2D = covers.get_texture(covers.import_image(zero_alpha).value)
	var opaque_image := opaque.get_image()
	opaque_image.convert(Image.FORMAT_RGBA8)
	var pixel := opaque_image.get_pixel(30, 30)
	_check(pixel.a > 0.99 and pixel.g > 0.6, "alfa zerado continua visível")

	# Leitura de arquivo.
	var dir := ProjectSettings.globalize_path(TEST_SAVE_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var png_path := dir.path_join("origem.png")
	wide.save_png(png_path)
	var from_file: ActionResult = covers.import_file(png_path)
	_check(from_file.ok, "importa PNG de qualquer pasta")
	_check(not covers.import_file(dir.path_join("nao_existe.png")).ok, "arquivo ausente é recusado")
	var text_path := dir.path_join("texto.png")
	var fake := FileAccess.open(text_path, FileAccess.WRITE)
	fake.store_string("isto nao é imagem")
	fake.close()
	_check(not covers.import_file(text_path).ok, "arquivo inválido é recusado")
	_check(not covers.import_image(Image.new()).ok, "imagem vazia é recusada")

	# Persistência: a capa precisa sobreviver a salvar e carregar em um novo processo do jogo.
	var song: SongData = game.create_song("Com capa", null, from_file.value).value
	var album_ids := _add_songs(game, 3)
	game.create_album("Projeto com capa", &"ep", album_ids, result.value)
	game.save_game()
	var fresh: Node = GameManagerScript.new()
	fresh.saves.save_dir = TEST_SAVE_DIR
	_check(fresh.load_game().ok, "carrega save com capas")
	var loaded_song: SongData = fresh.career.find_song(song.id)
	_check(loaded_song.cover_file == from_file.value, "capa da música salva")
	_check(fresh.covers.get_texture(loaded_song.cover_file) != null, "capa da música abre após carregar")
	_check(fresh.covers.get_texture(fresh.career.albums[0].cover_file) != null, "capa do projeto abre após carregar")

	# Um arquivo apagado não pode derrubar o jogo.
	_check(covers.get_texture("") == null, "sem capa")
	_check(covers.get_texture("sumiu.webp") == null, "capa ausente não quebra")
	fresh.free()
	game.free()


func _test_v2_round_trip() -> void:
	_clean_saves()
	var game := _make_game()
	var song: SongData = game.create_song("Completa", _credits(["dr_dre"], ["j_dilla"], ["nas"]), "capa.webp").value
	game.improve_song(song.id, "vocal")
	var ids := _add_songs(game, 3)
	game.create_album("Projeto", &"mixtape", ids, "projeto.webp")
	game.schedule_release(song.id, 5)
	game.schedule_release(game.career.albums[0].id, 4)
	game.cancel_schedule(game.career.albums[0].id)
	game.career.energy = 37
	game.next_week()
	game.career.energy = 37
	var expected := JSON.stringify(game.career.to_dict())
	_check(game.save_game().ok, "salva v2")
	_check(game.load_game().ok, "carrega v2")
	_check(JSON.stringify(game.career.to_dict()) == expected, "v2 idêntico após carregar")
	var loaded: SongData = game.career.find_song(song.id)
	_check(loaded.credits.feat_ids == ["nas"] and loaded.attribute_points["vocal"] > 0, "créditos e melhorias salvos")
	_check(game.career.energy == 37, "energia salva")
	_check(game.career.find_active_schedule(song.id).scheduled_week == 5, "agenda salva")
	game.next_week()
	game.next_week()
	game.next_week()
	_check(game.career.find_song(song.id).is_released(), "agendamento carregado continua funcionando")
	_check(not FileAccess.file_exists(TEST_SAVE_DIR.path_join("career.json.v2.bak")), "save atual não gera cópia")
	game.free()


func _test_v1_migration() -> void:
	_clean_saves()
	DirAccess.make_dir_recursive_absolute(TEST_SAVE_DIR)
	var save_path := TEST_SAVE_DIR.path_join("career.json")
	var fixture_text := FileAccess.get_file_as_string(V1_FIXTURE)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(fixture_text)
	file.close()
	var old: Dictionary = JSON.parse_string(fixture_text)["career"]

	var game: Node = GameManagerScript.new()
	game.rng.seed = 1
	game.saves.save_dir = TEST_SAVE_DIR
	_check(game.load_game().ok, "carrega save v1 real")
	var career: CareerData = game.career
	_check(FileAccess.get_file_as_string(save_path + ".v1.bak") == fixture_text, "cópia do save original guardada")

	# Nenhum progresso perdido.
	_check(career.artist_name == old["artist_name"], "nome preservado")
	_check(career.money == int(old["money"]) and career.fame == int(old["fame"]), "dinheiro e fama preservados")
	_check(career.reputation == int(old["reputation"]), "reputação preservada")
	_check(career.current_week == int(old["current_week"]), "semana preservada")
	_check(career.next_id == int(old["next_id"]), "contador de ids preservado")
	_check(career.songs.size() == old["songs"].size() and career.songs.size() == 8, "músicas preservadas")
	_check(career.albums.size() == 2, "projetos preservados")
	_check(career.releases.size() == old["releases"].size(), "lançamentos preservados")
	_check(career.finance_history.size() == old["finance_history"].size(), "histórico financeiro preservado")
	_check(career.week_reports.size() == old["week_reports"].size(), "relatórios preservados")
	for index in career.songs.size():
		var song := career.songs[index]
		var old_song: Dictionary = old["songs"][index]
		_check(song.title == old_song["title"] and song.quality == int(old_song["quality"]), "música %d intacta" % index)
		_check(song.attribute_bases.size() == 4, "atributos da música %d" % index)
		_check(song.status == old_song["status"], "status da música %d" % index)

	# Novos campos com valores coerentes.
	_check(career.energy == game.balance.max_energy, "energia inicial na migração")
	_check(career.scheduled_releases.is_empty(), "agenda vazia")
	_check(career.songs[0].cover_file == "", "sem capa")
	_check(career.songs[0].attribute_value("beat") == career.songs[0].quality, "atributos partem da nota antiga")

	# Regra dos formatos: o lançado fica como estava e o inédito vira EP lançável.
	var released: AlbumData = career.albums[0]
	var pending: AlbumData = career.albums[1]
	_check(released.is_released() and released.format_id == "album", "álbum lançado mantém o formato")
	_check(released.quality == int(old["albums"][0]["quality"]), "nota do álbum lançado intacta")
	_check(not pending.is_released() and pending.format_id == "ep", "álbum inédito curto vira EP")
	_check(pending.quality == int(old["albums"][1]["quality"]), "nota do projeto inédito intacta")

	# O jogo segue funcionando com os dados migrados.
	var report: WeekReport = game.next_week()
	_check(report.entries.size() == 2, "lançamentos antigos continuam rendendo")
	_check(game.release_content(pending.id).ok, "projeto migrado pode ser lançado")
	var legacy: SongData = career.songs[7]
	var legacy_quality := legacy.quality
	_check(game.edit_song(legacy.id, "Renomeada", legacy.credits, "").ok, "música antiga edita")
	_check(legacy.quality == legacy_quality, "renomear música antiga não muda a nota")
	_check(game.improve_song(legacy.id, "beat").ok and legacy.quality >= legacy_quality, "música antiga melhora")
	_check(not game.edit_song(career.songs[0].id, "X", SongCredits.new(), "").ok, "música antiga lançada segue bloqueada")

	# Salvar de novo grava v2, e a cópia v1 não é tocada.
	_check(game.save_game().ok, "salva migrado")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	_check(int(saved["version"]) == SaveSystem.SAVE_VERSION, "arquivo agora é v2")
	_check(FileAccess.get_file_as_string(save_path + ".v1.bak") == fixture_text, "cópia v1 preservada")
	var expected := JSON.stringify(game.career.to_dict())
	_check(game.load_game().ok and JSON.stringify(game.career.to_dict()) == expected, "migrado recarrega igual")
	game.free()


func _clean_saves() -> void:
	var dir := TEST_SAVE_DIR
	if not DirAccess.dir_exists_absolute(dir):
		return
	var covers := dir.path_join("covers")
	if DirAccess.dir_exists_absolute(covers):
		for file_name in DirAccess.get_files_at(covers):
			DirAccess.remove_absolute(covers.path_join(file_name))
		DirAccess.remove_absolute(covers)
	for file_name in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file_name))
	DirAccess.remove_absolute(dir)
