extends Screen
## Montagem de um show: independente novo, proposta recebida, data de turnê ou show já marcado.
## context: mode ("new", "offer", "tour_date", "view"), show_id, tour_id.

const WEEKDAYS := ["Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado", "Domingo"]
const COST_LABELS := {
	"rent": "Aluguel do local", "production": "Produção", "addons": "Personalizações", "crew": "Equipe",
	"guests": "Convidados", "travel": "Transporte", "lodging": "Hospedagem", "food": "Alimentação",
	"security": "Segurança", "promotion": "Divulgação",
}

var _mode: String
var _original: LiveShow
var _show: LiveShow
var _tour: LiveTour
var _ready_done := false
var _basics := false

var _title := Label.new()
var _info := Label.new()
var _grid := GridContainer.new()
var _estimate := Label.new()
var _message := Label.new()
var _city := OptionButton.new()
var _venue := OptionButton.new()
var _week := SpinBox.new()
var _weekday := OptionButton.new()
var _price := SpinBox.new()
var _vip := CheckBox.new()
var _vip_price := SpinBox.new()
var _production := OptionButton.new()
var _addons: Dictionary[String, CheckBox] = {}
var _crew: Dictionary[String, OptionButton] = {}
var _promotion := SpinBox.new()
var _guest_artist := OptionButton.new()
var _guest_role := OptionButton.new()
var _guest_list := VBoxContainer.new()
var _merch := CheckBox.new()
var _set_type := OptionButton.new()
var _confirm := Button.new()
var _cancel := Button.new()
var _cancel_dialog := ConfirmationDialog.new()


func _ready() -> void:
	var career := GameManager.career
	var live := GameManager.live
	for pair in [[_city, "CityOption"], [_venue, "VenueOption"], [_week, "WeekInput"], [_weekday, "WeekdayOption"],
			[_price, "PriceInput"], [_production, "ProductionOption"], [_estimate, "EstimateLabel"], [_message, "MessageLabel"],
			[_confirm, "ConfirmButton"], [_cancel, "CancelShowButton"], [_title, "Title"], [_promotion, "PromotionInput"],
			[_guest_artist, "GuestArtistOption"], [_guest_role, "GuestRoleOption"], [_info, "InfoLabel"], [_cancel_dialog, "CancelDialog"]]:
		pair[0].name = pair[1]
	_mode = context.get("mode", "new")
	_tour = career.find_tour(context.get("tour_id", ""))
	_original = career.find_live_show(context.get("show_id", ""))
	if _original != null:
		_show = _original.copy()
		if _tour == null:
			_tour = career.find_tour(_show.tour_id)
	else:
		_show = live.new_show(career, LiveShow.KIND_TOUR if _mode == "tour_date" else LiveShow.KIND_INDEPENDENT)
		if _mode == "tour_date":
			_show.day = _next_tour_day(career)
	_build_layout()
	_build_fields()
	_load_controls()
	_set_editable()
	_ready_done = true
	super()


func refresh() -> void:
	if _ready_done:
		_update_estimate()


# ---- montagem

func _build_layout() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	_title.theme_type_variation = &"TitleLabel"
	column.add_child(_title)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_info)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	column.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_grid)
	var side := PanelContainer.new()
	side.custom_minimum_size = Vector2(330, 0)
	body.add_child(side)
	var side_scroll := ScrollContainer.new()
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(side_scroll)
	_estimate.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_estimate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_scroll.add_child(_estimate)
	_message.theme_type_variation = &"MessageLabel"
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_message)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	var back := Button.new()
	back.text = "Voltar"
	back.name = "BackButton"
	back.pressed.connect(_go_back)
	row.add_child(back)
	_cancel.text = "Cancelar show"
	_cancel.pressed.connect(_cancel_dialog.popup_centered)
	row.add_child(_cancel)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_confirm.theme_type_variation = &"PrimaryButton"
	_confirm.pressed.connect(_on_confirm)
	row.add_child(_confirm)
	_cancel_dialog.title = "Cancelar show"
	_cancel_dialog.ok_button_text = "Cancelar show"
	_cancel_dialog.cancel_button_text = "Manter"
	_cancel_dialog.confirmed.connect(_on_cancel_show)
	add_child(_cancel_dialog)


func _field(label_text: String, control: Control) -> void:
	var label := Label.new()
	label.text = label_text
	_grid.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clip_options(control)
	_grid.add_child(control)


## Opções longas não podem alargar o formulário além da tela.
func _clip_options(control: Control) -> void:
	if control is OptionButton:
		control.clip_text = true
		control.fit_to_longest_item = false
		control.custom_minimum_size.x = 140
	for child in control.get_children():
		if child is Control:
			_clip_options(child)


func _section(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"HeaderLabel"
	_grid.add_child(label)
	_grid.add_child(Control.new())


func _build_fields() -> void:
	var rules := GameManager.balance.live
	var career := GameManager.career
	_section("Local e data")
	for city in rules.cities:
		_city.add_item("%s (%s)" % [city.display_name, city.country])
		_city.set_item_metadata(_city.item_count - 1, city.id)
	_field("Cidade", _city)
	for venue in rules.venues:
		_venue.add_item("%s (%s a %s lugares)" % [venue.display_name, Fmt.number(venue.min_capacity), Fmt.number(venue.max_capacity)])
		_venue.set_item_metadata(_venue.item_count - 1, venue.id)
	_field("Tipo de local", _venue)
	_week.min_value = career.current_week + 1
	_week.max_value = career.current_week + rules.weeks_per_year * 2
	_week.prefix = "Semana"
	_field("Semana", _week)
	for day_name in WEEKDAYS:
		_weekday.add_item(day_name)
	_field("Dia", _weekday)
	_section("Ingressos")
	_price.min_value = 1
	_price.max_value = 5000
	_price.prefix = "$"
	_field("Preço do ingresso", _price)
	_vip.text = "Vender área VIP"
	_field("VIP", _vip)
	_vip_price.min_value = 1
	_vip_price.max_value = 20000
	_vip_price.prefix = "$"
	_field("Preço do VIP", _vip_price)
	_section("Produção")
	for level in rules.production_levels:
		_production.add_item("%s (base %s)" % [level.display_name, Fmt.money(level.cost)])
		_production.set_item_metadata(_production.item_count - 1, level.id)
	_field("Nível de produção", _production)
	var addons := HFlowContainer.new()
	for addon in rules.addons:
		var check := CheckBox.new()
		check.text = "%s (%s)" % [addon.display_name, Fmt.money(addon.cost)]
		check.name = "Addon_%s" % addon.id
		check.toggled.connect(func(_on: bool) -> void: _on_changed())
		addons.add_child(check)
		_addons[addon.id] = check
	_field("Personalizações", addons)
	_promotion.min_value = 0
	_promotion.max_value = 10000000
	_promotion.step = 100
	_promotion.prefix = "$"
	_field("Divulgação", _promotion)
	if _show.kind == LiveShow.KIND_FESTIVAL:
		_set_type.add_item("Set completo")
		_set_type.set_item_metadata(0, "full")
		_set_type.add_item("Set reduzido")
		_set_type.set_item_metadata(1, "reduced")
		_field("Set", _set_type)
	_section("Equipe")
	for role in rules.crew_roles:
		var option := OptionButton.new()
		for tier in rules.crew_tier_labels.size():
			var cost := roundi(role.base_cost * rules.crew_tier_multipliers[tier])
			option.add_item(rules.crew_tier_labels[tier] if tier == 0 else "%s (%s)" % [rules.crew_tier_labels[tier], Fmt.money(cost)])
		option.name = "Crew_%s" % role.id
		option.item_selected.connect(func(_index: int) -> void: _on_changed())
		_field(role.display_name, option)
		_crew[role.id] = option
	_section("Convidados")
	var feats: Array = GameManager.balance.collaborators.feats.duplicate()
	feats.sort_custom(func(a: CollaboratorDefinition, b: CollaboratorDefinition) -> bool: return a.cost > b.cost)
	for person: CollaboratorDefinition in feats:
		_guest_artist.add_item("%s (%s)" % [person.display_name, Fmt.money(person.cost)])
		_guest_artist.set_item_metadata(_guest_artist.item_count - 1, String(person.id))
	for role_id in LiveRules.GUEST_ROLES:
		_guest_role.add_item(LiveRules.GUEST_ROLE_LABELS[role_id])
		_guest_role.set_item_metadata(_guest_role.item_count - 1, role_id)
	var guest_row := HFlowContainer.new()
	_guest_artist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_guest_artist.clip_text = true
	guest_row.add_child(_guest_artist)
	guest_row.add_child(_guest_role)
	var add := Button.new()
	add.text = "Adicionar"
	add.name = "AddGuestButton"
	add.pressed.connect(_add_guest)
	guest_row.add_child(add)
	_field("Artista", guest_row)
	_field("Na data", _guest_list)
	_section("Merchandising")
	_merch.text = "Vender merch neste show"
	_field("Merch", _merch)
	for option: OptionButton in [_city, _venue, _weekday, _production, _set_type]:
		option.item_selected.connect(func(_index: int) -> void: _on_changed(option))
	for spin: SpinBox in [_week, _price, _vip_price, _promotion]:
		spin.value_changed.connect(func(_value: float) -> void: _on_changed())
	for check: CheckBox in [_vip, _merch]:
		check.toggled.connect(func(_on: bool) -> void: _on_changed())


func _load_controls() -> void:
	_select(_city, _show.city_id)
	_select(_venue, _show.venue_id)
	_week.set_value_no_signal(_show.week())
	_weekday.select(_show.weekday() - 1)
	_price.set_value_no_signal(_show.ticket_price)
	_vip.set_pressed_no_signal(_show.vip_enabled)
	_vip_price.set_value_no_signal(maxf(_show.vip_price, 1.0))
	_select(_production, _show.production_id)
	for addon_id in _addons:
		_addons[addon_id].set_pressed_no_signal(addon_id in _show.addons)
	for role_id in _crew:
		_crew[role_id].select(int(_show.crew.get(role_id, 0)))
	_promotion.set_value_no_signal(_show.promotion)
	_merch.set_pressed_no_signal(_show.merch_enabled)
	if _set_type.item_count > 0:
		_select(_set_type, _show.set_type)
	_rebuild_guests()


func _set_editable() -> void:
	var live := GameManager.live
	var basics := _mode == "new" or _mode == "tour_date"
	_basics = basics
	var choices := _mode != "view"
	for control: Control in [_city, _venue, _week, _weekday, _price, _vip, _vip_price]:
		control.set("disabled", not basics)
		control.set("editable", basics)
	for control: Control in [_production, _promotion, _merch, _set_type, _guest_artist, _guest_role]:
		control.set("disabled", not choices)
		control.set("editable", choices)
	for check in _addons.values():
		check.disabled = not choices
	for option in _crew.values():
		option.disabled = not choices
	if _show.kind == LiveShow.KIND_FESTIVAL:
		var festival_rules := GameManager.balance.live.find_festival(GameManager.career.find_edition(_show.festival_edition_id).festival_id)
		if not festival_rules.merch_allowed:
			_merch.disabled = true
	_cancel.visible = _mode == "view" and _original != null and _original.status == LiveShow.STATUS_SCHEDULED and _original.kind != LiveShow.KIND_TOUR
	match _mode:
		"new":
			_title.text = "Novo show independente"
			_info.text = "Você organiza tudo: local, ingressos, produção, equipe e divulgação. As despesas são pagas ao confirmar; a bilheteria entra no dia do show."
			_confirm.text = "Confirmar show"
		"tour_date":
			_title.text = "Data da turnê %s" % (_tour.name if _tour != null else "")
			_info.text = "Cada data tem configuração própria. As despesas são pagas quando a turnê for confirmada."
			_confirm.text = "Salvar data"
		"offer":
			_title.text = "Proposta: %s" % _show.event_name
			_info.text = "%s • %s • %s. Condições: %s.%s Vence na semana %s." % [_show.venue_name, live.day_label(_show.day),
				_show.event_type, live.terms_text(_show), _covers_text(), Fmt.number(_show.offer_expires_week)]
			_confirm.text = "Aceitar proposta"
		_:
			_title.text = "Show marcado: %s" % (_show.event_name if not _show.event_name.is_empty() else _show.venue_name)
			_info.text = "%s • %s • %s.%s Despesas já pagas: %s." % [_show.venue_name, live.day_label(_show.day), live.terms_text(_show),
				_covers_text(), Fmt.money(_show.upfront_paid)]
			_confirm.visible = false


# ---- reação

func _on_changed(source: Control = null) -> void:
	if not _ready_done:
		return
	var live := GameManager.live
	var rules := GameManager.balance.live
	if source == _city or source == _venue:
		live.apply_venue(_show, _city.get_selected_metadata(), _venue.get_selected_metadata())
		if source == _venue:
			var venue := rules.find_venue(_show.venue_id)
			_price.set_value_no_signal(roundi(venue.base_ticket_price * live.price_fame_multiplier(GameManager.career)))
			_vip_price.set_value_no_signal(_price.value * rules.vip_price_multiplier)
	_show.day = live.first_day_of_week(int(_week.value)) + _weekday.selected
	_show.ticket_price = _price.value
	_show.vip_enabled = _vip.button_pressed
	_show.vip_price = _vip_price.value
	_show.production_id = _production.get_selected_metadata()
	var addons: Array[String] = []
	for addon_id in _addons:
		if _addons[addon_id].button_pressed:
			addons.append(addon_id)
	_show.addons = addons
	var crew: Dictionary[String, int] = {}
	for role_id in _crew:
		if _crew[role_id].selected > 0:
			crew[role_id] = _crew[role_id].selected
	_show.crew = crew
	_show.promotion = int(_promotion.value)
	_show.merch_enabled = _merch.button_pressed
	if _set_type.item_count > 0:
		_show.set_type = _set_type.get_selected_metadata()
	_update_estimate()


func _update_estimate() -> void:
	var career := GameManager.career
	var live := GameManager.live
	var venue := GameManager.balance.live.find_venue(_show.venue_id)
	_vip.disabled = not _basics or not venue.has_vip
	var p := live.estimate(career, _show)
	var lines := PackedStringArray()
	lines.append("PREVISÃO")
	lines.append("Capacidade: %s lugares" % Fmt.number(_show.capacity))
	lines.append("Público previsto: %s (%d%%)" % [Fmt.number(p["attendance"]), p["occupancy"]])
	if p["gross"] > 0:
		lines.append("Ingressos: %s comuns + %s VIP" % [Fmt.number(p["sold"]), Fmt.number(p["vip_sold"])])
		lines.append("Bilheteria bruta: %s" % Fmt.money(p["gross"]))
		lines.append("Taxas: -%s  •  Líquida: %s" % [Fmt.money(p["ticket_fees"]), Fmt.money(p["net_box"])])
	lines.append("Condições: %s" % live.terms_text(_show))
	lines.append("Sua receita: %s" % Fmt.money(p["income"]))
	if p["co_share"] > 0:
		lines.append("Parte do co-headliner: -%s" % Fmt.money(p["co_share"]))
	if p["commission"] > 0:
		lines.append("Comissão do agente: -%s" % Fmt.money(p["commission"]))
	lines.append("Merch estimado: %s" % Fmt.money(p["merch_net"]))
	lines.append("")
	lines.append("DESPESAS DO ARTISTA")
	var expenses: Dictionary = p["expenses"]
	for key: String in COST_LABELS:
		if int(expenses.get(key, 0)) > 0:
			lines.append("%s: %s" % [COST_LABELS[key], Fmt.money(expenses[key])])
	lines.append("Total: %s" % Fmt.money(p["total_expenses"]))
	lines.append("")
	lines.append("Lucro estimado: %s" % Fmt.signed_money(p["profit"]))
	lines.append("Qualidade prevista: %d/100" % p["quality"])
	if p["fatigue"] > 0:
		lines.append("Desgaste da turnê: %d/100" % p["fatigue"])
	if _mode == "view":
		lines.append("Dinheiro disponível: %s" % Fmt.money(career.money))
	else:
		var pay: int = p["total_expenses"] if _mode != "tour_date" else 0
		lines.append("Dinheiro: %s  →  depois de confirmar: %s" % [Fmt.money(career.money), Fmt.money(career.money - pay)])
		if pay > career.money:
			lines.append("Dinheiro insuficiente para as despesas.")
	if _mode != "view" and _mode != "offer":
		var conflict := live.conflict_error(career, _show)
		if not conflict.is_empty():
			lines.append("")
			lines.append("Conflito de agenda: %s" % conflict)
	_estimate.text = "\n".join(lines)


func _add_guest() -> void:
	if _guest_artist.item_count == 0:
		return
	var artist_id: String = _guest_artist.get_selected_metadata()
	for guest in _show.guests:
		if guest.get("artist_id", "") == artist_id:
			_message.text = "Esse artista já está na data."
			return
	_show.guests.append({"artist_id": artist_id, "role": _guest_role.get_selected_metadata()})
	_rebuild_guests()
	_update_estimate()


func _rebuild_guests() -> void:
	for child in _guest_list.get_children():
		_guest_list.remove_child(child)
		child.queue_free()
	if _show.guests.is_empty():
		var empty := Label.new()
		empty.text = "Nenhum convidado."
		_guest_list.add_child(empty)
	for guest in _show.guests:
		var row := HBoxContainer.new()
		var label := Label.new()
		var person := _person(guest.get("artist_id", ""))
		label.text = "%s — %s" % [person.display_name if person != null else "?", LiveRules.GUEST_ROLE_LABELS.get(guest.get("role", ""), "")]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		if _mode != "view":
			var remove := Button.new()
			remove.text = "Remover"
			remove.pressed.connect(_remove_guest.bind(guest))
			row.add_child(remove)
		_guest_list.add_child(row)


func _remove_guest(guest: Dictionary) -> void:
	_show.guests.erase(guest)
	_rebuild_guests()
	_update_estimate()


func _on_confirm() -> void:
	var result: ActionResult
	match _mode:
		"new":
			result = GameManager.schedule_show(_show)
		"tour_date":
			result = GameManager.save_tour_date(_tour.id, _show)
		"offer":
			result = GameManager.accept_offer(_original.id, _show)
	if result == null:
		return
	if result.ok:
		if _mode == "tour_date":
			navigate.call_deferred(Screen.TOUR_EDITOR, {"tour_id": _tour.id, "message": result.message})
		else:
			navigate.call_deferred(Screen.LIVE, {"tab": 0, "message": result.message})
	else:
		_message.text = result.message


func _on_cancel_show() -> void:
	var result := GameManager.cancel_show(_original.id)
	if result.ok:
		navigate.call_deferred(Screen.LIVE, {"tab": 0, "message": result.message})
	else:
		_message.text = result.message


func _go_back() -> void:
	if _tour != null and (_mode == "tour_date" or _show.kind == LiveShow.KIND_TOUR):
		navigate(Screen.TOUR_EDITOR, {"tour_id": _tour.id})
	else:
		navigate(Screen.LIVE, {"tab": 1 if _mode == "offer" else 0})


# ---- auxiliares

func _next_tour_day(career: CareerData) -> int:
	var live := GameManager.live
	var last := live.first_day_of_week(career.current_week + 2) + 2
	if _tour != null:
		for other in live.tour_shows(career, _tour):
			last = maxi(last, other.day)
		if not live.tour_shows(career, _tour).is_empty():
			last += 2
	return last


func _covers_text() -> String:
	if _show.covers_travel and _show.covers_lodging:
		return " Transporte e hospedagem pagos pelo contratante."
	return " Transporte e hospedagem por sua conta." if _show.kind != LiveShow.KIND_INDEPENDENT else ""


func _person(artist_id: String) -> CollaboratorDefinition:
	for person in GameManager.balance.collaborators.feats:
		if String(person.id) == artist_id:
			return person
	return null


func _select(option: OptionButton, value: Variant) -> void:
	for index in option.item_count:
		if option.get_item_metadata(index) == value:
			option.select(index)
			return
