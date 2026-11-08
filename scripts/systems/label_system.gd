class_name LabelSystem
extends RefCounted
## Gravadoras: propostas, contrato, rescisão, a gravadora do jogador e os artistas dela.
## Não há economia paralela: o dinheiro do artista passa pelo EconomySystem (que também divide as
## receitas de música e aplica a ajuda nos custos), e a gravadora própria tem um caixa com
## livro-caixa, abastecido por depósitos da carreira e pelo faturamento dos contratados.
## Os sorteios usam um gerador próprio por semana, para não mudar o resto do jogo.

const STARTING_BALANCE_RATE := 0.3
const SHAPES := ["circle", "hex", "diamond", "square", "shield"]
const TITLE_WORDS_A := ["Noite", "Rua", "Ouro", "Fumaça", "Neon", "Vento", "Asfalto", "Lua", "Fogo", "Corre"]
const TITLE_WORDS_B := ["Fria", "Alta", "Lenta", "Sem Fim", "de Vidro", "Selvagem", "na Pista", "Quente", "Livre", "Real"]

var _balance: GameBalance
var _economy: EconomySystem
var social: SocialSystem


func _init(balance: GameBalance, economy: EconomySystem) -> void:
	_balance = balance
	_economy = economy


func rules() -> LabelRules:
	return _balance.labels


func find_label(label_id: String) -> LabelDefinition:
	return rules().find_label(label_id)


func mode(career: CareerData) -> String:
	return career.label.mode(career.current_week)


func level(career: CareerData) -> LabelLevelDefinition:
	var own := career.label.own
	var levels := rules().levels
	return levels[clampi(own.level if own != null else 0, 0, levels.size() - 1)]


func next_level(career: CareerData) -> LabelLevelDefinition:
	var own := career.label.own
	if own == null or own.level + 1 >= rules().levels.size():
		return null
	return rules().levels[own.level + 1]


# ---- propostas

## Quanto o mercado quer o artista agora: fama, reputação, público e lançamentos recentes.
func market_score(career: CareerData, label: LabelDefinition) -> float:
	var fame_ratio := clampf(float(career.fame) / maxf(label.min_fame, 60.0), 0.0, 3.0)
	var recent := 0
	for report in career.week_reports.slice(-4):
		recent += report.plays
	var buzz := 1.0 + clampf(recent / 200000.0, 0.0, 1.5)
	var reputation := clampf(1.0 + career.reputation / 100.0, 0.5, 1.6)
	return fame_ratio * buzz * reputation


## Gravadoras que podem se interessar: fama perto do mínimo delas e sem selo próprio.
func interested(career: CareerData) -> Array[LabelDefinition]:
	var result: Array[LabelDefinition] = []
	if career.label.own != null or career.label.active_contract(career.current_week) != null:
		return result
	for label in rules().labels:
		if career.fame >= label.min_fame * 0.8:
			result.append(label)
	return result


## Termos de uma proposta desta gravadora para esta carreira.
func build_offer(career: CareerData, label: LabelDefinition, renewal: bool = false) -> LabelOffer:
	var offer := LabelOffer.new()
	offer.id = "label_offer_%d" % career.label.next_offer
	career.label.next_offer += 1
	offer.label_id = label.id
	offer.week = career.current_week
	offer.expires_week = career.current_week + rules().offer_weeks_valid
	offer.weeks = label.contract_weeks
	var pull := clampf(float(career.fame) / maxf(label.min_fame, 100.0), 0.6, rules().max_advance_multiplier)
	offer.advance = roundi(label.base_advance * pull / 500.0) * 500
	offer.artist_share = label.artist_share
	if renewal and career.label.contract != null and career.label.contract.recoup_left == 0:
		offer.artist_share = minf(label.artist_share + rules().renewal_share_bonus, 0.9)
	offer.marketing_support = label.marketing_support
	offer.video_support = label.video_support
	offer.release_support = label.release_support
	offer.budget = roundi(label.budget * clampf(pull, 0.8, 1.5) / 500.0) * 500
	offer.discovery_bonus = label.discovery_bonus
	offer.show_bonus = label.show_bonus
	offer.renewal = renewal
	return offer


func generate_offers(career: CareerData, report: WeekReport, rng: RandomNumberGenerator) -> void:
	var pending := career.label.offers
	for label in interested(career):
		if pending.size() >= rules().max_pending_offers:
			return
		if pending.any(func(item: LabelOffer) -> bool: return item.label_id == label.id):
			continue
		var chance := rules().offer_chance * label.offer_weight * minf(market_score(career, label), 2.5)
		if rng.randf() < chance:
			var offer := build_offer(career, label)
			pending.append(offer)
			_note(report, "Proposta da %s" % label.display_name, "%s, %d%% das receitas para você e %s de adiantamento. Veja em Carreira → Gravadora." % [
				label.tier_label(), roundi(offer.artist_share * 100), Fmt.money(offer.advance)])


func accept_block(career: CareerData, offer_id: String) -> String:
	var offer := career.label.find_offer(offer_id)
	if offer == null:
		return "Proposta não encontrada."
	if offer.expires_week < career.current_week:
		return "Esta proposta expirou."
	if career.label.active_contract(career.current_week) != null:
		return "Você já tem contrato com uma gravadora."
	if career.label.own != null:
		return "Você tem a sua própria gravadora."
	return ""


## Aceitar: o contrato começa nesta semana e o adiantamento entra no caixa do artista.
func accept_offer(career: CareerData, offer_id: String) -> ActionResult:
	var block := accept_block(career, offer_id)
	if not block.is_empty():
		return ActionResult.failure(block)
	var offer := career.label.find_offer(offer_id)
	var label := find_label(offer.label_id)
	var contract := LabelContract.new()
	contract.label_id = offer.label_id
	contract.start_week = career.current_week
	contract.end_week = career.current_week + offer.weeks
	contract.artist_share = offer.artist_share
	contract.advance = offer.advance
	contract.recoup_left = offer.advance
	contract.marketing_support = offer.marketing_support
	contract.video_support = offer.video_support
	contract.release_support = offer.release_support
	contract.budget = offer.budget
	contract.budget_left = offer.budget
	contract.discovery_bonus = offer.discovery_bonus
	contract.show_bonus = offer.show_bonus
	career.label.contract = contract
	career.label.offers.clear()
	career.label.periods.append({"label": label.display_name, "short": label.short, "from": career.current_week, "to": -1})
	_history(career, "Contrato com a %s por %d semanas (%d%% para você)." % [label.display_name, offer.weeks, roundi(offer.artist_share * 100)])
	if offer.advance > 0:
		_economy.earn(career, offer.advance, "Adiantamento da %s" % label.display_name, FinanceEntry.CATEGORY_LABEL)
	return ActionResult.success("Contrato assinado com a %s. Adiantamento de %s; ele é recuperado das suas receitas de música." % [label.display_name, Fmt.money(offer.advance)], contract)


func decline_offer(career: CareerData, offer_id: String) -> ActionResult:
	var offer := career.label.find_offer(offer_id)
	if offer == null:
		return ActionResult.failure("Proposta não encontrada.")
	career.label.offers.erase(offer)
	var label := find_label(offer.label_id)
	_history(career, "Recusou a proposta da %s." % label.display_name)
	return ActionResult.success("Proposta da %s recusada. Você segue independente." % label.display_name)


## Sair antes do fim: paga o que falta do adiantamento mais uma multa.
func termination_fee(career: CareerData) -> int:
	var contract := career.label.active_contract(career.current_week)
	if contract == null:
		return 0
	return contract.recoup_left + roundi(contract.advance * rules().termination_fee_rate)


func terminate(career: CareerData) -> ActionResult:
	var contract := career.label.active_contract(career.current_week)
	if contract == null:
		return ActionResult.failure("Você não tem contrato ativo.")
	var fee := termination_fee(career)
	if not _economy.can_afford(career, fee):
		return ActionResult.failure("A rescisão custa %s e faltam %s." % [Fmt.money(fee), Fmt.money(fee - career.money)])
	var label := find_label(contract.label_id)
	if fee > 0:
		_economy.spend(career, fee, "Rescisão com a %s" % label.display_name, FinanceEntry.CATEGORY_LABEL)
	contract.status = LabelContract.STATUS_TERMINATED
	contract.end_week = career.current_week
	_close_period(career)
	_history(career, "Rescindiu o contrato com a %s (%s)." % [label.display_name, Fmt.money(fee)])
	return ActionResult.success("Contrato com a %s encerrado. Você voltou a ser independente." % label.display_name)


# ---- gravadora própria

func create_block(career: CareerData, label_name: String) -> String:
	if career.label.own != null:
		return "Você já tem uma gravadora."
	if career.label.active_contract(career.current_week) != null:
		return "Enquanto tiver contrato com outra gravadora, não dá para abrir a sua."
	if label_name.strip_edges().length() < 2:
		return "Dê um nome à gravadora."
	if career.fame < rules().creation_min_fame:
		return "Precisa de %s de fama para abrir uma gravadora (você tem %s)." % [Fmt.number(rules().creation_min_fame), Fmt.number(career.fame)]
	if not _economy.can_afford(career, rules().creation_cost):
		return "Abrir a gravadora custa %s; faltam %s." % [Fmt.money(rules().creation_cost), Fmt.money(rules().creation_cost - career.money)]
	return ""


## Fundação: paga o custo, e parte dele vira o caixa inicial da gravadora.
func create_label(career: CareerData, label_name: String, short: String, shape: String, color: Color, color2: Color) -> ActionResult:
	var block := create_block(career, label_name)
	if not block.is_empty():
		return ActionResult.failure(block)
	var own := OwnLabel.new()
	own.name = label_name.strip_edges()
	own.short = (short.strip_edges() if not short.strip_edges().is_empty() else _initials(own.name)).to_upper().left(4)
	own.shape = shape if shape in SHAPES else "circle"
	own.color = color
	own.color2 = color2
	own.founded_week = career.current_week
	_economy.spend(career, rules().creation_cost, "Fundação da gravadora %s" % own.name, FinanceEntry.CATEGORY_LABEL)
	own.add_entry(career.current_week, roundi(rules().creation_cost * STARTING_BALANCE_RATE), "Caixa inicial", "transfer")
	career.label.own = own
	career.label.offers.clear()
	career.label.periods.append({"label": own.name, "short": own.short, "from": career.current_week, "to": -1})
	_history(career, "Fundou a gravadora %s." % own.name)
	return ActionResult.success("%s fundada! Seus lançamentos agora saem pelo seu selo." % own.name, own)


func deposit(career: CareerData, amount: int) -> ActionResult:
	var own := career.label.own
	if own == null or amount <= 0:
		return ActionResult.failure("Informe um valor.")
	if not _economy.can_afford(career, amount):
		return _economy.insufficient_funds(amount)
	_economy.spend(career, amount, "Depósito na gravadora %s" % own.name, FinanceEntry.CATEGORY_LABEL)
	own.add_entry(career.current_week, amount, "Depósito do dono", "transfer")
	return ActionResult.success("%s depositados na %s." % [Fmt.money(amount), own.name])


func withdraw(career: CareerData, amount: int) -> ActionResult:
	var own := career.label.own
	if own == null or amount <= 0:
		return ActionResult.failure("Informe um valor.")
	if amount > own.balance:
		return ActionResult.failure("A gravadora tem só %s em caixa." % Fmt.money(maxi(own.balance, 0)))
	own.add_entry(career.current_week, -amount, "Saque do dono", "transfer")
	_economy.earn(career, amount, "Saque da gravadora %s" % own.name, FinanceEntry.CATEGORY_LABEL)
	return ActionResult.success("%s sacados da %s." % [Fmt.money(amount), own.name])


func upgrade_block(career: CareerData) -> String:
	var own := career.label.own
	if own == null:
		return "Você não tem gravadora."
	var next := next_level(career)
	if next == null:
		return "A gravadora já está no nível máximo."
	if own.reputation < next.min_reputation:
		return "Precisa de %d de reputação (a gravadora tem %d)." % [next.min_reputation, floori(own.reputation)]
	if own.balance < next.upgrade_cost:
		return "Faltam %s no caixa da gravadora." % Fmt.money(next.upgrade_cost - maxi(own.balance, 0))
	return ""


func upgrade(career: CareerData) -> ActionResult:
	var block := upgrade_block(career)
	if not block.is_empty():
		return ActionResult.failure(block)
	var own := career.label.own
	var next := next_level(career)
	own.add_entry(career.current_week, -next.upgrade_cost, "Expansão para %s" % next.display_name, "investment")
	own.level += 1
	_history(career, "%s virou uma gravadora %s." % [own.name, next.display_name])
	return ActionResult.success("%s agora é %s: até %d artistas e mais alcance." % [own.name, next.display_name, next.max_artists])


## Artistas que a gravadora do jogador pode contratar: os do jogo que não são de outra gravadora.
func signable_artists(career: CareerData) -> Array[CollaboratorDefinition]:
	var taken: Array[String] = []
	for label in rules().labels:
		taken.append_array(label.roster)
	var result: Array[CollaboratorDefinition] = []
	for person in _balance.collaborators.feats:
		var artist_id := String(person.id)
		if artist_id in taken:
			continue
		if career.label.own != null and career.label.own.find_artist(artist_id) != null:
			continue
		result.append(person)
	result.sort_custom(func(a: CollaboratorDefinition, b: CollaboratorDefinition) -> bool: return a.cost < b.cost)
	return result


## Gravadora de um artista do jogo ("" = livre). A do jogador conta.
func label_of_artist(career: CareerData, artist_id: String) -> String:
	if career.label.own != null and career.label.own.find_artist(artist_id) != null:
		return career.label.own.name
	for label in rules().labels:
		if artist_id in label.roster:
			return label.display_name
	return ""


func signing_fee(career: CareerData, artist_id: String) -> int:
	var person := _person(artist_id)
	if person == null:
		return 0
	var fee := person.cost * rules().signing_fee_factor
	var relation := _relation(career, artist_id)
	if relation >= rules().friend_value:
		fee *= 1.0 - rules().friend_discount
	return roundi(fee / 100.0) * 100


func sign_block(career: CareerData, artist_id: String) -> String:
	var own := career.label.own
	if own == null:
		return "Você não tem gravadora."
	var person := _person(artist_id)
	if person == null:
		return "Artista não encontrado."
	if not label_of_artist(career, artist_id).is_empty():
		return "%s já tem gravadora." % person.display_name
	if own.artists.size() >= level(career).max_artists:
		return "O nível %s comporta %d artistas. Expanda a gravadora para contratar mais." % [level(career).display_name, level(career).max_artists]
	if _relation(career, artist_id) <= rules().rival_value:
		return "%s não quer assinar com você." % person.display_name
	var fee := signing_fee(career, artist_id)
	if own.balance < fee:
		return "A contratação custa %s; faltam %s no caixa da gravadora." % [Fmt.money(fee), Fmt.money(fee - maxi(own.balance, 0))]
	return ""


func sign_artist(career: CareerData, artist_id: String) -> ActionResult:
	var block := sign_block(career, artist_id)
	if not block.is_empty():
		return ActionResult.failure(block)
	var own := career.label.own
	var person := _person(artist_id)
	var signed := SignedArtist.new()
	signed.artist_id = artist_id
	signed.signed_week = career.current_week
	signed.end_week = career.current_week + rules().signed_contract_weeks
	signed.signing_fee = signing_fee(career, artist_id)
	signed.weekly_cost = maxi(roundi(person.cost * rules().artist_weekly_cost_rate), 50)
	signed.label_share = rules().label_share_of_artists
	own.add_entry(career.current_week, -signed.signing_fee, "Contratação de %s" % person.display_name, "signing")
	own.artists.append(signed)
	_history(career, "%s assinou com a %s." % [person.display_name, own.name])
	return ActionResult.success("%s agora é da %s, por %d semanas." % [person.display_name, own.name, rules().signed_contract_weeks], signed)


func release_artist(career: CareerData, artist_id: String) -> ActionResult:
	var own := career.label.own
	var signed := own.find_artist(artist_id) if own != null else null
	if signed == null:
		return ActionResult.failure("Este artista não é da sua gravadora.")
	own.artists.erase(signed)
	_history(career, "%s saiu da %s." % [_display(artist_id), own.name])
	return ActionResult.success("Contrato com %s encerrado." % _display(artist_id))


# ---- catálogo

## Lançamentos do jogador feitos sob um selo (contrato ou gravadora própria), do mais novo ao mais antigo.
func player_catalog(career: CareerData) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for release in career.releases:
		for period in career.label.periods:
			var to := int(period["to"])
			if release.release_week >= int(period["from"]) and (to < 0 or release.release_week < to):
				var content := career.find_content(release.content_id)
				result.append({"title": content.title if content != null else "—", "kind": release.content_type, "week": release.release_week,
					"streams": release.total_streams, "revenue": release.total_money, "label": period["label"], "artist": career.artist_name})
				break
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["week"] > b["week"])
	return result


# ---- semana

func process_week(career: CareerData, report: WeekReport) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([career.current_week, career.next_id, career.fame, career.artist_name])
	var data := career.label
	data.offers.assign(data.offers.filter(func(offer: LabelOffer) -> bool: return offer.expires_week >= career.current_week))
	var contract := data.contract
	if contract != null and contract.status == LabelContract.STATUS_ACTIVE and career.current_week >= contract.end_week:
		contract.status = LabelContract.STATUS_ENDED
		_close_period(career)
		var label := find_label(contract.label_id)
		_history(career, "Contrato com a %s terminou." % label.display_name)
		var renewal := build_offer(career, label, true)
		renewal.expires_week = career.current_week + rules().offer_weeks_valid + 1
		data.offers.append(renewal)
		_note(report, "Contrato encerrado", "Seu contrato com a %s acabou. Ela propôs renovar; você também pode seguir independente ou abrir sua gravadora." % label.display_name)
	else:
		generate_offers(career, report, rng)
	if data.own != null:
		_process_own_label(career, report, rng)


func _process_own_label(career: CareerData, report: WeekReport, rng: RandomNumberGenerator) -> void:
	var own := career.label.own
	var lvl := level(career)
	var week_income := 0
	var week_costs := 0
	for signed in own.artists.duplicate():
		if not signed.is_active(career.current_week):
			own.artists.erase(signed)
			_history(career, "Contrato de %s com a %s terminou." % [_display(signed.artist_id), own.name])
			continue
		var person := _person(signed.artist_id)
		var revenue := roundi(person.cost * rules().artist_weekly_revenue_rate * lvl.artist_revenue_multiplier
			* rng.randf_range(0.6, 1.4) * (1.0 + own.reputation / 300.0))
		if rng.randf() < 1.0 / maxf(rules().artist_release_interval, 1.0):
			var title := "%s %s" % [TITLE_WORDS_A[rng.randi() % TITLE_WORDS_A.size()], TITLE_WORDS_B[rng.randi() % TITLE_WORDS_B.size()]]
			var hit := revenue * rng.randi_range(2, 5)
			revenue += hit
			signed.releases += 1
			career.label.catalog.append({"artist_id": signed.artist_id, "title": title, "week": career.current_week,
				"streams": hit * 250, "revenue": hit})
		var label_part := roundi(revenue * signed.label_share)
		signed.revenue_total += revenue
		signed.label_revenue_total += label_part
		signed.last_week_revenue = revenue
		week_income += label_part
		week_costs += signed.weekly_cost
	if week_income > 0:
		own.add_entry(career.current_week, week_income, "Receitas dos artistas", "revenue")
	if week_costs > 0:
		own.add_entry(career.current_week, -week_costs, "Salários dos artistas", "payroll")
	own.reputation += week_income / 1000.0 * rules().reputation_per_k_revenue + report.plays / 1000.0 * rules().reputation_per_k_owner_plays
	if week_income > 0 or week_costs > 0:
		_note(report, own.name, "Semana da gravadora: %s em receitas, %s em salários. Caixa: %s." % [Fmt.money(week_income), Fmt.money(week_costs), Fmt.money(own.balance)])


# ---- apoio

func _close_period(career: CareerData) -> void:
	for period in career.label.periods:
		if int(period["to"]) < 0 and career.label.own == null:
			period["to"] = career.current_week


func _history(career: CareerData, text: String) -> void:
	career.label.history.append({"week": career.current_week, "text": text})


func _note(report: WeekReport, title: String, text: String) -> void:
	if report == null:
		return
	var line := WeekReportEntry.new()
	line.title = title
	line.note = text
	report.entries.append(line)


func _person(artist_id: String) -> CollaboratorDefinition:
	for person in _balance.collaborators.feats:
		if String(person.id) == artist_id:
			return person
	return null


func _display(artist_id: String) -> String:
	var person := _person(artist_id)
	return person.display_name if person != null else artist_id


func _relation(career: CareerData, artist_id: String) -> int:
	if social == null:
		return 0
	var current := social.peek(career, artist_id)
	return current.value if current != null and current.met else 0


func _initials(text: String) -> String:
	var letters := ""
	for word in text.split(" ", false):
		letters += word.left(1)
	return letters if not letters.is_empty() else "RS"
