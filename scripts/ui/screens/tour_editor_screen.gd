extends Screen
## Criação e acompanhamento de uma turnê: dados, datas, previsão, patrocínios e relatório final.
## context: tour_id (vazio para uma nova), message.

var _tour: LiveTour
var _title := Label.new()
var _name := LineEdit.new()
var _goal := LineEdit.new()
var _project := OptionButton.new()
var _partner := OptionButton.new()
var _types: Dictionary[String, CheckBox] = {}
var _save := Button.new()
var _dates := DataTable.new()
var _date_buttons := HBoxContainer.new()
var _summary := Label.new()
var _sponsors := VBoxContainer.new()
var _seek := Button.new()
var _message := Label.new()
var _confirm := Button.new()
var _pause := Button.new()
var _resume := Button.new()
var _cancel := Button.new()
var _cancel_dialog := ConfirmationDialog.new()


func _ready() -> void:
	_tour = GameManager.career.find_tour(context.get("tour_id", ""))
	for pair in [[_name, "TourName"], [_goal, "TourGoal"], [_save, "SaveTourButton"], [_dates, "DatesTable"], [_summary, "SummaryLabel"],
			[_seek, "SeekSponsorsButton"], [_message, "MessageLabel"], [_confirm, "ConfirmTourButton"], [_pause, "PauseButton"],
			[_resume, "ResumeButton"], [_cancel, "CancelTourButton"], [_cancel_dialog, "CancelDialog"], [_title, "Title"], [_partner, "PartnerOption"]]:
		pair[0].name = pair[1]
	_build()
	_message.text = context.get("message", "")
	super()


func refresh() -> void:
	var career := GameManager.career
	var editing := _tour == null or _tour.is_open()
	_title.text = "Nova turnê" if _tour == null else "Turnê: %s (%s)" % [_tour.name, _tour.status_label()]
	for control: Control in [_name, _goal]:
		control.editable = editing
	for control: Control in [_project, _partner]:
		control.disabled = not editing
	for check in _types.values():
		check.disabled = not editing
	_save.text = "Criar turnê" if _tour == null else "Salvar dados"
	_save.visible = editing
	_date_buttons.visible = _tour != null
	for child in _date_buttons.get_children():
		if child.has_meta("planning_only"):
			child.disabled = not editing
	_confirm.visible = _tour != null and _tour.is_open()
	_pause.visible = _tour != null and (_tour.status == LiveTour.STATUS_CONFIRMED or _tour.status == LiveTour.STATUS_IN_PROGRESS)
	_resume.visible = _tour != null and _tour.status == LiveTour.STATUS_PAUSED
	_cancel.visible = _tour != null and _tour.status != LiveTour.STATUS_COMPLETED and _tour.status != LiveTour.STATUS_CANCELLED
	_seek.visible = _tour != null and _tour.is_open()
	_fill_dates(career)
	_fill_summary(career)
	_fill_sponsors()


# ---- montagem

func _build() -> void:
	var career := GameManager.career
	var rules := GameManager.balance.live
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	_title.theme_type_variation = &"TitleLabel"
	column.add_child(_title)

	var form := GridContainer.new()
	form.columns = 4
	form.add_theme_constant_override("h_separation", 10)
	column.add_child(form)
	_name.placeholder_text = "Nome da turnê"
	_goal.placeholder_text = "Objetivo (ex.: divulgar o álbum, crescer no Nordeste)"
	_project.add_item("Sem projeto ligado")
	_project.set_item_metadata(0, "")
	for album in career.albums:
		_project.add_item(album.title)
		_project.set_item_metadata(_project.item_count - 1, album.id)
	_partner.add_item("Turnê solo")
	_partner.set_item_metadata(0, "")
	var feats: Array = GameManager.balance.collaborators.feats.duplicate()
	feats.sort_custom(func(a: CollaboratorDefinition, b: CollaboratorDefinition) -> bool: return a.cost > b.cost)
	for person: CollaboratorDefinition in feats:
		_partner.add_item("Turnê conjunta com %s" % person.display_name)
		_partner.set_item_metadata(_partner.item_count - 1, String(person.id))
	for pair in [["Nome", _name], ["Objetivo", _goal], ["Projeto", _project], ["Formato", _partner]]:
		var label := Label.new()
		label.text = pair[0]
		form.add_child(label)
		var control: Control = pair[1]
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		control.custom_minimum_size = Vector2(240, 0)
		form.add_child(control)
	for option: OptionButton in [_project, _partner]:
		option.clip_text = true
		option.fit_to_longest_item = false

	var types_row := HFlowContainer.new()
	var types_label := Label.new()
	types_label.text = "Tipos (combináveis):"
	types_row.add_child(types_label)
	for type in rules.tour_types:
		var check := CheckBox.new()
		check.text = type.display_name
		check.tooltip_text = type.description
		check.name = "Type_%s" % type.id
		types_row.add_child(check)
		_types[type.id] = check
	_save.pressed.connect(_on_save)
	types_row.add_child(_save)
	column.add_child(types_row)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	column.add_child(body)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	_dates.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_dates)
	_dates.set_headers(["Data", "Cidade", "Local", "Lugares", "Ingresso", "Resultado", "Desgaste"])
	_dates.item_activated.connect(_open_date)
	left.add_child(_date_buttons)
	_date_buttons.add_theme_constant_override("separation", 8)
	_date_button("Adicionar data", _add_date, true)
	_date_button("Abrir data", _open_date, false)
	_date_button("Remover data", _remove_date, true)

	var side := PanelContainer.new()
	side.custom_minimum_size = Vector2(400, 0)
	body.add_child(side)
	var side_scroll := ScrollContainer.new()
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(side_scroll)
	var side_column := VBoxContainer.new()
	side_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_scroll.add_child(side_column)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_column.add_child(_summary)
	side_column.add_child(_sponsors)
	_seek.text = "Buscar patrocinadores"
	_seek.pressed.connect(func() -> void: _show_result(GameManager.seek_sponsors(_tour.id)))
	side_column.add_child(_seek)

	_message.theme_type_variation = &"MessageLabel"
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_message)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	var back := Button.new()
	back.text = "Voltar"
	back.name = "BackButton"
	back.pressed.connect(navigate.bind(Screen.LIVE, {"tab": 2}))
	row.add_child(back)
	_pause.text = "Pausar"
	_pause.pressed.connect(func() -> void: _show_result(GameManager.pause_tour(_tour.id)))
	row.add_child(_pause)
	_resume.text = "Retomar"
	_resume.pressed.connect(func() -> void: _show_result(GameManager.resume_tour(_tour.id)))
	row.add_child(_resume)
	_cancel.text = "Cancelar turnê"
	_cancel.pressed.connect(_cancel_dialog.popup_centered)
	row.add_child(_cancel)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_confirm.text = "Confirmar turnê"
	_confirm.theme_type_variation = &"PrimaryButton"
	_confirm.pressed.connect(func() -> void: _show_result(GameManager.confirm_tour(_tour.id)))
	row.add_child(_confirm)
	_cancel_dialog.title = "Cancelar turnê"
	_cancel_dialog.dialog_text = "Cancelar a turnê? As datas futuras serão canceladas com reembolso parcial."
	_cancel_dialog.ok_button_text = "Cancelar turnê"
	_cancel_dialog.cancel_button_text = "Manter"
	_cancel_dialog.confirmed.connect(func() -> void: _show_result(GameManager.cancel_tour(_tour.id)))
	add_child(_cancel_dialog)

	if _tour != null:
		_name.text = _tour.name
		_goal.text = _tour.goal
		_select(_project, _tour.project_id)
		_select(_partner, _tour.co_headliner_id)
		for type_id in _types:
			_types[type_id].button_pressed = type_id in _tour.types


func _date_button(text: String, action: Callable, planning_only: bool) -> void:
	var button := Button.new()
	button.text = text
	button.name = text.replace(" ", "")
	button.pressed.connect(action)
	if planning_only:
		button.set_meta("planning_only", true)
	_date_buttons.add_child(button)


# ---- dados

func _fill_dates(career: CareerData) -> void:
	_dates.clear_rows()
	if _tour == null:
		return
	var live := GameManager.live
	for show in live.tour_shows(career, _tour):
		var outcome: String
		var fatigue: int
		if show.status == LiveShow.STATUS_DONE:
			outcome = Fmt.signed_money(show.result.get("profit", 0))
			fatigue = int(show.result.get("fatigue", 0))
		else:
			var projection := live.estimate(career, show)
			outcome = "Prev. %s" % Fmt.signed_money(projection["profit"])
			fatigue = projection["fatigue"]
		_dates.add_row([live.day_label(show.day), live.city_label(show.city_id), show.venue_name, Fmt.number(show.capacity),
			Fmt.money(roundi(show.ticket_price)), outcome, "%d/100" % fatigue], show.id)


func _fill_summary(career: CareerData) -> void:
	if _tour == null:
		_summary.text = "Dê um nome, escolha os tipos e crie a turnê para adicionar as datas."
		return
	var lines := PackedStringArray()
	if _tour.status == LiveTour.STATUS_COMPLETED or _tour.status == LiveTour.STATUS_CANCELLED or _tour.status == LiveTour.STATUS_IN_PROGRESS:
		var r := GameManager.tours.tour_report(career, _tour)
		lines.append("RELATÓRIO DA TURNÊ" if _tour.status != LiveTour.STATUS_IN_PROGRESS else "ATÉ AGORA")
		lines.append("Shows realizados: %d" % r["shows"])
		lines.append("Cidades: %s" % (", ".join(r["cities"]) if not r["cities"].is_empty() else "—"))
		lines.append("Público total: %s (ocupação %d%%)" % [Fmt.number(r["audience"]), r["occupancy"]])
		lines.append("Cachês: %s" % Fmt.money(r["fees"]))
		lines.append("Bilheteria: %s" % Fmt.money(r["box_office"]))
		lines.append("Merch: %s" % Fmt.money(r["merch"]))
		lines.append("Patrocínios: %s" % Fmt.money(r["sponsors"]))
		lines.append("Despesas: %s" % Fmt.money(r["expenses"]))
		lines.append("Resultado: %s" % Fmt.signed_money(r["profit"]))
		lines.append("Novos fãs nos shows: %s" % Fmt.number(r["new_fans"]))
		lines.append("Fama: %s  •  Seguidores: %s" % [Fmt.signed_number(r["fame_gain"]), Fmt.signed_number(r["followers_gain"])])
		lines.append("")
	if _tour.status != LiveTour.STATUS_COMPLETED and _tour.status != LiveTour.STATUS_CANCELLED:
		var f := GameManager.tours.forecast(career, _tour)
		lines.append("PREVISÃO")
		lines.append("Datas: %d  •  Cidades: %d" % [f["shows"], f["cities"]])
		lines.append("Público previsto: %s" % Fmt.number(f["audience"]))
		lines.append("Despesas: %s%s" % [Fmt.money(f["upfront"]), " (pagas na confirmação)" if _tour.is_open() else ""])
		lines.append("Cachês e bilheteria: %s" % Fmt.money(f["income"]))
		lines.append("Merch: %s" % Fmt.money(f["merch"]))
		if f["sponsor_cash"] > 0:
			lines.append("Patrocínios: %s" % Fmt.money(f["sponsor_cash"]))
		lines.append("Resultado previsto: %s" % Fmt.signed_money(f["profit"]))
		if _tour.is_open():
			lines.append("Dinheiro disponível: %s" % Fmt.money(career.money))
		for conflict: String in f["conflicts"]:
			lines.append("Conflito: %s" % conflict)
		for warning: String in f["warnings"]:
			lines.append("Aviso: %s" % warning)
	_summary.text = "\n".join(lines)


func _fill_sponsors() -> void:
	for child in _sponsors.get_children():
		_sponsors.remove_child(child)
		child.queue_free()
	if _tour == null:
		return
	if not _tour.sponsors.is_empty() or not _tour.sponsor_offers.is_empty():
		var header := Label.new()
		header.text = "PATROCÍNIOS"
		_sponsors.add_child(header)
	for sponsor in _tour.sponsors:
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = "Fechado — %s" % GameManager.tours.sponsor_text(sponsor)
		_sponsors.add_child(label)
	for offer in _tour.sponsor_offers:
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = "Proposta — %s" % GameManager.tours.sponsor_text(offer)
		_sponsors.add_child(label)
		var accept := Button.new()
		accept.text = "Aceitar patrocínio"
		accept.name = "AcceptSponsor_%s" % offer["sponsor_id"]
		accept.pressed.connect(func() -> void: _show_result(GameManager.accept_sponsor(_tour.id, offer["sponsor_id"])))
		_sponsors.add_child(accept)


# ---- ações

func _on_save() -> void:
	var types: Array[String] = []
	for type_id in _types:
		if _types[type_id].button_pressed:
			types.append(type_id)
	var result: ActionResult
	if _tour == null:
		result = GameManager.create_tour(_name.text, _goal.text, _project.get_selected_metadata(), types, _partner.get_selected_metadata())
		if result.ok:
			_tour = result.value
	else:
		result = GameManager.update_tour(_tour.id, _name.text, _goal.text, _project.get_selected_metadata(), types, _partner.get_selected_metadata())
	_show_result(result)


func _add_date() -> void:
	navigate.call_deferred(Screen.SHOW_EDITOR, {"mode": "tour_date", "tour_id": _tour.id})


func _open_date() -> void:
	var show_id: Variant = _dates.selected_value()
	if show_id == null:
		return
	var show := GameManager.career.find_live_show(show_id)
	if show.status == LiveShow.STATUS_DONE:
		navigate.call_deferred(Screen.SHOW_REPORT, {"show_id": show_id, "tour_id": _tour.id})
	elif show.status == LiveShow.STATUS_DRAFT:
		navigate.call_deferred(Screen.SHOW_EDITOR, {"mode": "tour_date", "tour_id": _tour.id, "show_id": show_id})
	else:
		navigate.call_deferred(Screen.SHOW_EDITOR, {"mode": "view", "tour_id": _tour.id, "show_id": show_id})


func _remove_date() -> void:
	var show_id: Variant = _dates.selected_value()
	if show_id == null:
		_message.text = "Selecione uma data."
		return
	_show_result(GameManager.remove_tour_date(show_id))


func _show_result(result: ActionResult) -> void:
	_message.text = result.message
	refresh()


func _select(option: OptionButton, value: Variant) -> void:
	for index in option.item_count:
		if option.get_item_metadata(index) == value:
			option.select(index)
			return
