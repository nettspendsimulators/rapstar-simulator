class_name FestivalSystem
extends RefCounted
## Festivais: edições anuais com lineup completo, convites automáticos e inscrições.
## Convites e inscrições aceitas viram ofertas do LiveSystem; o show acontece pelo fluxo normal.

const MAIN_STAGE_POSITIONS := ["support", "featured", "sub_headliner", "co_headliner", "headliner"]
const SIDE_STAGE_POSITIONS := ["opening", "opening", "support", "featured", "sub_headliner"]

var _balance: GameBalance
var _live: LiveSystem
var _rng: RandomNumberGenerator


func _init(balance: GameBalance, live: LiveSystem, rng: RandomNumberGenerator) -> void:
	_balance = balance
	_live = live
	_rng = rng


func year_of(week: int) -> int:
	return (week - 1) / _rules().weeks_per_year + 1


func edition_week(festival: FestivalDefinition, year: int) -> int:
	return (year - 1) * _rules().weeks_per_year + festival.week_of_year


## Relevância do artista para o festival: 1 significa porte de headliner.
func relevance(career: CareerData, festival: FestivalDefinition) -> float:
	var reference := maxf(festival.prestige * _rules().festival_fame_per_prestige, 1.0)
	return float(career.fame) / reference * (0.5 + 0.5 * festival.rap_affinity)


func position_for(relevance_value: float) -> String:
	var position := "opening"
	for candidate in LiveRules.POSITIONS:
		var threshold: float = _rules().position_thresholds.get(candidate, 0.0)
		if relevance_value >= threshold:
			position = candidate
	return position


## Edições deste ano e do próximo, criadas quando ainda estão por vir.
func ensure_editions(career: CareerData) -> void:
	var year := year_of(career.current_week)
	for festival in _rules().festivals:
		for edition_year in [year, year + 1]:
			if career.find_edition_for(festival.id, edition_year) == null and edition_week(festival, edition_year) >= career.current_week:
				career.festival_editions.append(_generate_edition(career, festival, edition_year))


func upcoming_editions(career: CareerData) -> Array[FestivalEdition]:
	var result: Array[FestivalEdition] = []
	for edition in career.festival_editions:
		if edition.week >= career.current_week:
			result.append(edition)
	result.sort_custom(func(a: FestivalEdition, b: FestivalEdition) -> bool: return a.week < b.week)
	return result


## Inscrição: a resposta chega na semana seguinte. Aceita, vira uma oferta.
func apply(career: CareerData, edition_id: String) -> ActionResult:
	var edition := career.find_edition(edition_id)
	if edition == null:
		return ActionResult.failure("Edição não encontrada.")
	if edition.has_player() or _has_offer(career, edition):
		return ActionResult.failure("Você já está nessa edição ou tem um convite dela.")
	if edition.application_status == FestivalEdition.APPLICATION_PENDING:
		return ActionResult.failure("A inscrição já foi enviada.")
	if edition.week <= career.current_week + 1:
		return ActionResult.failure("As inscrições dessa edição já fecharam.")
	edition.application_status = FestivalEdition.APPLICATION_PENDING
	edition.application_week = career.current_week
	return ActionResult.success("Inscrição enviada para %s. A resposta chega na próxima semana." % edition_title(edition), edition)


func edition_title(edition: FestivalEdition) -> String:
	return "%s — Ano %d" % [_rules().find_festival(edition.festival_id).display_name, edition.year]


func time_label(minutes: int) -> String:
	return "%02d:%02d" % [minutes / 60, minutes % 60]


## Etapa da semana: novas edições, respostas de inscrições e convites.
func process_week(career: CareerData, report: WeekReport) -> void:
	ensure_editions(career)
	for edition in upcoming_editions(career):
		var festival := _rules().find_festival(edition.festival_id)
		if edition.application_status == FestivalEdition.APPLICATION_PENDING and career.current_week > edition.application_week:
			_answer_application(career, festival, edition, report)
			continue
		var weeks_left := edition.week - career.current_week
		if weeks_left < _rules().invite_window_min or weeks_left > _rules().invite_window_max:
			continue
		if edition.has_player() or _has_offer(career, edition) or edition.application_status == FestivalEdition.APPLICATION_REJECTED:
			continue
		var value := relevance(career, festival)
		if career.fame < festival.min_fame or value < _rules().min_invite_relevance:
			continue
		var chance := minf(_rules().invite_base_chance + value * _rules().invite_relevance_chance, _rules().max_invite_chance)
		if _rng.randf() < chance:
			career.live_shows.append(make_invitation(career, festival, edition, position_for(value)))
			_note(report, festival, "Convite para tocar no %s." % edition_title(edition))


func make_invitation(career: CareerData, festival: FestivalDefinition, edition: FestivalEdition, position: String) -> LiveShow:
	var r := _rules()
	var show := LiveShow.new()
	show.kind = LiveShow.KIND_FESTIVAL
	show.status = LiveShow.STATUS_OFFER
	show.id = career.new_id("offer")
	show.city_id = festival.city_id
	show.venue_id = "stadium"
	show.venue_name = "%s — %s" % [edition_title(edition), _live.city_label(festival.city_id)]
	show.event_name = edition_title(edition)
	show.event_type = "Festival"
	show.festival_edition_id = edition.id
	show.lineup_position = position
	show.capacity = roundi(festival.capacity * float(r.position_draw.get(position, 0.1)))
	show.fee_model = festival.fee_model
	show.fee = roundi(festival.headliner_fee * float(r.position_fee.get(position, 0.02)))
	show.covers_travel = festival.covers_expenses
	show.covers_lodging = festival.covers_expenses
	show.merch_enabled = festival.merch_allowed
	show.model = ""
	show.day = _live.first_day_of_week(edition.week) + LiveSystem.FESTIVAL_FIRST_WEEKDAY - 1 + _rng.randi_range(0, festival.days - 1)
	show.offer_expires_week = mini(career.current_week + r.offer_expiry_weeks, edition.week - 1)
	return show


func _answer_application(career: CareerData, festival: FestivalDefinition, edition: FestivalEdition, report: WeekReport) -> void:
	var value := relevance(career, festival)
	var chance := clampf(value * _rules().application_chance_per_relevance, 0.05, 0.95) if career.fame >= festival.min_fame else 0.02
	if _rng.randf() < chance:
		var index := maxi(LiveRules.POSITIONS.find(position_for(value)) - 1, 0)
		career.live_shows.append(make_invitation(career, festival, edition, LiveRules.POSITIONS[index]))
		edition.application_status = FestivalEdition.APPLICATION_ACCEPTED
		_note(report, festival, "Inscrição aprovada no %s. Confira a proposta em Ofertas." % edition_title(edition))
	else:
		edition.application_status = FestivalEdition.APPLICATION_REJECTED
		_note(report, festival, "Inscrição recusada pelo %s." % edition_title(edition))


func _generate_edition(career: CareerData, festival: FestivalDefinition, year: int) -> FestivalEdition:
	var edition := FestivalEdition.new()
	edition.id = "%s_%d" % [festival.id, year]
	edition.festival_id = festival.id
	edition.year = year
	edition.week = edition_week(festival, year)
	var lineup_rng := RandomNumberGenerator.new()
	lineup_rng.seed = hash(edition.id)
	var pool := _artist_pool()
	# Festivais maiores puxam os artistas mais populares do catálogo.
	var start := clampi(roundi((100 - festival.prestige) / 100.0 * (pool.size() - 15)), 0, maxi(pool.size() - 1, 0))
	var used := {}
	for festival_day in range(1, festival.days + 1):
		for stage_index in festival.stages.size():
			var positions: Array = MAIN_STAGE_POSITIONS if stage_index == 0 else SIDE_STAGE_POSITIONS
			for slot_index in mini(positions.size(), _rules().lineup_slots_per_stage):
				var position: String = positions[slot_index]
				var person := _pick_artist(pool, used, start, position, lineup_rng)
				var minutes: int = _rules().position_minutes.get(position, 45)
				edition.lineup.append({
					"artist_id": String(person.id) if person != null else "tba",
					"name": person.display_name if person != null else "Atração a confirmar",
					"day": festival_day, "stage": festival.stages[stage_index],
					"start": 14 * 60 + slot_index * 100 + stage_index * 15, "minutes": minutes, "position": position,
				})
	return edition


func _pick_artist(pool: Array[CollaboratorDefinition], used: Dictionary, start: int, position: String, lineup_rng: RandomNumberGenerator) -> CollaboratorDefinition:
	var rank := LiveRules.POSITIONS.find(position)
	var preferred := clampi(start + (5 - rank) * 3 + lineup_rng.randi_range(-2, 2), 0, pool.size() - 1)
	for offset in pool.size():
		var candidate := pool[(preferred + offset) % pool.size()]
		if not used.has(candidate.display_name):
			used[candidate.display_name] = true
			return candidate
	return null


## Artistas do catálogo existente, do mais popular para o menos popular, sem repetir nomes.
func _artist_pool() -> Array[CollaboratorDefinition]:
	var catalog := _balance.collaborators
	var seen := {}
	var pool: Array[CollaboratorDefinition] = []
	for person in catalog.feats + catalog.producers + catalog.beatmakers:
		if not seen.has(person.display_name):
			seen[person.display_name] = true
			pool.append(person)
	pool.sort_custom(func(a: CollaboratorDefinition, b: CollaboratorDefinition) -> bool: return a.cost > b.cost)
	return pool


func _has_offer(career: CareerData, edition: FestivalEdition) -> bool:
	for show in career.live_shows:
		if show.festival_edition_id == edition.id and (show.status == LiveShow.STATUS_OFFER or show.status == LiveShow.STATUS_SCHEDULED):
			return true
	return false


func _note(report: WeekReport, festival: FestivalDefinition, text: String) -> void:
	var line := WeekReportEntry.new()
	line.title = "Festival: %s" % festival.display_name
	line.note = text
	report.entries.append(line)


func _rules() -> LiveRules:
	return _balance.live
