extends SceneTree
## Testes de shows, turnês, festivais e merchandising, sem interface. Para rodar:
##   godot --headless --path . --script res://tests/test_live.gd

const GameManagerScript := preload("res://scripts/core/game_manager.gd")
const TEST_SAVE_DIR := "user://test_saves_live"
const V6_FIXTURE := "res://tests/fixtures/save_v6.json"

var _failures := 0
var _checks := 0


func _init() -> void:
	_clean_saves()
	_test_catalog()
	_test_data_survives_export()
	_test_offers()
	_test_independent_show_risk()
	_test_ticket_price_and_no_guaranteed_sellout()
	_test_financial_models()
	_test_contracted_expenses()
	_test_production_and_crew()
	_test_guests()
	_test_calendar_conflicts()
	_test_tour_flow()
	_test_tour_travel_and_fatigue()
	_test_tour_pause_and_cancel()
	_test_sponsors()
	_test_merch()
	_test_festival_editions()
	_test_festival_invitation_and_impact()
	_test_festival_application()
	_test_show_report()
	_test_round_trip()
	_test_v6_migration()
	_test_long_run_economy()
	_clean_saves()
	print("%d verificações, %d falhas" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FALHOU: ", label)


func _make_game(money: int = 100000000, fame: int = 0, seed_value: int = 51) -> Node:
	var game: Node = GameManagerScript.new()
	game.rng.seed = seed_value
	game.saves.save_dir = TEST_SAVE_DIR
	game.new_career("MC Teste")
	game.career.money = money
	game.career.fame = fame
	game.balance.streaming.leak_chance_per_week = 0.0
	game.balance.videos.leak_chance_per_week = 0.0
	return game


func _restore(game: Node) -> void:
	game.balance.streaming.leak_chance_per_week = 0.02
	game.balance.videos.leak_chance_per_week = 0.03
	game.free()


func _show(game: Node, city_id: String = "sao_paulo", venue_id: String = "bar", week_offset: int = 2, weekday: int = 5) -> LiveShow:
	var live: LiveSystem = game.live
	var show := live.new_show(game.career, LiveShow.KIND_INDEPENDENT)
	live.apply_venue(show, city_id, venue_id)
	show.ticket_price = game.balance.live.find_venue(venue_id).base_ticket_price
	show.day = live.first_day_of_week(game.career.current_week + week_offset) + weekday - 1
	return show


func _offers(game: Node) -> Array[LiveShow]:
	return game.live.shows_with_status(game.career, LiveShow.STATUS_OFFER)


func _contracted_offer(game: Node) -> LiveShow:
	for i in 30:
		for offer in _offers(game):
			if offer.kind == LiveShow.KIND_CONTRACTED:
				return offer
		game.live.generate_offers(game.career)
	return null


func _weeks(game: Node, count: int) -> void:
	for i in count:
		game.next_week()


func _feat_id(game: Node, index: int) -> String:
	var feats: Array = game.balance.collaborators.feats
	var sorted := feats.duplicate()
	sorted.sort_custom(func(a: CollaboratorDefinition, b: CollaboratorDefinition) -> bool: return a.cost > b.cost)
	return String(sorted[index].id)


# ---- testes

func _test_catalog() -> void:
	var game := _make_game()
	var rules: LiveRules = game.balance.live
	_check(rules.venues.size() == 8, "8 categorias de local")
	_check(rules.find_venue("bar").min_capacity == 50 and rules.find_venue("stadium").min_capacity >= 40000, "capacidades de bar a estádio")
	_check(rules.production_levels.size() == 5, "5 níveis de produção")
	_check(rules.crew_roles.size() >= 11, "funções da equipe")
	_check(rules.tour_types.size() == 8, "8 tipos de turnê")
	_check(rules.festivals.size() >= 6, "festivais cadastrados")
	_check(rules.merch_products.size() >= 10, "produtos de merch")
	_check(rules.find_city(rules.home_city_id) != null, "cidade natal existe")
	for festival in rules.festivals:
		_check(rules.find_city(festival.city_id) != null, "cidade do festival existe: %s" % festival.id)
	_restore(game)


## Listas de texto gravadas como PackedStringArray nos .tres chegam vazias no .exe exportado
## (funcionam no editor). Os dados usam Array[String].
func _test_data_survives_export() -> void:
	for file_name in DirAccess.get_files_at("res://data"):
		if file_name.ends_with(".tres"):
			var text := FileAccess.get_file_as_string("res://data".path_join(file_name))
			_check(not "PackedStringArray(" in text, "sem PackedStringArray em %s" % file_name)


func _test_offers() -> void:
	var game := _make_game(100000, 50)
	game.live.generate_offers(game.career)
	var offer := _contracted_offer(game)
	_check(offer != null, "ofertas aparecem")
	if offer == null:
		_restore(game)
		return
	_check(offer.capacity > 0 and offer.week() > game.career.current_week, "oferta com capacidade e data futura")
	_check(not offer.event_name.is_empty() and not offer.venue_name.is_empty(), "oferta com evento e local")
	var projection: Dictionary = game.live.estimate(game.career, offer)
	_check(projection.has("profit") and projection.has("merch_net") and projection.has("total_expenses"), "oferta mostra lucro, merch e despesas estimados")
	var money_before: int = game.career.money
	var accepted: ActionResult = game.accept_offer(offer.id, null)
	_check(accepted.ok, "aceita oferta")
	_check(offer.status == LiveShow.STATUS_SCHEDULED, "oferta aceita vira show agendado")
	_check(game.career.money == money_before - offer.upfront_paid, "despesas do artista pagas ao aceitar")
	var other := _contracted_offer(game)
	if other != null and other != offer:
		_check(game.reject_offer(other.id).ok and game.career.find_live_show(other.id) == null, "recusa oferta")
	# Ofertas vencem.
	game.live.generate_offers(game.career)
	var pending := _offers(game)
	_weeks(game, game.balance.live.offer_expiry_weeks + 1)
	var expired := true
	for item in pending:
		if game.career.find_live_show(item.id) != null and item.status == LiveShow.STATUS_OFFER:
			expired = false
	_check(expired, "ofertas antigas vencem")
	_restore(game)


func _test_independent_show_risk() -> void:
	var game := _make_game(5000, 0)
	var big := _show(game, "sao_paulo", "arena")
	big.production_id = "big"
	var result: ActionResult = game.schedule_show(big)
	_check(not result.ok, "sem dinheiro não agenda show caro")
	game.career.money = 10000000
	result = game.schedule_show(big)
	_check(result.ok, "show independente não precisa de aprovação")
	var money_after_pay: int = game.career.money
	_weeks(game, 2)
	_check(big.status == LiveShow.STATUS_DONE, "show acontece na semana marcada")
	_check(big.result["occupancy"] < 50, "artista desconhecido não lota uma arena")
	_check(big.result["profit"] < 0, "show independente pode dar prejuízo")
	_check(game.career.money - money_after_pay == big.result["artist_income"] + big.result["merch_net"], "bilheteria entra no dia do show")
	var lines: Array = game.career.finance_history.filter(func(item: FinanceEntry) -> bool: return item.category == FinanceEntry.CATEGORY_LIVE)
	_check(lines.size() >= 2, "despesas e bilheteria no histórico financeiro")
	_restore(game)


func _test_ticket_price_and_no_guaranteed_sellout() -> void:
	var game := _make_game(10000000, 400)
	var live: LiveSystem = game.live
	var show := _show(game, "sao_paulo", "club")
	show.ticket_price = 10
	var cheap: Dictionary = live.estimate(game.career, show)
	show.ticket_price = 200
	var expensive: Dictionary = live.estimate(game.career, show)
	_check(cheap["sold"] > expensive["sold"], "ingresso caro vende menos")
	show.ticket_price = 10
	_check(cheap["sold"] <= show.capacity, "nunca vende mais que a capacidade")
	show.vip_enabled = true
	show.vip_price = 60
	var vip: Dictionary = live.estimate(game.career, show)
	_check(vip["vip_sold"] > 0, "VIP vende quando o local tem área VIP")
	_check(vip["ticket_fees"] == roundi(vip["gross"] * game.balance.live.ticket_fee_rate), "taxas sobre a bilheteria")
	_check(vip["net_box"] == vip["gross"] - vip["ticket_fees"], "bilheteria líquida")
	var unknown := _make_game(10000000, 0)
	var stadium := _show(unknown, "sao_paulo", "stadium")
	_check(unknown.live.estimate(unknown.career, stadium)["occupancy"] < 5, "lotação não é garantida")
	unknown.free()
	_restore(game)


func _test_financial_models() -> void:
	var game := _make_game(10000000, 300)
	var live: LiveSystem = game.live
	var show := _show(game, "sao_paulo", "hall")
	var incomes := {}
	for model in [LiveRules.MODEL_FIXED, LiveRules.MODEL_PERCENTAGE, LiveRules.MODEL_FEE_PLUS_PERCENTAGE, LiveRules.MODEL_GUARANTEE]:
		show.kind = LiveShow.KIND_CONTRACTED
		show.model = model
		live.apply_promoter_terms(game.career, show)
		var projection: Dictionary = live.estimate(game.career, show)
		incomes[model] = projection["income"]
		_check(not live.terms_text(show).is_empty(), "condições descritas: %s" % model)
	show.model = LiveRules.MODEL_FIXED
	show.fee = 1234
	_check(live.estimate(game.career, show)["income"] == 1234, "cachê fixo independe do público")
	show.model = LiveRules.MODEL_PERCENTAGE
	show.percentage = 0.5
	var projection: Dictionary = live.estimate(game.career, show)
	_check(absi(projection["income"] - roundi(projection["net_box"] * 0.5)) <= 1, "porcentagem da bilheteria")
	show.model = LiveRules.MODEL_FEE_PLUS_PERCENTAGE
	show.fee = 500
	_check(absi(live.estimate(game.career, show)["income"] - roundi(500 + projection["net_box"] * 0.5)) <= 1, "cachê + porcentagem")
	show.model = LiveRules.MODEL_GUARANTEE
	show.fee = 999999
	_check(live.estimate(game.career, show)["income"] == 999999, "garantia mínima protege o artista")
	show.fee = 1
	_check(absi(live.estimate(game.career, show)["income"] - roundi(projection["net_box"] * 0.5)) <= 1, "porcentagem vence a garantia baixa")
	_check(live.estimate(game.career, show)["commission"] > 0, "comissão em show contratado")
	_restore(game)


func _test_contracted_expenses() -> void:
	var game := _make_game(10000000, 300)
	var live: LiveSystem = game.live
	var show := _show(game, "recife", "club")
	show.kind = LiveShow.KIND_CONTRACTED
	show.model = LiveRules.MODEL_FIXED
	show.fee = 3000
	var paying: Dictionary = live.costs(game.career, show, {})
	_check(paying["travel"] > 0 and paying["lodging"] > 0, "artista paga viagem quando o contratante não cobre")
	_check(paying["rent"] == 0 and paying["security"] == 0, "contratante paga local e segurança")
	show.covers_travel = true
	show.covers_lodging = true
	var covered: Dictionary = live.costs(game.career, show, {})
	_check(covered["travel"] == 0 and covered["lodging"] == 0, "contratante cobre transporte e hospedagem")
	show.kind = LiveShow.KIND_INDEPENDENT
	show.model = LiveRules.MODEL_INDEPENDENT
	show.covers_travel = false
	show.covers_lodging = false
	var own: Dictionary = live.costs(game.career, show, {})
	_check(own["rent"] > 0 and own["security"] > 0, "show independente paga local e segurança")
	_restore(game)


func _test_production_and_crew() -> void:
	var game := _make_game(10000000, 500)
	var live: LiveSystem = game.live
	var show := _show(game, "sao_paulo", "hall")
	var basic: Dictionary = live.estimate(game.career, show)
	show.production_id = "professional"
	var pro: Dictionary = live.estimate(game.career, show)
	_check(pro["quality"] > basic["quality"] and pro["total_expenses"] > basic["total_expenses"], "produção melhor custa mais e melhora o show")
	show.addons = ["lighting", "screens"]
	var addons: Dictionary = live.estimate(game.career, show)
	_check(addons["quality"] > pro["quality"] and addons["expenses"]["addons"] > 0, "personalizações custam e melhoram")
	show.crew = {"sound_engineer": 2, "dj": 1}
	var crew: Dictionary = live.estimate(game.career, show)
	_check(crew["quality"] > addons["quality"] and crew["expenses"]["crew"] > 0, "equipe custa e melhora")
	show.crew = {"sound_engineer": 3, "dj": 1}
	_check(live.estimate(game.career, show)["expenses"]["crew"] > crew["expenses"]["crew"], "nível da equipe muda o custo")
	var big := _show(game, "sao_paulo", "arena")
	var unorganized: int = live.estimate(game.career, big)["quality"]
	big.crew = {"tour_manager": 2, "roadies": 2, "security": 2}
	_check(live.estimate(game.career, big)["quality"] > unorganized, "show grande sem equipe perde qualidade")
	_restore(game)


func _test_guests() -> void:
	var game := _make_game(10000000, 100)
	var live: LiveSystem = game.live
	var show := _show(game, "sao_paulo", "hall")
	var alone: Dictionary = live.estimate(game.career, show)
	show.guests = [{"artist_id": _feat_id(game, 0), "role": "special"}]
	var guest: Dictionary = live.estimate(game.career, show)
	_check(guest["sold"] > alone["sold"], "convidado popular atrai público")
	_check(guest["expenses"]["guests"] > 0, "convidado tem custo")
	show.guests = [{"artist_id": _feat_id(game, 0), "role": "co_headliner"}]
	var co: Dictionary = live.estimate(game.career, show)
	_check(co["co_share"] > 0, "co-headliner divide a receita")
	_restore(game)


func _test_calendar_conflicts() -> void:
	var game := _make_game()
	var first := _show(game, "sao_paulo", "bar", 3, 5)
	_check(game.schedule_show(first).ok, "primeiro show agendado")
	var same_day := _show(game, "sao_paulo", "club", 3, 5)
	_check(not game.schedule_show(same_day).ok, "não marca dois shows no mesmo dia")
	var far := _show(game, "toquio", "club", 3, 6)
	_check(not game.schedule_show(far).ok, "sem tempo de viagem entre cidades distantes")
	var next_day := _show(game, "sao_paulo", "club", 3, 6)
	_check(game.schedule_show(next_day).ok, "mesma cidade no dia seguinte")
	var past := _show(game, "sao_paulo", "club", 0, 3)
	_check(not game.schedule_show(past).ok, "não agenda no passado")
	_restore(game)


func _tour_with_dates(game: Node, cities: Array, types: Array[String] = ["national"], gap: int = 2) -> LiveTour:
	var tour: LiveTour = game.create_tour("Turnê Teste", "Crescer", "", types, "").value
	var day: int = game.live.first_day_of_week(game.career.current_week + 2) + 4
	for city_id: String in cities:
		var show: LiveShow = game.live.new_show(game.career, LiveShow.KIND_TOUR)
		game.live.apply_venue(show, city_id, "club")
		show.ticket_price = 25
		show.day = day
		var saved: ActionResult = game.save_tour_date(tour.id, show)
		_check(saved.ok, "data salva em %s" % city_id)
		day += gap
	return tour


func _test_tour_flow() -> void:
	var game := _make_game(10000000, 600)
	var created: ActionResult = game.create_tour("", "", "", [] as Array[String], "")
	_check(not created.ok, "turnê precisa de nome e tipo")
	var tour := _tour_with_dates(game, ["sao_paulo", "rio", "belo_horizonte"], ["regional", "national"])
	_check(tour.status == LiveTour.STATUS_PLANNING, "turnê começa em planejamento")
	_check(tour.types.size() == 2, "tipos combinados")
	var forecast: Dictionary = game.tours.forecast(game.career, tour)
	_check(forecast["shows"] == 3 and forecast["cities"] == 3, "previsão conta datas e cidades")
	_check(forecast["upfront"] > 0 and forecast.has("profit"), "previsão mostra custos e lucro")
	var money_before: int = game.career.money
	_check(game.confirm_tour(tour.id).ok, "confirma turnê")
	_check(tour.status == LiveTour.STATUS_CONFIRMED, "turnê confirmada")
	_check(game.career.money == money_before - forecast["upfront"], "despesas das datas pagas na confirmação")
	_check(not game.confirm_tour(tour.id).ok, "não confirma duas vezes")
	var draft: LiveShow = game.live.new_show(game.career, LiveShow.KIND_TOUR)
	_check(not game.save_tour_date(tour.id, draft).ok, "turnê confirmada não recebe datas")
	_weeks(game, 3)
	_check(tour.status == LiveTour.STATUS_IN_PROGRESS or tour.status == LiveTour.STATUS_COMPLETED, "turnê em andamento")
	_weeks(game, 3)
	_check(tour.status == LiveTour.STATUS_COMPLETED, "turnê concluída")
	var report: Dictionary = game.tours.tour_report(game.career, tour)
	_check(report["shows"] == 3 and report["cities"].size() == 3, "relatório consolidado com shows e cidades")
	_check(report["audience"] > 0 and report["expenses"] > 0, "relatório com público e despesas")
	_check(report["fame_gain"] == tour.fame_end - tour.fame_start, "relatório com ganho de fama")
	_restore(game)


func _test_tour_travel_and_fatigue() -> void:
	var game := _make_game(10000000, 600)
	var live: LiveSystem = game.live
	var near := _tour_with_dates(game, ["sao_paulo", "rio", "curitiba"], ["national"], 2)
	var near_cost: int = game.tours.forecast(game.career, near)["upfront"]
	var tight_fatigue: int = live.context_for(game.career, live.tour_shows(game.career, near)[2])["fatigue"]
	var other := _make_game(10000000, 600)
	var rested := _tour_with_dates(other, ["sao_paulo", "rio", "curitiba"], ["national"], 5)
	var rested_fatigue: int = other.live.context_for(other.career, other.live.tour_shows(other.career, rested)[2])["fatigue"]
	_check(rested_fatigue < tight_fatigue, "dias de descanso reduzem o desgaste")
	var zigzag := _make_game(10000000, 600)
	var bad := _tour_with_dates(zigzag, ["sao_paulo", "manaus", "curitiba"], ["national"], 3)
	_check(zigzag.tours.forecast(zigzag.career, bad)["upfront"] > near_cost, "ordem das cidades muda o transporte")
	var conflict: LiveShow = live.new_show(game.career, LiveShow.KIND_TOUR)
	live.apply_venue(conflict, "toquio", "club")
	conflict.day = live.tour_shows(game.career, near)[0].day + 1
	_check(not game.save_tour_date(near.id, conflict).ok, "data incompatível na turnê é recusada")
	var world := _tour_with_dates(game, ["sao_paulo"], ["world"])
	_check(not game.tours.forecast(game.career, world)["warnings"].is_empty(), "aviso quando o tipo não combina com as datas")
	other.free()
	zigzag.free()
	_restore(game)


func _test_tour_pause_and_cancel() -> void:
	var game := _make_game(10000000, 600)
	var tour := _tour_with_dates(game, ["sao_paulo", "rio", "curitiba"], ["national"], 7)
	game.confirm_tour(tour.id)
	_check(game.pause_tour(tour.id).ok and tour.status == LiveTour.STATUS_PAUSED, "pausa turnê")
	_weeks(game, 3)
	var shows: Array[LiveShow] = game.live.tour_shows(game.career, tour)
	_check(shows.size() < 3, "datas durante a pausa são canceladas")
	_check(game.resume_tour(tour.id).ok, "retoma turnê")
	var money_before: int = game.career.money
	_check(game.cancel_tour(tour.id).ok and tour.status == LiveTour.STATUS_CANCELLED, "cancela turnê")
	_check(game.career.money > money_before, "cancelamento devolve parte das despesas")
	_restore(game)


func _test_sponsors() -> void:
	var game := _make_game(10000000, 3000)
	game.balance.live.sponsor_seek_chance = 1.0
	var tour := _tour_with_dates(game, ["sao_paulo", "rio", "belo_horizonte"])
	var cost_before: int = game.tours.forecast(game.career, tour)["upfront"]
	_check(game.seek_sponsors(tour.id).ok and tour.sponsor_offers.size() > 0, "procura patrocinadores")
	_check(not game.tours.sponsor_text(tour.sponsor_offers[0]).is_empty(), "proposta mostra benefícios e contrapartidas")
	var accepted_any := false
	for offer in tour.sponsor_offers.duplicate():
		accepted_any = game.accept_sponsor(tour.id, offer["sponsor_id"]).ok or accepted_any
	_check(accepted_any and tour.sponsor_offers.is_empty(), "aceita patrocínios")
	var forecast: Dictionary = game.tours.forecast(game.career, tour)
	_check(forecast["upfront"] < cost_before or forecast["sponsor_cash"] > 0, "patrocínio reduz custos ou financia")
	var money_before: int = game.career.money
	game.confirm_tour(tour.id)
	_check(game.career.money == money_before - forecast["upfront"] + forecast["sponsor_cash"], "dinheiro do patrocínio entra na confirmação")
	_check(not game.seek_sponsors(tour.id).ok, "patrocínios só no planejamento")
	var small := _make_game(10000000, 0)
	small.balance.live.sponsor_seek_chance = 1.0
	var tiny := _tour_with_dates(small, ["sao_paulo"])
	_check(not small.seek_sponsors(tiny.id).ok, "artista desconhecido não atrai marcas")
	small.balance.live.sponsor_seek_chance = 0.5
	small.free()
	game.balance.live.sponsor_seek_chance = 0.5
	_restore(game)


func _test_merch() -> void:
	var game := _make_game(1000, 800)
	var merch: MerchSystem = game.merch
	_check(not game.manufacture_merch("hoodie", 1000, 150, MerchItem.EXCLUSIVE_NONE, "", false).ok, "fabricação paga antes: sem dinheiro, sem estoque")
	game.career.money = 1000000
	_check(merch.manufacture_cost("tshirt", 2000) < merch.manufacture_cost("tshirt", 100) * 20, "desconto por volume")
	var money_before: int = game.career.money
	var made: ActionResult = game.manufacture_merch("tshirt", 50, 60, MerchItem.EXCLUSIVE_NONE, "", false)
	_check(made.ok, "fabrica camisetas")
	var item: MerchItem = made.value
	_check(game.career.money == money_before - item.cost_total and item.stock == 50, "custo pago e estoque criado")
	var show := _show(game, "sao_paulo", "hall")
	show.ticket_price = 20
	game.schedule_show(show)
	_weeks(game, 2)
	_check(show.result["merch_units"] > 0, "vende merch no show")
	_check(item.sold + item.stock == 50, "estoque baixa com as vendas")
	_check(item.sold <= 50, "nunca vende sem estoque")
	_check(item.revenue > 0 and item.profit() == item.revenue - item.cost_total, "receita e lucro do produto")
	item.stock = 0
	var empty := _show(game, "sao_paulo", "hall", 2)
	game.schedule_show(empty)
	_weeks(game, 2)
	_check(empty.result["merch_units"] == 0, "sem estoque, sem venda")
	var tour := _tour_with_dates(game, ["sao_paulo"])
	var exclusive: MerchItem = game.manufacture_merch("poster", 30, 30, MerchItem.EXCLUSIVE_TOUR, tour.id, true).value
	var other := _show(game, "sao_paulo", "hall", 3)
	game.schedule_show(other)
	_weeks(game, 3)
	_check(exclusive.sold == 0, "produto exclusivo da turnê não vende em outros shows")
	_check(game.set_merch_price(item.id, 80).ok and item.price == 80, "muda o preço")
	var online := _make_game(1000000, 2000)
	var shirt: MerchItem = online.manufacture_merch("tshirt", 500, 50, MerchItem.EXCLUSIVE_NONE, "", false).value
	var song: SongData = online.create_song("Hit").value
	song.quality = 90
	online.release_content(song.id)
	_weeks(online, 6)
	_check(shirt.sold > 0, "loja oficial vende produtos")
	online.free()
	_restore(game)


func _test_festival_editions() -> void:
	var game := _make_game()
	var festivals: FestivalSystem = game.festivals
	var rules: LiveRules = game.balance.live
	_check(game.career.festival_editions.size() >= rules.festivals.size(), "edições criadas na nova carreira")
	var edition: FestivalEdition = festivals.upcoming_editions(game.career)[0]
	var festival := rules.find_festival(edition.festival_id)
	_check(edition.lineup.size() == festival.days * festival.stages.size() * rules.lineup_slots_per_stage, "lineup completo por dia e palco")
	var headliners := edition.lineup.filter(func(slot: Dictionary) -> bool: return slot["position"] == "headliner")
	_check(headliners.size() == festival.days, "um headliner por dia")
	var names := {}
	for slot in edition.lineup:
		names[slot["name"]] = true
	_check(names.size() == edition.lineup.size(), "sem artista repetido no lineup")
	_weeks(game, rules.weeks_per_year + 2)
	var next: FestivalEdition = game.career.find_edition_for(festival.id, edition.year + 1)
	_check(next != null and next.id != edition.id, "nova edição a cada ano")
	var lineup_a: Array = edition.lineup.map(func(slot: Dictionary) -> String: return slot["name"])
	var lineup_b: Array = next.lineup.map(func(slot: Dictionary) -> String: return slot["name"])
	_check(lineup_a != lineup_b, "edições com lineups diferentes")
	_restore(game)


func _test_festival_invitation_and_impact() -> void:
	var game := _make_game(10000000, 12000)
	var festivals: FestivalSystem = game.festivals
	var rules: LiveRules = game.balance.live
	var big := rules.find_festival("rock_in_rio")
	var small := rules.find_festival("quebrada_fest")
	_check(festivals.position_for(festivals.relevance(game.career, big)) == "headliner", "artista enorme é headliner")
	game.career.fame = 300
	_check(LiveRules.POSITIONS.find(festivals.position_for(festivals.relevance(game.career, big))) < 2, "artista pequeno abre o festival grande")
	_check(festivals.position_for(festivals.relevance(game.career, small)) != "opening", "artista pequeno sobe no festival pequeno")
	game.career.fame = 12000
	var edition: FestivalEdition = game.career.find_edition_for(big.id, festivals.year_of(game.career.current_week))
	if edition == null or edition.week <= game.career.current_week + 1:
		edition = game.career.find_edition_for(big.id, festivals.year_of(game.career.current_week) + 1)
	var headline := festivals.make_invitation(game.career, big, edition, "headliner")
	var opening := festivals.make_invitation(game.career, big, edition, "opening")
	_check(headline.fee > opening.fee * 10 and headline.capacity > opening.capacity, "headliner ganha muito mais")
	game.career.live_shows.append(headline)
	var accepted: ActionResult = game.accept_offer(headline.id, null)
	_check(accepted.ok and edition.has_player(), "convite aceito coloca o artista no lineup")
	var day_in_festival: int = game.live.festival_day(headline.day, edition.week)
	var slot: Array = edition.lineup.filter(func(item: Dictionary) -> bool: return item["artist_id"] == FestivalEdition.PLAYER_ID)
	_check(slot.size() == 1 and int(slot[0]["day"]) == day_in_festival and slot[0]["position"] == "headliner", "artista no dia e posição certos")
	while headline.status == LiveShow.STATUS_SCHEDULED:
		game.next_week()
	_check(headline.status == LiveShow.STATUS_DONE, "show do festival acontece")
	_check(headline.result["fame"] > 100 and headline.result["quality"] > 30, "festival dá fama")
	var small_show := festivals.make_invitation(game.career, big, edition, "opening")
	small_show.status = LiveShow.STATUS_SCHEDULED
	var impact_head: float = game.live._impact(game.career, headline)
	var impact_open: float = game.live._impact(game.career, small_show)
	_check(impact_head > impact_open * 3, "headliner tem impacto muito maior")
	var covered := festivals.make_invitation(game.career, small, game.career.find_edition_for(small.id, edition.year), "featured")
	covered.fee_model = "covered"
	_check(game.live.estimate(game.career, covered)["income"] == 0 and game.live.terms_text(covered).begins_with("Sem cachê"), "festival sem cachê com despesas pagas")
	_restore(game)


func _test_festival_application() -> void:
	var game := _make_game(10000000, 400)
	game.balance.live.application_chance_per_relevance = 100.0
	var edition: FestivalEdition = null
	for item in game.festivals.upcoming_editions(game.career):
		if item.festival_id == "quebrada_fest" and item.week > game.career.current_week + 2:
			edition = item
			break
	_check(edition != null, "edição pequena por vir")
	_check(game.apply_to_festival(edition.id).ok, "envia inscrição")
	_check(not game.apply_to_festival(edition.id).ok, "não inscreve duas vezes")
	game.next_week()
	var offers := _offers(game).filter(func(show: LiveShow) -> bool: return show.festival_edition_id == edition.id)
	_check(edition.application_status == FestivalEdition.APPLICATION_ACCEPTED and offers.size() == 1, "inscrição aprovada vira proposta")
	game.balance.live.application_chance_per_relevance = 1.5
	_restore(game)


func _test_show_report() -> void:
	var game := _make_game(10000000, 300)
	var show := _show(game, "sao_paulo", "club")
	game.schedule_show(show)
	var report: WeekReport
	for i in 2:
		report = game.next_week()
	var keys := ["attendance", "sold", "occupancy", "gross", "artist_income", "total_expenses", "profit", "merch_net", "new_fans", "fame", "buzz_label"]
	for key in keys:
		_check(show.result.has(key), "relatório do show tem %s" % key)
	var lines := report.entries.filter(func(line: WeekReportEntry) -> bool: return line.title.begins_with("Show:"))
	_check(lines.size() == 1, "show aparece no relatório semanal")
	_check(game.live.history(game.career).has(show), "show no histórico")
	_restore(game)


func _test_round_trip() -> void:
	var game := _make_game(10000000, 1500)
	game.manufacture_merch("cap", 40, 40, MerchItem.EXCLUSIVE_NONE, "", true)
	var tour := _tour_with_dates(game, ["sao_paulo", "rio"])
	var show := _show(game, "curitiba", "club", 5)
	show.crew = {"dj": 2}
	show.guests = [{"artist_id": _feat_id(game, 3), "role": "opening"}]
	show.addons = ["lighting"]
	game.schedule_show(show)
	game.live.generate_offers(game.career)
	_check(game.save_game().ok, "salva carreira ao vivo")
	var loaded := _make_game()
	_check(loaded.load_game().ok, "carrega carreira ao vivo")
	var career: CareerData = loaded.career
	_check(career.live_shows.size() == game.career.live_shows.size(), "shows preservados")
	_check(career.live_tours.size() == 1 and career.live_tours[0].name == tour.name, "turnês preservadas")
	_check(career.merch_items.size() == 1 and career.merch_items[0].limited, "merch preservado")
	_check(career.festival_editions.size() == game.career.festival_editions.size(), "edições de festival preservadas")
	var copy := career.find_live_show(show.id)
	_check(copy != null and copy.crew.get("dj", 0) == 2 and copy.guests.size() == 1 and copy.addons == show.addons, "configuração do show preservada")
	_check(JSON.stringify(career.to_dict()) == JSON.stringify(game.career.to_dict()), "carreira idêntica após salvar e carregar")
	loaded.free()
	_restore(game)


func _test_v6_migration() -> void:
	_clean_saves()
	DirAccess.make_dir_recursive_absolute(TEST_SAVE_DIR)
	var save_path := TEST_SAVE_DIR.path_join("career.json")
	var fixture_text := FileAccess.get_file_as_string(V6_FIXTURE)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(fixture_text)
	file.close()
	var old_payload: Dictionary = JSON.parse_string(fixture_text)
	var old: Dictionary = old_payload["career"]
	_check(int(old_payload["version"]) == 6, "fixture é v6")
	var game: Node = GameManagerScript.new()
	game.saves.save_dir = TEST_SAVE_DIR
	_check(game.load_game().ok, "carrega save v6 real")
	var career: CareerData = game.career
	_check(FileAccess.get_file_as_string(save_path + ".v6.bak") == fixture_text, "cópia do save v6 guardada")
	_check(career.money == int(old["money"]) and career.fame == int(old["fame"]), "dinheiro e fama preservados")
	_check(career.songs.size() == old["songs"].size() and career.music_videos.size() == old["music_videos"].size(), "músicas e clipes preservados")
	_check(career.next_id == int(old["next_id"]), "contador de ids preservado")
	_check(career.live_shows.is_empty() and career.live_tours.is_empty() and career.merch_items.is_empty(), "carreira ao vivo começa vazia")
	_check(not career.festival_editions.is_empty(), "festivais criados ao carregar")
	game.next_week()
	_check(game.save_game().ok, "salva no formato novo")
	_check(int(JSON.parse_string(FileAccess.get_file_as_string(save_path))["version"]) == SaveSystem.SAVE_VERSION, "save migrado para a versão atual")
	game.free()


## Shows precisam render, mas sem dinheiro infinito.
func _test_long_run_economy() -> void:
	var game := _make_game(20000, 0, 77)
	var live: LiveSystem = game.live
	for week in 104:
		for offer in _offers(game):
			var projection: Dictionary = live.estimate(game.career, offer)
			if offer.kind == LiveShow.KIND_CONTRACTED and projection["profit"] > 0 and game.career.money > projection["total_expenses"]:
				game.accept_offer(offer.id, null)
		game.next_week()
	var earned := 0
	for entry in game.career.finance_history:
		if entry.category == FinanceEntry.CATEGORY_LIVE and entry.amount > 0:
			earned += entry.amount
	_check(earned > 0, "shows contratados rendem dinheiro")
	_check(game.career.money < 50000000, "sem dinheiro infinito em 2 anos de shows")
	_check(game.live.history(game.career).size() > 5, "artista faz shows ao longo da carreira")
	_restore(game)


func _clean_saves() -> void:
	if not DirAccess.dir_exists_absolute(TEST_SAVE_DIR):
		return
	for file_name in DirAccess.get_files_at(TEST_SAVE_DIR):
		DirAccess.remove_absolute(TEST_SAVE_DIR.path_join(file_name))
	DirAccess.remove_absolute(TEST_SAVE_DIR)
