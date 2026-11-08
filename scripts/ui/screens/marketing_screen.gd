extends Screen
## Marketing de uma música ou projeto: monta a campanha e agenda o lançamento com ela.
## context precisa ter content_id. context["back"] define a tela de volta.

var _content: ReleasableContent


func _ready() -> void:
	_content = GameManager.career.find_content(context.get("content_id", ""))
	%ActionsTable.set_headers(["Ação", "Custo", "Alcance", "Duração", "Hype", "Retorno", "Requisitos", "Situação"])
	%ActionsTable.set_column_expand_ratio(7, 2)
	%ActionsTable.set_column_expand_ratio(6, 2)
	%ActionsTable.item_selected.connect(_update_action_buttons)
	%AddButton.pressed.connect(_on_add_pressed)
	%RemoveButton.pressed.connect(_on_remove_pressed)
	%WeekInput.value_changed.connect(func(_value: float) -> void: _update_numbers())
	%ScheduleButton.pressed.connect(_on_schedule_pressed)
	%CancelButton.pressed.connect(_on_cancel_pressed)
	%BackButton.pressed.connect(func() -> void: navigate(context.get("back", Screen.MARKETING_HUB), {"song_id": _content.id}))
	_setup_week_input()
	# Ficha da música ou do projeto fica sob demanda: o essencial é orçamento e campanha.
	%SongLabel.visible = false
	%SongLabel.theme_type_variation = &"MutedLabel"
	var details := Button.new()
	details.name = "DetailsToggle"
	details.text = "Ver ficha do lançamento"
	details.theme_type_variation = &"ChipButton"
	details.toggle_mode = true
	details.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	details.toggled.connect(func(on: bool) -> void:
		%SongLabel.visible = on
		details.text = "Esconder ficha" if on else "Ver ficha do lançamento")
	%SongLabel.get_parent().add_child(details)
	super()


func refresh() -> void:
	%Title.text = _content.title
	%SongLabel.text = _content_text()
	_fill_actions()
	_update_schedule_controls()
	_update_numbers()
	_update_action_buttons()


func _setup_week_input() -> void:
	var career := GameManager.career
	var schedule := career.find_active_schedule(_content.id)
	%WeekInput.min_value = career.current_week + 1
	%WeekInput.max_value = career.current_week + GameManager.balance.max_schedule_weeks_ahead
	%WeekInput.value = schedule.scheduled_week if schedule != null else career.current_week + 2


func _content_text() -> String:
	var career := GameManager.career
	var parts := PackedStringArray([
		"Artista: %s" % career.artist_name,
		"Feats: %s" % _feats_text(),
		"Qualidade: %d" % _content.quality,
		"Status: %s" % _content.display_status(),
		"Tipo: %s" % GameManager.releases.content_type_label(_content),
		"Lançamento: %s" % _release_text(),
	])
	return "  |  ".join(parts)


func _feats_text() -> String:
	if not _content is SongData:
		return "—"
	var feats := CollaboratorCatalog.names(GameManager.balance.collaborators.feats, _content.credits.feat_ids)
	return "—" if feats.is_empty() else ", ".join(feats)


func _release_text() -> String:
	var career := GameManager.career
	if _content.is_released():
		return "semana %s" % Fmt.number(_content.release_week)
	var schedule := career.find_active_schedule(_content.id)
	if schedule != null:
		return "semana %s (%s)" % [Fmt.number(schedule.scheduled_week), schedule.status_label()]
	return "não agendado"


func _fill_actions() -> void:
	var selected: Variant = %ActionsTable.selected_value()
	%ActionsTable.clear_rows()
	for action in GameManager.balance.marketing.actions:
		%ActionsTable.add_row([
			action.display_name,
			Fmt.money(action.cost),
			Fmt.number(action.reach),
			"%d sem." % action.duration_weeks,
			"+%d" % roundi(action.hype_impact),
			"x%s" % str(snappedf(action.return_potential, 0.01)).replace(".", ","),
			action.requirements_text(),
			_action_state(action),
		], action.id)
	if selected != null:
		%ActionsTable.select_value(selected)


func _action_state(action: MarketingActionDefinition) -> String:
	var campaign := GameManager.career.find_campaign(_content.id)
	var in_campaign := campaign.find_action(action.id) if campaign != null else null
	if in_campaign != null:
		return "Paga" if in_campaign.is_paid() else "Planejada"
	return "Disponível" if action.meets_requirements(GameManager.career) else "Bloqueada"


func _update_numbers() -> void:
	var career := GameManager.career
	var campaign := career.find_campaign(_content.id)
	var invested := campaign.invested() if campaign != null else 0
	var planned := GameManager.marketing.unpaid_cost(career, _content.id)
	%BudgetLabel.text = "Orçamento disponível: %s  |  Investimento atual: %s  |  Planejado: %s  |  Valor restante: %s" % [
		Fmt.money(career.money),
		Fmt.money(invested),
		Fmt.money(planned),
		Fmt.money(career.money - planned),
	]
	if campaign != null and campaign.result != null:
		%ForecastLabel.text = _result_text(campaign.result)
		return
	var forecast := GameManager.marketing.forecast(career, _content.id, _weeks_until_release())
	var campaign_status := campaign.status_label() if campaign != null else "Sem campanha"
	%ForecastLabel.text = "Campanha: %s  |  Previsão no lançamento: alcance %s, expectativa %d  |  Expectativa atual: %d" % [
		campaign_status,
		Fmt.number(forecast.reach),
		forecast.hype,
		campaign.hype if campaign != null else 0,
	]
	_update_schedule_text(planned)


func _result_text(result: MarketingResult) -> String:
	return "%s: alcance %s, expectativa %d, %s pré-saves, %s novos fãs, exposição %d, popularidade %d, potencial x%s" % [
		result.outcome_label,
		Fmt.number(result.reach),
		result.expectation,
		Fmt.number(result.pre_saves),
		Fmt.number(result.new_fans),
		result.exposure,
		result.popularity,
		str(snappedf(result.initial_potential, 0.01)).replace(".", ","),
	]


func _weeks_until_release() -> int:
	return maxi(int(%WeekInput.value) - GameManager.career.current_week, 0)


func _update_schedule_controls() -> void:
	var is_scheduled := GameManager.career.find_active_schedule(_content.id) != null
	%ScheduleRow.visible = not _content.is_released()
	%CancelButton.visible = is_scheduled


func _update_schedule_text(planned: int) -> void:
	var career := GameManager.career
	if career.find_active_schedule(_content.id) != null:
		%ScheduleButton.text = "Remarcar lançamento"
		return
	var release_cost := GameManager.releases.release_cost(_content)
	%ScheduleButton.text = "Agendar lançamento (%s)" % Fmt.money(planned + release_cost)


func _update_action_buttons() -> void:
	var action_id: Variant = %ActionsTable.selected_value()
	var definition: MarketingActionDefinition = null
	if action_id != null:
		definition = GameManager.balance.marketing.find_action(action_id)
	var campaign := GameManager.career.find_campaign(_content.id)
	var in_campaign := campaign.find_action(action_id) if campaign != null and action_id != null else null
	%AddButton.text = "Adicionar (%s)" % Fmt.money(definition.cost) if definition != null else "Adicionar"
	%AddButton.disabled = definition == null or in_campaign != null or _content.is_released()
	%RemoveButton.disabled = in_campaign == null or in_campaign.is_paid() or _content.is_released()


func _on_add_pressed() -> void:
	%MessageLabel.text = GameManager.add_marketing_action(_content.id, %ActionsTable.selected_value()).message


func _on_remove_pressed() -> void:
	%MessageLabel.text = GameManager.remove_marketing_action(_content.id, %ActionsTable.selected_value()).message


func _on_schedule_pressed() -> void:
	var week := int(%WeekInput.value)
	var result: ActionResult
	if GameManager.career.find_active_schedule(_content.id) != null:
		result = GameManager.reschedule_release(_content.id, week)
	else:
		result = GameManager.schedule_release(_content.id, week)
	%MessageLabel.text = result.message


func _on_cancel_pressed() -> void:
	var result := GameManager.cancel_schedule(_content.id)
	%MessageLabel.text = "%s O marketing já pago não é devolvido e vale para o próximo agendamento." % result.message
