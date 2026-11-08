extends SceneTree
## Testes de progressão da carreira, balanço semanal, agenda e próximos passos. Para rodar:
##   godot --headless --path . --script res://tests/test_progression.gd

const GameManagerScript := preload("res://scripts/core/game_manager.gd")
const TEST_SAVE_DIR := "user://test_saves_progression"

var _failures := 0
var _checks := 0


func _init() -> void:
	_test_stages()
	_test_week_balance()
	_test_stage_up()
	_test_agenda()
	_test_next_steps()
	_test_report_round_trip()
	_test_ticket_price_cap()
	_clean()
	print("%d verificações, %d falhas" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FALHOU: ", label)


func _game(money: int = 100000, fame: int = 0) -> Node:
	var game: Node = GameManagerScript.new()
	game.rng.seed = 71
	game.saves.save_dir = TEST_SAVE_DIR
	game.new_career("MC Progresso")
	game.career.money = money
	game.career.fame = fame
	return game


func _test_stages() -> void:
	var game := _game()
	var progression: ProgressionSystem = game.progression
	var stages := progression.stages()
	_check(stages.size() == 6, "seis fases da carreira")
	_check(stages[0].min_fame == 0 and stages[-1].display_name == "Estrela", "de desconhecido a estrela")
	for i in range(1, stages.size()):
		_check(stages[i].min_fame > stages[i - 1].min_fame, "fases em ordem: %s" % stages[i].id)
		_check(not stages[i].description.is_empty(), "fase com descrição: %s" % stages[i].id)
	_check(progression.stage_for(0).id == "unknown", "começa desconhecido")
	_check(progression.stage_for(stages[2].min_fame).id == stages[2].id, "limite exato muda a fase")
	_check(progression.stage_for(stages[2].min_fame - 1).id == stages[1].id, "um abaixo do limite")
	_check(progression.next_stage(stages[-1].min_fame) == null and progression.stage_progress(999999) == 1.0, "topo da carreira")
	var middle := (stages[1].min_fame + stages[2].min_fame) / 2
	_check(absf(progression.stage_progress(middle) - 0.5) < 0.02, "progresso até a próxima fase")
	game.free()


func _test_week_balance() -> void:
	var game := _game(5000)
	var song: SongData = game.create_song("Hit").value
	game.release_content(song.id)
	var money_before: int = game.career.money
	var fame_before: int = game.career.fame
	var fans_before: int = game.streaming.total_followers(game.career)
	var plays_before: int = game.streaming.total_plays(game.career)
	var report: WeekReport = game.next_week()
	_check(report.money_change == game.career.money - money_before, "saldo real de dinheiro da semana")
	_check(report.fame_change == game.career.fame - fame_before, "fama da semana")
	_check(report.fans_change == game.streaming.total_followers(game.career) - fans_before, "fãs da semana")
	_check(report.plays == game.streaming.total_plays(game.career) - plays_before and report.plays > 0, "streams da semana")
	var job: ActionResult = game.work_job(&"heavy_labor")
	_check(job.ok and game.career.last_report().money_change >= game.balance.find_job(&"heavy_labor").pay - 1000, "semana de trabalho também tem balanço")
	game.free()


func _test_stage_up() -> void:
	var game := _game(5000)
	var underground: CareerStageDefinition = game.progression.stages()[1]
	game.career.fame = underground.min_fame - 1
	game.balance.live.base_offers_per_week = 0.0
	var song: SongData = game.create_song("Subida").value
	game.release_content(song.id)
	var report: WeekReport = game.next_week()
	_check(game.career.fame >= underground.min_fame, "semana dá fama suficiente")
	_check(report.stage_reached == underground.id, "relatório marca a nova fase")
	_check(report.entries[0].title.contains(underground.display_name), "aviso de nova fase em destaque")
	var calm: WeekReport = game.next_week()
	_check(calm.stage_reached.is_empty(), "sem aviso quando a fase não muda")
	game.balance.live.base_offers_per_week = 0.4
	game.free()


func _test_agenda() -> void:
	var game := _game(500000, 500)
	var progression: ProgressionSystem = game.progression
	_check(progression.agenda(game.career).is_empty(), "agenda vazia no começo")
	var song: SongData = game.create_song("Agendada").value
	game.add_marketing_action(song.id, "social")
	game.schedule_release(song.id, game.career.current_week + 3)
	var show: LiveShow = game.live.new_show(game.career, LiveShow.KIND_INDEPENDENT)
	game.schedule_show(show)
	var types: Array[String] = ["national"]
	game.create_tour("Planejada", "", "", types, "")
	var released: SongData = game.create_song("Com clipe").value
	game.release_content(released.id)
	game.create_video(released.id, game.videos.default_choices(), "", "date", game.career.current_week + 8)
	var items := progression.agenda(game.career)
	var kinds := items.map(func(item: Dictionary) -> String: return item["kind"])
	for kind in ["release", "show", "tour", "video", "marketing"]:
		_check(kind in kinds, "agenda mostra %s" % kind)
	for i in range(1, items.size()):
		_check(items[i]["week"] >= items[i - 1]["week"], "agenda em ordem")
	game.free()


func _test_next_steps() -> void:
	var game := _game(5000)
	var steps: PackedStringArray = game.progression.next_steps(game.career)
	_check(steps.size() <= 3 and steps[0].contains("primeira música"), "primeiro passo: gravar")
	game.create_song("Inédita")
	steps = game.progression.next_steps(game.career)
	_check(steps[0].contains("inédita"), "sugere lançar músicas prontas")
	game.career.money = 50
	steps = game.progression.next_steps(game.career)
	_check(steps[0].contains("trabalhe"), "sugere trabalhar sem dinheiro")
	game.free()


func _test_report_round_trip() -> void:
	var game := _game(5000)
	var song: SongData = game.create_song("Salva").value
	game.release_content(song.id)
	game.next_week()
	var before := JSON.stringify(game.career.last_report().to_dict())
	game.save_game()
	var other := _game()
	other.load_game()
	_check(JSON.stringify(other.career.last_report().to_dict()) == before, "balanço da semana salvo")
	other.free()
	game.free()


func _test_ticket_price_cap() -> void:
	var game := _game(100000, 0)
	var live: LiveSystem = game.live
	var small := live.price_fame_multiplier(game.career)
	game.career.fame = 1000000
	var huge := live.price_fame_multiplier(game.career)
	_check(small == 1.0 and huge == 1.0 + game.balance.live.max_price_fame_bonus, "fama aumenta o preço com teto")
	game.free()


func _clean() -> void:
	if not DirAccess.dir_exists_absolute(TEST_SAVE_DIR):
		return
	for file_name in DirAccess.get_files_at(TEST_SAVE_DIR):
		DirAccess.remove_absolute(TEST_SAVE_DIR.path_join(file_name))
	DirAccess.remove_absolute(TEST_SAVE_DIR)
