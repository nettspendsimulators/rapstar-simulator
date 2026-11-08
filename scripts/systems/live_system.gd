class_name LiveSystem
extends RefCounted
## Shows ao vivo: público, ingressos, custos, modelos financeiros, ofertas, calendário e resultados.
## Usa a fama, os seguidores das plataformas como fãs, a economia, as semanas e o relatório semanal.
## Todas as despesas do artista são pagas ao confirmar o show; no dia, entram cachê, bilheteria e merch.

const OFFER_EVENTS := {
	"bar": ["Noite de rap no bar", "Sarau de rima"], "underground": ["Festa underground", "Batalha de rima"],
	"club": ["Noite de trap", "Festa na boate"], "hall": ["Show em casa de shows"], "theater": ["Show no teatro"],
	"arena": ["Show na arena"], "big_arena": ["Grande evento"], "stadium": ["Evento no estádio"],
}
const PRIVATE_EVENT := "Apresentação privada"
## Festivais começam na sexta-feira da semana da edição.
const FESTIVAL_FIRST_WEEKDAY := 5

var _balance: GameBalance
var _economy: EconomySystem
var _streaming: StreamingSystem
var _merch: MerchSystem
var _rng: RandomNumberGenerator
## Relações: preço e disposição dos convidados, parceiros e encontros em festivais.
var social: SocialSystem


func _init(balance: GameBalance, economy: EconomySystem, streaming: StreamingSystem, merch: MerchSystem, rng: RandomNumberGenerator) -> void:
	_balance = balance
	_economy = economy
	_streaming = streaming
	_merch = merch
	_rng = rng


func rules() -> LiveRules:
	return _balance.live


# ---- calendário e lugares

func first_day_of_week(week: int) -> int:
	return (week - 1) * 7 + 1


func day_label(day: int) -> String:
	return "Semana %s, dia %d" % [Fmt.number((day - 1) / 7 + 1), (day - 1) % 7 + 1]


## Dia do festival (1, 2, 3...) para um dia do calendário.
func festival_day(day: int, edition_week: int) -> int:
	return day - first_day_of_week(edition_week) - FESTIVAL_FIRST_WEEKDAY + 2


## Quanto o público aceita pagar a mais pela fama do artista, com teto.
func price_fame_multiplier(career: CareerData) -> float:
	return 1.0 + minf(float(career.fame) / rules().price_fame_reference, rules().max_price_fame_bonus)


## Versão curta para tabelas: "Sem 7 · Sex".
func short_day_label(day: int) -> String:
	const NAMES := ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"]
	return "Sem %s · %s" % [Fmt.number((day - 1) / 7 + 1), NAMES[(day - 1) % 7]]


func city_label(city_id: String) -> String:
	var city := rules().find_city(city_id)
	return city.display_name if city != null else "?"


func capacity_for(city_id: String, venue_id: String) -> int:
	var city := rules().find_city(city_id)
	var venue := rules().find_venue(venue_id)
	return roundi(lerpf(venue.min_capacity, venue.max_capacity, clampf(city.market, 0.0, 1.0)))


func venue_name_for(city_id: String, venue_id: String) -> String:
	var city := rules().find_city(city_id)
	var venue := rules().find_venue(venue_id)
	return "%s — %s" % [venue.venue_names[abs(hash(city.id)) % venue.venue_names.size()], city.display_name]


## Cidade e categoria definem o local; o preço volta ao valor de referência do local.
func apply_venue(show: LiveShow, city_id: String, venue_id: String) -> void:
	show.city_id = city_id
	show.venue_id = venue_id
	show.capacity = capacity_for(city_id, venue_id)
	show.venue_name = venue_name_for(city_id, venue_id)


## Um show novo com o básico: casa, bar, sexta-feira daqui a duas semanas.
func new_show(career: CareerData, kind: String) -> LiveShow:
	var show := LiveShow.new()
	show.kind = kind
	apply_venue(show, rules().home_city_id, "bar")
	show.day = first_day_of_week(career.current_week + 2) + 4
	show.ticket_price = rules().find_venue("bar").base_ticket_price
	show.vip_price = show.ticket_price * rules().vip_price_multiplier
	return show


func distance_km(city_a: String, city_b: String) -> float:
	if city_a == city_b:
		return 0.0
	var a := rules().find_city(city_a)
	var b := rules().find_city(city_b)
	var lat1 := deg_to_rad(a.latitude)
	var lat2 := deg_to_rad(b.latitude)
	var d_lat := lat2 - lat1
	var d_lon := deg_to_rad(b.longitude - a.longitude)
	var h := sin(d_lat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(d_lon / 2) ** 2
	return 6371.0 * 2.0 * asin(sqrt(h))


func travel_days(city_a: String, city_b: String) -> int:
	var km := distance_km(city_a, city_b)
	if km <= rules().short_trip_km:
		return 0
	return clampi(ceili(km / rules().travel_km_per_day), 1, rules().max_travel_days)


## Devolve a mensagem de erro, ou um texto vazio se o dia estiver livre na agenda do artista.
## Considera o tempo de viagem entre cidades.
func conflict_error(career: CareerData, show: LiveShow) -> String:
	for other in career.live_shows:
		if other == show or other.id == show.id and not show.id.is_empty():
			continue
		var counts := other.status == LiveShow.STATUS_SCHEDULED
		if other.status == LiveShow.STATUS_DRAFT and not show.tour_id.is_empty() and other.tour_id == show.tour_id:
			counts = true
		if not counts:
			continue
		var gap := absi(other.day - show.day)
		if gap == 0:
			return "Já existe um compromisso em %s (%s)." % [day_label(show.day), other.venue_name]
		var needed := travel_days(other.city_id, show.city_id)
		if needed > 0 and gap < needed + 1:
			return "Não dá tempo de viajar entre %s e %s (%d dia(s) de viagem)." % [city_label(other.city_id), city_label(show.city_id), needed]
	return ""


# ---- público e qualidade

func reach(career: CareerData, city: CityDefinition) -> float:
	var home := rules().find_city(rules().home_city_id)
	if city.country == home.country:
		return 1.0
	return clampf(float(career.fame) / rules().international_reach_fame, rules().min_international_reach, 1.0)


func potential_audience(career: CareerData, show: LiveShow) -> float:
	var r := rules()
	var city := r.find_city(show.city_id)
	var local := city.market * city.rap_scene * reach(career, city)
	var audience := (r.base_locals + career.fame * r.fame_draw + _streaming.total_followers(career) * r.follower_draw) * local
	for guest in _all_guests(career, show):
		audience += guest["person"].cost * r.guest_fame_per_cost * r.fame_draw * float(r.guest_draw.get(guest["role"], 0.0)) * local
	return audience


## Ingressos e VIP vendidos. Nunca garante lotação.
func demand(career: CareerData, show: LiveShow, context: Dictionary, noisy: bool) -> Vector2i:
	var r := rules()
	var noise := _rng.randf_range(1.0 - r.demand_noise, 1.0 + r.demand_noise) if noisy else 1.0
	if show.kind == LiveShow.KIND_FESTIVAL or show.event_type == PRIVATE_EVENT:
		return Vector2i(roundi(show.capacity * clampf(0.92 * noise, 0.0, 1.0)), 0)
	var venue := r.find_venue(show.venue_id)
	var reference_price := venue.base_ticket_price * price_fame_multiplier(career)
	var price_factor := clampf(pow(reference_price / maxf(show.ticket_price, 1.0), r.price_elasticity), r.min_price_factor, r.max_price_factor)
	var promotion := 1.0 + minf(show.promotion / maxf(show.capacity * r.promotion_per_seat, 1.0), 1.0) * r.promotion_max_bonus
	promotion *= 1.0 + float(context.get("promotion_bonus", 0.0))
	var hype := 1.0 + r.find_production(show.production_id).tier * r.production_hype_per_tier
	var saturation := pow(r.city_saturation_factor, _recent_shows_in_city(career, show))
	var release := 1.0 + (r.recent_release_bonus if _has_recent_release(career) else 0.0)
	var expected := potential_audience(career, show) * price_factor * promotion * hype * saturation * release * noise
	var vip_capacity := 0
	var vip_sold := 0
	if show.vip_enabled and venue.has_vip:
		vip_capacity = roundi(show.capacity * r.vip_capacity_share)
		var vip_factor := clampf(pow(reference_price * r.vip_price_multiplier / maxf(show.vip_price, 1.0), r.price_elasticity), r.min_price_factor, r.max_price_factor)
		vip_sold = mini(vip_capacity, roundi(expected * r.vip_demand_share * vip_factor))
	return Vector2i(mini(show.capacity - vip_capacity, roundi(expected)), vip_sold)


## Qualidade da apresentação, de 0 a 100: produção, equipe, convidados, catálogo e desgaste.
func quality(career: CareerData, show: LiveShow, context: Dictionary) -> int:
	var r := rules()
	var value := float(r.base_quality) + _catalog_quality(career) * r.catalog_quality_weight
	value += r.find_production(show.production_id).quality
	for addon_id in show.addons:
		var addon := r.find_addon(addon_id)
		if addon != null:
			value += addon.quality
	var organization := 0.0
	for role_id in show.crew:
		var role := r.find_crew_role(role_id)
		var tier: int = show.crew[role_id]
		if role != null:
			value += role.quality * tier
			organization += role.organization * tier
	value += _all_guests(career, show).size() * 3
	value -= float(context.get("fatigue", 0)) * r.fatigue_quality_penalty
	# Quem organiza cuida da estrutura: o artista só precisa de equipe própria nos shows que ele produz.
	if show.model == LiveRules.MODEL_INDEPENDENT and show.kind != LiveShow.KIND_FESTIVAL:
		var required := show.capacity / 1000.0 * r.organization_per_thousand
		value -= maxf(required - organization, 0.0) * r.organization_shortfall_penalty
	return clampi(roundi(value), 0, 100)


# ---- custos e receitas

## Despesas pagas pelo artista ao confirmar o show.
func costs(career: CareerData, show: LiveShow, context: Dictionary) -> Dictionary:
	var r := rules()
	var size := maxf(float(show.capacity) / r.production_size_reference, r.min_size_factor)
	if show.kind == LiveShow.KIND_FESTIVAL:
		size = minf(size, 1.0)  # o festival já entrega palco e estrutura; o artista paga só o próprio show
	var equipment := 1.0 - float(context.get("equipment_reduction", 0.0))
	var self_organized := show.model == LiveRules.MODEL_INDEPENDENT and show.kind != LiveShow.KIND_FESTIVAL
	var people := 1
	var crew_cost := 0.0
	for role_id in show.crew:
		var role := r.find_crew_role(role_id)
		var tier: int = show.crew[role_id]
		if role != null and tier > 0:
			crew_cost += role.base_cost * r.crew_tier_multipliers[tier]
			people += role.people * tier
	var addons_cost := 0.0
	for addon_id in show.addons:
		var addon := r.find_addon(addon_id)
		if addon != null:
			addons_cost += addon.cost
	var guests_cost := 0.0
	for guest in show.guests:
		var person := _person(guest.get("artist_id", ""))
		if person != null:
			var multiplier := social.price_multiplier(career, String(person.id)) if social != null else 1.0
			guests_cost += person.cost * multiplier * float(r.guest_fee.get(guest.get("role", "guest"), 0.0))
	var previous: String = context.get("previous_city", r.home_city_id)
	var km := distance_km(previous, show.city_id)
	var travel := float(r.local_transport)
	if km >= r.flight_distance_km:
		travel = r.flight_per_person * people
	elif km > 0.0:
		travel = km * r.transport_per_km_person * people + r.local_transport
	travel *= 1.0 - float(context.get("transport_reduction", 0.0))
	var extra_nights: int = context.get("extra_nights", 0)
	var away := show.city_id != r.home_city_id
	var lodging := people * r.hotel_per_person_night * (1 + extra_nights) * (1.0 - float(context.get("lodging_reduction", 0.0))) if away else 0.0
	var covered := show.kind == LiveShow.KIND_FESTIVAL and show.covers_travel
	if show.covers_travel or covered:
		travel = 0.0
	if show.covers_lodging or covered:
		lodging = 0.0
	return {
		"rent": rules().find_venue(show.venue_id).rent if self_organized else 0,
		"production": roundi(r.find_production(show.production_id).cost * size * equipment),
		"addons": roundi(addons_cost * size * equipment),
		"crew": roundi(crew_cost),
		"guests": roundi(guests_cost),
		"travel": roundi(travel),
		"lodging": roundi(lodging),
		"food": 0 if covered else people * r.food_per_person * (1 + extra_nights),
		"security": roundi(show.capacity * r.security_per_seat) if self_organized else 0,
		"promotion": show.promotion,
	}


## Previsão completa do show, sem sorteio, para mostrar antes de confirmar.
func estimate(career: CareerData, show: LiveShow, context: Variant = null) -> Dictionary:
	var ctx: Dictionary = context if context != null else context_for(career, show)
	var tickets := demand(career, show, ctx, false)
	var show_quality := quality(career, show, ctx)
	var result := _money_result(career, show, tickets, show_quality)
	result["merch_net"] = _merch_estimate(career, show, tickets.x + tickets.y, show_quality)
	result["expenses"] = costs(career, show, ctx)
	result["total_expenses"] = _sum(result["expenses"])
	result["profit"] = result["artist_income"] + result["merch_net"] - result["total_expenses"]
	result["fatigue"] = int(ctx.get("fatigue", 0))
	return result


## Contexto da turnê: cidade anterior, desgaste acumulado, noites extras e benefícios dos patrocinadores.
func context_for(career: CareerData, show: LiveShow) -> Dictionary:
	var r := rules()
	var context := {"fatigue": 0, "previous_city": r.home_city_id, "extra_nights": 0}
	var tour := career.find_tour(show.tour_id)
	if tour == null:
		return context
	context["transport_reduction"] = tour.sponsor_benefit("transport")
	context["lodging_reduction"] = tour.sponsor_benefit("lodging")
	context["equipment_reduction"] = tour.sponsor_benefit("equipment")
	context["promotion_bonus"] = tour.sponsor_benefit("promotion")
	var fatigue := 0.0
	var previous: LiveShow = null
	for other in tour_shows(career, tour):
		if previous != null:
			var gap := other.day - previous.day
			var travel := travel_days(previous.city_id, other.city_id)
			var rest := maxi(gap - 1 - travel, 0)
			fatigue = clampf(fatigue + travel * r.fatigue_per_travel_day - rest * r.rest_recovery, 0.0, 100.0)
		if other == show or (other.id == show.id and not show.id.is_empty()):
			context["fatigue"] = roundi(fatigue)
			if previous != null:
				context["previous_city"] = previous.city_id
				var gap := other.day - previous.day
				if previous.city_id != r.home_city_id and other.city_id != r.home_city_id:
					context["extra_nights"] = maxi(gap - 1, 0)
			return context
		var manager_tier: int = other.crew.get("tour_manager", 0)
		fatigue = clampf(fatigue + r.fatigue_per_show * (1.0 - manager_tier * r.manager_fatigue_reduction), 0.0, 100.0)
		previous = other
	return context


func tour_shows(career: CareerData, tour: LiveTour) -> Array[LiveShow]:
	var shows: Array[LiveShow] = []
	for show in career.live_shows:
		if show.tour_id == tour.id and show.status != LiveShow.STATUS_CANCELLED:
			shows.append(show)
	shows.sort_custom(func(a: LiveShow, b: LiveShow) -> bool: return a.day < b.day)
	return shows


## Condições sugeridas para um acordo com promotor, a partir da bilheteria esperada.
func apply_promoter_terms(career: CareerData, show: LiveShow) -> void:
	var tickets := demand(career, show, context_for(career, show), false)
	var expected_net := (tickets.x * show.ticket_price + tickets.y * show.vip_price) * (1.0 - rules().ticket_fee_rate)
	match show.model:
		LiveRules.MODEL_FIXED:
			show.fee = maxi(roundi(expected_net * 0.6), rules().min_offer_fee)
			show.percentage = 0.0
		LiveRules.MODEL_PERCENTAGE:
			show.fee = 0
			show.percentage = 0.4
		LiveRules.MODEL_FEE_PLUS_PERCENTAGE:
			show.fee = roundi(expected_net * 0.15)
			show.percentage = 0.25
		LiveRules.MODEL_GUARANTEE:
			show.fee = roundi(expected_net * 0.3)
			show.percentage = 0.45
		_:
			show.fee = 0
			show.percentage = 0.0


func terms_text(show: LiveShow) -> String:
	match show.model:
		LiveRules.MODEL_FIXED:
			return "Cachê de %s" % Fmt.money(show.fee)
		LiveRules.MODEL_PERCENTAGE:
			return "%d%% da bilheteria líquida" % roundi(show.percentage * 100)
		LiveRules.MODEL_FEE_PLUS_PERCENTAGE:
			return "%s + %d%% da bilheteria" % [Fmt.money(show.fee), roundi(show.percentage * 100)]
		LiveRules.MODEL_GUARANTEE:
			return "O maior entre %s e %d%% da bilheteria" % [Fmt.money(show.fee), roundi(show.percentage * 100)]
	if show.kind == LiveShow.KIND_FESTIVAL:
		return "Sem cachê, despesas pagas" if show.fee_model == "covered" else "Cachê de %s" % Fmt.money(show.fee)
	return "Bilheteria líquida (você assume os riscos)"


# ---- ações

func schedule_independent(career: CareerData, show: LiveShow) -> ActionResult:
	var error := _validate(career, show)
	if not error.is_empty():
		return ActionResult.failure(error)
	var projection := estimate(career, show)
	var upfront: int = projection["total_expenses"]
	if not _economy.can_afford(career, upfront):
		return _economy.insufficient_funds(upfront)
	_pay_upfront(career, show, upfront)
	show.kind = LiveShow.KIND_INDEPENDENT
	show.status = LiveShow.STATUS_SCHEDULED
	show.id = career.new_id("show")
	career.live_shows.append(show)
	return ActionResult.success("Show agendado em %s." % day_label(show.day), show)


## Aceita uma oferta com as escolhas do artista (produção, equipe, convidados e merch).
func accept_offer(career: CareerData, offer_id: String, choices: LiveShow) -> ActionResult:
	var offer := career.find_live_show(offer_id)
	if offer == null or offer.status != LiveShow.STATUS_OFFER:
		return ActionResult.failure("Oferta não encontrada.")
	if choices != null:
		offer.production_id = choices.production_id
		offer.addons = choices.addons.duplicate()
		offer.crew = choices.crew.duplicate()
		offer.guests = choices.guests.duplicate(true)
		offer.merch_enabled = choices.merch_enabled
		offer.promotion = choices.promotion
		offer.set_type = choices.set_type
	var error := guests_refusal(career, offer)
	if error.is_empty():
		error = conflict_error(career, offer)
	if not error.is_empty():
		return ActionResult.failure(error)
	var upfront: int = estimate(career, offer)["total_expenses"]
	if not _economy.can_afford(career, upfront):
		return _economy.insufficient_funds(upfront)
	_pay_upfront(career, offer, upfront)
	offer.status = LiveShow.STATUS_SCHEDULED
	if offer.kind == LiveShow.KIND_FESTIVAL:
		var edition := career.find_edition(offer.festival_edition_id)
		var slot := edition.place_player(career.artist_name, offer.lineup_position, festival_day(offer.day, edition.week), _set_minutes(offer))
		offer.stage_name = slot.get("stage", "")
		edition.application_status = FestivalEdition.APPLICATION_ACCEPTED
	return ActionResult.success("Proposta aceita: %s." % day_label(offer.day), offer)


func reject_offer(career: CareerData, offer_id: String) -> ActionResult:
	var offer := career.find_live_show(offer_id)
	if offer == null or offer.status != LiveShow.STATUS_OFFER:
		return ActionResult.failure("Oferta não encontrada.")
	career.live_shows.erase(offer)
	return ActionResult.success("Proposta recusada.")


## Shows próprios devolvem parte das despesas; cancelar um compromisso contratado afeta a reputação.
func cancel_show(career: CareerData, show_id: String) -> ActionResult:
	var show := career.find_live_show(show_id)
	if show == null or show.status != LiveShow.STATUS_SCHEDULED:
		return ActionResult.failure("Show não encontrado.")
	show.status = LiveShow.STATUS_CANCELLED
	var refund := 0
	if show.kind == LiveShow.KIND_INDEPENDENT or show.kind == LiveShow.KIND_TOUR:
		refund = roundi(show.upfront_paid * rules().cancel_refund)
		if refund > 0:
			_economy.earn(career, refund, "Reembolso de show cancelado: %s" % show.venue_name, FinanceEntry.CATEGORY_LIVE)
	else:
		_economy.add_reputation(career, -1)
	if show.kind == LiveShow.KIND_FESTIVAL:
		var edition := career.find_edition(show.festival_edition_id)
		for slot in edition.lineup:
			if slot.get("artist_id", "") == FestivalEdition.PLAYER_ID:
				slot["artist_id"] = "tba"
				slot["name"] = "Atração a confirmar"
	return ActionResult.success("Show cancelado. %s devolvidos." % Fmt.money(refund), show)


## Etapa da semana: ofertas vencidas saem, os shows da semana acontecem, a loja vende e chegam ofertas.
func process_week(career: CareerData, report: WeekReport) -> void:
	for show in career.live_shows.duplicate():
		if show.status == LiveShow.STATUS_OFFER and show.offer_expires_week < career.current_week:
			career.live_shows.erase(show)
	var due: Array[LiveShow] = []
	for show in career.live_shows:
		if show.status == LiveShow.STATUS_SCHEDULED and show.week() <= career.current_week:
			due.append(show)
	due.sort_custom(func(a: LiveShow, b: LiveShow) -> bool: return a.day < b.day)
	for show in due:
		var tour := career.find_tour(show.tour_id)
		if tour != null and (tour.status == LiveTour.STATUS_PAUSED or tour.status == LiveTour.STATUS_CANCELLED):
			show.status = LiveShow.STATUS_CANCELLED
			continue
		perform(career, show, report)
	var online := _merch.sell_online(career, _streaming.total_followers(career))
	if online["units"] > 0:
		var line := WeekReportEntry.new()
		line.title = "Loja oficial"
		line.sales = online["units"]
		line.money = online["net"]
		report.entries.append(line)
	var before := career.live_shows.size()
	generate_offers(career)
	var new_offers := career.live_shows.slice(before)
	if not new_offers.is_empty():
		var best: LiveShow = new_offers[0]
		for offer: LiveShow in new_offers:
			if offer.capacity > best.capacity:
				best = offer
		var notice := WeekReportEntry.new()
		notice.title = "%d nova(s) proposta(s) de show" % new_offers.size()
		notice.note = "Maior delas: %s, %s (%s). Responda em Shows e ofertas." % [best.event_name, day_label(best.day), terms_text(best)]
		report.entries.append(notice)


func perform(career: CareerData, show: LiveShow, report: WeekReport) -> void:
	var r := rules()
	var context := context_for(career, show)
	var tickets := demand(career, show, context, true)
	var show_quality := clampi(quality(career, show, context) + _rng.randi_range(-5, 5), 0, 100)
	var money := _money_result(career, show, tickets, show_quality)
	var attendance := tickets.x + tickets.y
	var merch_bonus := 0.0
	var buzz := show_quality * 0.6 + float(attendance) / maxf(show.capacity, 1.0) * 40.0
	for role_id in show.crew:
		var role := r.find_crew_role(role_id)
		if role != null:
			merch_bonus += role.merch_bonus * show.crew[role_id]
			buzz += role.buzz * show.crew[role_id]
	var cut := r.festival_merch_cut if show.kind == LiveShow.KIND_FESTIVAL else r.venue_merch_cut
	var merch := _merch.sell_at_show(career, show, attendance, show_quality, cut, merch_bonus)
	var impact := _impact(career, show)
	buzz += (impact - 1.0) * 5.0
	var new_fans := roundi(attendance * r.fan_rate * show_quality / 50.0)
	var fame := roundi(float(attendance) / r.attendees_per_fame * show_quality / 50.0 * impact / (1.0 + float(career.fame) / r.show_fame_softcap))
	var reputation := 1 if show_quality >= r.reputation_quality else (-1 if show_quality < 30 else 0)
	var income: int = money["artist_income"]
	if income > 0:
		_economy.earn(career, income, "Show: %s (%s)" % [show.venue_name, terms_text(show)], FinanceEntry.CATEGORY_LIVE)
	_streaming.add_followers(career, new_fans)
	_economy.add_fame(career, fame)
	_economy.add_reputation(career, reputation)
	var expenses := costs(career, show, context)
	var result := money
	result["quality"] = show_quality
	result["merch_units"] = merch["units"]
	result["merch_gross"] = merch["gross"]
	result["merch_net"] = merch["net"]
	result["expenses"] = expenses
	result["total_expenses"] = show.upfront_paid
	result["profit"] = income + merch["net"] - show.upfront_paid
	result["new_fans"] = new_fans
	result["fame"] = fame
	result["reputation"] = reputation
	result["buzz"] = roundi(buzz)
	result["buzz_label"] = _buzz_label(buzz)
	result["fatigue"] = int(context.get("fatigue", 0))
	result["week"] = career.current_week
	show.result = result
	show.status = LiveShow.STATUS_DONE
	if social != null:
		social.on_show_performed(career, show, report)
	var line := WeekReportEntry.new()
	line.title = "Show: %s" % show.venue_name
	line.note = "Público %s de %s (%d%%), qualidade %d, repercussão %s. Resultado: %s." % [
		Fmt.number(attendance), Fmt.number(show.capacity), result["occupancy"], show_quality, result["buzz_label"], Fmt.signed_money(result["profit"])
	]
	line.money = income + merch["net"]
	line.fame = fame
	report.entries.append(line)


func generate_offers(career: CareerData) -> void:
	var r := rules()
	var expected := minf(r.base_offers_per_week + career.fame * r.offers_per_fame, r.max_offers_per_week)
	var count := floori(expected) + (1 if _rng.randf() < expected - floorf(expected) else 0)
	for i in count:
		career.live_shows.append(_make_offer(career))


func history(career: CareerData) -> Array[LiveShow]:
	var done: Array[LiveShow] = []
	for show in career.live_shows:
		if show.status == LiveShow.STATUS_DONE:
			done.append(show)
	done.sort_custom(func(a: LiveShow, b: LiveShow) -> bool: return a.day > b.day)
	return done


func shows_with_status(career: CareerData, status: String) -> Array[LiveShow]:
	var result: Array[LiveShow] = []
	for show in career.live_shows:
		if show.status == status:
			result.append(show)
	result.sort_custom(func(a: LiveShow, b: LiveShow) -> bool: return a.day < b.day)
	return result


# ---- internos

func _validate(career: CareerData, show: LiveShow) -> String:
	if rules().find_city(show.city_id) == null or rules().find_venue(show.venue_id) == null:
		return "Escolha a cidade e o local."
	if show.week() <= career.current_week:
		return "Escolha uma data a partir da semana %s." % Fmt.number(career.current_week + 1)
	if show.ticket_price <= 0.0 and show.event_type != PRIVATE_EVENT:
		return "Defina o preço do ingresso."
	var refusal := guests_refusal(career, show)
	if not refusal.is_empty():
		return refusal
	return conflict_error(career, show)


## Convidados em inimizade ou beef recusam subir no palco com o jogador.
func guests_refusal(career: CareerData, show: LiveShow) -> String:
	if social == null:
		return ""
	for guest in show.guests:
		var reason := social.refusal(career, guest.get("artist_id", ""))
		if not reason.is_empty():
			return reason
	return ""


## Propostas de um amigo: subir no palco do show dele (1) ou algumas datas da turnê dele.
func partner_offers(career: CareerData, artist_id: String, artist_name: String, count: int) -> void:
	for index in count:
		var offer := _make_offer(career)
		offer.partner_id = artist_id
		offer.event_type = "Participação especial"
		offer.event_name = ("Show de %s" % artist_name) if count == 1 else ("Turnê de %s — data %d" % [artist_name, index + 1])
		offer.model = LiveRules.MODEL_FIXED
		offer.fee = maxi(roundi(offer.fee * 0.6), rules().min_offer_fee)
		offer.covers_travel = true
		offer.covers_lodging = true
		offer.day += index * 3
		career.live_shows.append(offer)


func _money_result(career: CareerData, show: LiveShow, tickets: Vector2i, show_quality: int) -> Dictionary:
	var r := rules()
	var selling_tickets := show.kind != LiveShow.KIND_FESTIVAL and show.event_type != PRIVATE_EVENT
	var gross := (tickets.x * show.ticket_price + tickets.y * show.vip_price) if selling_tickets else 0.0
	var fees := gross * r.ticket_fee_rate
	var net_box := gross - fees
	var income := _income(show, net_box, tickets.x)
	var co_share := income * r.co_headliner_revenue_share if _has_co_headliner(career, show) else 0.0
	var commission := 0.0 if show.model == LiveRules.MODEL_INDEPENDENT and show.kind != LiveShow.KIND_FESTIVAL else (income - co_share) * r.agent_commission
	var attendance := tickets.x + tickets.y
	return {
		"attendance": attendance, "sold": tickets.x, "vip_sold": tickets.y, "capacity": show.capacity,
		"occupancy": roundi(float(attendance) / maxf(show.capacity, 1.0) * 100.0),
		"gross": roundi(gross), "ticket_fees": roundi(fees), "net_box": roundi(net_box),
		"income": roundi(income), "co_share": roundi(co_share), "commission": roundi(commission),
		"artist_income": roundi(income - co_share - commission), "quality": show_quality,
	}


func _income(show: LiveShow, net_box: float, sold: int) -> float:
	if show.kind == LiveShow.KIND_FESTIVAL:
		match show.fee_model:
			"variable":
				return show.fee * clampf(float(sold) / maxf(show.capacity, 1.0), 0.5, 1.2)
			"covered":
				return 0.0
		return show.fee
	match show.model:
		LiveRules.MODEL_FIXED:
			return show.fee
		LiveRules.MODEL_PERCENTAGE:
			return net_box * show.percentage
		LiveRules.MODEL_FEE_PLUS_PERCENTAGE:
			return show.fee + net_box * show.percentage
		LiveRules.MODEL_GUARANTEE:
			return maxf(show.fee, net_box * show.percentage)
	return net_box


func _merch_estimate(career: CareerData, show: LiveShow, attendance: int, show_quality: int) -> int:
	if not show.merch_enabled:
		return 0
	var r := rules()
	var cut := r.festival_merch_cut if show.kind == LiveShow.KIND_FESTIVAL else r.venue_merch_cut
	var total := 0.0
	var budget := attendance * r.max_show_buy_rate
	for item in career.merch_items:
		if item.stock <= 0 or (item.exclusive_kind == MerchItem.EXCLUSIVE_TOUR and item.exclusive_id != show.tour_id):
			continue
		if item.exclusive_kind == MerchItem.EXCLUSIVE_SHOW and item.exclusive_id != show.id:
			continue
		var product := r.find_product(item.product_id)
		var price_factor := clampf(pow(float(product.suggested_price) / maxf(item.price, 1.0), r.merch_price_elasticity), 0.05, 2.0)
		var units := minf(minf(attendance * r.show_buy_rate * product.appeal * price_factor * show_quality / 60.0, item.stock), budget)
		budget -= units
		total += units * item.price * (1.0 - cut)
	return roundi(total)


func _impact(career: CareerData, show: LiveShow) -> float:
	var r := rules()
	var impact := 1.0
	if show.kind == LiveShow.KIND_FESTIVAL:
		var edition := career.find_edition(show.festival_edition_id)
		var festival := r.find_festival(edition.festival_id) if edition != null else null
		var prestige := festival.prestige if festival != null else 50
		impact = float(r.position_impact.get(show.lineup_position, 1.0)) * prestige / 50.0
		if show.set_type == "reduced":
			impact *= r.reduced_set_factor
	var tour := career.find_tour(show.tour_id)
	if tour != null:
		var best := 1.0
		for type_id in tour.types:
			var type := r.find_tour_type(type_id)
			if type != null:
				best = maxf(best, type.fame_multiplier)
		impact *= best
	return impact


func _pay_upfront(career: CareerData, show: LiveShow, upfront: int) -> void:
	show.upfront_paid = upfront
	if upfront > 0:
		_economy.spend(career, upfront, "Despesas de show: %s (%s)" % [show.venue_name, day_label(show.day)], FinanceEntry.CATEGORY_LIVE)


func _make_offer(career: CareerData) -> LiveShow:
	var r := rules()
	var city := _pick_city(career)
	var show := LiveShow.new()
	show.kind = LiveShow.KIND_CONTRACTED
	show.status = LiveShow.STATUS_OFFER
	show.id = career.new_id("offer")
	apply_venue(show, city.id, "bar")
	var potential := potential_audience(career, show)
	var venue_id := "bar"
	for venue in r.venues:
		if venue.min_capacity <= potential * 1.1:
			venue_id = venue.id
	if venue_id != "bar" and _rng.randf() < 0.3:
		venue_id = r.venues[maxi(_venue_index(venue_id) - 1, 0)].id
	apply_venue(show, city.id, venue_id)
	var venue := r.find_venue(venue_id)
	show.ticket_price = venue.base_ticket_price * price_fame_multiplier(career)
	show.vip_price = show.ticket_price * r.vip_price_multiplier
	var events: Array = OFFER_EVENTS.get(venue_id, ["Show"])
	show.event_type = events[_rng.randi() % events.size()]
	var tickets := demand(career, show, {}, false)
	var expected_net := tickets.x * show.ticket_price * (1.0 - r.ticket_fee_rate)
	var importance := 1.0 + _venue_index(venue_id) * 0.05
	var base_fee := maxf(expected_net * r.offer_fee_share * importance, r.min_offer_fee)
	var roll := _rng.randf()
	if _rng.randf() < r.private_event_chance:
		show.event_type = PRIVATE_EVENT
		show.model = LiveRules.MODEL_FIXED
		show.fee = roundi(base_fee * r.private_event_fee_multiplier)
		show.capacity = mini(show.capacity, 500)
	elif roll < 0.4:
		show.model = LiveRules.MODEL_FIXED
		show.fee = roundi(base_fee)
	elif roll < 0.6:
		show.model = LiveRules.MODEL_PERCENTAGE
		show.percentage = 0.3 + _rng.randf() * 0.15
	elif roll < 0.8:
		show.model = LiveRules.MODEL_FEE_PLUS_PERCENTAGE
		show.fee = roundi(base_fee * 0.5)
		show.percentage = 0.2
	else:
		show.model = LiveRules.MODEL_GUARANTEE
		show.fee = roundi(base_fee * 0.8)
		show.percentage = 0.45
	if city.id != r.home_city_id and _rng.randf() < 0.6:
		show.covers_travel = true
		show.covers_lodging = true
	show.event_name = "%s em %s" % [show.event_type, city.display_name]
	show.day = first_day_of_week(career.current_week + _rng.randi_range(r.offer_lead_min, r.offer_lead_max)) + _rng.randi_range(3, 6)
	show.offer_expires_week = career.current_week + r.offer_expiry_weeks
	return show


func _pick_city(career: CareerData) -> CityDefinition:
	var r := rules()
	var total := 0.0
	var weights: Array[float] = []
	for city in r.cities:
		var weight := city.market * city.rap_scene * reach(career, city) * (2.0 if city.id == r.home_city_id else 1.0)
		weights.append(weight)
		total += weight
	var roll := _rng.randf() * total
	for index in weights.size():
		roll -= weights[index]
		if roll <= 0.0:
			return r.cities[index]
	return r.find_city(r.home_city_id)


func _venue_index(venue_id: String) -> int:
	for index in rules().venues.size():
		if rules().venues[index].id == venue_id:
			return index
	return 0


func _recent_shows_in_city(career: CareerData, show: LiveShow) -> int:
	var count := 0
	for other in career.live_shows:
		if other.status == LiveShow.STATUS_DONE and other.city_id == show.city_id and other.id != show.id:
			if show.week() - other.week() <= rules().city_saturation_weeks:
				count += 1
	return count


func _has_recent_release(career: CareerData) -> bool:
	for release in career.releases:
		if career.current_week - release.release_week <= rules().recent_release_weeks:
			return true
	return false


func _catalog_quality(career: CareerData) -> float:
	var qualities: Array[int] = []
	for song in career.songs:
		if song.is_released():
			qualities.append(song.quality)
	if qualities.is_empty():
		return 40.0
	qualities.sort()
	qualities.reverse()
	var top := qualities.slice(0, 5)
	var total := 0
	for value in top:
		total += value
	return float(total) / top.size()


## Convidados do show e, numa turnê conjunta, o co-headliner da turnê.
func _all_guests(career: CareerData, show: LiveShow) -> Array[Dictionary]:
	var guests: Array[Dictionary] = []
	for guest in show.guests:
		var person := _person(guest.get("artist_id", ""))
		if person != null:
			guests.append({"person": person, "role": guest.get("role", "guest")})
	var tour := career.find_tour(show.tour_id)
	if tour != null and not tour.co_headliner_id.is_empty():
		var partner := _person(tour.co_headliner_id)
		if partner != null:
			guests.append({"person": partner, "role": "co_headliner"})
	return guests


func _has_co_headliner(career: CareerData, show: LiveShow) -> bool:
	for guest in _all_guests(career, show):
		if guest["role"] == "co_headliner":
			return true
	return false


func _person(artist_id: String) -> CollaboratorDefinition:
	var ids: Array[String] = [artist_id]
	var people := CollaboratorCatalog.resolve(_balance.collaborators.feats, ids)
	return people[0] if not people.is_empty() else null


func _set_minutes(show: LiveShow) -> int:
	var minutes: int = rules().position_minutes.get(show.lineup_position, 45)
	return roundi(minutes * (rules().reduced_set_factor if show.set_type == "reduced" else 1.0))


func _buzz_label(buzz: float) -> String:
	if buzz >= 80:
		return "Histórica"
	if buzz >= 60:
		return "Ótima"
	if buzz >= 40:
		return "Boa"
	return "Discreta"


func _sum(values: Dictionary) -> int:
	var total := 0
	for key: Variant in values:
		total += int(values[key])
	return total
