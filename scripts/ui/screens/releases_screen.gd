extends Screen


func _ready() -> void:
	%PendingTable.set_headers(["Nome", "Tipo", "Nota", "Custo de lançamento", "Situação"])
	%PendingTable.set_column_expand_ratio(4, 2)
	%ScheduleTable.set_headers(["Nome", "Tipo", "Semana programada", "Status", "Expectativa"])
	%ReleasedTable.set_headers(["Nome", "Tipo", "Semana", "Streams", "Vendas", "Dinheiro", "Fama"])
	%PendingTable.item_selected.connect(_on_pending_selected)
	%ScheduleTable.item_selected.connect(%MessageLabel.set_text.bind(""))
	%ReleaseButton.pressed.connect(_on_release_pressed)
	%ScheduleButton.pressed.connect(_on_schedule_pressed)
	%RescheduleButton.pressed.connect(_on_reschedule_pressed)
	%CancelButton.pressed.connect(_on_cancel_pressed)
	%BackButton.pressed.connect(navigate.bind(Screen.HUB))
	super()


func refresh() -> void:
	var career := GameManager.career
	%MoneyLabel.text = "Dinheiro: %s  |  Semana atual: %s" % [Fmt.money(career.money), Fmt.number(career.current_week)]
	_setup_week_input(%ScheduleWeek)
	_setup_week_input(%RescheduleWeek)
	_fill_pending()
	_fill_schedule()
	_fill_released()


func _setup_week_input(input: SpinBox) -> void:
	var career := GameManager.career
	input.min_value = career.current_week + 1
	input.max_value = career.current_week + GameManager.balance.max_schedule_weeks_ahead
	input.value = maxf(input.value, input.min_value)


func _fill_pending() -> void:
	var release_system := GameManager.releases
	%PendingTable.clear_rows()
	for content in release_system.unreleased_content(GameManager.career):
		%PendingTable.add_row([
			content.title,
			release_system.content_type_label(content),
			content.quality,
			Fmt.money(release_system.release_cost(content)),
			_situation_text(content),
		], content.id, content.cover_file)
	_set_release_blocked(false)


## Projetos mostram o progresso até o mínimo de músicas.
func _situation_text(content: ReleasableContent) -> String:
	if content is AlbumData:
		var album_format := GameManager.balance.find_album_format(content.format_id)
		return album_format.progress_text(content.song_ids.size())
	var planned_cost := GameManager.marketing.unpaid_cost(GameManager.career, content.id)
	if planned_cost > 0:
		return "Marketing a pagar: %s" % Fmt.money(planned_cost)
	return "Pronta (vazou)" if content.is_leaked() else "Pronta"


func _on_pending_selected() -> void:
	var content := GameManager.career.find_content(%PendingTable.selected_value())
	var error := GameManager.releases.release_error(GameManager.career, content)
	_set_release_blocked(not error.is_empty())
	%MessageLabel.text = error


func _set_release_blocked(blocked: bool) -> void:
	%ReleaseButton.disabled = blocked
	%ScheduleButton.disabled = blocked


## Agendamentos ativos primeiro, do mais próximo ao mais distante; depois, o histórico recente.
func _fill_schedule() -> void:
	var career := GameManager.career
	var entries := career.scheduled_releases.duplicate()
	entries.sort_custom(func(a: ScheduledRelease, b: ScheduledRelease) -> bool:
		if a.is_active() != b.is_active():
			return a.is_active()
		return a.scheduled_week < b.scheduled_week if a.is_active() else a.scheduled_week > b.scheduled_week
	)
	%ScheduleTable.clear_rows()
	for entry: ScheduledRelease in entries:
		var content := career.find_content(entry.content_id)
		%ScheduleTable.add_row([
			content.title,
			GameManager.releases.content_type_label(content),
			Fmt.number(entry.scheduled_week),
			"Vazado" if entry.is_active() and content.is_leaked() else entry.status_label(),
			_expectation_text(entry),
		], entry.content_id if entry.is_active() else null, content.cover_file)


func _expectation_text(entry: ScheduledRelease) -> String:
	var campaign := GameManager.career.find_campaign(entry.content_id)
	return str(campaign.hype) if campaign != null and entry.is_active() else "—"


func _fill_released() -> void:
	var career := GameManager.career
	%ReleasedTable.clear_rows()
	for release in career.releases:
		var content := career.find_content(release.content_id)
		%ReleasedTable.add_row([
			content.title,
			GameManager.releases.content_type_label(content),
			Fmt.number(release.release_week),
			Fmt.number(release.total_streams),
			Fmt.number(release.total_sales),
			Fmt.money(release.total_money),
			Fmt.number(release.total_fame),
		], null, content.cover_file)


func _on_release_pressed() -> void:
	var content_id: Variant = %PendingTable.selected_value()
	if content_id == null:
		%MessageLabel.text = "Selecione o que deseja lançar."
		return
	%MessageLabel.text = GameManager.release_content(content_id).message


func _on_schedule_pressed() -> void:
	var content_id: Variant = %PendingTable.selected_value()
	if content_id == null:
		%MessageLabel.text = "Selecione o que deseja agendar."
		return
	%MessageLabel.text = GameManager.schedule_release(content_id, int(%ScheduleWeek.value)).message


func _on_reschedule_pressed() -> void:
	var content_id: Variant = %ScheduleTable.selected_value()
	if content_id == null:
		%MessageLabel.text = "Selecione um lançamento com status Agendado."
		return
	%MessageLabel.text = GameManager.reschedule_release(content_id, int(%RescheduleWeek.value)).message


func _on_cancel_pressed() -> void:
	var content_id: Variant = %ScheduleTable.selected_value()
	if content_id == null:
		%MessageLabel.text = "Selecione um lançamento com status Agendado."
		return
	%MessageLabel.text = GameManager.cancel_schedule(content_id).message
