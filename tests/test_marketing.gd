extends SceneTree
## Testes do marketing, sem interface. Para rodar:
##   godot --headless --path . --script res://tests/test_marketing.gd

const GameManagerScript := preload("res://scripts/core/game_manager.gd")
const TEST_SAVE_DIR := "user://test_saves_marketing"
const V3_FIXTURE := "res://tests/fixtures/save_v3.json"
const EXPECTED_ACTIONS: Array[String] = ["Redes sociais", "Teaser", "Publicidade paga", "Influenciadores", "Rádio", "Playlists", "Entrevistas", "Videoclipe", "Pré-save"]
const STARTER_ACTIONS: Array[String] = ["social", "teaser", "pre_save"]

var _failures := 0
var _checks := 0


func _init() -> void:
	_clean_saves()
	_test_catalog()
	_test_planning_and_costs()
	_test_requirements_and_progression()
	_test_schedule_integration()
	_test_scheduling_from_any_screen_pays_once()
	_test_weeks_and_release()
	_test_timing_matters()
	_test_hype_factors()
	_test_hype_is_not_a_guarantee()
	_test_active_campaign_editing()
	_test_cancel_and_reschedule()
	_test_immediate_release()
	_test_track_released_by_project()
	_test_outcomes_vary()
	_test_performance_potential()
	_test_no_campaign_changes_nothing()
	_test_round_trip()
	_test_v3_migration()
	_clean_saves()
	print("%d verificações, %d falhas" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FALHOU: ", label)


func _make_game(money: int = 1000000, fame: int = 0) -> Node:
	var game: Node = GameManagerScript.new()
	game.rng.seed = 21
	game.saves.save_dir = TEST_SAVE_DIR
	game.new_career("MC Teste")
	game.career.money = money
	game.career.fame = fame
	return game


func _song(game: Node, title: String = "Noite Fria") -> SongData:
	return game.create_song(title).value


func _plan(game: Node, song: SongData, action_ids: Array[String]) -> void:
	for action_id in action_ids:
		game.add_marketing_action(song.id, action_id)


func _test_catalog() -> void:
	var game := _make_game()
	var rules: MarketingRules = game.balance.marketing
	var names: Array = rules.actions.map(func(item: MarketingActionDefinition) -> String: return item.display_name)
	for expected in EXPECTED_ACTIONS:
		_check(expected in names, "ação %s existe" % expected)
	_check(rules.actions.size() == 9, "nove ações")
	for action in rules.actions:
		_check(action.cost > 0 and action.reach > 0 and action.duration_weeks > 0, "%s tem custo, alcance e duração" % action.id)
		_check(action.hype_impact > 0.0 and action.return_potential > 0.0, "%s tem hype e retorno" % action.id)
	game.free()


func _test_planning_and_costs() -> void:
	var game := _make_game(10000, 10)
	var song := _song(game)
	var money: int = game.career.money
	_check(game.add_marketing_action(song.id, "teaser").ok, "planeja teaser")
	_check(game.career.money == money, "planejar não cobra")
	_check(game.career.find_campaign(song.id).status == MarketingCampaign.STATUS_PLANNING, "campanha em planejamento")
	_check(not game.add_marketing_action(song.id, "teaser").ok, "ação repetida recusada")
	_check(not game.add_marketing_action(song.id, "inventada").ok, "ação inválida recusada")
	_check(not game.add_marketing_action("song_999", "social").ok, "música inválida recusada")
	# Exemplo da especificação: $5.100 no total, com requisitos atendidos.
	game.career.fame = 20
	_plan(game, song, ["social", "influencers", "radio", "pre_save"] as Array[String])
	_check(game.marketing.unpaid_cost(game.career, song.id) == 5100, "soma das ações é $5.100")
	_check(game.career.find_campaign(song.id).actions.size() == 5, "combina cinco ações")
	_check(game.remove_marketing_action(song.id, "radio").ok, "remove ação planejada")
	_check(game.marketing.unpaid_cost(game.career, song.id) == 3600, "custo cai ao remover")
	_check(not game.remove_marketing_action(song.id, "radio").ok, "remover de novo é recusado")

	# Sem dinheiro para o total planejado, a ação é recusada.
	game.career.money = 3600
	var result: ActionResult = game.add_marketing_action(song.id, "radio")
	_check(not result.ok and "insuficiente" in result.message, "falta de dinheiro recusa a ação")
	_check(game.career.find_campaign(song.id).find_action("radio") == null, "recusa não entra na campanha")
	_check(game.career.money == 3600, "recusa não cobra")
	game.free()


func _test_requirements_and_progression() -> void:
	var game := _make_game(10000000, 0)
	var song := _song(game)
	for action_id in STARTER_ACTIONS:
		_check(game.add_marketing_action(song.id, action_id).ok, "iniciante acessa %s" % action_id)
	_check(not game.add_marketing_action(song.id, "video").ok, "iniciante não acessa videoclipe")
	_check(not game.add_marketing_action(song.id, "radio").ok, "iniciante não acessa rádio")
	game.career.fame = 20
	_check(game.add_marketing_action(song.id, "radio").ok, "fama libera rádio")
	game.career.fame = 500
	_check(not game.add_marketing_action(song.id, "interviews").ok, "entrevistas exigem reputação")
	game.career.reputation = 5
	_check(game.add_marketing_action(song.id, "interviews").ok, "reputação libera entrevistas")
	_check(game.add_marketing_action(song.id, "video").ok, "artista grande acessa videoclipe")
	var rules: MarketingRules = game.balance.marketing
	var starter := rules.find_action("teaser")
	var big := rules.find_action("video")
	_check(big.cost > starter.cost * 10 and big.reach > starter.reach * 10, "ações grandes custam e alcançam mais")
	game.free()


func _test_schedule_integration() -> void:
	var game := _make_game(10000)
	var song := _song(game)
	_plan(game, song, ["teaser", "social"] as Array[String])
	var money: int = game.career.money

	game.career.money = 1349
	var refused: ActionResult = game.schedule_release(song.id, 4)
	_check(not refused.ok and "1.350" in refused.message, "agendar exige lançamento + marketing")
	_check(game.career.scheduled_releases.is_empty(), "recusa não agenda")
	_check(game.career.find_campaign(song.id).invested() == 0, "recusa não paga a campanha")
	game.career.money = money

	_check(game.schedule_release(song.id, 4).ok, "agenda com o sistema existente")
	_check(game.career.money == money - 50 - 1300, "paga lançamento e marketing")
	var campaign: MarketingCampaign = game.career.find_campaign(song.id)
	_check(campaign.is_active() and campaign.invested() == 1300, "campanha em andamento")
	_check(game.marketing.unpaid_cost(game.career, song.id) == 0, "nada a pagar")
	var lines: Array = game.career.finance_history.filter(func(item: FinanceEntry) -> bool: return item.category == FinanceEntry.CATEGORY_MARKETING)
	_check(lines.size() == 2 and lines[0].amount == -500 and "Teaser" in lines[0].description, "uma linha por ação no histórico")
	_check(game.career.find_active_schedule(song.id).scheduled_week == 4, "usa a agenda existente")
	game.free()


func _test_scheduling_from_any_screen_pays_once() -> void:
	var game := _make_game(10000)
	var song := _song(game)
	_plan(game, song, ["teaser"] as Array[String])
	game.schedule_release(song.id, 3)
	var money: int = game.career.money
	game.reschedule_release(song.id, 5)
	_check(game.career.money == money, "remarcar não cobra de novo")
	game.free()


func _test_weeks_and_release() -> void:
	var game := _make_game(10000)
	var song := _song(game)
	_plan(game, song, ["teaser", "social", "pre_save"] as Array[String])
	game.schedule_release(song.id, 4)
	var campaign: MarketingCampaign = game.career.find_campaign(song.id)
	var hype_start: int = campaign.hype

	var first: WeekReport = game.next_week()
	_check(campaign.actions[0].weeks_active == 1, "semana avança a campanha")
	_check(campaign.hype > hype_start, "expectativa cresce com o tempo")
	_check(first.entries.size() == 1 and "Expectativa" in first.entries[0].note, "relatório mostra a campanha")
	_check(not song.is_released(), "ainda não saiu")

	game.work_job(&"delivery")
	_check(campaign.actions[0].weeks_active == 2, "trabalhar também passa a semana")

	var money: int = game.career.money
	var release_report: WeekReport = game.next_week()
	_check(song.is_released() and song.release_week == 4, "sai na semana marcada")
	_check(campaign.is_completed() and campaign.status_label() == "Concluída", "campanha concluída")
	_check(game.career.money == money, "lançar não cobra de novo")

	var result: MarketingResult = campaign.result
	_check(result != null and not result.outcome_id.is_empty() and not result.outcome_label.is_empty(), "resultado gerado")
	_check(result.reach > 0, "alcance")
	_check(result.expectation > 0 and result.expectation <= 100, "expectativa")
	_check(result.pre_saves > 0, "pré-saves")
	_check(result.new_fans > 0, "novos fãs")
	_check(result.exposure > 0 and result.exposure <= 100, "exposição")
	_check(result.popularity >= 0, "popularidade")
	_check(result.initial_potential >= 1.0, "potencial inicial")
	var notes := release_report.entries.map(func(item: WeekReportEntry) -> String: return item.note)
	_check(notes.any(func(note: String) -> bool: return result.outcome_label in note), "relatório mostra o resultado")
	_check(game.career.find_release(song.id).initial_potential == result.initial_potential, "lançamento recebe o potencial")

	var weeks_before: int = campaign.actions[0].weeks_active
	game.next_week()
	_check(campaign.actions[0].weeks_active == weeks_before, "campanha concluída não avança")
	_check(not game.add_marketing_action(song.id, "influencers").ok, "lançada não recebe marketing")
	_check(not game.remove_marketing_action(song.id, "teaser").ok, "concluída não muda")
	game.free()


func _test_timing_matters() -> void:
	var game := _make_game()
	var marketing: MarketingSystem = game.marketing
	var teaser: MarketingActionDefinition = game.balance.marketing.find_action("teaser")
	var rules: MarketingRules = game.balance.marketing
	_check(is_equal_approx(marketing.timing_efficiency(teaser, 0), rules.min_timing_efficiency), "sem antecedência rende o mínimo")
	_check(marketing.timing_efficiency(teaser, 1) > marketing.timing_efficiency(teaser, 0), "uma semana rende mais")
	_check(is_equal_approx(marketing.timing_efficiency(teaser, teaser.duration_weeks), 1.0), "duração ideal rende tudo")
	_check(marketing.timing_efficiency(teaser, teaser.duration_weeks + 4) < 1.0, "antecedência demais perde força")
	_check(is_equal_approx(marketing.timing_efficiency(teaser, 200), rules.overrun_efficiency_floor), "perda tem piso")

	var song := _song(game)
	_plan(game, song, ["teaser", "social"] as Array[String])
	var rushed: MarketingSystem.Forecast = marketing.forecast(game.career, song.id, 1)
	var ideal: MarketingSystem.Forecast = marketing.forecast(game.career, song.id, 3)
	var early: MarketingSystem.Forecast = marketing.forecast(game.career, song.id, 20)
	_check(ideal.hype > rushed.hype and ideal.reach > rushed.reach, "tempo ideal supera a pressa")
	_check(ideal.hype > early.hype and ideal.reach > early.reach, "tempo ideal supera campanha cedo demais")
	game.free()


func _test_hype_factors() -> void:
	var game := _make_game()
	var marketing: MarketingSystem = game.marketing
	var song := _song(game)
	_check(marketing.forecast(game.career, song.id, 3).hype == 0, "sem campanha, sem expectativa")
	_plan(game, song, ["teaser"] as Array[String])
	var one_action: int = marketing.forecast(game.career, song.id, 3).hype
	_check(one_action > 0, "uma ação gera expectativa")
	_plan(game, song, ["social"] as Array[String])
	_check(marketing.forecast(game.career, song.id, 3).hype > one_action, "mais ações geram mais expectativa")

	song.quality = 20
	var weak: int = marketing.forecast(game.career, song.id, 3).hype
	song.quality = 95
	var strong: int = marketing.forecast(game.career, song.id, 3).hype
	_check(strong > weak, "qualidade pesa na expectativa")

	var unknown: int = strong
	game.career.fame = 200
	var famous: MarketingSystem.Forecast = marketing.forecast(game.career, song.id, 3)
	_check(famous.hype > unknown, "popularidade pesa na expectativa")
	game.career.fame = 0
	_check(famous.reach > marketing.forecast(game.career, song.id, 3).reach, "popularidade aumenta o alcance")

	game.career.fame = 100000
	game.career.reputation = 100
	for action in game.balance.marketing.actions:
		game.add_marketing_action(song.id, action.id)
	_check(marketing.forecast(game.career, song.id, 4).hype <= 100, "expectativa não passa de 100")
	game.free()


func _test_hype_is_not_a_guarantee() -> void:
	# Mesma campanha e qualidade baixa: o bônus de desempenho fica pequeno.
	var game := _make_game(1000000, 200)
	var weak := _song(game, "Fraca")
	weak.quality = 10
	_plan(game, weak, ["teaser", "social", "pre_save"] as Array[String])
	game.schedule_release(weak.id, 4)
	var strong := _song(game, "Forte")
	strong.quality = 95
	_plan(game, strong, ["teaser", "social", "pre_save"] as Array[String])
	game.schedule_release(strong.id, 4)
	for i in 3:
		game.next_week()
	var weak_result: MarketingResult = game.career.find_campaign(weak.id).result
	var strong_result: MarketingResult = game.career.find_campaign(strong.id).result
	var rules: MarketingRules = game.balance.marketing
	_check(strong_result.new_fans >= weak_result.new_fans, "qualidade ajuda a gerar fãs")
	_check(weak_result.initial_potential <= 1.0 + rules.max_initial_bonus and strong_result.initial_potential <= 1.0 + rules.max_initial_bonus, "potencial tem limite")

	# O marketing não adiciona streams diretamente: sem a sorte, o multiplicador só amplia a base.
	var fixed := PerformanceRules.new()
	fixed.units_min = 1000
	fixed.units_max = 1000
	var plain: PerformanceSystem.Result = game.performance.calculate_week(fixed, 50, 0, 0, 1.0)
	var boosted: PerformanceSystem.Result = game.performance.calculate_week(fixed, 50, 0, 0, 1.5)
	_check(boosted.units == 1500 and plain.units == 1000, "potencial multiplica a base")
	_check(boosted.fame == plain.fame, "potencial não dá fama direta")
	game.free()


func _test_active_campaign_editing() -> void:
	var game := _make_game(10000)
	var song := _song(game)
	_plan(game, song, ["teaser"] as Array[String])
	game.schedule_release(song.id, 5)
	game.next_week()
	var campaign: MarketingCampaign = game.career.find_campaign(song.id)
	var money: int = game.career.money
	_check(game.add_marketing_action(song.id, "social").ok, "adiciona em campanha ativa")
	_check(game.career.money == money - 800, "paga na hora")
	var added := campaign.find_action("social")
	_check(added.is_paid() and added.weeks_active == 0, "ação nova começa do zero")
	_check(campaign.find_action("teaser").weeks_active == 1, "ação antiga mantém o tempo")
	_check(not game.remove_marketing_action(song.id, "social").ok, "ação paga não sai")

	game.career.money = 100
	var refused: ActionResult = game.add_marketing_action(song.id, "pre_save")
	_check(not refused.ok and game.career.money == 100, "sem dinheiro não adiciona em campanha ativa")
	game.free()


func _test_cancel_and_reschedule() -> void:
	var game := _make_game(10000)
	var song := _song(game)
	_plan(game, song, ["teaser"] as Array[String])
	game.schedule_release(song.id, 6)
	game.next_week()
	var campaign: MarketingCampaign = game.career.find_campaign(song.id)
	var weeks_before: int = campaign.actions[0].weeks_active

	var money: int = game.career.money
	_check(game.cancel_schedule(song.id).ok, "cancela")
	_check(game.career.money == money + 50, "devolve só o lançamento")
	_check(campaign.status == MarketingCampaign.STATUS_PLANNING, "campanha volta ao planejamento")
	_check(campaign.invested() == 500, "marketing pago continua valendo")
	game.next_week()
	_check(campaign.actions[0].weeks_active == weeks_before, "campanha parada não avança")
	_check(not song.is_released(), "cancelada não sai")

	money = game.career.money
	_check(game.schedule_release(song.id, game.career.current_week + 2).ok, "agenda de novo")
	_check(game.career.money == money - 50, "não paga o marketing duas vezes")
	_check(campaign.is_active(), "campanha retomada")
	var week: int = game.career.current_week + 1
	_check(game.reschedule_release(song.id, week).ok, "remarca")
	game.next_week()
	_check(song.is_released() and campaign.is_completed(), "sai na nova data")
	game.free()


func _test_immediate_release() -> void:
	var game := _make_game(10000)
	var song := _song(game)
	_plan(game, song, ["teaser"] as Array[String])
	var money: int = game.career.money
	_check(game.release_content(song.id).ok, "lançar agora continua funcionando")
	_check(game.career.money == money - 50, "ação só planejada não é cobrada")
	_check(game.career.find_campaign(song.id) == null, "campanha não paga é descartada")
	_check(game.career.find_release(song.id).initial_potential == 1.0, "sem bônus")

	var paid := _song(game, "Paga")
	_plan(game, paid, ["teaser"] as Array[String])
	game.schedule_release(paid.id, 5)
	game.cancel_schedule(paid.id)
	_check(game.release_content(paid.id).ok, "lança com campanha já paga")
	var campaign: MarketingCampaign = game.career.find_campaign(paid.id)
	_check(campaign.is_completed() and campaign.result != null, "campanha paga gera resultado")
	game.free()


func _test_track_released_by_project() -> void:
	var game := _make_game(100000)
	var ids: Array[String] = []
	for i in 3:
		ids.append(_song(game, "Faixa %d" % i).id)
	var album: AlbumData = game.create_album("Projeto", &"ep", ids).value
	var track: SongData = game.career.find_song(ids[0])
	_plan(game, track, ["teaser"] as Array[String])
	game.schedule_release(track.id, 6)
	_check(game.release_content(album.id).ok, "projeto sai com faixa em campanha")
	_check(track.is_released() and game.career.find_campaign(track.id).is_completed(), "campanha da faixa termina junto")
	_check(game.career.find_active_schedule(track.id) == null, "single agendado cancelado")
	_check(game.career.find_campaign(album.id) == null, "projeto só tem campanha própria")
	game.free()


func _test_outcomes_vary() -> void:
	var rules: MarketingRules = _rules()
	var total_weight := 0.0
	for outcome in rules.outcomes:
		total_weight += outcome.weight
	_check(total_weight > 0.0 and rules.outcomes.size() == 4, "quatro resultados possíveis")
	var ids := rules.outcomes.map(func(item: MarketingOutcomeDefinition) -> String: return item.id)
	_check(ids == ["below", "normal", "great", "opportunity"], "resultados esperados")

	var seen := {}
	var reaches := {}
	for i in 300:
		var game := _make_game(100000)
		game.rng.seed = i + 1
		var song := _song(game)
		song.quality = 60
		_plan(game, song, ["teaser", "social"] as Array[String])
		game.schedule_release(song.id, 3)
		game.next_week()
		game.next_week()
		var result: MarketingResult = game.career.find_campaign(song.id).result
		seen[result.outcome_id] = seen.get(result.outcome_id, 0) + 1
		reaches[result.reach] = true
		game.free()
	for outcome_id in ["below", "normal", "great", "opportunity"]:
		_check(seen.get(outcome_id, 0) > 0, "resultado %s acontece" % outcome_id)
	_check(seen.get("normal", 0) > seen.get("opportunity", 0), "normal é mais comum que oportunidade")
	_check(reaches.size() >= 4, "alcance varia")


func _rules() -> MarketingRules:
	var game: Node = GameManagerScript.new()
	var rules: MarketingRules = game.balance.marketing
	game.free()
	return rules


func _test_performance_potential() -> void:
	var game := _make_game()
	var marketing: MarketingSystem = game.marketing
	var release := ReleaseData.new()
	_check(marketing.units_multiplier(release, 0) == 1.0, "sem campanha, sem bônus")
	release.initial_potential = 1.4
	_check(is_equal_approx(marketing.units_multiplier(release, 0), 1.4), "bônus na primeira semana")
	_check(marketing.units_multiplier(release, 1) < 1.4, "bônus cai")
	_check(marketing.units_multiplier(release, 30) < 1.01, "bônus some com o tempo")
	game.free()


func _test_no_campaign_changes_nothing() -> void:
	var game := _make_game(10000)
	var song := _song(game)
	game.schedule_release(song.id, 2)
	var money: int = game.career.money
	var report: WeekReport = game.next_week()
	_check(song.is_released() and game.career.money == money, "agendar sem marketing segue igual")
	_check(report.entries.size() == 1, "relatório sem linhas de campanha")
	_check(game.career.marketing_campaigns.is_empty(), "sem campanha criada")
	game.free()


func _test_round_trip() -> void:
	_clean_saves()
	var game := _make_game(100000)
	var active := _song(game, "Ativa")
	_plan(game, active, ["teaser", "social"] as Array[String])
	game.schedule_release(active.id, 5)
	var done := _song(game, "Pronta")
	_plan(game, done, ["pre_save"] as Array[String])
	game.schedule_release(done.id, 3)
	var planning := _song(game, "Planejada")
	_plan(game, planning, ["teaser"] as Array[String])
	game.next_week()
	game.next_week()
	var expected := JSON.stringify(game.career.to_dict())
	_check(game.save_game().ok and game.load_game().ok, "salva e carrega")
	_check(JSON.stringify(game.career.to_dict()) == expected, "save idêntico")

	var career: CareerData = game.career
	var loaded_active: MarketingCampaign = career.find_campaign(active.id)
	_check(loaded_active.is_active() and loaded_active.actions[0].weeks_active == 2, "campanha ativa salva")
	var loaded_done: MarketingCampaign = career.find_campaign(done.id)
	_check(loaded_done.is_completed() and loaded_done.result.reach > 0, "resultado salvo")
	_check(career.find_release(done.id).initial_potential == loaded_done.result.initial_potential, "potencial salvo")
	_check(career.find_campaign(planning.id).status == MarketingCampaign.STATUS_PLANNING, "planejamento salvo")
	_check(game.marketing.unpaid_cost(career, planning.id) == 500, "ação planejada salva")

	game.next_week()
	game.next_week()
	game.next_week()
	_check(career.find_song(active.id).is_released() and loaded_active.is_completed(), "campanha carregada termina")
	game.free()


func _test_v3_migration() -> void:
	_clean_saves()
	DirAccess.make_dir_recursive_absolute(TEST_SAVE_DIR)
	var save_path := TEST_SAVE_DIR.path_join("career.json")
	var fixture_text := FileAccess.get_file_as_string(V3_FIXTURE)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(fixture_text)
	file.close()
	var old_payload: Dictionary = JSON.parse_string(fixture_text)
	var old: Dictionary = old_payload["career"]
	_check(int(old_payload["version"]) == 3, "fixture é v3")

	var game: Node = GameManagerScript.new()
	game.rng.seed = 5
	game.saves.save_dir = TEST_SAVE_DIR
	_check(game.load_game().ok, "carrega save v3 real")
	var career: CareerData = game.career
	_check(FileAccess.get_file_as_string(save_path + ".v3.bak") == fixture_text, "cópia v3 guardada")
	_check(career.marketing_campaigns.is_empty(), "sem campanhas antigas")
	_check(career.money == int(old["money"]) and career.fame == int(old["fame"]), "dinheiro e fama preservados")
	_check(career.energy == 55 and career.current_week == int(old["current_week"]), "energia e semana preservadas")
	_check(career.songs.size() == old["songs"].size(), "músicas preservadas")
	_check(career.albums[0].song_ids.size() == 2, "projeto em construção preservado")
	_check(career.finance_history.size() == old["finance_history"].size(), "histórico preservado")
	for index in career.songs.size():
		var song := career.songs[index]
		var old_song: Dictionary = old["songs"][index]
		_check(song.quality == int(old_song["quality"]) and song.title == old_song["title"], "música %d intacta" % index)
		_check(song.attribute_value("vocal") == int(old_song["attribute_bases"]["vocal"]) + int(old_song["attribute_points"].get("vocal", 0)), "vocal da música %d" % index)
	var old_release: ReleaseData = career.releases[0]
	_check(old_release.initial_potential == 1.0, "lançamento antigo sem bônus")
	var free_song := career.songs[2]
	_check(free_song.title == "Inédita solta", "música esperada")
	_check(game.add_marketing_action(free_song.id, "teaser").ok, "música antiga recebe marketing")
	var scheduled := career.songs[1]
	_check(career.find_active_schedule(scheduled.id) != null, "agendamento antigo preservado")
	var money_before: int = career.money
	_check(game.add_marketing_action(scheduled.id, "teaser").ok, "agendada antiga aceita marketing")
	var scheduled_campaign: MarketingCampaign = career.find_campaign(scheduled.id)
	_check(scheduled_campaign.is_active() and career.money == money_before - 500, "já agendada: ação paga e iniciada na hora")
	while career.current_week < 6:
		game.next_week()
	_check(scheduled.is_released(), "agendamento antigo acontece")
	_check(scheduled_campaign.is_completed() and scheduled_campaign.result != null, "campanha de agendada antiga gera resultado")
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
