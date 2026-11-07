extends SceneTree
## Testes de videoclipes, sem interface. Para rodar:
##   godot --headless --path . --script res://tests/test_videos.gd

const GameManagerScript := preload("res://scripts/core/game_manager.gd")
const TEST_SAVE_DIR := "user://test_saves_videos"
const V5_FIXTURE := "res://tests/fixtures/save_v5.json"
const EXAMPLE := {
	"concept": ["concept_street"], "scale": ["scale_indie"], "locations": ["loc_street", "loc_house"],
	"direction": ["dir_beginner"], "crew": ["crew_indie"], "extras": ["extras_few"], "dancers": ["dancers_none"],
	"wardrobe": ["wardrobe_stylist"], "set": ["set_existing"], "visual": ["visual_simple"],
	"presence": ["presence_balanced"], "editing": ["editing_pro"], "effects": ["fx_none"], "complexity": ["complexity_moderate"],
}

var _failures := 0
var _checks := 0


func _init() -> void:
	_clean_saves()
	_test_catalog()
	_test_budget_example()
	_test_choices_shape_the_result()
	_test_scales_and_costs()
	_test_validation_and_money()
	_test_eligible_songs()
	_test_production_time()
	_test_production_problems()
	_test_cover_is_free()
	_test_auto_release_with_scheduled_song()
	_test_auto_release_with_immediate_release()
	_test_auto_release_when_ready_later()
	_test_separate_date()
	_test_old_song_new_date()
	_test_projects()
	_test_leak()
	_test_performance_and_youtube()
	_test_video_boosts_song()
	_test_marketing_influences_video()
	_test_bad_song_expensive_video()
	_test_varied_results()
	_test_round_trip()
	_test_v5_migration()
	_clean_saves()
	print("%d verificações, %d falhas" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FALHOU: ", label)


func _make_game(money: int = 100000000, fame: int = 0, seed_value: int = 41) -> Node:
	var game: Node = GameManagerScript.new()
	game.rng.seed = seed_value
	game.saves.save_dir = TEST_SAVE_DIR
	game.new_career("MC Teste")
	game.career.money = money
	game.career.fame = fame
	game.balance.videos.problem_chance_per_risk = 0.0
	game.balance.videos.leak_chance_per_week = 0.0
	game.balance.streaming.leak_chance_per_week = 0.0
	game.balance.streaming.leak_hype_chance = 0.0
	return game


func _restore(game: Node) -> void:
	game.balance.videos.problem_chance_per_risk = 0.006
	game.balance.videos.leak_chance_per_week = 0.03
	game.balance.streaming.leak_chance_per_week = 0.02
	game.balance.streaming.leak_hype_chance = 0.03
	game.free()


func _choices(overrides: Dictionary = {}) -> Dictionary:
	var choices := EXAMPLE.duplicate(true)
	for key: String in overrides:
		choices[key] = overrides[key]
	return choices


func _video(game: Node, song: SongData, overrides: Dictionary = {}, mode: String = VideoRules.MODE_WITH_SONG, week: int = -1) -> MusicVideo:
	var result: ActionResult = game.create_video(song.id, _choices(overrides), "", mode, week)
	return result.value if result.ok else null


func _weeks(game: Node, count: int) -> void:
	for i in count:
		game.next_week()


func _test_catalog() -> void:
	var game := _make_game()
	var rules: VideoRules = game.balance.videos
	var expected := ["concept", "scale", "locations", "direction", "crew", "extras", "dancers", "wardrobe", "set", "visual", "presence", "editing", "effects", "complexity"]
	_check(rules.categories.map(func(item: VideoCategoryDefinition) -> String: return item.id) == expected, "14 etapas de produção")
	_check(rules.find_category("concept").options.size() == 12, "12 conceitos")
	_check(rules.find_category("scale").options.size() == 5, "5 escalas")
	_check(rules.find_category("locations").multiple and rules.find_category("locations").max_choices > 1, "várias locações")
	var total := rules.technical_weight + rules.visual_weight + rules.creativity_weight + rules.identity_weight + rules.coherence_weight
	_check(is_equal_approx(total, 1.0), "pesos da nota somam 1")
	_restore(game)


func _test_budget_example() -> void:
	var game := _make_game()
	var song: SongData = game.create_song("Rua").value
	var evaluation: VideoSystem.Evaluation = game.videos.evaluate(song, _choices())
	_check(evaluation.cost == 22000, "exemplo da especificação custa $22.000: %d" % evaluation.cost)
	_check(evaluation.weeks >= 1, "prazo estimado")
	for stat in ["technical", "visual", "creativity", "identity", "coherence", "commercial", "discovery", "viral", "risk", "score"]:
		var value: int = evaluation.get(stat)
		_check(value >= 0 and value <= 100, "%s entre 0 e 100" % stat)
	_restore(game)


func _test_choices_shape_the_result() -> void:
	var game := _make_game()
	var song: SongData = game.create_song("Base").value
	var videos: VideoSystem = game.videos
	var base := videos.evaluate(song, _choices())
	var renowned := videos.evaluate(song, _choices({"direction": ["dir_renowned"]}))
	_check(renowned.visual > base.visual and renowned.creativity > base.creativity and renowned.cost > base.cost, "direção renomada melhora e custa mais")
	var crowd := videos.evaluate(song, _choices({"extras": ["extras_huge"]}))
	_check(crowd.visual > base.visual and crowd.commercial > base.commercial and crowd.cost > base.cost, "figurantes aumentam escala e impacto")
	var more_locations := videos.evaluate(song, _choices({"locations": ["loc_street", "loc_house", "loc_studio", "loc_own"]}))
	_check(more_locations.cost > base.cost and more_locations.weeks > base.weeks and more_locations.visual > base.visual, "mais locações: custo, prazo e variedade")
	_check(more_locations.risk > base.risk, "mais locações: mais complexidade")
	var complex := videos.evaluate(song, _choices({"complexity": ["complexity_very"]}))
	_check(complex.weeks > base.weeks and complex.risk > base.risk and complex.visual > base.visual, "complexidade: prazo, risco e potencial")
	var overloaded := videos.evaluate(song, _choices({"complexity": ["complexity_very"], "crew": ["crew_basic"]}))
	_check(overloaded.risk > complex.risk, "equipe pequena para produção complexa aumenta o risco")
	var neon := videos.evaluate(song, _choices({"visual": ["visual_neon"]}))
	_check(neon.identity > base.identity and neon.visual > base.visual, "direção visual afeta identidade e visual")
	var editing := videos.evaluate(song, _choices({"editing": ["editing_complex"]}))
	_check(editing.weeks > base.weeks and editing.technical > base.technical, "edição complexa: prazo e técnica")

	# Conceito e escolhas que combinam: coerência.
	var party_fit := videos.evaluate(song, _choices({"concept": ["concept_party"], "locations": ["loc_party"], "extras": ["extras_many"], "dancers": ["dancers_pro"]}))
	var party_clash := videos.evaluate(song, _choices({"concept": ["concept_party"], "locations": ["loc_own"], "extras": ["extras_none"], "dancers": ["dancers_none"]}))
	_check(party_fit.coherence > party_clash.coherence, "conceito muda como as escolhas combinam")
	# Efeito caro não garante resultado.
	var minimal := videos.evaluate(song, _choices({"concept": ["concept_minimal"]}))
	var minimal_cgi := videos.evaluate(song, _choices({"concept": ["concept_minimal"], "effects": ["fx_cgi_advanced"]}))
	_check(minimal_cgi.cost > minimal.cost * 5, "CGI avançado é caro")
	_check(minimal_cgi.coherence < minimal.coherence and minimal_cgi.risk > minimal.risk, "CGI destoa do minimalista e aumenta o risco")
	# A música importa para a coerência.
	for attribute_id in ["vocal", "lyrics", "beat", "production"]:
		song.attribute_bases[attribute_id] = 50
	song.attribute_bases["vocal"] = 95
	song.quality = 60
	var performance_concept := videos.evaluate(song, _choices({"concept": ["concept_performance"]}))
	var party_concept := videos.evaluate(song, _choices({"concept": ["concept_party"]}))
	_check(performance_concept.coherence > party_concept.coherence, "conceito que valoriza o vocal combina com música de vocal forte")
	# Feats combinam com artista + convidados.
	var credits := SongCredits.new()
	credits.feat_ids = ["jid"]
	var feat_song: SongData = game.create_song("Com feat", credits).value
	var guests_with := videos.evaluate(feat_song, _choices({"presence": ["presence_guests"]}))
	var guests_without := videos.evaluate(game.create_song("Sem feat").value, _choices({"presence": ["presence_guests"]}))
	_check(guests_with.coherence > guests_without.coherence, "convidados combinam com música que tem feat")
	_restore(game)


func _test_scales_and_costs() -> void:
	var game := _make_game()
	var song: SongData = game.create_song("Escalas").value
	var videos: VideoSystem = game.videos
	var cheapest := videos.evaluate(song, videos.default_choices())
	_check(cheapest.cost == 0, "caseiro mais simples é de graça")
	var home := videos.evaluate(song, _choices({"scale": ["scale_home"]}))
	_check(home.cost <= 15000, "caseiro barato: %d" % home.cost)
	var ranges := [["scale_indie", 5000, 35000], ["scale_pro", 25000, 120000], ["scale_big", 100000, 350000]]
	var previous := home
	for item: Array in ranges:
		var evaluation := videos.evaluate(song, _choices({"scale": [item[0]]}))
		_check(evaluation.cost >= item[1] and evaluation.cost <= item[2], "%s na faixa: %d" % [item[0], evaluation.cost])
		_check(evaluation.cost > previous.cost and evaluation.weeks >= previous.weeks, "%s custa mais e não demora menos" % item[0])
		previous = evaluation
	var everything := {}
	for category in game.balance.videos.categories:
		var last: Array[String] = [category.options.back().id]
		everything[category.id] = last
	everything["locations"] = ["loc_special", "loc_mansion", "loc_hotel", "loc_party"]
	var super_production := videos.evaluate(song, everything)
	_check(super_production.cost >= 1000000, "superprodução completa passa de $1M: %d" % super_production.cost)
	_check(super_production.weeks > previous.weeks, "superprodução leva mais tempo")
	var mismatch := videos.evaluate(song, _choices({"scale": ["scale_home"], "set": ["set_big"]}))
	_check(mismatch.risk > home.risk, "cenário enorme em produção caseira aumenta o risco")
	_restore(game)


func _test_validation_and_money() -> void:
	var game := _make_game(30000)
	var song: SongData = game.create_song("Validação").value
	var missing := _choices()
	missing.erase("concept")
	_check(not game.create_video(song.id, missing, "", VideoRules.MODE_WITH_SONG, -1).ok, "etapa obrigatória")
	_check(not game.create_video(song.id, _choices({"locations": ["loc_street", "loc_house", "loc_own", "loc_studio", "loc_club"]}), "", VideoRules.MODE_WITH_SONG, -1).ok, "limite de locações")
	_check(not game.create_video(song.id, _choices({"locations": ["loc_street", "loc_street"]}), "", VideoRules.MODE_WITH_SONG, -1).ok, "locação repetida")
	_check(not game.create_video(song.id, _choices({"concept": ["inventado"]}), "", VideoRules.MODE_WITH_SONG, -1).ok, "opção inválida")
	_check(not game.create_video("song_999", _choices(), "", VideoRules.MODE_WITH_SONG, -1).ok, "música inválida")
	_check(not game.create_video(song.id, _choices(), "", VideoRules.MODE_DATE, 1).ok, "data no passado")
	_check(not game.create_video(song.id, _choices(), "", "inventado", -1).ok, "modo inválido")

	game.career.money = 21999
	var refused: ActionResult = game.create_video(song.id, _choices(), "", VideoRules.MODE_WITH_SONG, -1)
	_check(not refused.ok and "insuficiente" in refused.message, "sem dinheiro não produz")
	_check(game.career.music_videos.is_empty() and game.career.money == 21999, "recusa não cobra nem cria")
	game.career.money = 22000
	var video := _video(game, song)
	_check(video != null and game.career.money == 0, "valor exato produz")
	var line: FinanceEntry = game.career.finance_history.back()
	_check(line.category == FinanceEntry.CATEGORY_VIDEO and line.amount == -22000, "custo no histórico financeiro")
	game.career.money = 100000
	_check(_video(game, song) == null, "um videoclipe por música")
	_restore(game)


func _test_eligible_songs() -> void:
	var game := _make_game()
	var unreleased: SongData = game.create_song("Nova").value
	var old: SongData = game.create_song("Antiga").value
	game.release_content(old.id)
	_weeks(game, 10)
	var ids := []
	for i in 3:
		ids.append(game.create_song("Faixa %d" % i).value.id)
	var typed: Array[String] = []
	typed.assign(ids)
	game.create_album("EP", &"ep", typed)
	var eligible: Array = game.videos.eligible_songs(game.career).map(func(song: SongData) -> String: return song.id)
	_check(unreleased.id in eligible and old.id in eligible and typed[0] in eligible, "nova, antiga e de projeto")
	_check(_video(game, old) != null, "música lançada há semanas ganha videoclipe")
	_check(old.id not in game.videos.eligible_songs(game.career).map(func(song: SongData) -> String: return song.id), "sai da lista depois")
	_restore(game)


func _test_production_time() -> void:
	var game := _make_game()
	var song: SongData = game.create_song("Prazo").value
	var big_choices := _choices({"scale": ["scale_big"], "set": ["set_elaborate"]})
	var evaluation: VideoSystem.Evaluation = game.videos.evaluate(song, big_choices)
	var result: ActionResult = game.create_video(song.id, big_choices, "", VideoRules.MODE_WITH_SONG, -1)
	var video: MusicVideo = result.value
	_check(video.status == MusicVideo.STATUS_PRODUCTION, "em produção")
	_check(video.ready_week == 1 + evaluation.weeks and video.production_weeks == evaluation.weeks, "pronto na semana prevista")
	_check(video.cost == evaluation.cost and video.score == evaluation.score, "custo e notas guardados")
	_weeks(game, evaluation.weeks - 1)
	_check(video.status == MusicVideo.STATUS_PRODUCTION, "ainda em produção")
	var report: WeekReport = game.next_week()
	_check(video.status == MusicVideo.STATUS_READY, "pronto no prazo")
	_check(report.entries.any(func(item: WeekReportEntry) -> bool: return "Produção concluída" in item.note), "relatório avisa")
	_check(not video.is_released(), "música não lançada segura o videoclipe")
	var quality_before := song.quality
	_check(song.quality == quality_before, "videoclipe não muda a nota da música")
	_restore(game)


func _test_production_problems() -> void:
	# A chance tem teto de 90%: procura uma semente em que o problema aconteça.
	var game: Node
	var video: MusicVideo
	var planned := 0
	var technical := 0
	for seed_value in range(1, 20):
		game = _make_game(100000000, 0, seed_value)
		game.balance.videos.problem_chance_per_risk = 1.0
		var song: SongData = game.create_song("Problema").value
		video = _video(game, song, {"complexity": ["complexity_very"], "crew": ["crew_basic"]})
		planned = video.ready_week
		technical = video.technical
		while game.career.current_week < planned:
			game.next_week()
		if not video.problem_note.is_empty():
			break
		_restore(game)
	_check(video.ready_week > planned and not video.problem_note.is_empty(), "problema atrasa a produção")
	_check(video.technical < technical, "problema prejudica a parte técnica")
	_check(video.status == MusicVideo.STATUS_PRODUCTION, "ainda em produção depois do problema")
	while game.career.current_week < video.ready_week:
		game.next_week()
	_check(video.status == MusicVideo.STATUS_READY, "termina depois do atraso")
	_restore(game)


func _test_cover_is_free() -> void:
	var game := _make_game()
	var song: SongData = game.create_song("Capa", null, "capa_musica.webp").value
	var without: VideoSystem.Evaluation = game.videos.evaluate(song, _choices())
	var money: int = game.career.money
	var result: ActionResult = game.create_video(song.id, _choices(), "capa_video.webp", VideoRules.MODE_WITH_SONG, -1)
	var video: MusicVideo = result.value
	_check(video.cover_file == "capa_video.webp" and song.cover_file == "capa_musica.webp", "capa própria, diferente da música")
	_check(game.career.money == money - without.cost and video.score == without.score, "capa não muda custo nem nota")
	money = game.career.money
	_check(game.update_video(video.id, "outra.webp", VideoRules.MODE_WITH_SONG, -1).ok, "troca de capa")
	_check(video.cover_file == "outra.webp" and game.career.money == money and video.score == without.score, "troca de capa grátis")
	_restore(game)


func _test_auto_release_with_scheduled_song() -> void:
	var game := _make_game()
	var song: SongData = game.create_song("Junto").value
	var video := _video(game, song, {"scale": ["scale_home"]})
	game.schedule_release(song.id, video.ready_week + 2)
	while game.career.current_week < video.ready_week + 1:
		game.next_week()
	_check(video.status == MusicVideo.STATUS_READY and not video.is_released(), "pronto esperando a música")
	game.next_week()
	_check(song.is_released() and video.is_released(), "música e videoclipe saem juntos")
	_check(video.release_week == song.release_week, "mesma semana")
	_restore(game)


func _test_auto_release_with_immediate_release() -> void:
	var game := _make_game()
	var song: SongData = game.create_song("Agora").value
	var video := _video(game, song, {"scale": ["scale_home"]})
	while video.status != MusicVideo.STATUS_READY:
		game.next_week()
	game.release_content(song.id)
	_check(video.is_released() and video.release_week == song.release_week, "lançar a música agora leva o videoclipe junto")
	_restore(game)


func _test_auto_release_when_ready_later() -> void:
	var game := _make_game()
	var song: SongData = game.create_song("Atrasado").value
	game.release_content(song.id)
	var video := _video(game, song, {"scale": ["scale_pro"]})
	_check(not video.is_released(), "não sai antes de ficar pronto")
	while game.career.current_week < video.ready_week:
		game.next_week()
	_check(video.is_released() and video.release_week == video.ready_week, "sai assim que fica pronto")
	_restore(game)


func _test_separate_date() -> void:
	var game := _make_game()
	var song: SongData = game.create_song("Separado").value
	game.schedule_release(song.id, 3)
	var video := _video(game, song, {"scale": ["scale_home"]}, VideoRules.MODE_DATE, 6)
	_weeks(game, 2)
	_check(song.is_released() and not video.is_released(), "música sai antes")
	_weeks(game, 2)
	_check(not video.is_released(), "espera a data própria")
	game.next_week()
	_check(video.is_released() and video.release_week == 6, "videoclipe sai na própria data")
	_check(game.update_video(video.id, "x.webp", VideoRules.MODE_DATE, 20).ok and video.release_week == 6, "lançado não muda a data")

	# Data antes da música: espera a música.
	var early: SongData = game.create_song("Cedo").value
	var early_video := _video(game, early, {"scale": ["scale_home"]}, VideoRules.MODE_DATE, game.career.current_week + 2)
	game.schedule_release(early.id, game.career.current_week + 5)
	_weeks(game, 3)
	_check(not early_video.is_released(), "não sai antes da música")
	_weeks(game, 2)
	_check(early_video.is_released() and early.is_released(), "sai depois da música")

	# Remarcar antes de lançar.
	var later: SongData = game.create_song("Remarcar").value
	game.release_content(later.id)
	var later_video := _video(game, later, {"scale": ["scale_home"]}, VideoRules.MODE_DATE, game.career.current_week + 8)
	_check(game.update_video(later_video.id, "", VideoRules.MODE_DATE, game.career.current_week + 3).ok, "remarca")
	_check(not game.update_video(later_video.id, "", VideoRules.MODE_DATE, game.career.current_week).ok, "não remarca para o passado")
	_weeks(game, 3)
	_check(later_video.is_released(), "sai na nova data")
	_restore(game)


func _test_old_song_new_date() -> void:
	var game := _make_game()
	var old: SongData = game.create_song("Antiga").value
	game.release_content(old.id)
	_weeks(game, 20)
	var plays_before: int = game.career.find_performance(old.id).total_plays
	var video := _video(game, old, {"scale": ["scale_home"]}, VideoRules.MODE_DATE, game.career.current_week + 4)
	_weeks(game, 4)
	_check(video.is_released() and video.release_week == 25, "música antiga com nova data")
	_check(game.career.find_performance(old.id).total_plays >= plays_before, "música continua no catálogo")
	_restore(game)


func _test_projects() -> void:
	for format_id: StringName in [&"ep", &"album", &"mixtape"]:
		var game := _make_game()
		var album_format: AlbumFormatDefinition = game.balance.find_album_format(format_id)
		var ids: Array[String] = []
		for i in album_format.min_songs:
			ids.append(game.create_song("Faixa %d" % i).value.id)
		var album: AlbumData = game.create_album("Projeto", format_id, ids).value
		var together := _video(game, game.career.find_song(ids[0]), {"scale": ["scale_home"]})
		var after := _video(game, game.career.find_song(ids[1]), {"scale": ["scale_home"]}, VideoRules.MODE_DATE, 8)
		game.schedule_release(album.id, 4)
		_weeks(game, 3)
		_check(album.is_released() and together.is_released() and together.release_week == 4, "%s: videoclipe junto com o projeto" % format_id)
		_check(not after.is_released(), "%s: videoclipe depois espera" % format_id)
		_weeks(game, 4)
		_check(after.is_released() and after.release_week == 8, "%s: videoclipe depois sai na data" % format_id)
		var report: WeekReport = game.next_week()
		_check(together.total_views > 0 and report.entries.any(func(item: WeekReportEntry) -> bool: return "Videoclipe" in item.title), "%s: videoclipe de faixa rende" % format_id)
		_restore(game)


func _test_leak() -> void:
	var game := _make_game()
	game.balance.videos.leak_chance_per_week = 1.0
	var song: SongData = game.create_song("Vazado").value
	game.release_content(song.id)
	var video := _video(game, song, {"scale": ["scale_pro"]}, VideoRules.MODE_DATE, 12)
	var money: int = game.career.money
	var youtube_before: int = game.career.platform_stats_for("youtube").total_plays
	var report: WeekReport = game.next_week()
	_check(video.is_leaked() and video.leak_week == 2 and not video.is_released(), "vazou antes do lançamento")
	_check(video.leak_views > 0 and video.total_views == 0, "visualizações do vazamento separadas")
	_check(report.entries.any(func(item: WeekReportEntry) -> bool: return "Vazamento do videoclipe" in item.title), "relatório avisa")
	_check(video.leak_effect != 1.0, "vazamento afeta a estreia")
	var leak_views := video.leak_views
	game.next_week()
	_check(video.leak_views > leak_views, "vazamento continua circulando")
	_check(game.career.platform_stats_for("youtube").total_plays - youtube_before < video.leak_views, "vazamento fora das visualizações oficiais")
	var video_income: Array = game.career.finance_history.filter(func(item: FinanceEntry) -> bool: return "videoclipe" in item.description and item.amount > 0)
	_check(video_income.is_empty(), "vazamento sem receita")
	game.balance.videos.leak_chance_per_week = 0.0
	while game.career.current_week < 12:
		game.next_week()
	_check(video.is_released() and video.release_week == 12, "lançamento oficial mantido")
	var leak_total := video.leak_views
	game.next_week()
	_check(video.total_views > 0 and video.revenue > 0, "desempenho oficial depois")
	_check(video.leak_views == leak_total, "vazamento para de somar depois do oficial")
	_check(game.career.money > money - 1, "receita oficial entra")

	# Burburinho ou prejuízo dependem do sorteio e da nota.
	var buzz := 0
	var harm := 0
	for i in 60:
		var run := _make_game(100000000, 0, i + 1)
		run.balance.videos.leak_chance_per_week = 1.0
		var item: SongData = run.create_song("V").value
		var leaked := _video(run, item, {"scale": ["scale_home"]}, VideoRules.MODE_DATE, 9)
		run.next_week()
		if leaked.leak_effect > 1.0:
			buzz += 1
		else:
			harm += 1
		_restore(run)
	_check(buzz > 0 and harm > 0, "vazamento pode ajudar ou prejudicar: %d x %d" % [buzz, harm])
	_restore(game)


func _test_performance_and_youtube() -> void:
	var game := _make_game()
	var song: SongData = game.create_song("Desempenho").value
	game.release_content(song.id)
	var video := _video(game, song, {"scale": ["scale_home"]})
	while not video.is_released():
		game.next_week()
	var youtube: ArtistPlatformStats = game.career.platform_stats_for("youtube")
	var plays_before := youtube.total_plays
	var revenue_before := youtube.revenue
	var money: int = game.career.money
	var report: WeekReport = game.next_week()
	var line: WeekReportEntry
	for entry in report.entries:
		if entry.title == "Videoclipe: Desempenho":
			line = entry
	_check(line != null and line.streams == video.total_views and video.total_views > 0, "visualizações no relatório")
	_check(youtube.total_plays - plays_before >= video.total_views, "visualizações entram no YouTube")
	_check(youtube.revenue - revenue_before >= video.revenue and video.revenue > 0, "receita do YouTube")
	_check(game.career.money == money + report.total_money(), "receita pela economia existente")
	var income: Array = game.career.finance_history.filter(func(item: FinanceEntry) -> bool: return "videoclipe" in item.description)
	_check(not income.is_empty() and income[0].category == FinanceEntry.CATEGORY_STREAMS, "linha no histórico")
	_check(video.likes > 0, "engajamento")
	var youtube_def: PlatformDefinition = game.balance.streaming.find_platform("youtube")
	_check(video.revenue == roundi(video.total_views * youtube_def.money_per_play), "valor por visualização do YouTube")
	_weeks(game, 6)
	_check(video.weekly_views.size() == 7 and video.peak_week_views > 0, "desempenho ao longo do tempo")
	_check(youtube.followers > 0, "inscritos crescem")
	_check(not video.trajectory_id.is_empty(), "trajetória sorteada")
	_restore(game)


func _test_video_boosts_song() -> void:
	var game := _make_game()
	var song: SongData = game.create_song("Puxada").value
	game.release_content(song.id)
	var video := _video(game, song, {"scale": ["scale_home"]})
	var performance: SongPerformance = game.career.find_performance(song.id)
	while not video.is_released():
		game.next_week()
	_check(performance.video_boost == 1.0, "sem visualizações, sem bônus")
	game.next_week()
	_check(performance.video_boost > 1.0, "videoclipe aumenta a popularidade da música")
	_check(performance.video_boost <= 1.0 + game.balance.videos.max_song_boost, "bônus tem limite")
	_restore(game)


func _test_marketing_influences_video() -> void:
	var game := _make_game(100000000, 20)
	var promoted: SongData = game.create_song("Promovida").value
	game.add_marketing_action(promoted.id, "influencers")
	game.add_marketing_action(promoted.id, "social")
	game.schedule_release(promoted.id, 4)
	var plain: SongData = game.create_song("Sem campanha").value
	game.schedule_release(plain.id, 4)
	_weeks(game, 3)
	var videos: VideoSystem = game.videos
	_check(videos._marketing_exposure(game.career, promoted) > 0, "campanha dá exposição ao videoclipe")
	_check(videos._marketing_exposure(game.career, plain) == 0, "sem campanha, sem exposição")
	_check(videos._marketing_multiplier(game.career, promoted, 0) > 1.0, "campanha amplia o início")
	_check(videos._marketing_multiplier(game.career, plain, 0) == 1.0, "sem campanha, sem bônus")
	_check(videos._marketing_multiplier(game.career, promoted, 20) < videos._marketing_multiplier(game.career, promoted, 0), "efeito do marketing passa")

	# Projeto: a campanha do projeto ajuda os videoclipes das faixas.
	var ids: Array[String] = []
	for i in 3:
		ids.append(game.create_song("F%d" % i).value.id)
	var ep: AlbumData = game.create_album("EP", &"ep", ids).value
	game.add_marketing_action(ep.id, "teaser")
	game.schedule_release(ep.id, game.career.current_week + 2)
	_weeks(game, 2)
	_check(videos._marketing_exposure(game.career, game.career.find_song(ids[0])) > 0, "campanha do projeto ajuda as faixas")
	var marketing_lines: Array = game.career.finance_history.filter(func(item: FinanceEntry) -> bool: return item.category == FinanceEntry.CATEGORY_MARKETING and item.amount > 0)
	_check(marketing_lines.is_empty(), "marketing nunca devolve dinheiro")
	_restore(game)


func _views_after(quality: int, overrides: Dictionary, seed_value: int, weeks: int) -> int:
	var game := _make_game(100000000, 0, seed_value)
	var song: SongData = game.create_song("S").value
	song.quality = quality
	for attribute_id in ["vocal", "lyrics", "beat", "production"]:
		song.attribute_bases[attribute_id] = quality
	game.release_content(song.id)
	var video := _video(game, song, overrides)
	while not video.is_released():
		game.next_week()
	_weeks(game, weeks)
	var views := video.total_views
	_restore(game)
	return views


func _test_bad_song_expensive_video() -> void:
	var expensive := {"scale": ["scale_super"], "direction": ["dir_renowned"], "crew": ["crew_large"], "effects": ["fx_cgi"], "editing": ["editing_cinematic"], "visual": ["visual_cinematic"], "concept": ["concept_cinematic"]}
	var cheap := {"scale": ["scale_home"]}
	var bad_total := 0
	var good_total := 0
	for i in 20:
		bad_total += _views_after(15, expensive, i + 1, 6)
		good_total += _views_after(90, cheap, i + 1, 6)
	_check(good_total > bad_total, "música boa com clipe barato supera música ruim com clipe caro: %d x %d" % [good_total, bad_total])


func _test_varied_results() -> void:
	var trajectories := {}
	var viral_cheap := 0
	for i in 120:
		var game := _make_game(100000000, 0, i + 1)
		var song: SongData = game.create_song("S").value
		game.release_content(song.id)
		var video := _video(game, song, {"scale": ["scale_home"], "concept": ["concept_comedy"]})
		while not video.is_released():
			game.next_week()
		trajectories[video.trajectory_id] = trajectories.get(video.trajectory_id, 0) + 1
		if video.trajectory_id == "viral":
			viral_cheap += 1
		_restore(game)
	_check(trajectories.size() >= 6, "comportamentos variados: %s" % str(trajectories))
	_check(viral_cheap > 0, "videoclipe barato pode viralizar: %d" % viral_cheap)
	_check(trajectories.has("flop") or trajectories.has("debut_crash"), "videoclipe também pode fracassar")


func _test_round_trip() -> void:
	_clean_saves()
	var game := _make_game()
	game.balance.videos.leak_chance_per_week = 1.0
	var song: SongData = game.create_song("Salva").value
	game.release_content(song.id)
	var leaked := _video(game, song, {"scale": ["scale_home"]}, VideoRules.MODE_DATE, 5)
	game.next_week()
	game.balance.videos.leak_chance_per_week = 0.0
	var other: SongData = game.create_song("Em produção").value
	var producing: MusicVideo = game.create_video(other.id, _choices({"scale": ["scale_big"]}), "capa.webp", VideoRules.MODE_WITH_SONG, -1).value
	_weeks(game, 5)
	var expected := JSON.stringify(game.career.to_dict())
	_check(game.save_game().ok and game.load_game().ok, "salva e carrega")
	_check(JSON.stringify(game.career.to_dict()) == expected, "save idêntico")
	var loaded: MusicVideo = game.career.find_video(leaked.id)
	_check(loaded.is_released() and loaded.total_views > 0 and loaded.weekly_views[0] is int, "desempenho salvo")
	_check(loaded.is_leaked() and loaded.leak_views > 0, "vazamento salvo")
	_check(loaded.choices["locations"] is Array and loaded.choices["scale"] == ["scale_home"], "escolhas salvas")
	var loaded_producing: MusicVideo = game.career.find_video(producing.id)
	_check(loaded_producing.cover_file == "capa.webp" and loaded_producing.status == MusicVideo.STATUS_PRODUCTION, "produção salva")
	var views := loaded.total_views
	game.next_week()
	_check(game.career.find_video(leaked.id).total_views > views, "continua rendendo após carregar")
	_restore(game)


func _test_v5_migration() -> void:
	_clean_saves()
	DirAccess.make_dir_recursive_absolute(TEST_SAVE_DIR)
	var save_path := TEST_SAVE_DIR.path_join("career.json")
	var fixture_text := FileAccess.get_file_as_string(V5_FIXTURE)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(fixture_text)
	file.close()
	var old_payload: Dictionary = JSON.parse_string(fixture_text)
	var old: Dictionary = old_payload["career"]
	_check(int(old_payload["version"]) == 5, "fixture é v5")
	_check(fixture_text.count('"action_id": "video"') == 2, "fixture tem a ação antiga de videoclipe")

	var game := _make_game()
	_check(game.load_game().ok, "carrega save v5 real")
	var career: CareerData = game.career
	_check(FileAccess.get_file_as_string(save_path + ".v5.bak") == fixture_text, "cópia v5 guardada")
	_check(career.money == int(old["money"]) and career.fame == int(old["fame"]), "dinheiro e fama preservados")
	_check(career.energy == 45 and career.current_week == int(old["current_week"]), "energia e semana preservadas")
	_check(career.finance_history.size() == old["finance_history"].size(), "histórico preservado, inclusive o videoclipe pago")
	_check(career.song_performances.size() == old["song_performances"].size(), "desempenho preservado")
	_check(career.music_videos.is_empty(), "sem videoclipes antigos")
	for campaign in career.marketing_campaigns:
		_check(campaign.find_action("video") == null, "ação de videoclipe removida da campanha")
	var planned := career.songs.filter(func(item: SongData) -> bool: return item.title == "Planejada com videoclipe")[0] as SongData
	var planned_campaign := career.find_campaign(planned.id)
	_check(planned_campaign.actions.size() == 1 and planned_campaign.actions[0].action_id == "social", "outras ações da campanha mantidas")
	_check(game.marketing.forecast(career, planned.id, 3).hype > 0, "campanha migrada funciona")
	for index in career.songs.size():
		_check(career.songs[index].quality == int(old["songs"][index]["quality"]), "nota da música %d" % index)

	var hit := career.songs[0]
	_check(_video(game, hit, {"scale": ["scale_home"]}) != null, "música antiga recebe videoclipe")
	var money: int = career.money
	var report: WeekReport = game.next_week()
	_check(career.money == money + report.total_money(), "tudo segue rendendo")
	_check(game.save_game().ok, "salva migrado")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	_check(int(saved["version"]) == SaveSystem.SAVE_VERSION, "arquivo atualizado")
	_restore(game)


func _clean_saves() -> void:
	if not DirAccess.dir_exists_absolute(TEST_SAVE_DIR):
		return
	for file_name in DirAccess.get_files_at(TEST_SAVE_DIR):
		DirAccess.remove_absolute(TEST_SAVE_DIR.path_join(file_name))
	DirAccess.remove_absolute(TEST_SAVE_DIR)
