extends SceneTree
## Testes de plataformas, desempenho, vazamentos e samples, sem interface. Para rodar:
##   godot --headless --path . --script res://tests/test_streaming.gd

const GameManagerScript := preload("res://scripts/core/game_manager.gd")
const TEST_SAVE_DIR := "user://test_saves_streaming"
const V4_FIXTURE := "res://tests/fixtures/save_v4.json"
const STREAMING_IDS: Array[String] = ["spotify", "apple_music", "deezer", "soundcloud", "youtube"]

var _failures := 0
var _checks := 0


func _init() -> void:
	_clean_saves()
	_test_catalog()
	_test_single_on_platforms()
	_test_projects_on_platforms()
	_test_existing_single_keeps_own_release()
	_test_platform_differences()
	_test_radio_access()
	_test_store()
	_test_artist_growth()
	_test_trajectory_shapes()
	_test_trajectories_follow_factors()
	_test_performance_not_only_random()
	_test_trend_labels()
	_test_no_runaway_growth()
	_test_discovery()
	_test_marketing_all_formats()
	_test_marketing_has_no_guaranteed_return()
	_test_marketing_cancel_keeps_money_spent()
	_test_leak()
	_test_leak_then_official_release()
	_test_leak_of_project()
	_test_leak_chance_is_configurable()
	_test_samples()
	_test_own_sample()
	_test_sample_interest()
	_test_profile()
	_test_history()
	_test_round_trip()
	_test_v4_migration()
	_clean_saves()
	print("%d verificações, %d falhas" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FALHOU: ", label)


func _make_game(money: int = 10000000, fame: int = 0, seed_value: int = 31) -> Node:
	var game: Node = GameManagerScript.new()
	game.rng.seed = seed_value
	game.saves.save_dir = TEST_SAVE_DIR
	game.new_career("MC Teste")
	game.career.money = money
	game.career.fame = fame
	return game


func _add_songs(game: Node, count: int) -> Array[String]:
	var ids: Array[String] = []
	for i in count:
		ids.append(game.create_song("Faixa %d" % i).value.id)
	return ids


func _released_single(game: Node, title: String = "Single") -> SongData:
	var song: SongData = game.create_song(title).value
	game.release_content(song.id)
	return song


func _weeks(game: Node, count: int) -> void:
	for i in count:
		game.next_week()


func _test_catalog() -> void:
	var game := _make_game()
	var rules: StreamingRules = game.balance.streaming
	var names: Array = rules.platforms.map(func(item: PlatformDefinition) -> String: return item.display_name)
	_check(names == ["Spotify", "Apple Music", "Deezer", "SoundCloud", "YouTube", "Loja digital", "Rádio"], "sete plataformas")
	var share := 0.0
	for platform_id in STREAMING_IDS:
		share += rules.find_platform(platform_id).audience_share
	_check(is_equal_approx(share, 1.0), "partes do streaming somam 1")
	_check(rules.find_platform("spotify").listeners_label == "Ouvintes mensais", "Spotify mostra ouvintes mensais")
	_check(rules.find_platform("youtube").followers_label == "Inscritos", "YouTube mostra inscritos")
	_check(rules.find_platform("youtube").plays_label == "Visualizações", "YouTube mostra visualizações")
	_check(rules.find_platform("soundcloud").extra_label == "Curtidas", "SoundCloud mostra curtidas")
	_check(rules.find_platform("soundcloud").listeners_label.is_empty(), "SoundCloud não mostra ouvintes")
	for trajectory_id in ["instant_hit", "slow_growth", "steady", "viral", "delayed", "platform_focus", "underground", "debut_crash", "flop", "catalog_late"]:
		_check(rules.find_trajectory(trajectory_id) != null, "trajetória %s" % trajectory_id)
	game.free()


func _test_single_on_platforms() -> void:
	var game := _make_game()
	var song: SongData = game.create_song("Single").value
	_check(game.career.find_performance(song.id) == null, "inédita não está nas plataformas")
	game.next_week()
	_check(game.career.find_performance(song.id) == null, "semana sem lançar não muda")
	game.release_content(song.id)
	var performance: SongPerformance = game.career.find_performance(song.id)
	_check(performance != null and performance.release_id == song.id, "single entra nas plataformas")
	_check(performance.total_plays == 0, "só rende na semana seguinte")

	var money: int = game.career.money
	var report: WeekReport = game.next_week()
	var entry: WeekReportEntry = report.entries[0]
	_check(entry.streams > 0 and performance.total_plays == entry.streams, "reproduções no relatório")
	for platform_id in STREAMING_IDS:
		_check(performance.platform_plays.get(platform_id, 0) > 0, "toca em %s" % platform_id)
	_check(game.career.money == money + report.total_money(), "dinheiro entra pela economia")
	var lines: Array = game.career.finance_history.filter(func(item: FinanceEntry) -> bool: return item.category == FinanceEntry.CATEGORY_STREAMS)
	_check(lines.size() == 1 and "Streams" in lines[0].description, "linha de streams no histórico")
	_check(performance.revenue > 0, "música registra receita")
	_check(game.career.find_release(song.id).total_streams == entry.streams, "lançamento acumula")
	game.free()


func _test_projects_on_platforms() -> void:
	for format_id: StringName in [&"ep", &"album", &"mixtape"]:
		var game := _make_game()
		var album_format: AlbumFormatDefinition = game.balance.find_album_format(format_id)
		var ids := _add_songs(game, album_format.min_songs)
		var album: AlbumData = game.create_album("Projeto", format_id, ids).value
		for song_id in ids:
			_check(game.career.find_performance(song_id) == null, "%s: faixa inédita fora das plataformas" % format_id)
		_check(game.release_content(album.id).ok, "%s lança" % format_id)
		for song_id in ids:
			var performance: SongPerformance = game.career.find_performance(song_id)
			_check(performance != null and performance.release_id == album.id, "%s: faixa entra nas plataformas" % format_id)
		var report: WeekReport = game.next_week()
		_check(report.entries.size() >= 1 and report.entries[0].streams > 0, "%s gera streams" % format_id)
		_check(report.entries[0].sales > 0, "%s gera vendas" % format_id)
		_check(game.career.find_performance(ids[0]).total_plays > 0, "%s: faixa tem reproduções próprias" % format_id)
		_check(game.career.find_release(album.id).total_streams == report.entries[0].streams, "%s acumula" % format_id)
		_check(game.career.platform_stats_for("digital_store").total_plays > 0, "%s aparece na Loja" % format_id)
		game.free()


func _test_existing_single_keeps_own_release() -> void:
	var game := _make_game()
	var ids := _add_songs(game, 3)
	game.release_content(ids[0])
	var album: AlbumData = game.create_album("Projeto", &"ep", ids).value
	game.release_content(album.id)
	_check(game.career.song_performances.size() == 3, "nenhuma faixa duplicada")
	_check(game.career.find_performance(ids[0]).release_id == ids[0], "single continua no próprio lançamento")
	_check(game.career.find_performance(ids[1]).release_id == album.id, "inédita pertence ao projeto")
	game.free()


func _test_platform_differences() -> void:
	# A plataforma preferida pelo atributo em alta recebe uma parte maior.
	var game := _make_game()
	var rules: StreamingRules = game.balance.streaming
	var plain: SongData = game.create_song("Plana").value
	for attribute_id in ["vocal", "lyrics", "beat", "production"]:
		plain.attribute_bases[attribute_id] = 50
	plain.quality = 50
	var strong_beat: SongData = game.create_song("Beat forte").value
	for attribute_id in ["vocal", "lyrics", "production"]:
		strong_beat.attribute_bases[attribute_id] = 50
	strong_beat.attribute_bases["beat"] = 100
	strong_beat.quality = 65
	_check(game.streaming._affinity(rules.find_platform("soundcloud"), strong_beat) > game.streaming._affinity(rules.find_platform("soundcloud"), plain), "SoundCloud valoriza beat")
	var performance := SongPerformance.new()
	performance.trajectory_id = "steady"
	var shares: Dictionary = game.streaming._platform_shares(plain, performance)
	_check(is_equal_approx(shares["spotify"], 0.45), "parte padrão do Spotify")
	var total := 0.0
	for platform_id: String in shares:
		total += shares[platform_id]
	_check(is_equal_approx(total, 1.0), "partes somam 1")
	performance.spotlight_platform = "soundcloud"
	performance.trajectory_id = "underground"
	var focused: Dictionary = game.streaming._platform_shares(plain, performance)
	_check(focused["soundcloud"] > shares["soundcloud"] * 1.5, "sucesso concentrado em uma plataforma")

	var song := _released_single(game)
	_weeks(game, 2)
	var soundcloud: PlatformDefinition = rules.find_platform("soundcloud")
	var spotify: PlatformDefinition = rules.find_platform("spotify")
	var youtube: PlatformDefinition = rules.find_platform("youtube")
	_check(spotify.money_per_play > soundcloud.money_per_play and spotify.money_per_play > youtube.money_per_play, "plataformas pagam diferente")
	_check(game.career.platform_stats_for("spotify").listeners > 0, "Spotify tem ouvintes")
	_check(game.career.platform_stats_for("soundcloud").listeners == 0, "SoundCloud não calcula ouvintes")
	_check(game.career.platform_stats_for("youtube").followers > 0, "YouTube ganha inscritos")
	_check(song.is_released(), "música lançada")
	game.free()


func _test_radio_access() -> void:
	var game := _make_game()
	var song := _released_single(game)
	_weeks(game, 2)
	_check(game.career.find_performance(song.id).platform_plays.get("radio", 0) == 0, "iniciante não toca na rádio")

	var famous := _make_game(10000000, 50)
	var famous_song := _released_single(famous)
	_weeks(famous, 1)
	_check(famous.career.find_performance(famous_song.id).platform_plays.get("radio", 0) > 0, "fama abre a rádio")
	famous.free()

	var campaign_game := _make_game(10000000, 20)
	var promoted: SongData = campaign_game.create_song("Promovida").value
	campaign_game.add_marketing_action(promoted.id, "radio")
	campaign_game.schedule_release(promoted.id, 3)
	_weeks(campaign_game, 3)
	_check(campaign_game.career.find_performance(promoted.id).platform_plays.get("radio", 0) > 0, "ação de Rádio abre a rádio")
	_check(campaign_game.career.platform_stats_for("radio").revenue > 0, "rádio gera receita")
	campaign_game.free()
	game.free()


func _test_store() -> void:
	var game := _make_game()
	var song: SongData = game.create_song("Boa").value
	song.quality = 90
	game.release_content(song.id)
	var report: WeekReport = game.next_week()
	_check(report.entries[0].sales > 0, "single vende na Loja")
	var store: ArtistPlatformStats = game.career.platform_stats_for("digital_store")
	_check(store.total_plays == report.entries[0].sales and store.revenue > 0, "Loja registra vendas")
	var sales_lines: Array = game.career.finance_history.filter(func(item: FinanceEntry) -> bool: return item.category == FinanceEntry.CATEGORY_SALES)
	_check(sales_lines.size() == 1, "venda no histórico financeiro")
	game.free()


func _test_artist_growth() -> void:
	var game := _make_game()
	var streaming: StreamingSystem = game.streaming
	var song := _released_single(game)
	_check(streaming.total_listeners(game.career) == 0 and streaming.total_followers(game.career) == 0, "sem reproduções, sem público")
	var fame_before: int = game.career.fame
	var report: WeekReport = game.next_week()
	_check(streaming.total_listeners(game.career) > 0, "streams viram ouvintes")
	_check(streaming.total_followers(game.career) > 0, "ouvintes viram seguidores")
	_check(game.career.fame == fame_before + report.total_fame(), "fama usa o sistema existente")
	var followers_before: int = streaming.total_followers(game.career)
	_weeks(game, 5)
	_check(streaming.total_followers(game.career) > followers_before, "seguidores crescem")
	_check(game.career.fame > fame_before, "fama cresce")
	_check(song.is_released(), "música segue lançada")

	var per_fame: int = game.balance.streaming.followers_per_fame
	var growth := _make_game()
	growth.career.platform_stats_for("spotify").followers = per_fame - 1
	growth.streaming.add_followers(growth.career, 0)
	var stats: ArtistPlatformStats = growth.career.platform_stats_for("spotify")
	stats.week_plays = 1000
	var growth_report := WeekReport.new()
	growth.streaming.finish_week(growth.career, growth_report)
	_check(growth.career.fame == 1 and growth_report.entries.size() == 1, "seguidores viram popularidade")
	_check(growth_report.total_fame() == 1, "ganho aparece no relatório")
	growth.free()
	game.free()


func _test_trajectory_shapes() -> void:
	var game := _make_game()
	var rules: StreamingRules = game.balance.streaming
	var curve := func(id: String, age: int, surge: int = -1) -> float:
		return rules.find_trajectory(id).multiplier(age, surge)
	_check(curve.call("instant_hit", 0) > 1.5, "hit imediato estreia alto")
	_check(curve.call("slow_growth", 6) > curve.call("slow_growth", 0) * 2.0, "crescimento lento sobe devagar")
	_check(curve.call("slow_growth", 1) < curve.call("slow_growth", 3), "crescimento lento é gradual")
	_check(curve.call("steady", 8) > curve.call("steady", 0), "crescimento constante sobe")
	_check(curve.call("viral", 3, 4) < curve.call("viral", 4, 4) / 2.0, "explosão viral é repentina")
	_check(curve.call("delayed", 6, 6) > curve.call("delayed", 5, 6) * 2.0, "cresce semanas depois")
	_check(curve.call("debut_crash", 0) > 2.5 and curve.call("debut_crash", 4) < 0.5, "grande estreia seguida de queda")
	_check(curve.call("flop", 0) < 0.3, "fracasso estreia baixo")
	_check(curve.call("catalog_late", 15, 15) > curve.call("catalog_late", 14, 15) * 1.5, "sucesso tardio de catálogo")
	_check(curve.call("legacy", 0) == 1.0 and curve.call("legacy", 500) == 0.1, "curva antiga preservada")
	game.free()


func _trajectory_counts(quality: int, fame: int, hype_actions: bool, runs: int) -> Dictionary:
	var counts := {}
	for i in runs:
		var game := _make_game(10000000, fame, i + 1)
		var song: SongData = game.create_song("Música").value
		song.quality = quality
		if hype_actions:
			game.career.fame = 200
			for action in game.balance.marketing.actions:
				game.add_marketing_action(song.id, action.id)
			game.career.fame = fame
			game.schedule_release(song.id, 3)
			_weeks(game, 2)
		else:
			game.release_content(song.id)
		var performance: SongPerformance = game.career.find_performance(song.id)
		counts[performance.trajectory_id] = counts.get(performance.trajectory_id, 0) + 1
		game.free()
	return counts


func _test_trajectories_follow_factors() -> void:
	var good := _trajectory_counts(90, 0, false, 200)
	var bad := _trajectory_counts(15, 0, false, 200)
	_check(bad.get("flop", 0) > good.get("flop", 0) * 2, "música fraca fracassa mais: %s x %s" % [bad.get("flop", 0), good.get("flop", 0)])
	_check(good.get("instant_hit", 0) > bad.get("instant_hit", 0), "música boa vira hit mais vezes")
	_check(good.keys().size() >= 6, "resultados variados: %d" % good.keys().size())
	var unknown := _trajectory_counts(70, 0, false, 200)
	var famous := _trajectory_counts(70, 200, false, 200)
	_check(unknown.get("underground", 0) > famous.get("underground", 0), "underground é coisa de quem não é famoso")
	var hyped := _trajectory_counts(70, 0, true, 100)
	var plain := _trajectory_counts(70, 0, false, 100)
	_check(hyped.get("instant_hit", 0) + hyped.get("debut_crash", 0) > plain.get("instant_hit", 0) + plain.get("debut_crash", 0), "expectativa favorece grandes estreias")


func _test_performance_not_only_random() -> void:
	# Mesmo público-base e mesma semana: qualidade e fama definem o resultado.
	var game := _make_game()
	var rules: PerformanceRules = game.balance.song_performance
	var base: int = game.performance.stream_units(rules, 5000, 50, 0, 1.0, 0.0)
	_check(base == 5000, "fatores neutros")
	_check(game.performance.stream_units(rules, 5000, 100, 0, 1.0, 0.0) == 10000, "qualidade pesa")
	_check(game.performance.stream_units(rules, 5000, 50, 100, 1.0, 0.0) > base, "popularidade pesa")
	_check(game.performance.stream_units(rules, 5000, 50, 0, 2.0, 0.0) == 10000, "multiplicadores pesam")
	var noisy: int = game.performance.stream_units(rules, 5000, 50, 0, 1.0, 0.1)
	_check(noisy >= 4500 and noisy <= 5500, "variação semanal controlada")

	# A evolução semanal não pula de forma aleatória.
	var song := _released_single(game)
	var performance: SongPerformance = game.career.find_performance(song.id)
	performance.trajectory_id = "steady"
	performance.launch_factor = 1.0
	_weeks(game, 6)
	for index in range(1, performance.weekly_plays.size()):
		var ratio := float(performance.weekly_plays[index]) / performance.weekly_plays[index - 1]
		_check(ratio > 0.6 and ratio < 1.7, "semana %d sem salto aleatório: %s" % [index, ratio])

	# Economia: um single comum rende na ordem de grandeza de antes.
	var revenue_game := _make_game(10000000, 0, 77)
	var average := _released_single(revenue_game, "Média")
	var average_perf: SongPerformance = revenue_game.career.find_performance(average.id)
	average_perf.trajectory_id = "legacy"
	average_perf.base_units = 5500
	average_perf.launch_factor = 1.0
	average.quality = 50
	var report: WeekReport = revenue_game.next_week()
	_check(report.total_money() > 25 and report.total_money() < 150, "receita compatível com a economia: %d" % report.total_money())
	revenue_game.free()
	game.free()


func _test_trend_labels() -> void:
	var game := _make_game()
	var streaming: StreamingSystem = game.streaming
	var performance := SongPerformance.new()
	_check(streaming.trend_label(performance) == "Estreia", "sem histórico")
	performance.weekly_plays.assign([1000, 1500, 2000, 3000])
	_check(streaming.trend_label(performance) == "Crescendo", "crescendo")
	performance.weekly_plays.assign([3000, 2000, 1500, 1000])
	_check(streaming.trend_label(performance) == "Caindo", "caindo")
	performance.weekly_plays.assign([1000, 1000, 1000, 1000])
	_check(streaming.trend_label(performance) == "Estável", "estável")
	game.free()


## Fama aumenta reproduções, e reproduções aumentam a fama: os dois não podem se multiplicar sem limite.
func _test_no_runaway_growth() -> void:
	var game := _make_game(0, 0, 11)
	var rules: PerformanceRules = game.balance.song_performance
	_check(game.performance.fame_factor(rules, 0) == 1.0, "sem fama, sem bônus")
	_check(game.performance.fame_factor(rules, 100000000) == rules.max_fame_factor, "bônus de fama tem teto")
	var low: PerformanceSystem.Result = game.performance.calculate_week(rules, 50, 0, 0)
	_check(low.fame * 1500 <= low.units + 1500, "fama vem das unidades")
	var songs := 0
	var fame_at_year_one := 0
	for week in 156:
		if game.career.money >= 300 and week % 3 == 0:
			var song: SongData = game.create_song("S%d" % songs).value
			songs += 1
			game.release_content(song.id)
		if game.career.money < 500:
			game.work_job(&"heavy_labor")
		else:
			game.next_week()
		if week == 51:
			fame_at_year_one = game.career.fame
	_check(game.career.money < 50000000, "dinheiro não explode em 3 anos: %d" % game.career.money)
	_check(game.career.fame < 100000, "fama não explode em 3 anos: %d" % game.career.fame)
	_check(game.career.fame > fame_at_year_one, "carreira segue crescendo")
	_check(game.career.fame < fame_at_year_one * 30, "crescimento sem disparar: %d para %d" % [fame_at_year_one, game.career.fame])
	game.free()


func _test_discovery() -> void:
	var game := _make_game()
	var streaming: StreamingSystem = game.streaming
	var performance := SongPerformance.new()
	var base: float = streaming._discovery_score(game.career, performance, 0, 0)
	_check(base == 0.0, "sem nada, sem descoberta")
	_check(streaming._discovery_score(game.career, performance, 100, 0) > base, "marketing ajuda a descoberta")
	_check(streaming._discovery_score(game.career, performance, 0, 1000000) > base, "músicas anteriores ajudam a descoberta")
	game.career.fame = 200
	_check(streaming._discovery_score(game.career, performance, 0, 0) > base, "popularidade ajuda a descoberta")
	game.career.fame = 0
	performance.weekly_plays.assign([1000, 2000])
	_check(streaming._discovery_score(game.career, performance, 0, 0) > base, "desempenho ajuda a descoberta")
	performance.weekly_plays.clear()
	game.career.platform_stats_for("spotify").listeners = 100000
	_check(streaming._discovery_score(game.career, performance, 0, 0) > base, "ouvintes ajudam a descoberta")
	_check(streaming._discovery_score(game.career, performance, 100, 10000000) <= 1.0, "descoberta tem limite")

	var recommended := 0
	for i in 40:
		var run := _make_game(10000000, 200, i + 1)
		var song := _released_single(run)
		_weeks(run, 10)
		recommended += run.career.find_performance(song.id).recommendations
		run.free()
	_check(recommended > 0, "recomendações acontecem: %d" % recommended)
	game.free()


func _test_marketing_all_formats() -> void:
	var cases := [["single", &"", 0], ["ep", &"ep", 3], ["album", &"album", 7], ["mixtape", &"mixtape", 3]]
	for item: Array in cases:
		var game := _make_game()
		var content: ReleasableContent
		if item[0] == "single":
			content = game.create_song("Single").value
		else:
			content = game.create_album("Projeto", item[1], _add_songs(game, item[2])).value
		var money: int = game.career.money
		_check(game.add_marketing_action(content.id, "teaser").ok, "%s aceita marketing" % item[0])
		_check(game.add_marketing_action(content.id, "social").ok, "%s combina ações" % item[0])
		_check(game.marketing.forecast(game.career, content.id, 3).hype > 0, "%s tem previsão" % item[0])
		_check(game.schedule_release(content.id, 4).ok, "%s agenda" % item[0])
		var campaign: MarketingCampaign = game.career.find_campaign(content.id)
		var release_cost: int = game.releases.release_cost(content)
		_check(game.career.money == money - release_cost - 1300, "%s paga campanha" % item[0])
		_check(campaign.is_active() and campaign.content_id == content.id, "%s em campanha" % item[0])
		_weeks(game, 3)
		_check(content.is_released() and campaign.is_completed(), "%s sai e conclui" % item[0])
		_check(campaign.result.reach > 0 and campaign.result.expectation > 0, "%s gera resultado" % item[0])
		var release: ReleaseData = game.career.find_release(content.id)
		_check(release.initial_potential >= 1.0, "%s recebe potencial" % item[0])
		_check(game.streaming.total_followers(game.career) >= campaign.result.new_fans - 5, "%s: fãs viram seguidores" % item[0])
		var report: WeekReport = game.next_week()
		_check(report.entries[0].streams > 0, "%s rende nas plataformas" % item[0])
		game.free()


func _test_marketing_has_no_guaranteed_return() -> void:
	var covered := 0
	var runs := 30
	for i in runs:
		var game := _make_game(10000000, 20, i + 1)
		var song: SongData = game.create_song("Campanha").value
		song.quality = 60
		for action_id in ["teaser", "social", "influencers", "radio", "pre_save"]:
			game.add_marketing_action(song.id, action_id)
		var invested_before: int = game.career.money
		game.schedule_release(song.id, 3)
		var invested: int = invested_before - game.career.money
		_check(invested == 5150, "campanha de $5.100 + lançamento")
		var money_after_paying: int = game.career.money
		_weeks(game, 2)
		var after_release: int = game.career.money
		_check(after_release - money_after_paying < 500, "lançar não reembolsa o marketing")
		_weeks(game, 10)
		if game.career.money - money_after_paying >= invested:
			covered += 1
		game.free()
	_check(covered < runs, "marketing não se paga obrigatoriamente: %d de %d" % [covered, runs])

	# O marketing aumenta o público, sem criar dinheiro direto.
	var with_campaign := _make_game(10000000, 20, 5)
	var promoted: SongData = with_campaign.create_song("Promovida").value
	with_campaign.add_marketing_action(promoted.id, "influencers")
	with_campaign.schedule_release(promoted.id, 3)
	_weeks(with_campaign, 2)
	_check(with_campaign.streaming.total_followers(with_campaign.career) > 0, "marketing traz seguidores")
	var earnings: Array = with_campaign.career.finance_history.filter(func(item: FinanceEntry) -> bool: return item.category == FinanceEntry.CATEGORY_MARKETING and item.amount > 0)
	_check(earnings.is_empty(), "nenhum crédito de marketing no histórico")
	with_campaign.free()


func _test_marketing_cancel_keeps_money_spent() -> void:
	var game := _make_game()
	var ids := _add_songs(game, 3)
	var album: AlbumData = game.create_album("Projeto", &"ep", ids).value
	game.add_marketing_action(album.id, "teaser")
	var money: int = game.career.money
	game.schedule_release(album.id, 5)
	_check(game.career.money == money - 75 - 500, "agendamento e marketing pagos")
	var money_scheduled: int = game.career.money
	_check(game.cancel_schedule(album.id).ok, "cancela")
	_check(game.career.money == money_scheduled + 75, "só o agendamento é devolvido")
	_check(game.career.find_campaign(album.id).invested() == 500, "marketing segue pago")
	_check(game.schedule_release(album.id, 5).ok and game.career.money == money_scheduled, "reagendar não paga marketing de novo")
	game.free()


func _with_leak_chance(game: Node, chance: float) -> float:
	var rules: StreamingRules = game.balance.streaming
	var previous := rules.leak_chance_per_week
	rules.leak_chance_per_week = chance
	return previous


func _test_leak() -> void:
	var game := _make_game()
	var previous := _with_leak_chance(game, 1.0)
	var song: SongData = game.create_song("Vazada").value
	game.add_marketing_action(song.id, "teaser")
	game.add_marketing_action(song.id, "social")
	game.schedule_release(song.id, 5)
	var campaign: MarketingCampaign = game.career.find_campaign(song.id)
	var money: int = game.career.money
	var followers_before: int = game.streaming.total_followers(game.career)
	var report: WeekReport = game.next_week()
	_check(song.is_leaked() and song.leak_week == 2, "vazamento registrado")
	_check(not song.is_released(), "vazou mas não foi lançada")
	_check(song.status_label() == "Não lançada" and "vazou" in song.display_status(), "status mostra o vazamento")
	_check(game.career.find_active_schedule(song.id) != null, "agendamento continua")
	_check(game.career.find_performance(song.id) == null, "não entra nas plataformas")
	_check(game.career.find_release(song.id) == null, "não vira lançamento")
	_check(game.career.money == money, "vazamento não gera receita")
	_check(report.total_money() == 0, "relatório sem receita")
	var lines := report.entries.map(func(item: WeekReportEntry) -> String: return item.title)
	_check(lines.any(func(title: String) -> bool: return "Vazamento" in title), "relatório avisa do vazamento")
	_check(campaign.leak_penalty == game.balance.streaming.leak_hype_penalty, "expectativa prejudicada")
	_check(song.leak_attention > 0, "gera atenção")
	_check(game.streaming.total_followers(game.career) > followers_before, "gera exposição")
	var attention := song.leak_attention
	game.next_week()
	_check(song.leak_attention == attention and song.leak_week == 2, "só vaza uma vez")
	game.balance.streaming.leak_chance_per_week = previous
	game.free()


func _test_leak_then_official_release() -> void:
	var game := _make_game()
	var previous := _with_leak_chance(game, 1.0)
	var song: SongData = game.create_song("Vazada").value
	game.schedule_release(song.id, 3)
	game.next_week()
	_check(song.is_leaked() and not song.is_released(), "vazou antes da data")
	var money: int = game.career.money
	game.next_week()
	_check(song.is_released() and song.release_week == 3, "sai oficialmente na data")
	_check(game.career.find_release(song.id) != null, "lançamento oficial registrado")
	var performance: SongPerformance = game.career.find_performance(song.id)
	_check(performance != null and performance.total_plays == 0, "entra nas plataformas sem contar o vazamento")
	_check(game.career.money == money, "sem receita até a primeira semana oficial")
	var report: WeekReport = game.next_week()
	_check(report.entries[0].streams > 0 and report.total_money() > 0, "receita depois do lançamento oficial")
	_check(game.career.money > money, "dinheiro entra")
	_check(song.display_status() == "Lançada", "status oficial")
	_check(song.is_leaked(), "histórico do vazamento fica")

	# Também é possível cancelar e lançar quando quiser.
	var other: SongData = game.create_song("Outra").value
	game.schedule_release(other.id, game.career.current_week + 4)
	game.next_week()
	_check(other.is_leaked(), "outra vazou")
	_check(game.cancel_schedule(other.id).ok, "pode cancelar depois de vazar")
	_check(game.release_content(other.id).ok, "pode lançar manualmente depois de vazar")
	_check(other.is_released(), "lançada oficialmente")
	game.balance.streaming.leak_chance_per_week = previous
	game.free()


func _test_leak_of_project() -> void:
	for format_id: StringName in [&"ep", &"album", &"mixtape"]:
		var game := _make_game()
		var previous := _with_leak_chance(game, 1.0)
		var album_format: AlbumFormatDefinition = game.balance.find_album_format(format_id)
		var ids := _add_songs(game, album_format.min_songs)
		var album: AlbumData = game.create_album("Projeto", format_id, ids).value
		game.schedule_release(album.id, 3)
		var money: int = game.career.money
		var report: WeekReport = game.next_week()
		_check(album.is_leaked() and not album.is_released(), "%s vazou" % format_id)
		_check(report.total_money() == 0 and game.career.money == money, "%s vazado sem receita" % format_id)
		_check(game.career.find_performance(ids[0]) == null, "%s: faixas fora das plataformas" % format_id)
		game.next_week()
		_check(album.is_released(), "%s sai oficialmente" % format_id)
		var official: WeekReport = game.next_week()
		_check(official.entries[0].streams > 0 and official.entries[0].sales > 0, "%s rende depois" % format_id)
		game.balance.streaming.leak_chance_per_week = previous
		game.free()


func _test_leak_chance_is_configurable() -> void:
	var game := _make_game()
	var rules: StreamingRules = game.balance.streaming
	var previous := _with_leak_chance(game, 0.0)
	var previous_hype := rules.leak_hype_chance
	rules.leak_hype_chance = 0.0
	var song: SongData = game.create_song("Segura").value
	game.schedule_release(song.id, 30)
	_weeks(game, 20)
	_check(not song.is_leaked(), "chance zero nunca vaza")
	rules.leak_chance_per_week = previous
	rules.leak_hype_chance = previous_hype
	_check(previous > 0.0 and previous < 0.2, "chance padrão é baixa")

	var leaks := 0
	for i in 200:
		var run := _make_game(10000000, 0, i + 1)
		var item: SongData = run.create_song("Item").value
		run.schedule_release(item.id, 4)
		_weeks(run, 2)
		leaks += 1 if item.is_leaked() else 0
		run.free()
	_check(leaks > 0 and leaks < 40, "vazamento não é obrigatório: %d de 200" % leaks)
	game.free()


func _sample(sample_id: String, song_id: String = "") -> SongSample:
	var sample := SongSample.new()
	sample.sample_id = sample_id
	sample.song_id = song_id
	return sample


func _test_samples() -> void:
	var game := _make_game()
	var catalog: SampleCatalog = game.balance.samples
	var types := {}
	for sample in catalog.samples:
		types[sample.type] = true
		_check(not sample.info_text().is_empty(), "%s se explica" % sample.id)
	_check(types.has("iconic") and types.has("obscure") and types.has("recognizable") and types.has("own"), "quatro tipos")

	var cases := [["iconic_funk_break", "icônico"], ["obscure_library_loop", "obscuro"], ["recognizable_jazz_piano", "reconhecível"]]
	for item: Array in cases:
		var definition: SampleDefinition = catalog.find_sample(item[0])
		var run := _make_game(10000000, 0, 3)
		var without: SongData = run.create_song("Sem").value
		var run2 := _make_game(10000000, 0, 3)
		var money: int = run2.career.money
		var with_sample: SongData = run2.create_song("Com", null, "", _sample(item[0])).value
		_check(with_sample.sample.sample_id == item[0], "sample %s registrado" % item[1])
		_check(with_sample.quality == clampi(without.quality + definition.quality_impact, 0, 100), "sample %s muda a nota" % item[1])
		_check(run2.career.money == money - 100 - definition.cost, "sample %s cobra" % item[1])
		var line: FinanceEntry = run2.career.finance_history.back()
		_check(line.category == FinanceEntry.CATEGORY_SAMPLE and line.amount == -definition.cost, "sample %s no histórico" % item[1])
		run.free()
		run2.free()

	_check(not game.create_song("X", null, "", _sample("nao_existe")).ok, "sample inválido recusado")
	_check(not game.create_song("X", null, "", _sample("iconic_funk_break", "song_1")).ok, "sample comum não aceita música própria")

	game.career.money = 10
	var money_before: int = game.career.money
	_check(not game.create_song("Sem dinheiro", null, "", _sample("iconic_funk_break")).ok, "falta de dinheiro recusa o sample")
	_check(game.career.money == money_before, "recusa não cobra")
	game.career.money = 10000000

	# Edição: troca, mantém e remove.
	var song: SongData = game.create_song("Editável").value
	var base := song.quality
	var money: int = game.career.money
	_check(game.edit_song(song.id, song.title, song.credits, "", _sample("obscure_library_loop")).ok, "adiciona sample ao editar")
	_check(game.career.money == money - 200 and song.quality == base + 3, "edição cobra e soma")
	money = game.career.money
	_check(game.edit_song(song.id, "Novo nome", song.credits, "").ok, "editar sem sample mantém o atual")
	_check(song.sample.sample_id == "obscure_library_loop" and game.career.money == money, "mantém sem cobrar")
	_check(game.edit_song(song.id, song.title, song.credits, "", SongSample.new()).ok, "remove sample")
	_check(song.sample.is_empty() and song.quality == base, "remover restaura a nota")
	game.release_content(song.id)
	_check(not game.edit_song(song.id, song.title, song.credits, "", _sample("obscure_library_loop")).ok, "lançada não troca sample")
	game.free()


func _test_own_sample() -> void:
	var game := _make_game()
	var original: SongData = game.create_song("NOITE FRIA").value
	var money: int = game.career.money
	var missing: ActionResult = game.create_song("Sem escolha", null, "", _sample("own_song"))
	_check(not missing.ok and "Selecione" in missing.message, "sample próprio exige escolher a música")
	_check(game.career.songs.size() == 1 and game.career.money == money, "recusa não cria música")
	_check(not game.create_song("Inválida", null, "", _sample("own_song", "song_999")).ok, "música inexistente recusada")

	var result: ActionResult = game.create_song("Remix", null, "", _sample("own_song", original.id))
	_check(result.ok, "sample próprio com música escolhida")
	var remix: SongData = result.value
	_check(remix.sample.sample_id == "own_song" and remix.sample.song_id == original.id, "registra a música usada")
	_check(not game.edit_song(remix.id, remix.title, remix.credits, "", _sample("own_song", remix.id)).ok, "não sampleia a si mesma")
	_check(not game.edit_song(remix.id, remix.title, remix.credits, "", _sample("own_song")).ok, "edição também exige escolher")
	_check(remix.sample.song_id == original.id, "recusa mantém a escolha")
	game.free()


func _test_sample_interest() -> void:
	var game := _make_game()
	var plain: SongData = game.create_song("Sem").value
	var iconic: SongData = game.create_song("Icônico", null, "", _sample("iconic_funk_break")).value
	var obscure: SongData = game.create_song("Obscuro", null, "", _sample("obscure_library_loop")).value
	var streaming: StreamingSystem = game.streaming
	_check(streaming._sample_launch_factor(game.career, plain) == 1.0, "sem sample, sem efeito")
	var iconic_factor: float = streaming._sample_launch_factor(game.career, iconic)
	var obscure_factor: float = streaming._sample_launch_factor(game.career, obscure)
	_check(iconic_factor > obscure_factor and obscure_factor > 1.0, "sample icônico gera mais interesse")
	var catalog: SampleCatalog = game.balance.samples
	_check(catalog.find_sample("iconic_funk_break").recognition > catalog.find_sample("obscure_library_loop").recognition, "icônico é mais reconhecido")
	_check(catalog.find_sample("iconic_funk_break").attention > catalog.find_sample("obscure_library_loop").attention, "icônico chama mais atenção")

	var original := _released_single(game, "Original")
	_weeks(game, 2)
	var own: SongData = game.create_song("Própria", null, "", _sample("own_song", original.id)).value
	var low: SongData = game.create_song("Própria 2", null, "", _sample("own_song", plain.id)).value
	_check(streaming._sample_launch_factor(game.career, own) > streaming._sample_launch_factor(game.career, low), "música sampleada com público ajuda mais")

	var viral_with := 0
	var viral_without := 0
	for i in 200:
		var run := _make_game(10000000, 0, i + 1)
		var a: SongData = run.create_song("A", null, "", _sample("iconic_funk_break")).value
		run.release_content(a.id)
		viral_with += 1 if run.career.find_performance(a.id).trajectory_id == "viral" else 0
		run.free()
		var run2 := _make_game(10000000, 0, i + 1)
		var b: SongData = run2.create_song("B").value
		run2.release_content(b.id)
		viral_without += 1 if run2.career.find_performance(b.id).trajectory_id == "viral" else 0
		run2.free()
	_check(viral_with > viral_without, "sample com atenção favorece viralizar: %d x %d" % [viral_with, viral_without])
	game.free()


func _test_profile() -> void:
	var game := _make_game()
	var streaming: StreamingSystem = game.streaming
	_check(streaming.catalog_text(game.career) == "nenhum lançamento", "catálogo vazio")
	_check("início de carreira" in streaming.artist_bio(game.career), "descrição inicial")
	game.career.fame = 150
	_check("consolidado" in streaming.artist_bio(game.career), "descrição evolui com a carreira")
	game.career.fame = 0
	game.set_artist_bio("  Do Nordeste para o mundo  ")
	_check(streaming.artist_bio(game.career) == "Do Nordeste para o mundo", "descrição própria")
	game.set_artist_cover("foto.webp")
	_check(game.career.artist_cover == "foto.webp", "foto do perfil")
	_released_single(game)
	var ids := _add_songs(game, 3)
	game.release_content(game.create_album("Meu EP", &"ep", ids).value.id)
	var text: String = streaming.catalog_text(game.career)
	_check("1 single" in text and "1 EP" in text, "catálogo por tipo: " + text)
	game.free()


func _test_history() -> void:
	var game := _make_game()
	var streaming: StreamingSystem = game.streaming
	var first := _released_single(game, "Primeira")
	_weeks(game, 3)
	var second := _released_single(game, "Segunda")
	_weeks(game, 4)
	var snapshots: Array[PerformanceSnapshot] = game.career.performance_snapshots
	_check(snapshots.size() >= 6, "histórico semanal: %d" % snapshots.size())
	_check(snapshots.back().week == game.career.current_week, "última semana no histórico")
	_check(snapshots.back().followers >= snapshots[0].followers, "crescimento de seguidores")
	_check(snapshots.any(func(item: PerformanceSnapshot) -> bool: return item.revenue > 0), "receita no histórico")
	_check(streaming.peak_listeners(game.career) >= streaming.total_listeners(game.career), "maior número de ouvintes")
	_check(streaming.peak_week_plays(game.career) > 0, "maior número de streams")
	var top := streaming.top_songs(game.career)
	_check(top.size() == 2 and top[0].total_plays >= top[1].total_plays, "música mais popular")
	_check(streaming.best_release(game.career) != null, "melhor lançamento")
	var perf: SongPerformance = game.career.find_performance(first.id)
	_check(perf.weekly_plays.size() == 7 and perf.peak_week_plays > 0, "histórico por música")
	_check(game.career.find_performance(second.id).weekly_plays.size() == 4, "cada música no próprio ritmo")
	game.free()


func _test_round_trip() -> void:
	_clean_saves()
	var game := _make_game()
	var previous := _with_leak_chance(game, 1.0)
	var leaked: SongData = game.create_song("Vazada").value
	game.schedule_release(leaked.id, 9)
	game.next_week()
	game.balance.streaming.leak_chance_per_week = 0.0
	var original := _released_single(game, "Original")
	var ids := _add_songs(game, 3)
	var ep: AlbumData = game.create_album("EP", &"ep", ids).value
	game.add_marketing_action(ep.id, "teaser")
	game.schedule_release(ep.id, 4)
	var sampled: SongData = game.create_song("Remix", null, "", _sample("own_song", original.id)).value
	game.set_artist_bio("Bio")
	game.set_artist_cover("foto.webp")
	_weeks(game, 3)
	game.next_week()
	var expected := JSON.stringify(game.career.to_dict())
	_check(game.save_game().ok and game.load_game().ok, "salva e carrega")
	_check(JSON.stringify(game.career.to_dict()) == expected, "save idêntico")
	var career: CareerData = game.career
	_check(career.artist_bio == "Bio" and career.artist_cover == "foto.webp", "perfil salvo")
	_check(career.find_song(leaked.id).is_leaked(), "vazamento salvo")
	_check(career.find_song(sampled.id).sample.song_id == original.id, "sample próprio salvo")
	var perf: SongPerformance = career.find_performance(original.id)
	_check(perf.total_plays > 0 and perf.platform_plays["spotify"] > 0 and perf.weekly_plays[0] is int, "desempenho salvo")
	_check(career.platform_stats["spotify"].followers > 0, "público salvo")
	_check(career.performance_snapshots.size() > 0 and career.performance_snapshots[0].plays is int, "histórico salvo")
	_check(career.find_campaign(ep.id).is_completed(), "campanha de projeto salva")
	var plays_before := perf.total_plays
	game.next_week()
	_check(career.find_performance(original.id).total_plays > plays_before, "continua rendendo após carregar")
	game.balance.streaming.leak_chance_per_week = previous
	game.free()


func _test_v4_migration() -> void:
	_clean_saves()
	DirAccess.make_dir_recursive_absolute(TEST_SAVE_DIR)
	var save_path := TEST_SAVE_DIR.path_join("career.json")
	var fixture_text := FileAccess.get_file_as_string(V4_FIXTURE)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(fixture_text)
	file.close()
	var old_payload: Dictionary = JSON.parse_string(fixture_text)
	var old: Dictionary = old_payload["career"]
	_check(int(old_payload["version"]) == 4, "fixture é v4")

	var game: Node = GameManagerScript.new()
	game.rng.seed = 9
	game.saves.save_dir = TEST_SAVE_DIR
	_check(game.load_game().ok, "carrega save v4 real")
	var career: CareerData = game.career
	_check(FileAccess.get_file_as_string(save_path + ".v4.bak") == fixture_text, "cópia v4 guardada")
	_check(career.money == int(old["money"]) and career.fame == int(old["fame"]), "dinheiro e fama preservados")
	_check(career.energy == 35 and career.current_week == int(old["current_week"]), "energia e semana preservadas")
	_check(career.songs.size() == old["songs"].size() and career.albums.size() == old["albums"].size(), "conteúdo preservado")
	_check(career.finance_history.size() == old["finance_history"].size(), "histórico preservado")
	_check(career.releases.size() == old["releases"].size(), "lançamentos preservados")
	for index in career.songs.size():
		_check(career.songs[index].quality == int(old["songs"][index]["quality"]), "nota da música %d" % index)
		_check(career.songs[index].sample.is_empty(), "música %d sem sample" % index)
		_check(not career.songs[index].is_leaked(), "música %d sem vazamento" % index)

	# Campanhas agora guardam o conteúdo, em qualquer estado.
	_check(career.marketing_campaigns.size() == old["marketing_campaigns"].size(), "campanhas preservadas")
	var titles := {"Hit com campanha": MarketingCampaign.STATUS_COMPLETED, "Campanha ativa": MarketingCampaign.STATUS_ACTIVE, "Campanha planejada": MarketingCampaign.STATUS_PLANNING}
	for song in career.songs:
		if titles.has(song.title):
			var campaign := career.find_campaign(song.id)
			_check(campaign != null and campaign.status == titles[song.title], "campanha de %s" % song.title)

	# Desempenho antigo vira desempenho nas plataformas.
	var total_streams := 0
	for release in career.releases:
		if release.content_type == ReleaseData.TYPE_SONG:
			total_streams += release.total_streams
			var performance := career.find_performance(release.content_id)
			_check(performance != null and performance.total_plays == release.total_streams, "single antigo mantém os streams")
			_check(performance.trajectory_id == "legacy", "single antigo mantém a curva")
	_check(game.streaming.total_plays(career) == total_streams, "total de reproduções preservado")
	var spread := 0
	for platform_id in STREAMING_IDS:
		spread += career.platform_stats_for(platform_id).total_plays
	_check(abs(spread - total_streams) <= 5, "streams distribuídos entre plataformas")
	_check(game.streaming.total_followers(career) > 0, "público inicial a partir dos streams")

	var ep: AlbumData = career.albums[0]
	_check(ep.is_released(), "EP lançado")
	for song_id in ep.song_ids:
		_check(career.find_performance(song_id).release_id == ep.id, "faixa do EP entra nas plataformas")
	_check(career.platform_stats_for("digital_store").total_plays == career.find_release(ep.id).total_sales, "vendas antigas na Loja")

	var money: int = career.money
	var report: WeekReport = game.next_week()
	_check(game.career.money == money + report.total_money(), "tudo segue rendendo")
	_check(career.find_performance(ep.song_ids[0]).total_plays > 0, "faixas antigas passam a tocar")
	var active_title := career.songs.filter(func(item: SongData) -> bool: return item.title == "Campanha ativa")[0] as SongData
	while career.current_week < 9:
		game.next_week()
	_check(active_title.is_released() and career.find_campaign(active_title.id).result != null, "campanha antiga termina")
	_check(game.save_game().ok, "salva migrado")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	_check(int(saved["version"]) == SaveSystem.SAVE_VERSION, "arquivo atualizado")
	game.free()


func _clean_saves() -> void:
	if not DirAccess.dir_exists_absolute(TEST_SAVE_DIR):
		return
	for file_name in DirAccess.get_files_at(TEST_SAVE_DIR):
		DirAccess.remove_absolute(TEST_SAVE_DIR.path_join(file_name))
	DirAccess.remove_absolute(TEST_SAVE_DIR)
