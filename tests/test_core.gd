extends SceneTree
## Testes das regras do jogo, sem interface. Para rodar:
##   godot --headless --path . --script res://tests/test_core.gd

const GameManagerScript := preload("res://scripts/core/game_manager.gd")
const TEST_SAVE_DIR := "user://test_saves"

var _failures := 0
var _checks := 0


func _init() -> void:
	_test_new_career()
	_test_work()
	_test_songs()
	_test_albums()
	_test_releases_and_week()
	_test_album_tracks()
	_test_save_load()
	_test_corrupt_save()
	_test_fmt()
	_clean_saves()
	print("%d verificações, %d falhas" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FALHOU: ", label)


func _make_game(money: int = 10000) -> Node:
	var game: Node = GameManagerScript.new()
	game.rng.seed = 42
	game.saves.save_dir = TEST_SAVE_DIR
	game.new_career("MC Teste")
	game.career.money = money
	return game


func _test_new_career() -> void:
	var game: Node = GameManagerScript.new()
	_check(not game.new_career("   ").ok, "nome vazio é rejeitado")
	_check(game.new_career(" Kid ").ok, "carreira criada")
	_check(game.career.artist_name == "Kid", "nome sem espaços")
	_check(game.career.money == 500 and game.career.fame == 0, "valores iniciais")
	_check(game.career.reputation == 0 and game.career.current_week == 1, "semana inicial")
	game.free()


func _test_work() -> void:
	var game := _make_game(0)
	var result: ActionResult = game.work_job(&"waiter")
	_check(result.ok and game.career.money == 250, "garçom paga $250")
	_check(game.career.current_week == 2, "trabalho consome a semana")
	_check(result.message == "Você trabalhou como Garçom.", "mensagem do trabalho")
	var last: FinanceEntry = game.career.finance_history.back()
	_check(last.amount == 250 and last.description == "Trabalho como Garçom", "histórico do trabalho")
	var report: WeekReport = result.value
	_check(report.week == 2 and report.total_money() == 250, "trabalho no relatório")
	_check(not game.work_job(&"nao_existe").ok, "trabalho inválido")
	_check(game.career.current_week == 2, "trabalho inválido não passa a semana")
	game.free()


func _test_songs() -> void:
	var game := _make_game(150)
	_check(not game.create_song("  ").ok, "música sem nome")
	var result: ActionResult = game.create_song("Primeira")
	_check(result.ok and game.career.money == 50, "desconta produção")
	var song: SongData = game.career.songs[0]
	_check(song.quality >= 0 and song.quality <= 100, "nota na faixa")
	_check(song.status_label() == "Não lançada", "status inicial")
	_check(not game.create_song("Sem dinheiro").ok, "sem dinheiro não produz")
	_check(game.career.money == 50 and game.career.songs.size() == 1, "falha não altera estado")
	game.free()


func _test_albums() -> void:
	var game := _make_game()
	for i in 4:
		game.create_song("Faixa %d" % i)
	var ids: Array[String] = [game.career.songs[0].id, game.career.songs[1].id, game.career.songs[2].id]
	var money_before: int = game.career.money
	_check(game.create_album("Disco", &"ep", ids).ok, "álbum criado")
	var album: AlbumData = game.career.albums[0]
	_check(album.song_ids.size() == 3 and album.production_cost == 160, "dados do projeto")
	_check(game.career.money == money_before - 160, "desconta projeto")
	_check(game.albums.available_songs(game.career).size() == 1, "faixas usadas saem da lista")
	_check(not game.create_album("Repetido", &"ep", ids).ok, "música usada em dois álbuns")
	var duplicated: Array[String] = [game.career.songs[3].id, game.career.songs[3].id, game.career.songs[3].id]
	_check(not game.create_album("Duplicado", &"ep", duplicated).ok, "faixa repetida")
	game.free()


func _test_releases_and_week() -> void:
	var game := _make_game()
	game.create_song("Hit")
	var song: SongData = game.career.songs[0]
	var empty_report: WeekReport = game.next_week()
	_check(empty_report.entries.is_empty(), "música não lançada não rende")

	var money_before: int = game.career.money
	_check(game.release_content(song.id).ok, "lançamento")
	_check(song.is_released() and song.release_week == 2, "semana do lançamento")
	_check(song.status_label() == "Lançada", "status lançada")
	_check(game.career.money == money_before - 50, "custo de lançamento")
	_check(not game.release_content(song.id).ok, "não lança duas vezes")

	var fame_before: int = game.career.fame
	money_before = game.career.money
	var report: WeekReport = game.next_week()
	var entry: WeekReportEntry = report.entries[0]
	_check(report.week == 3 and entry.streams > 0, "gera streams")
	_check(game.career.money == money_before + report.total_money(), "dinheiro do relatório")
	_check(game.career.fame == fame_before + report.total_fame(), "fama do relatório")
	_check(entry.money == roundi(entry.streams * 0.01), "dinheiro baseado em streams")
	_check(game.career.find_release(song.id).total_streams == entry.streams, "acumulado do lançamento")
	_check(game.career.last_report() == report, "relatório registrado")

	var rules := PerformanceRules.new()
	rules.units_min = 1000
	rules.units_max = 1000
	var first: PerformanceSystem.Result = game.performance.calculate_week(rules, 50, 0, 0)
	var later: PerformanceSystem.Result = game.performance.calculate_week(rules, 50, 5, 0)
	var ancient: PerformanceSystem.Result = game.performance.calculate_week(rules, 50, 500, 0)
	_check(first.units == 1000, "fatores neutros")
	_check(later.units < first.units, "desempenho cai com o tempo")
	_check(ancient.units == 100, "piso de idade")
	_check(game.performance.reputation_change(60) == 1, "reputação sobe")
	_check(game.performance.reputation_change(40) == -1, "reputação desce")
	game.free()


func _test_album_tracks() -> void:
	var game := _make_game()
	var ids: Array[String] = []
	for i in 3:
		game.create_song("Faixa %d" % i)
		ids.append(game.career.songs[i].id)
	game.release_content(ids[0])
	game.create_album("Disco", &"ep", ids)
	var album: AlbumData = game.career.albums[0]
	_check(game.releases.unreleased_content(game.career).size() == 3, "pendentes: 2 faixas + álbum")
	_check(game.release_content(album.id).ok, "álbum lançado")
	_check(album.status_label() == "Lançado" and album.release_week == 1, "status do álbum")
	_check(game.career.find_song(ids[1]).is_released(), "faixa sai com o álbum")
	_check(game.releases.unreleased_content(game.career).is_empty(), "nada pendente")
	_check(game.career.releases.size() == 2, "só single e álbum geram lançamento")
	var report: WeekReport = game.next_week()
	_check(report.entries.size() == 2, "single e álbum no relatório")
	_check(report.entries[1].sales > 0 and report.entries[1].streams == 0, "álbum gera vendas")
	game.free()


func _test_save_load() -> void:
	_clean_saves()
	var game := _make_game()
	_check(not game.has_save(), "sem save inicial")
	_check(not game.load_game().ok, "carregar sem save falha")
	var ids: Array[String] = []
	for i in 3:
		game.create_song("Faixa \"%d\" ç" % i)
		ids.append(game.career.songs[i].id)
	game.create_album("Disco", &"ep", ids)
	game.release_content(game.career.albums[0].id)
	game.work_job(&"delivery")
	_check(game.save_game().ok, "salvar")
	_check(game.save_game().ok, "salvar por cima")
	var expected: Dictionary = game.career.to_dict()
	game.create_song("Depois do save")
	game.career.money = 1

	_check(game.load_game().ok, "carregar")
	var career: CareerData = game.career
	_check(JSON.stringify(career.to_dict()) == JSON.stringify(expected), "save idêntico à carreira")
	_check(career.songs.size() == 3 and career.albums[0].song_ids.size() == 3, "listas restauradas")
	_check(career.money is int and career.songs[0].quality is int, "números continuam inteiros")
	_check(game.work_job(&"delivery").ok, "continua jogando")
	_check(game.create_song("Nova").ok and game.career.songs.back().id != ids[0], "ids não repetem")
	game.free()


func _test_corrupt_save() -> void:
	var game := _make_game()
	game.save_game()
	var file := FileAccess.open(TEST_SAVE_DIR.path_join("career.json"), FileAccess.WRITE)
	file.store_string("{ quebrado")
	file.close()
	var career_before: CareerData = game.career
	_check(not game.load_game().ok, "save corrompido é recusado")
	_check(game.career == career_before, "carreira atual preservada")
	game.free()


func _test_fmt() -> void:
	_check(Fmt.number(5430) == "5.430", "milhar")
	_check(Fmt.number(1234567) == "1.234.567", "milhão")
	_check(Fmt.number(999) == "999", "centena")
	_check(Fmt.money(-100) == "-$100", "negativo")
	_check(Fmt.signed_money(250) == "+$250", "positivo")


func _clean_saves() -> void:
	if not DirAccess.dir_exists_absolute(TEST_SAVE_DIR):
		return
	for file_name in DirAccess.get_files_at(TEST_SAVE_DIR):
		DirAccess.remove_absolute(TEST_SAVE_DIR.path_join(file_name))
	DirAccess.remove_absolute(TEST_SAVE_DIR)
