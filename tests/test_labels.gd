extends SceneTree
## Testes do sistema de gravadoras, sem interface. Para rodar:
##   godot --headless --path . --script res://tests/test_labels.gd

const GameManagerScript := preload("res://scripts/core/game_manager.gd")
const TEST_SAVE_DIR := "user://test_saves_labels"
const V11_FIXTURE := "res://tests/fixtures/save_v11.json"

var _failures := 0
var _checks := 0


func _init() -> void:
	_clean_saves()
	_test_catalog_of_labels()
	_test_independent_by_default()
	_test_offers_follow_the_career()
	_test_decline_and_stay_independent()
	_test_accept_and_revenue_split()
	_test_label_pays_part_of_costs()
	_test_discovery_and_shows()
	_test_release_split_end_to_end()
	_test_terminate()
	_test_contract_end_and_renewal()
	_test_create_own_label()
	_test_own_label_artists_and_money()
	_test_own_label_growth()
	_test_catalog()
	_test_save_load_and_careers()
	_test_v11_migration()
	_clean_saves()
	print("%d verificações, %d falhas" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FALHOU: ", label)


func _game(artist: String = "MC Selo") -> Node:
	var game: Node = GameManagerScript.new()
	game.rng.seed = 77
	game.saves.save_dir = TEST_SAVE_DIR
	game.new_career(artist)
	return game


## Uma proposta montada com os termos da gravadora, entregue à carreira.
func _give_offer(game: Node, label_id: String) -> LabelOffer:
	var offer: LabelOffer = game.labels.build_offer(game.career, game.labels.find_label(label_id))
	game.career.label.offers.append(offer)
	return offer


# ---- testes

func _test_catalog_of_labels() -> void:
	var game := _game()
	var rules: LabelRules = game.labels.rules()
	var tiers := {}
	var previous_fame := -1
	for label in rules.labels:
		tiers[label.tier] = true
		_check(label.artist_share > 0.3 and label.artist_share < 0.95, "%s: parte do artista razoável" % label.id)
		_check(not label.roster.is_empty() and label.contract_weeks > 0, "%s: elenco e duração" % label.id)
		for artist_id in label.roster:
			_check(game.social.person(artist_id) != null, "%s: %s existe no jogo" % [label.id, artist_id])
	for tier in ["underground", "indie", "medium", "big", "major"]:
		_check(tiers.has(tier), "há gravadora %s" % tier)
	# Quanto maior a gravadora, maior o adiantamento e menor a parte do artista.
	var porao: LabelDefinition = game.labels.find_label("porao")
	var orbita: LabelDefinition = game.labels.find_label("orbita")
	_check(orbita.base_advance > porao.base_advance * 50 and orbita.artist_share < porao.artist_share, "major paga mais e fica com mais")
	_check(rules.levels.size() == 4 and rules.levels[3].max_artists > rules.levels[0].max_artists, "níveis da gravadora própria")
	# Contratar precisa valer a pena: em média, a parte da gravadora menos o salário paga a contratação
	# antes do fim do contrato (sem contar os lançamentos, que só ajudam).
	var weekly_net := rules.artist_weekly_revenue_rate * rules.label_share_of_artists - rules.artist_weekly_cost_rate
	_check(weekly_net * rules.signed_contract_weeks > rules.signing_fee_factor, "contratação se paga dentro do contrato")
	_check(weekly_net * rules.signed_contract_weeks < rules.signing_fee_factor * 3.0, "mas não é dinheiro fácil")
	game.free()


func _test_independent_by_default() -> void:
	var game := _game()
	var career: CareerData = game.career
	_check(game.labels.mode(career) == LabelData.MODE_INDEPENDENT, "carreira nova é independente")
	var money := career.money
	game.economy.earn(career, 1000, "Streams: teste", FinanceEntry.CATEGORY_STREAMS)
	_check(career.money == money + 1000, "independente recebe 100% dos streams")
	_check(game.streaming.label_discovery_bonus(career) == 0.0, "sem bônus de alcance")
	game.free()


func _test_offers_follow_the_career() -> void:
	var game := _game()
	var career: CareerData = game.career
	career.fame = 0
	_check(game.labels.interested(career).all(func(label: LabelDefinition) -> bool: return label.min_fame == 0), "no começo só selos underground olham")
	career.fame = 12000
	_check(game.labels.interested(career).size() == game.labels.rules().labels.size(), "estrela interessa a todas")
	var porao: LabelDefinition = game.labels.find_label("porao")
	var low: float = game.labels.market_score(career, porao)
	career.reputation = 50
	_check(game.labels.market_score(career, porao) > low, "reputação aumenta o interesse")
	var weeks := 0
	while career.label.offers.is_empty() and weeks < 80:
		game.next_week()
		weeks += 1
	_check(not career.label.offers.is_empty(), "propostas chegam com o tempo (%d semanas)" % weeks)
	_check(career.label.offers.size() <= game.labels.rules().max_pending_offers, "limite de propostas pendentes")
	var offer: LabelOffer = career.label.offers[0]
	_check(offer.advance > 0 and offer.expires_week > offer.week and offer.weeks > 0, "proposta tem adiantamento, validade e duração")
	# Propostas vencem se ninguém responder.
	career.current_week = offer.expires_week + 1
	game.labels.process_week(career, WeekReport.new())
	_check(career.label.find_offer(offer.id) == null, "proposta vencida some")
	game.free()


func _test_decline_and_stay_independent() -> void:
	var game := _game()
	var offer := _give_offer(game, "nova_rota")
	var result: ActionResult = game.decline_label_offer(offer.id)
	_check(result.ok and game.career.label.offers.is_empty(), "recusa remove a proposta")
	_check(game.labels.mode(game.career) == LabelData.MODE_INDEPENDENT and game.career.label.contract == null, "segue independente")
	_check(game.career.label.history[-1]["text"].contains("Recusou"), "recusa no histórico")
	game.free()


func _test_accept_and_revenue_split() -> void:
	var game := _game()
	var career: CareerData = game.career
	career.fame = 300
	var offer := _give_offer(game, "nova_rota")
	_give_offer(game, "porao")
	var money := career.money
	var result: ActionResult = game.accept_label_offer(offer.id)
	_check(result.ok and game.labels.mode(career) == LabelData.MODE_SIGNED, "aceitar assina o contrato")
	var contract: LabelContract = career.label.contract
	_check(career.money == money + offer.advance and career.finance_history[-1].category == FinanceEntry.CATEGORY_LABEL, "adiantamento entra nas finanças")
	_check(contract.end_week == career.current_week + offer.weeks and contract.recoup_left == offer.advance, "contrato com prazo e adiantamento a recuperar")
	_check(career.label.offers.is_empty(), "outras propostas saem")
	_check(not game.accept_label_offer("label_offer_999").ok, "não assina duas vezes")
	# Receita de streams: a gravadora fica com a parte dela e a parte do artista paga o adiantamento.
	money = career.money
	game.economy.earn(career, 10000, "Streams: Hit", FinanceEntry.CATEGORY_STREAMS)
	var label_cut := roundi(10000 * (1.0 - offer.artist_share))
	var artist_part := 10000 - label_cut
	var recoup := mini(offer.advance, artist_part)
	_check(career.money == money + artist_part - recoup, "artista recebe a parte dele menos o adiantamento")
	_check(contract.label_total == label_cut and contract.recoup_left == offer.advance - recoup, "gravadora e adiantamento contabilizados")
	_check(career.finance_history[-1].description.contains("gravadora"), "histórico mostra a divisão")
	# Quitado o adiantamento, o artista recebe a parte inteira.
	contract.recoup_left = 0
	money = career.money
	game.economy.earn(career, 10000, "Vendas digitais: Hit", FinanceEntry.CATEGORY_SALES)
	_check(career.money == money + artist_part, "depois de quitar, só a divisão")
	money = career.money
	game.economy.earn(career, 5000, "Show: Teste", FinanceEntry.CATEGORY_LIVE)
	_check(career.money == money + 5000, "shows não são divididos")
	game.free()


func _test_label_pays_part_of_costs() -> void:
	var game := _game()
	var career: CareerData = game.career
	career.money = 100000
	var offer := _give_offer(game, "mare_alta")
	game.accept_label_offer(offer.id)
	var contract: LabelContract = career.label.contract
	var money := career.money
	game.economy.spend(career, 2000, "Marketing: teste", FinanceEntry.CATEGORY_MARKETING)
	var covered := roundi(2000 * offer.marketing_support)
	_check(career.money == money - (2000 - covered) and contract.budget_left == offer.budget - covered, "gravadora paga parte do marketing")
	money = career.money
	game.economy.spend(career, 1000, "Produção: teste", FinanceEntry.CATEGORY_PRODUCTION)
	_check(career.money == money - 1000, "produção não tem ajuda")
	contract.budget_left = 100
	money = career.money
	game.economy.spend(career, 2000, "Videoclipe: teste", FinanceEntry.CATEGORY_VIDEO)
	_check(career.money == money - 1900 and contract.budget_left == 0, "ajuda limitada ao orçamento")
	game.free()


func _test_discovery_and_shows() -> void:
	var game := _game()
	var career: CareerData = game.career
	var offer := _give_offer(game, "coroa")
	game.accept_label_offer(offer.id)
	_check(is_equal_approx(game.streaming.label_discovery_bonus(career), offer.discovery_bonus), "contrato dá alcance nas plataformas")
	_check(is_equal_approx(game.live._label_show_bonus(career), offer.show_bonus), "contrato dá mais propostas de show")
	game.free()


## Um lançamento de verdade: as semanas de streams passam pela divisão do contrato.
func _test_release_split_end_to_end() -> void:
	var game := _game()
	var career: CareerData = game.career
	career.money = 500000
	career.fame = 400
	var offer := _give_offer(game, "nova_rota")
	game.accept_label_offer(offer.id)
	var song: SongData = game.create_song("Selo Hit").value
	game.release_content(song.id)
	for i in 3:
		game.next_week()
	var contract: LabelContract = career.label.contract
	_check(contract.gross_total > 0 and contract.label_total > 0, "streams do lançamento divididos com a gravadora")
	var split_entries := career.finance_history.filter(func(entry: FinanceEntry) -> bool: return entry.category == FinanceEntry.CATEGORY_STREAMS and entry.description.contains("gravadora"))
	_check(not split_entries.is_empty(), "finanças mostram bruto e parte da gravadora")
	_check(contract.covered_total > 0, "gravadora pagou parte do lançamento")
	game.free()


func _test_terminate() -> void:
	var game := _game()
	var career: CareerData = game.career
	var offer := _give_offer(game, "atlas")
	game.accept_label_offer(offer.id)
	var fee: int = game.labels.termination_fee(career)
	_check(fee == offer.advance + roundi(offer.advance * game.labels.rules().termination_fee_rate), "multa = adiantamento a recuperar + taxa")
	career.money = fee - 1
	_check(not game.terminate_label_contract().ok and game.labels.mode(career) == LabelData.MODE_SIGNED, "sem dinheiro não rescinde")
	career.money = fee + 10
	_check(game.terminate_label_contract().ok and career.money == 10 and game.labels.mode(career) == LabelData.MODE_INDEPENDENT, "rescisão paga e volta a ser independente")
	_check(career.label.contract.status == LabelContract.STATUS_TERMINATED and int(career.label.periods[-1]["to"]) == career.current_week, "contrato e período encerrados")
	game.free()


func _test_contract_end_and_renewal() -> void:
	var game := _game()
	var career: CareerData = game.career
	var offer := _give_offer(game, "porao")
	offer.weeks = 2
	game.accept_label_offer(offer.id)
	career.label.contract.recoup_left = 0
	game.next_week()
	_check(game.labels.mode(career) == LabelData.MODE_SIGNED, "contrato vale até o fim")
	var report: WeekReport = game.next_week()
	_check(game.labels.mode(career) == LabelData.MODE_INDEPENDENT and career.label.contract.status == LabelContract.STATUS_ENDED, "contrato termina no prazo")
	var renewal: LabelOffer = career.label.offers[0] if not career.label.offers.is_empty() else null
	_check(renewal != null and renewal.renewal and renewal.label_id == "porao", "gravadora propõe renovar")
	_check(renewal != null and renewal.artist_share > game.labels.find_label("porao").artist_share, "renovação melhora a parte do artista quando o adiantamento foi pago")
	_check(report.entries.any(func(entry: WeekReportEntry) -> bool: return entry.title == "Contrato encerrado"), "relatório avisa o fim do contrato")
	game.free()


func _test_create_own_label() -> void:
	var game := _game()
	var career: CareerData = game.career
	var rules: LabelRules = game.labels.rules()
	career.fame = rules.creation_min_fame - 1
	career.money = rules.creation_cost
	_check(not game.create_label("Selo X", "SX", "hex", Color.RED, Color.WHITE).ok, "precisa de fama")
	career.fame = rules.creation_min_fame
	career.money = rules.creation_cost - 1
	_check(not game.create_label("Selo X", "SX", "hex", Color.RED, Color.WHITE).ok and career.label.own == null, "precisa de dinheiro")
	var offer := _give_offer(game, "porao")
	game.accept_label_offer(offer.id)
	career.money = rules.creation_cost * 2
	_check(not game.create_label("Selo X", "SX", "hex", Color.RED, Color.WHITE).ok, "não abre gravadora durante contrato")
	career.label.contract.status = LabelContract.STATUS_TERMINATED
	career.money = rules.creation_cost
	var result: ActionResult = game.create_label("Casa do Corre", "", "shield", Color.RED, Color.WHITE)
	var own: OwnLabel = career.label.own
	_check(result.ok and game.labels.mode(career) == LabelData.MODE_OWNER, "fundar gravadora")
	_check(career.money == 0 and own.balance == roundi(rules.creation_cost * LabelSystem.STARTING_BALANCE_RATE), "custo pago e caixa inicial")
	_check(own.short == "CDC" and own.shape == "shield" and own.level == 0, "sigla automática e identidade")
	_check(not game.create_label("Outra", "O", "circle", Color.RED, Color.WHITE).ok, "uma gravadora por carreira")
	_check(is_equal_approx(game.streaming.label_discovery_bonus(career), rules.levels[0].reach_bonus), "selo próprio dá alcance do nível")
	var money := career.money
	game.economy.earn(career, 1000, "Streams: meu selo", FinanceEntry.CATEGORY_STREAMS)
	_check(career.money == money + 1000, "dono recebe 100% das próprias receitas")
	game.free()


func _test_own_label_artists_and_money() -> void:
	var game := _game()
	var career: CareerData = game.career
	career.fame = 2000
	career.money = 2000000
	game.create_label("Casa do Corre", "CC", "circle", Color.RED, Color.WHITE)
	var own: OwnLabel = career.label.own
	_check(game.label_deposit(500000).ok and own.balance == roundi(game.labels.rules().creation_cost * LabelSystem.STARTING_BALANCE_RATE) + 500000, "depósito vai para o caixa")
	_check(career.finance_history[-1].category == FinanceEntry.CATEGORY_LABEL, "depósito nas finanças da carreira")
	var signable: Array = game.labels.signable_artists(career)
	var taken: Array = []
	for label in game.labels.rules().labels:
		taken.append_array(label.roster)
	_check(signable.all(func(person: CollaboratorDefinition) -> bool: return not String(person.id) in taken), "artistas de outras gravadoras não aparecem")
	var cheap: CollaboratorDefinition = signable[0]
	var fee: int = game.labels.signing_fee(career, String(cheap.id))
	var before := own.balance
	_check(game.sign_label_artist(String(cheap.id)).ok and own.balance == before - fee and own.artists.size() == 1, "contratação sai do caixa")
	_check(not game.sign_label_artist(String(cheap.id)).ok, "não contrata o mesmo artista duas vezes")
	_check(game.labels.label_of_artist(career, String(cheap.id)) == own.name, "artista passa a ser da gravadora")
	# Amizade barateia; rivalidade impede.
	var friend: CollaboratorDefinition = signable[1]
	var base_fee: int = game.labels.signing_fee(career, String(friend.id))
	var relation: Relationship = game.social.relation(career, String(friend.id))
	relation.met = true
	relation.value = 60
	_check(game.labels.signing_fee(career, String(friend.id)) < base_fee, "amigo faz desconto")
	relation.value = -40
	_check(not game.labels.sign_block(career, String(friend.id)).is_empty(), "rival recusa")
	relation.value = 0
	game.sign_label_artist(String(friend.id))
	_check(not game.labels.sign_block(career, String(signable[2].id)).is_empty(), "limite de artistas do nível")
	# Uma semana: faturamento e salários no livro-caixa.
	var ledger_size := own.ledger.size()
	game.next_week()
	var income := own.ledger.slice(ledger_size).filter(func(entry: Dictionary) -> bool: return entry["category"] == "revenue")
	var payroll := own.ledger.slice(ledger_size).filter(func(entry: Dictionary) -> bool: return entry["category"] == "payroll")
	_check(not income.is_empty() and not payroll.is_empty(), "receitas e salários semanais")
	_check(own.artists[0].revenue_total > 0 and own.reputation > 0, "artistas rendem e a gravadora ganha reputação")
	var totals := own.totals()
	_check(totals["income"] > 0 and totals["expenses"] > 0 and totals["profit"] == totals["income"] - totals["expenses"], "receitas, despesas e lucro")
	_check(not game.label_withdraw(own.balance + 1).ok, "não saca mais que o caixa")
	var money := career.money
	_check(game.label_withdraw(1000).ok and career.money == money + 1000, "saque volta para o artista")
	_check(game.release_label_artist(String(cheap.id)).ok and own.artists.size() == 1, "liberar artista")
	game.free()


func _test_own_label_growth() -> void:
	var game := _game()
	var career: CareerData = game.career
	career.fame = 2000
	career.money = 5000000
	game.create_label("Casa", "C", "circle", Color.RED, Color.WHITE)
	var own: OwnLabel = career.label.own
	var next: LabelLevelDefinition = game.labels.next_level(career)
	game.label_deposit(next.upgrade_cost)
	_check(not game.upgrade_label().ok, "expansão pede reputação")
	own.reputation = next.min_reputation
	var before := own.balance
	_check(game.upgrade_label().ok and own.level == 1 and own.balance == before - next.upgrade_cost, "expansão paga com o caixa")
	_check(game.labels.level(career).max_artists == next.max_artists, "mais vagas")
	_check(is_equal_approx(game.streaming.label_discovery_bonus(career), next.reach_bonus), "mais alcance")
	game.free()


func _test_catalog() -> void:
	var game := _game()
	var career: CareerData = game.career
	career.money = 500000
	var before_song: SongData = game.create_song("Antes do selo").value
	game.release_content(before_song.id)
	game.next_week()
	var offer := _give_offer(game, "porao")
	game.accept_label_offer(offer.id)
	var song: SongData = game.create_song("Pelo selo").value
	game.release_content(song.id)
	var catalog: Array = game.labels.player_catalog(career)
	_check(catalog.size() == 1 and catalog[0]["title"] == "Pelo selo" and catalog[0]["label"] == "Porão Records", "catálogo só com o que saiu pelo selo")
	game.free()


func _test_save_load_and_careers() -> void:
	_clean_saves()
	var game := _game("Contratado")
	var career: CareerData = game.career
	var offer := _give_offer(game, "mare_alta")
	game.accept_label_offer(offer.id)
	game.economy.earn(career, 5000, "Streams: x", FinanceEntry.CATEGORY_STREAMS)
	var first: String = game.saves.new_slot_id()
	game.current_slot = first
	game.save_game()
	var expected: Dictionary = career.label.to_dict()
	var other := _game("Dono")
	other.career.fame = 2000
	other.career.money = 1000000
	other.create_label("Outro Selo", "OS", "hex", Color.BLUE, Color.WHITE)
	other.current_slot = first + "_b"
	other.save_game()
	var reloaded: Node = GameManagerScript.new()
	reloaded.saves.save_dir = TEST_SAVE_DIR
	_check(reloaded.load_game(first).ok, "carrega carreira contratada")
	_check(JSON.stringify(reloaded.career.label.to_dict()) == JSON.stringify(expected), "contrato, totais e histórico salvos")
	_check(reloaded.career.label.own == null, "selo da outra carreira não vaza")
	_check(reloaded.load_game(first + "_b").ok and reloaded.career.label.own != null and reloaded.career.label.contract == null, "dono carregado com a própria gravadora")
	reloaded.free()
	other.free()
	game.free()


func _test_v11_migration() -> void:
	_clean_saves()
	DirAccess.make_dir_recursive_absolute(TEST_SAVE_DIR)
	var save_path := TEST_SAVE_DIR.path_join("career.json")
	var fixture_text := FileAccess.get_file_as_string(V11_FIXTURE)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(fixture_text)
	file.close()
	var old: Dictionary = JSON.parse_string(fixture_text)["career"]
	_check(int(JSON.parse_string(fixture_text)["version"]) == 11, "fixture é v11")
	var game: Node = GameManagerScript.new()
	game.saves.save_dir = TEST_SAVE_DIR
	_check(game.load_game(SaveSystem.DEFAULT_SLOT).ok, "carrega save v11 real")
	var career: CareerData = game.career
	_check(career.money == int(old["money"]) and career.songs.size() == old["songs"].size() and career.vehicles.size() == old["vehicles"].size(), "progresso mantido")
	_check(game.labels.mode(career) == LabelData.MODE_INDEPENDENT and career.label.offers.is_empty(), "começa independente")
	_check(FileAccess.get_file_as_string(save_path + ".v11.bak") == fixture_text, "cópia do save v11 guardada")
	_check(game.save_game().ok and int(JSON.parse_string(FileAccess.get_file_as_string(save_path))["version"]) == SaveSystem.SAVE_VERSION, "salva no formato novo")
	game.free()


func _clean_saves() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.dir_exists("test_saves_labels"):
		var saves := DirAccess.open(TEST_SAVE_DIR)
		for name in saves.get_files():
			saves.remove(name)
		dir.remove("test_saves_labels")
