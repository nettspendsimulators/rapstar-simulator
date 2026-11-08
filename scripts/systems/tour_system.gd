class_name TourSystem
extends RefCounted
## Turnês: datas em planejamento, previsão de custos, conflitos e desgaste, confirmação,
## pausa, cancelamento, patrocínios e relatório consolidado. As datas são shows do LiveSystem.

var _balance: GameBalance
var _economy: EconomySystem
var _live: LiveSystem
var _streaming: StreamingSystem
var _rng: RandomNumberGenerator
var social: SocialSystem


func _init(balance: GameBalance, economy: EconomySystem, live: LiveSystem, streaming: StreamingSystem, rng: RandomNumberGenerator) -> void:
	_balance = balance
	_economy = economy
	_live = live
	_streaming = streaming
	_rng = rng


func create_tour(career: CareerData, tour_name: String, goal: String, project_id: String, types: Array[String], co_headliner_id: String) -> ActionResult:
	var clean_name := tour_name.strip_edges()
	if clean_name.is_empty():
		return ActionResult.failure("Dê um nome para a turnê.")
	if types.is_empty():
		return ActionResult.failure("Escolha pelo menos um tipo de turnê.")
	var partner_error := _partner_refusal(career, co_headliner_id)
	if not partner_error.is_empty():
		return ActionResult.failure(partner_error)
	var tour := LiveTour.new()
	tour.id = career.new_id("tour")
	tour.name = clean_name
	tour.goal = goal.strip_edges()
	tour.project_id = project_id
	tour.types = types.duplicate()
	tour.co_headliner_id = co_headliner_id
	career.live_tours.append(tour)
	return ActionResult.success("Turnê \"%s\" criada. Adicione as datas." % clean_name, tour)


func update_tour(career: CareerData, tour_id: String, tour_name: String, goal: String, project_id: String, types: Array[String], co_headliner_id: String) -> ActionResult:
	var tour := career.find_tour(tour_id)
	if tour == null or not tour.is_open():
		return ActionResult.failure("Só turnês em planejamento podem ser alteradas.")
	if tour_name.strip_edges().is_empty() or types.is_empty():
		return ActionResult.failure("A turnê precisa de nome e de pelo menos um tipo.")
	var partner_error := _partner_refusal(career, co_headliner_id)
	if not partner_error.is_empty():
		return ActionResult.failure(partner_error)
	tour.name = tour_name.strip_edges()
	tour.goal = goal.strip_edges()
	tour.project_id = project_id
	tour.types = types.duplicate()
	tour.co_headliner_id = co_headliner_id
	return ActionResult.success("Turnê atualizada.", tour)


## Adiciona ou substitui uma data. A data fica em planejamento até a turnê ser confirmada.
func save_date(career: CareerData, tour_id: String, show: LiveShow) -> ActionResult:
	var tour := career.find_tour(tour_id)
	if tour == null or not tour.is_open():
		return ActionResult.failure("Só turnês em planejamento recebem datas.")
	if show.week() <= career.current_week:
		return ActionResult.failure("Escolha uma data a partir da semana %s." % Fmt.number(career.current_week + 1))
	if show.ticket_price <= 0.0:
		return ActionResult.failure("Defina o preço do ingresso.")
	show.kind = LiveShow.KIND_TOUR
	show.status = LiveShow.STATUS_DRAFT
	show.tour_id = tour.id
	var error := _live.guests_refusal(career, show)
	if error.is_empty():
		error = _live.conflict_error(career, show)
	if not error.is_empty():
		return ActionResult.failure(error)
	var existing := career.find_live_show(show.id) if not show.id.is_empty() else null
	if existing != null:
		career.live_shows[career.live_shows.find(existing)] = show
	else:
		show.id = career.new_id("show")
		career.live_shows.append(show)
	return ActionResult.success("Data salva: %s." % _live.day_label(show.day), show)


func remove_date(career: CareerData, show_id: String) -> ActionResult:
	var show := career.find_live_show(show_id)
	if show == null or show.status != LiveShow.STATUS_DRAFT:
		return ActionResult.failure("Só datas em planejamento podem ser removidas.")
	career.live_shows.erase(show)
	return ActionResult.success("Data removida.")


## Previsão completa: custos, receitas, lucro, cidades, desgaste, conflitos e avisos.
func forecast(career: CareerData, tour: LiveTour) -> Dictionary:
	var result := {"shows": 0, "cities": 0, "upfront": 0, "income": 0, "merch": 0, "profit": 0, "audience": 0,
		"sponsor_cash": _sponsor_cash(tour), "conflicts": PackedStringArray(), "warnings": PackedStringArray()}
	var cities := {}
	var countries := {}
	var continents := {}
	var regions := {}
	for show in _live.tour_shows(career, tour):
		var projection := _live.estimate(career, show)
		result["shows"] += 1
		result["upfront"] += projection["total_expenses"]
		result["income"] += projection["artist_income"]
		result["merch"] += projection["merch_net"]
		result["profit"] += projection["profit"]
		result["audience"] += projection["attendance"]
		var city := _rules().find_city(show.city_id)
		cities[city.id] = true
		countries[city.country] = true
		continents[city.continent] = true
		regions[city.region] = true
		if show.status == LiveShow.STATUS_DRAFT:
			var error := _live.conflict_error(career, show)
			if not error.is_empty():
				result["conflicts"].append(error)
		if projection["fatigue"] >= 60:
			result["warnings"].append("Desgaste alto em %s: inclua dias de descanso." % _live.day_label(show.day))
	result["cities"] = cities.size()
	result["profit"] += result["sponsor_cash"]
	var home := _rules().find_city(_rules().home_city_id)
	if "mini" in tour.types and result["shows"] > 5:
		result["warnings"].append("Uma Mini Tour costuma ter até 5 datas.")
	if "regional" in tour.types and regions.size() > 1:
		result["warnings"].append("Uma Regional Tour costuma ficar em uma região.")
	if "national" in tour.types and regions.size() < 2:
		result["warnings"].append("Uma National Tour costuma passar por várias regiões.")
	if ("international" in tour.types or "world" in tour.types) and countries.size() == 1 and countries.has(home.country):
		result["warnings"].append("Turnês internacionais precisam de cidades fora do país.")
	if "world" in tour.types and continents.size() < 3:
		result["warnings"].append("Uma World Tour costuma passar por pelo menos 3 continentes.")
	if "album" in tour.types and tour.project_id.is_empty():
		result["warnings"].append("Uma Album Tour deve estar ligada a um projeto.")
	return result


## Paga as despesas de todas as datas e coloca a turnê no calendário.
func confirm(career: CareerData, tour_id: String) -> ActionResult:
	var tour := career.find_tour(tour_id)
	if tour == null or not tour.is_open():
		return ActionResult.failure("A turnê já foi confirmada.")
	var shows := _live.tour_shows(career, tour)
	if shows.is_empty():
		return ActionResult.failure("Adicione pelo menos uma data.")
	var projection := forecast(career, tour)
	if not projection["conflicts"].is_empty():
		return ActionResult.failure("Resolva os conflitos de agenda: %s" % projection["conflicts"][0])
	for show in shows:
		if show.week() <= career.current_week:
			return ActionResult.failure("Há datas no passado: %s." % _live.day_label(show.day))
	var cash: int = projection["sponsor_cash"]
	var needed: int = projection["upfront"] - cash
	if not _economy.can_afford(career, maxi(needed, 0)):
		return _economy.insufficient_funds(needed)
	if cash > 0:
		_economy.earn(career, cash, "Patrocínios da turnê %s" % tour.name, FinanceEntry.CATEGORY_SPONSOR)
	for show in shows:
		var upfront: int = _live.estimate(career, show)["total_expenses"]
		show.upfront_paid = upfront
		show.status = LiveShow.STATUS_SCHEDULED
		if upfront > 0:
			_economy.spend(career, upfront, "Turnê %s: %s" % [tour.name, show.venue_name], FinanceEntry.CATEGORY_LIVE)
	tour.status = LiveTour.STATUS_CONFIRMED
	tour.fame_start = career.fame
	tour.followers_start = _streaming.total_followers(career)
	return ActionResult.success("Turnê confirmada: %d datas no calendário." % shows.size(), tour)


func pause(career: CareerData, tour_id: String) -> ActionResult:
	var tour := career.find_tour(tour_id)
	if tour == null or not (tour.status == LiveTour.STATUS_CONFIRMED or tour.status == LiveTour.STATUS_IN_PROGRESS):
		return ActionResult.failure("Só turnês confirmadas ou em andamento podem ser pausadas.")
	tour.status = LiveTour.STATUS_PAUSED
	return ActionResult.success("Turnê pausada. Datas que passarem durante a pausa são canceladas.", tour)


func resume(career: CareerData, tour_id: String) -> ActionResult:
	var tour := career.find_tour(tour_id)
	if tour == null or tour.status != LiveTour.STATUS_PAUSED:
		return ActionResult.failure("A turnê não está pausada.")
	tour.status = LiveTour.STATUS_IN_PROGRESS if _done_count(career, tour) > 0 else LiveTour.STATUS_CONFIRMED
	return ActionResult.success("Turnê retomada.", tour)


## Datas futuras são canceladas, com o reembolso parcial padrão dos shows próprios.
func cancel(career: CareerData, tour_id: String) -> ActionResult:
	var tour := career.find_tour(tour_id)
	if tour == null or tour.status == LiveTour.STATUS_COMPLETED or tour.status == LiveTour.STATUS_CANCELLED:
		return ActionResult.failure("Esta turnê não pode ser cancelada.")
	var refund := 0
	for show in _live.tour_shows(career, tour):
		if show.status == LiveShow.STATUS_DRAFT:
			career.live_shows.erase(show)
		elif show.status == LiveShow.STATUS_SCHEDULED:
			var result := _live.cancel_show(career, show.id)
			refund += roundi(show.upfront_paid * _rules().cancel_refund) if result.ok else 0
	tour.status = LiveTour.STATUS_CANCELLED
	return ActionResult.success("Turnê cancelada. %s devolvidos." % Fmt.money(refund), tour)


## Procura patrocinadores. Só turnês em planejamento, para os benefícios entrarem nos custos.
func seek_sponsors(career: CareerData, tour_id: String) -> ActionResult:
	var tour := career.find_tour(tour_id)
	if tour == null or not tour.is_open():
		return ActionResult.failure("Patrocínios são fechados antes de confirmar a turnê.")
	var found := 0
	for sponsor in _rules().sponsors:
		if career.fame < sponsor.min_fame or _has_sponsor(tour, sponsor.id) or _rng.randf() > _rules().sponsor_seek_chance:
			continue
		tour.sponsor_offers.append(_proposal(career, tour, sponsor))
		found += 1
	if found == 0:
		return ActionResult.failure("Nenhuma marca se interessou agora. A fama e o tamanho da turnê pesam.")
	return ActionResult.success("%d proposta(s) de patrocínio recebida(s)." % found, tour)


func accept_sponsor(career: CareerData, tour_id: String, sponsor_id: String) -> ActionResult:
	var tour := career.find_tour(tour_id)
	if tour == null or not tour.is_open():
		return ActionResult.failure("Patrocínios são fechados antes de confirmar a turnê.")
	for offer in tour.sponsor_offers:
		if offer.get("sponsor_id", "") == sponsor_id:
			tour.sponsor_offers.erase(offer)
			tour.sponsors.append(offer)
			return ActionResult.success("Patrocínio de %s aceito." % _rules().find_sponsor(sponsor_id).display_name, tour)
	return ActionResult.failure("Proposta não encontrada.")


func sponsor_text(offer: Dictionary) -> String:
	var sponsor := _rules().find_sponsor(offer.get("sponsor_id", ""))
	var benefit: String
	match offer.get("benefit", "cash"):
		"transport":
			benefit = "%d%% de desconto no transporte" % roundi(float(offer["benefit_value"]) * 100)
		"lodging":
			benefit = "%d%% de desconto na hospedagem" % roundi(float(offer["benefit_value"]) * 100)
		"equipment":
			benefit = "%d%% de desconto em produção e equipamentos" % roundi(float(offer["benefit_value"]) * 100)
		"promotion":
			benefit = "+%d%% de divulgação" % roundi(float(offer["benefit_value"]) * 100)
		_:
			benefit = "%s de financiamento" % Fmt.money(int(offer.get("value", 0)))
	return "%s: %s. Contrapartida: %s" % [sponsor.display_name, benefit, sponsor.obligations]


## Etapa da semana: atualiza o estado das turnês e fecha as que terminaram.
func process_week(career: CareerData, report: WeekReport) -> void:
	for tour in career.live_tours:
		if not tour.is_running() or tour.status == LiveTour.STATUS_PAUSED:
			continue
		var shows := _live.tour_shows(career, tour)
		var done := _done_count(career, tour)
		if done > 0 and tour.status == LiveTour.STATUS_CONFIRMED:
			tour.status = LiveTour.STATUS_IN_PROGRESS
		var pending := shows.filter(func(show: LiveShow) -> bool: return show.status == LiveShow.STATUS_SCHEDULED)
		if pending.is_empty() and done > 0:
			tour.status = LiveTour.STATUS_COMPLETED
			tour.fame_end = career.fame
			tour.followers_end = _streaming.total_followers(career)
			var summary := tour_report(career, tour)
			var line := WeekReportEntry.new()
			line.title = "Turnê concluída: %s" % tour.name
			line.note = "%d shows, %s pessoas, resultado %s." % [summary["shows"], Fmt.number(summary["audience"]), Fmt.signed_money(summary["profit"])]
			report.entries.append(line)
			if social != null:
				social.on_tour_completed(career, tour, report)


## Relatório consolidado a partir dos shows realizados.
func tour_report(career: CareerData, tour: LiveTour) -> Dictionary:
	var report := {"shows": 0, "cities": PackedStringArray(), "audience": 0, "sold": 0, "capacity": 0, "fees": 0, "box_office": 0,
		"merch": 0, "sponsors": _sponsor_cash(tour), "expenses": 0, "profit": 0, "new_fans": 0}
	var cities := {}
	for show in _live.tour_shows(career, tour):
		if show.status != LiveShow.STATUS_DONE:
			continue
		var result := show.result
		report["shows"] += 1
		cities[_live.city_label(show.city_id)] = true
		report["audience"] += int(result.get("attendance", 0))
		report["sold"] += int(result.get("sold", 0)) + int(result.get("vip_sold", 0))
		report["capacity"] += int(result.get("capacity", 0))
		if show.model == LiveRules.MODEL_INDEPENDENT:
			report["box_office"] += int(result.get("artist_income", 0))
		else:
			report["fees"] += int(result.get("artist_income", 0))
		report["merch"] += int(result.get("merch_net", 0))
		report["expenses"] += int(result.get("total_expenses", 0))
		report["new_fans"] += int(result.get("new_fans", 0))
	report["cities"] = PackedStringArray(cities.keys())
	report["occupancy"] = roundi(float(report["sold"]) / maxf(report["capacity"], 1.0) * 100.0)
	report["profit"] = report["fees"] + report["box_office"] + report["merch"] + report["sponsors"] - report["expenses"]
	var end_fame := tour.fame_end if tour.status == LiveTour.STATUS_COMPLETED else career.fame
	var end_followers := tour.followers_end if tour.status == LiveTour.STATUS_COMPLETED else _streaming.total_followers(career)
	report["fame_gain"] = end_fame - tour.fame_start
	report["followers_gain"] = end_followers - tour.followers_start
	return report


func _proposal(career: CareerData, tour: LiveTour, sponsor: SponsorDefinition) -> Dictionary:
	var r := _rules()
	var shows := _live.tour_shows(career, tour).size()
	var scale := 1.0 + career.fame * r.sponsor_value_per_fame + shows * r.sponsor_value_per_show
	var type_bonus := 1.0
	for type_id in tour.types:
		var type := r.find_tour_type(type_id)
		if type != null:
			type_bonus = maxf(type_bonus, type.sponsor_multiplier)
	return {
		"sponsor_id": sponsor.id,
		"benefit": sponsor.benefit,
		"benefit_value": sponsor.benefit_value,
		"value": roundi(sponsor.base_value * scale * type_bonus) if sponsor.benefit == "cash" else 0,
	}


func _sponsor_cash(tour: LiveTour) -> int:
	var total := 0
	for sponsor in tour.sponsors:
		total += int(sponsor.get("value", 0))
	return total


func _has_sponsor(tour: LiveTour, sponsor_id: String) -> bool:
	for item in tour.sponsors + tour.sponsor_offers:
		if item.get("sponsor_id", "") == sponsor_id:
			return true
	return false


func _done_count(career: CareerData, tour: LiveTour) -> int:
	return _live.tour_shows(career, tour).filter(func(show: LiveShow) -> bool: return show.status == LiveShow.STATUS_DONE).size()


func _rules() -> LiveRules:
	return _balance.live


## Rivais recusam dividir uma turnê.
func _partner_refusal(career: CareerData, co_headliner_id: String) -> String:
	if social == null or co_headliner_id.is_empty():
		return ""
	return social.refusal(career, co_headliner_id)
