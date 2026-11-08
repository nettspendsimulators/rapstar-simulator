extends Screen
## Área "Ao vivo": shows marcados, ofertas, turnês, festivais, merchandising e histórico.
## context pode ter tab (índice da aba aberta).

const TABS := ["Shows", "Ofertas", "Turnês", "Festivais", "Merchandising", "Histórico"]

var _stats := Label.new()
var _tabs := TabContainer.new()
var _message := Label.new()
var _shows := DataTable.new()
var _offers := DataTable.new()
var _tours := DataTable.new()
var _festivals := DataTable.new()
var _merch := DataTable.new()
var _history := DataTable.new()
var _product := OptionButton.new()
var _quantity := SpinBox.new()
var _price := SpinBox.new()
var _exclusive := OptionButton.new()
var _limited := CheckBox.new()
var _merch_cost := Label.new()


func _ready() -> void:
	for pair in [[_shows, "ShowsTable"], [_offers, "OffersTable"], [_tours, "ToursTable"], [_festivals, "FestivalsTable"],
			[_merch, "MerchTable"], [_history, "HistoryTable"], [_tabs, "LiveTabs"], [_message, "MessageLabel"],
			[_product, "ProductOption"], [_quantity, "QuantityInput"], [_price, "MerchPriceInput"], [_stats, "StatsLabel"]]:
		pair[0].name = pair[1]
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var title := Label.new()
	title.text = "Ao vivo"
	title.theme_type_variation = &"TitleLabel"
	column.add_child(title)
	column.add_child(_stats)
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_tabs)
	_build_shows_tab()
	_build_offers_tab()
	_build_tours_tab()
	_build_festivals_tab()
	_build_merch_tab()
	_build_history_tab()
	for index in TABS.size():
		_tabs.set_tab_title(index, TABS[index])
	_tabs.current_tab = clampi(int(context.get("tab", 0)), 0, TABS.size() - 1)
	_message.theme_type_variation = &"MessageLabel"
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_message)
	var back := Button.new()
	back.text = "Voltar"
	back.name = "BackButton"
	back.pressed.connect(navigate.bind(Screen.HUB))
	var row := HBoxContainer.new()
	row.add_child(back)
	column.add_child(row)
	_message.text = context.get("message", "")
	super()


func refresh() -> void:
	var career := GameManager.career
	_stats.text = "Dinheiro: %s   •   Fama: %s   •   Fãs: %s   •   Estoque de merch: %s itens" % [
		Fmt.money(career.money), Fmt.number(career.fame), Fmt.number(GameManager.streaming.total_followers(career)),
		Fmt.number(GameManager.merch.total_stock(career))]
	_fill_shows()
	_fill_offers()
	_fill_tours()
	_fill_festivals()
	_fill_merch()
	_fill_history()
	_update_merch_cost()


# ---- abas

func _page(hint: String, table: DataTable, headers: PackedStringArray) -> HBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	_tabs.add_child(page)
	var label := Label.new()
	label.text = hint
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(label)
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(table)
	table.set_headers(headers)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	page.add_child(buttons)
	return buttons


func _button(row: Container, text: String, action: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.name = text.validate_node_name().replace(" ", "")
	button.pressed.connect(action)
	if primary:
		button.theme_type_variation = &"PrimaryButton"
	row.add_child(button)
	return button


func _build_shows_tab() -> void:
	var row := _page("Seus compromissos marcados. Shows independentes não precisam de aprovação: você escolhe tudo e assume os custos.",
		_shows, ["Evento", "Data", "Cidade", "Público previsto", "Condições", "Resultado previsto"])
	_shows.item_activated.connect(_open_show)
	_button(row, "Ver detalhes", _open_show)
	_button(row, "Novo show independente", navigate.bind(Screen.SHOW_EDITOR, {"mode": "new"}), true)


func _build_offers_tab() -> void:
	var row := _page("Propostas de contratantes, do underground aos grandes palcos. Abra uma proposta para montar o show e aceitar.",
		_offers, ["Evento", "Data", "Local", "Público esperado", "Condições", "Lucro estimado"])
	_offers.item_activated.connect(_open_offer)
	_button(row, "Recusar", _reject_offer)
	_button(row, "Ver e aceitar", _open_offer, true)


func _build_tours_tab() -> void:
	var row := _page("Monte turnês com quantas datas quiser. A ordem das cidades muda transporte, hospedagem e desgaste.",
		_tours, ["Turnê", "Tipos", "Status", "Datas", "Período", "Resultado"])
	_tours.item_activated.connect(_open_tour)
	_button(row, "Abrir turnê", _open_tour)
	_button(row, "Nova turnê", navigate.bind(Screen.TOUR_EDITOR, {}), true)


func _build_festivals_tab() -> void:
	var row := _page("Edições anuais com lineups próprios. Convites chegam sozinhos em Ofertas; você também pode se inscrever.",
		_festivals, ["Festival", "Quando", "Cidade", "Prestígio", "Sua posição provável", "Situação"])
	_festivals.item_activated.connect(_open_festival)
	_button(row, "Inscrever-se", _apply_festival)
	_button(row, "Ver lineup", _open_festival, true)


func _build_merch_tab() -> void:
	var row := _page("Produtos são fabricados e pagos antes. Sem estoque, não há venda. Vendem nos shows e na loja oficial.",
		_merch, ["Produto", "Preço", "Estoque", "Vendidos", "Receita", "Lucro"])
	var page: Control = row.get_parent()
	var form := HFlowContainer.new()
	form.add_theme_constant_override("h_separation", 8)
	page.add_child(form)
	page.move_child(form, page.get_child_count() - 2)
	for product in GameManager.balance.live.merch_products:
		_product.add_item("%s (%s/un.)" % [product.display_name, Fmt.money(product.unit_cost)])
		_product.set_item_metadata(_product.item_count - 1, product.id)
	_product.custom_minimum_size.x = 240
	_product.item_selected.connect(func(_index: int) -> void: _on_product_selected())
	form.add_child(_product)
	_quantity.min_value = 10
	_quantity.max_value = 50000
	_quantity.step = 10
	_quantity.value = 100
	_quantity.prefix = "Qtd."
	_quantity.custom_minimum_size.x = 160
	_quantity.value_changed.connect(func(_value: float) -> void: _update_merch_cost())
	form.add_child(_quantity)
	_price.min_value = 1
	_price.max_value = 10000
	_price.prefix = "Preço $"
	_price.custom_minimum_size.x = 160
	form.add_child(_price)
	_exclusive.fit_to_longest_item = false
	_exclusive.clip_text = true
	_exclusive.custom_minimum_size.x = 320
	_exclusive.item_selected.connect(func(_index: int) -> void: _update_merch_cost())
	form.add_child(_exclusive)
	_limited.text = "Edição limitada"
	form.add_child(_limited)
	form.add_child(_merch_cost)
	_on_product_selected()
	_button(row, "Mudar preço do selecionado", _set_merch_price)
	_button(row, "Fabricar", _manufacture, true)


func _build_history_tab() -> void:
	var row := _page("Shows realizados e turnês encerradas.", _history, ["Evento", "Data", "Público", "Ocupação", "Qualidade", "Resultado"])
	_history.item_activated.connect(_open_history)
	_button(row, "Ver relatório", _open_history, true)


# ---- preenchimento

func _fill_shows() -> void:
	var career := GameManager.career
	var live := GameManager.live
	_shows.clear_rows()
	for show in live.shows_with_status(career, LiveShow.STATUS_SCHEDULED):
		var projection := live.estimate(career, show)
		_shows.add_row([_event(show), live.short_day_label(show.day), live.city_label(show.city_id),
			"%s de %s" % [Fmt.number(projection["attendance"]), Fmt.number(show.capacity)], live.terms_text(show),
			Fmt.signed_money(projection["artist_income"] + projection["merch_net"] - show.upfront_paid)], show.id)


func _fill_offers() -> void:
	var career := GameManager.career
	var live := GameManager.live
	_offers.clear_rows()
	for offer in live.shows_with_status(career, LiveShow.STATUS_OFFER):
		var projection := live.estimate(career, offer)
		_offers.add_row([_event(offer), live.short_day_label(offer.day), offer.venue_name,
			"%s (cap. %s)" % [Fmt.number(projection["attendance"]), Fmt.number(offer.capacity)], live.terms_text(offer),
			Fmt.signed_money(projection["profit"])], offer.id)
	_tabs.set_tab_title(1, "Ofertas (%d)" % live.shows_with_status(career, LiveShow.STATUS_OFFER).size())


func _fill_tours() -> void:
	var career := GameManager.career
	var live := GameManager.live
	_tours.clear_rows()
	for tour in career.live_tours:
		var shows := live.tour_shows(career, tour)
		var period := "—" if shows.is_empty() else "Sem. %s a %s" % [Fmt.number(shows[0].week()), Fmt.number(shows[-1].week())]
		var outcome: String
		if tour.status == LiveTour.STATUS_COMPLETED or tour.status == LiveTour.STATUS_CANCELLED:
			outcome = Fmt.signed_money(GameManager.tours.tour_report(career, tour)["profit"])
		else:
			outcome = "Prev. %s" % Fmt.signed_money(GameManager.tours.forecast(career, tour)["profit"])
		_tours.add_row([tour.name, _types_text(tour), tour.status_label(), shows.size(), period, outcome], tour.id)


func _fill_festivals() -> void:
	var career := GameManager.career
	var festivals := GameManager.festivals
	var rules := GameManager.balance.live
	_festivals.clear_rows()
	for edition in festivals.upcoming_editions(career):
		var festival := rules.find_festival(edition.festival_id)
		var position: String = LiveRules.POSITION_LABELS[festivals.position_for(festivals.relevance(career, festival))]
		if career.fame < festival.min_fame:
			position = "Fama mínima %s" % Fmt.number(festival.min_fame)
		_festivals.add_row([festivals.edition_title(edition), "Semana %s" % Fmt.number(edition.week),
			"%s, %s" % [GameManager.live.city_label(festival.city_id), festival.country], festival.prestige, position,
			_edition_status(edition)], edition.id)


func _fill_merch() -> void:
	var career := GameManager.career
	_merch.clear_rows()
	for item in career.merch_items:
		_merch.add_row([GameManager.merch.item_label(career, item), Fmt.money(item.price), Fmt.number(item.stock),
			Fmt.number(item.sold), Fmt.money(item.revenue), Fmt.signed_money(item.profit())], item.id)
	var selected: Variant = _exclusive.get_selected_metadata() if _exclusive.item_count > 0 else null
	_exclusive.clear()
	_exclusive.add_item("Produto comum")
	_exclusive.set_item_metadata(0, "")
	for tour in career.live_tours:
		if tour.status != LiveTour.STATUS_CANCELLED and tour.status != LiveTour.STATUS_COMPLETED:
			_exclusive.add_item("Exclusivo da turnê %s" % tour.name)
			_exclusive.set_item_metadata(_exclusive.item_count - 1, "%s:%s" % [MerchItem.EXCLUSIVE_TOUR, tour.id])
	for album in career.albums:
		_exclusive.add_item("Do projeto %s" % album.title)
		_exclusive.set_item_metadata(_exclusive.item_count - 1, "%s:%s" % [MerchItem.EXCLUSIVE_PROJECT, album.id])
	for show in GameManager.live.shows_with_status(career, LiveShow.STATUS_SCHEDULED):
		_exclusive.add_item("Exclusivo do show %s" % show.venue_name)
		_exclusive.set_item_metadata(_exclusive.item_count - 1, "%s:%s" % [MerchItem.EXCLUSIVE_SHOW, show.id])
	for index in _exclusive.item_count:
		if _exclusive.get_item_metadata(index) == selected:
			_exclusive.select(index)


func _fill_history() -> void:
	var career := GameManager.career
	var live := GameManager.live
	_history.clear_rows()
	for tour in career.live_tours:
		if tour.status == LiveTour.STATUS_COMPLETED:
			var report := GameManager.tours.tour_report(career, tour)
			_history.add_row(["Turnê: %s" % tour.name, "%d shows" % report["shows"], Fmt.number(report["audience"]),
				"%d%%" % report["occupancy"], "—", Fmt.signed_money(report["profit"])], "tour:%s" % tour.id)
	for show in live.history(career):
		var result := show.result
		_history.add_row([_event(show), live.short_day_label(show.day), Fmt.number(result.get("attendance", 0)),
			"%d%%" % int(result.get("occupancy", 0)), result.get("quality", 0), Fmt.signed_money(result.get("profit", 0))], show.id)


# ---- ações

func _open_show() -> void:
	var show_id: Variant = _shows.selected_value()
	if show_id != null:
		navigate.call_deferred(Screen.SHOW_EDITOR, {"mode": "view", "show_id": show_id})


func _open_offer() -> void:
	var offer_id: Variant = _offers.selected_value()
	if offer_id != null:
		navigate.call_deferred(Screen.SHOW_EDITOR, {"mode": "offer", "show_id": offer_id})


func _reject_offer() -> void:
	var offer_id: Variant = _offers.selected_value()
	if offer_id == null:
		_message.text = "Selecione uma proposta."
		return
	_message.text = GameManager.reject_offer(offer_id).message


func _open_tour() -> void:
	var tour_id: Variant = _tours.selected_value()
	if tour_id != null:
		navigate.call_deferred(Screen.TOUR_EDITOR, {"tour_id": tour_id})


func _open_festival() -> void:
	var edition_id: Variant = _festivals.selected_value()
	if edition_id != null:
		navigate.call_deferred(Screen.FESTIVAL, {"edition_id": edition_id})


func _apply_festival() -> void:
	var edition_id: Variant = _festivals.selected_value()
	if edition_id == null:
		_message.text = "Selecione uma edição."
		return
	_message.text = GameManager.apply_to_festival(edition_id).message


func _open_history() -> void:
	var value: Variant = _history.selected_value()
	if value == null:
		return
	if String(value).begins_with("tour:"):
		navigate.call_deferred(Screen.TOUR_EDITOR, {"tour_id": String(value).trim_prefix("tour:")})
	else:
		navigate.call_deferred(Screen.SHOW_REPORT, {"show_id": value})


func _on_product_selected() -> void:
	var product := GameManager.balance.live.find_product(_product.get_selected_metadata())
	_price.value = product.suggested_price
	_update_merch_cost()


func _update_merch_cost() -> void:
	if _product.item_count == 0:
		return
	var cost := GameManager.merch.manufacture_cost(_product.get_selected_metadata(), int(_quantity.value))
	var money := GameManager.career.money
	_merch_cost.text = "Custo: %s  •  Dinheiro: %s  →  depois: %s" % [Fmt.money(cost), Fmt.money(money), Fmt.money(money - cost)]


func _manufacture() -> void:
	var exclusive: String = _exclusive.get_selected_metadata() if _exclusive.item_count > 0 else ""
	var parts := exclusive.split(":")
	var kind := parts[0] if parts.size() == 2 else MerchItem.EXCLUSIVE_NONE
	var target := parts[1] if parts.size() == 2 else ""
	_message.text = GameManager.manufacture_merch(_product.get_selected_metadata(), int(_quantity.value), int(_price.value), kind, target, _limited.button_pressed).message


func _set_merch_price() -> void:
	var item_id: Variant = _merch.selected_value()
	if item_id == null:
		_message.text = "Selecione um produto da lista."
		return
	_message.text = GameManager.set_merch_price(item_id, int(_price.value)).message


# ---- textos

func _event(show: LiveShow) -> String:
	if show.kind == LiveShow.KIND_TOUR:
		var tour := GameManager.career.find_tour(show.tour_id)
		return "%s — %s" % [tour.name if tour != null else "Turnê", show.venue_name]
	if show.kind == LiveShow.KIND_FESTIVAL:
		return "%s (%s)" % [show.event_name, LiveRules.POSITION_LABELS.get(show.lineup_position, "")]
	if show.kind == LiveShow.KIND_INDEPENDENT:
		return "Show próprio — %s" % show.venue_name
	return show.event_name if not show.event_name.is_empty() else show.venue_name


func _types_text(tour: LiveTour) -> String:
	var names := PackedStringArray()
	for type_id in tour.types:
		var type := GameManager.balance.live.find_tour_type(type_id)
		names.append(type.display_name if type != null else type_id)
	return ", ".join(names)


func _edition_status(edition: FestivalEdition) -> String:
	if edition.has_player():
		return "Você está no lineup"
	for show in GameManager.career.live_shows:
		if show.festival_edition_id == edition.id and show.status == LiveShow.STATUS_OFFER:
			return "Convite em Ofertas"
	match edition.application_status:
		FestivalEdition.APPLICATION_PENDING:
			return "Inscrição enviada"
		FestivalEdition.APPLICATION_REJECTED:
			return "Inscrição recusada"
	return "—"
