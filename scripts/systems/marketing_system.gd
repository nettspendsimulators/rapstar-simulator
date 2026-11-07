class_name MarketingSystem
extends RefCounted
## Campanhas de marketing de músicas e projetos. Ações são planejadas livremente, pagas e iniciadas
## pelo ReleaseSystem ao agendar, avançam na semana e geram o resultado quando o conteúdo sai.
## O marketing amplia alcance e potencial, mas nunca devolve dinheiro diretamente.

## Números de uma campanha em um dado momento.
class Forecast:
	var reach: int = 0
	var hype: int = 0


var _balance: GameBalance
var _economy: EconomySystem
var _rng: RandomNumberGenerator


func _init(balance: GameBalance, economy: EconomySystem, rng: RandomNumberGenerator) -> void:
	_balance = balance
	_economy = economy
	_rng = rng


## Em uma campanha em andamento, a ação é paga na hora e começa com menos tempo que as outras.
func add_action(career: CareerData, content_id: String, action_id: String) -> ActionResult:
	var content := career.find_content(content_id)
	if content == null:
		return ActionResult.failure("Conteúdo não encontrado.")
	if content.is_released():
		return ActionResult.failure("\"%s\" já foi lançado." % content.title)
	var definition := _rules().find_action(action_id)
	if definition == null:
		return ActionResult.failure("Ação inválida.")
	var campaign := career.find_campaign(content_id)
	if campaign != null and campaign.find_action(action_id) != null:
		return ActionResult.failure("%s já está na campanha." % definition.display_name)
	if not definition.meets_requirements(career):
		return ActionResult.failure("%s exige: %s." % [definition.display_name, definition.requirements_text()])
	var planned_cost := unpaid_cost(career, content_id)
	if not _economy.can_afford(career, planned_cost + definition.cost):
		return _economy.insufficient_funds(planned_cost + definition.cost)

	if campaign == null:
		campaign = MarketingCampaign.new()
		campaign.content_id = content_id
		career.marketing_campaigns.append(campaign)
	if career.find_active_schedule(content_id) != null:
		campaign.status = MarketingCampaign.STATUS_ACTIVE
	var action := MarketingCampaign.Action.new()
	action.action_id = action_id
	campaign.actions.append(action)
	if campaign.is_active():
		_pay(career, content, action, definition)
		_refresh_hype(career, campaign)
		return ActionResult.success("%s adicionado à campanha por %s." % [definition.display_name, Fmt.money(definition.cost)], campaign)
	return ActionResult.success("%s planejado. O pagamento acontece ao agendar." % definition.display_name, campaign)


## Só ações ainda não pagas podem sair da campanha.
func remove_action(career: CareerData, content_id: String, action_id: String) -> ActionResult:
	var campaign := career.find_campaign(content_id)
	var action := campaign.find_action(action_id) if campaign != null else null
	if action == null:
		return ActionResult.failure("Esta ação não está na campanha.")
	if campaign.is_completed():
		return ActionResult.failure("A campanha já terminou.")
	if action.is_paid():
		return ActionResult.failure("Esta ação já foi paga e não pode sair da campanha.")
	campaign.actions.erase(action)
	return ActionResult.success("%s removido da campanha." % _rules().find_action(action_id).display_name, campaign)


## Quanto ainda falta pagar pelas ações planejadas do conteúdo.
func unpaid_cost(career: CareerData, content_id: String) -> int:
	var campaign := career.find_campaign(content_id)
	if campaign == null:
		return 0
	var total := 0
	for action in campaign.actions:
		if not action.is_paid():
			total += _rules().find_action(action.action_id).cost
	return total


## Chamado ao agendar. Quem chama deve garantir o dinheiro de unpaid_cost.
func start_campaign(career: CareerData, content_id: String) -> void:
	var campaign := career.find_campaign(content_id)
	if campaign == null or campaign.actions.is_empty():
		return
	var content := career.find_content(content_id)
	for action in campaign.actions:
		if not action.is_paid():
			_pay(career, content, action, _rules().find_action(action.action_id))
	campaign.status = MarketingCampaign.STATUS_ACTIVE
	_refresh_hype(career, campaign)


## Chamado ao cancelar o agendamento. O dinheiro não volta, mas o que já foi pago
## continua valendo para um novo agendamento.
func pause_campaign(career: CareerData, content_id: String) -> void:
	var campaign := career.find_campaign(content_id)
	if campaign != null and campaign.is_active():
		campaign.status = MarketingCampaign.STATUS_PLANNING


## Etapa da semana: campanhas em andamento ganham uma semana de promoção.
func process_week(career: CareerData, report: WeekReport) -> void:
	for campaign in career.marketing_campaigns:
		if not campaign.is_active():
			continue
		for action in campaign.actions:
			action.weeks_active += 1
		_refresh_hype(career, campaign)
		var content := career.find_content(campaign.content_id)
		var line := WeekReportEntry.new()
		line.title = "Campanha: %s" % content.title
		line.cover_file = content.cover_file
		line.note = "Expectativa em %d." % campaign.hype
		report.entries.append(line)


## Chamado quando o conteúdo sai. Ações não pagas são descartadas.
## Devolve o multiplicador de streams da primeira semana.
func finish_campaign(career: CareerData, content: ReleasableContent, report: WeekReport = null) -> float:
	var campaign := career.find_campaign(content.id)
	if campaign == null or campaign.is_completed():
		return 1.0
	campaign.actions = campaign.actions.filter(func(action: MarketingCampaign.Action) -> bool: return action.is_paid())
	if campaign.actions.is_empty():
		career.marketing_campaigns.erase(campaign)
		return 1.0
	_refresh_hype(career, campaign)
	campaign.result = _generate_result(career, content, campaign)
	campaign.status = MarketingCampaign.STATUS_COMPLETED
	if report != null:
		var line := WeekReportEntry.new()
		line.title = "Resultado da campanha: %s" % content.title
		line.cover_file = content.cover_file
		line.note = "%s. Alcance %s, expectativa %d, %s pré-saves, %s novos fãs." % [
			campaign.result.outcome_label,
			Fmt.number(campaign.result.reach),
			campaign.result.expectation,
			Fmt.number(campaign.result.pre_saves),
			Fmt.number(campaign.result.new_fans),
		]
		report.entries.append(line)
	return campaign.result.initial_potential


## Multiplicador de streams de um lançamento em uma semana. O bônus cai com o tempo.
func units_multiplier(release_entry: ReleaseData, age_weeks: int) -> float:
	return 1.0 + (release_entry.initial_potential - 1.0) * pow(_rules().initial_bonus_decay, age_weeks)


## Um vazamento antecipa parte da novidade e reduz a expectativa da campanha.
func apply_leak(career: CareerData, content_id: String, penalty: int) -> void:
	var campaign := career.find_campaign(content_id)
	if campaign != null and not campaign.is_completed():
		campaign.leak_penalty += penalty
		_refresh_hype(career, campaign)


## Previsão da campanha se ela tiver extra_weeks semanas a mais antes do lançamento.
func forecast(career: CareerData, content_id: String, extra_weeks: int = 0) -> Forecast:
	var result := Forecast.new()
	var campaign := career.find_campaign(content_id)
	if campaign == null or campaign.actions.is_empty():
		return result
	var content := career.find_content(content_id)
	var reach := 0.0
	var raw_hype := 0.0
	for action in campaign.actions:
		var definition := _rules().find_action(action.action_id)
		var efficiency := timing_efficiency(definition, action.weeks_active + extra_weeks)
		reach += definition.reach * efficiency
		raw_hype += definition.hype_impact * efficiency
	var rules := _rules()
	reach *= 1.0 + career.fame * rules.reach_per_fame_point
	var quality_factor := lerpf(rules.quality_factor_min, rules.quality_factor_max, content.quality / 100.0)
	var fame_factor := minf(1.0 + career.fame * rules.hype_per_fame_point, rules.max_fame_hype_factor)
	var synergy := 1.0 + (campaign.actions.size() - 1) * rules.synergy_per_extra_action
	var hype := raw_hype * quality_factor * fame_factor * synergy + _magnitude(reach) * rules.hype_per_reach_magnitude
	result.reach = roundi(reach)
	result.hype = clampi(roundi(hype) - campaign.leak_penalty, 0, 100)
	return result


## Pouco tempo reduz a eficiência da ação, e tempo demais também: o público perde o interesse.
func timing_efficiency(definition: MarketingActionDefinition, weeks: int) -> float:
	var rules := _rules()
	if weeks < definition.duration_weeks:
		return lerpf(rules.min_timing_efficiency, 1.0, float(weeks) / definition.duration_weeks)
	var overrun := weeks - definition.duration_weeks
	return maxf(1.0 - overrun * rules.overrun_efficiency_loss, rules.overrun_efficiency_floor)


func _generate_result(career: CareerData, content: ReleasableContent, campaign: MarketingCampaign) -> MarketingResult:
	var rules := _rules()
	var current := forecast(career, content.id)
	var outcome := _roll_outcome()
	var average_return := 0.0
	var pre_save_potential := 0.0
	for action in campaign.actions:
		var definition := rules.find_action(action.action_id)
		average_return += definition.return_potential
		pre_save_potential += definition.reach * timing_efficiency(definition, action.weeks_active) * definition.pre_save_rate
	average_return /= campaign.actions.size()

	var result := MarketingResult.new()
	result.outcome_id = outcome.id
	result.outcome_label = outcome.label
	result.reach = roundi(current.reach * outcome.multiplier)
	result.expectation = clampi(roundi(current.hype * outcome.multiplier), 0, 100)
	result.pre_saves = roundi(pre_save_potential * result.expectation / 100.0 * outcome.multiplier)
	result.new_fans = roundi(result.reach * rules.new_fan_rate * average_return * content.quality / 100.0)
	result.exposure = clampi(roundi(_magnitude(result.reach) * rules.exposure_per_reach_magnitude), 0, 100)
	result.popularity = result.new_fans / rules.new_fans_per_popularity_point
	# A qualidade limita o bônus: uma música fraca não aproveita toda a expectativa.
	var bonus := rules.max_initial_bonus * result.expectation / 100.0 * content.quality / 100.0 * average_return
	result.initial_potential = 1.0 + minf(bonus, rules.max_initial_bonus)
	return result


func _roll_outcome() -> MarketingOutcomeDefinition:
	var outcomes := _rules().outcomes
	var total := 0.0
	for outcome in outcomes:
		total += outcome.weight
	var roll := _rng.randf() * total
	for outcome in outcomes:
		roll -= outcome.weight
		if roll <= 0.0:
			return outcome
	return outcomes.back()


func _pay(career: CareerData, content: ReleasableContent, action: MarketingCampaign.Action, definition: MarketingActionDefinition) -> void:
	var description := "Marketing (%s): %s" % [definition.display_name, content.title]
	_economy.spend(career, definition.cost, description, FinanceEntry.CATEGORY_MARKETING)
	action.paid_cost = definition.cost


func _refresh_hype(career: CareerData, campaign: MarketingCampaign) -> void:
	campaign.hype = forecast(career, campaign.content_id).hype


func _magnitude(reach: float) -> float:
	return log(reach + 1.0) / log(10.0)


func _rules() -> MarketingRules:
	return _balance.marketing
