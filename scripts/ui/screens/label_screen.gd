extends Screen
## Gravadora: a tela muda com a situação da carreira.
## - Independente: o que isso significa, propostas recebidas, gravadoras do jogo, abrir a sua e histórico.
## - Contratado: o selo, o contrato (prazo, divisão, adiantamento, orçamento), o caminho do dinheiro
##   (bruto → gravadora → você), os benefícios em vigor, o catálogo e a rescisão.
## - Dono: a sua gravadora, com caixa, receitas, despesas e lucro, artistas, contratações,
##   catálogo, finanças e evolução de nível.

const PRESET_COLORS := [["#f5b82e", "#16131c"], ["#a25cff", "#f3f0f7"], ["#2ec4b6", "#0f3b47"], ["#ff5f6d", "#1b1a1c"],
	["#1b1a1c", "#f5b82e"], ["#f3f0f7", "#16131c"]]

var _page := ""
var _header := VBoxContainer.new()
var _tabs := HBoxContainer.new()
var _content := VBoxContainer.new()
var _message := Label.new()
var _create_name := LineEdit.new()
var _create_short := LineEdit.new()
var _create_shape := "circle"
var _create_colors: Array = PRESET_COLORS[0]
var _create_logo := LabelLogo.new()
var _amount := SpinBox.new()


func _ready() -> void:
	_page = String(context.get("page", ""))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	_header.name = "LabelHeader"
	column.add_child(_header)
	_tabs.name = "LabelTabs"
	_tabs.add_theme_constant_override("separation", 6)
	column.add_child(_tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_content.name = "LabelContent"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	scroll.add_child(_content)
	_message.name = "MessageLabel"
	_message.theme_type_variation = &"MessageLabel"
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_message)
	_create_name.name = "LabelNameEdit"
	_create_name.placeholder_text = "Nome da gravadora"
	_create_name.max_length = 32
	_create_name.text_changed.connect(func(_text: String) -> void: _update_create_logo())
	_create_short.name = "LabelShortEdit"
	_create_short.placeholder_text = "Sigla (até 4 letras)"
	_create_short.max_length = 4
	_create_short.text_changed.connect(func(_text: String) -> void: _update_create_logo())
	_amount.name = "LabelAmount"
	_amount.min_value = 1000
	_amount.max_value = 100000000
	_amount.step = 1000
	_amount.value = 50000
	_amount.prefix = "$"
	super()


func refresh() -> void:
	var career := GameManager.career
	var mode := GameManager.labels.mode(career)
	var pages: Array = _pages_for(mode, career)
	if not pages.any(func(item: Array) -> bool: return item[0] == _page):
		_page = pages[0][0]
	_clear(_header)
	match mode:
		LabelData.MODE_SIGNED:
			_build_signed_header(career)
		LabelData.MODE_OWNER:
			_build_owner_header(career)
		_:
			_build_independent_header(career)
	_clear(_tabs)
	var group := ButtonGroup.new()
	for item: Array in pages:
		var tab := Button.new()
		tab.name = "Page_%s" % item[0]
		tab.text = item[1]
		tab.theme_type_variation = &"ChipButton"
		tab.toggle_mode = true
		tab.button_group = group
		tab.focus_mode = Control.FOCUS_NONE
		tab.button_pressed = item[0] == _page
		tab.pressed.connect(func() -> void:
			_page = item[0]
			refresh())
		_tabs.add_child(tab)
	_clear(_content)
	match _page:
		"offers":
			_build_offers(career)
		"labels":
			_build_directory(career)
		"create":
			_build_create(career)
		"history":
			_build_history(career)
		"contract":
			_build_contract(career)
		"catalog":
			_build_catalog(career)
		"artists":
			_build_artists(career)
		"sign":
			_build_sign(career)
		"finance":
			_build_finance(career)
		"growth":
			_build_growth(career)


func _pages_for(mode: String, career: CareerData) -> Array:
	match mode:
		LabelData.MODE_SIGNED:
			return [["contract", "Contrato"], ["catalog", "Catálogo"], ["labels", "Gravadoras"], ["history", "Histórico"]]
		LabelData.MODE_OWNER:
			return [["artists", "Artistas (%d)" % career.label.own.artists.size()], ["sign", "Contratar"], ["catalog", "Catálogo"],
				["finance", "Finanças"], ["growth", "Evolução"], ["history", "Histórico"]]
	return [["offers", "Propostas (%d)" % career.label.offers.size()], ["labels", "Gravadoras"], ["create", "Criar gravadora"], ["history", "Histórico"]]


# ---- cabeçalhos

func _hero(logo: Control, kicker: String, title: String, subtitle: String) -> HBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"HeroPanel"
	_header.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	logo.custom_minimum_size = Vector2(76, 76)
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(logo)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 2)
	row.add_child(texts)
	texts.add_child(_label(kicker, &"Kicker"))
	var name_label := _label(title, &"HeroTitle")
	name_label.name = "LabelTitle"
	name_label.add_theme_font_size_override("font_size", 32)
	texts.add_child(name_label)
	var sub := _label(subtitle, &"MutedLabel")
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(sub)
	return row


func _build_independent_header(career: CareerData) -> void:
	var logo := LabelLogo.new()
	logo.shape = "circle"
	logo.color = Color("#2a2540")
	logo.color2 = Color("#f3f0f7")
	logo.text = "IND"
	_hero(logo, "SITUAÇÃO", "Artista independente",
		"Você fica com 100% das receitas e paga todos os custos. Uma gravadora divide as receitas, mas paga parte do marketing, dos clipes e dos lançamentos, adianta dinheiro e amplia o alcance.")


func _build_signed_header(career: CareerData) -> void:
	var contract := career.label.contract
	var label := GameManager.labels.find_label(contract.label_id)
	var row := _hero(LabelLogo.new().setup_from(label), "CONTRATADO  •  %s" % label.tier_label().to_upper(), label.display_name,
		"Contrato até a semana %d (faltam %d semanas). %s" % [contract.end_week, contract.weeks_left(career.current_week), label.profile])
	row.add_child(_big_value("%d%%" % roundi(contract.artist_share * 100), "SUA PARTE"))


func _build_owner_header(career: CareerData) -> void:
	var own := career.label.own
	var lvl := GameManager.labels.level(career)
	var row := _hero(LabelLogo.new().setup_own(own), "MINHA GRAVADORA  •  %s" % lvl.display_name.to_upper(), own.name,
		"Fundada na semana %d  •  reputação %d  •  %d/%d artistas" % [own.founded_week, floori(own.reputation), own.artists.size(), lvl.max_artists])
	row.add_child(_big_value(Fmt.money(own.balance), "CAIXA"))


func _big_value(value: String, caption: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -2)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var number := _label(value, &"BigNumber")
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(number)
	var cap := _label(caption, &"SectionLabel")
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(cap)
	return box


# ---- independente

func _build_offers(career: CareerData) -> void:
	if career.label.offers.is_empty():
		var interested := GameManager.labels.interested(career).size()
		_content.add_child(_note("Nenhuma proposta agora. Gravadoras procuram artistas com fama, público crescendo e lançamentos recentes. %d gravadora(s) já olham para o seu nível; continue lançando e fazendo shows." % interested))
		return
	for offer in career.label.offers:
		_content.add_child(_offer_card(career, offer))


func _offer_card(career: CareerData, offer: LabelOffer) -> PanelContainer:
	var label := GameManager.labels.find_label(offer.label_id)
	var card := _card("Offer_%s" % offer.id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	var logo := LabelLogo.new().setup_from(label)
	logo.custom_minimum_size = Vector2(64, 64)
	logo.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(logo)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 4)
	row.add_child(texts)
	texts.add_child(_label("%s%s  •  expira na semana %d" % ["RENOVAÇÃO  •  " if offer.renewal else "", label.tier_label().to_upper(), offer.expires_week], &"Kicker"))
	var title := _label(label.display_name, &"ChipLabel")
	title.add_theme_font_size_override("font_size", 20)
	texts.add_child(title)
	var terms := GridContainer.new()
	terms.columns = 4
	terms.add_theme_constant_override("h_separation", 26)
	texts.add_child(terms)
	for pair: Array in [["%d%%" % roundi(offer.artist_share * 100), "para você"], [Fmt.money(offer.advance), "adiantamento"],
			["%d sem." % offer.weeks, "duração"], [Fmt.money(offer.budget), "orçamento"]]:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", -2)
		box.add_child(_label(pair[0], &"StatValue"))
		box.add_child(_label(pair[1], &"StatCaption"))
		terms.add_child(box)
	var benefits := _label(_benefits_text(offer.marketing_support, offer.video_support, offer.release_support, offer.discovery_bonus, offer.show_bonus), &"MutedLabel")
	benefits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(benefits)
	var limits := _label("Limites: a gravadora fica com %d%% de streams e vendas; o adiantamento é recuperado das suas receitas; sair antes custa o que faltar recuperar mais %d%% do adiantamento; sem gravadora própria durante o contrato." % [
		roundi((1.0 - offer.artist_share) * 100), roundi(GameManager.labels.rules().termination_fee_rate * 100)], &"StatCaption")
	limits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(limits)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(buttons)
	var accept := Button.new()
	accept.name = "AcceptOffer_%s" % offer.id
	accept.text = "Assinar"
	accept.theme_type_variation = &"PrimaryButton"
	var block := GameManager.labels.accept_block(career, offer.id)
	accept.disabled = not block.is_empty()
	accept.tooltip_text = block
	accept.pressed.connect(func() -> void: _message.text = GameManager.accept_label_offer(offer.id).message)
	buttons.add_child(accept)
	var decline := Button.new()
	decline.name = "DeclineOffer_%s" % offer.id
	decline.text = "Recusar"
	decline.theme_type_variation = &"GhostButton"
	decline.pressed.connect(func() -> void: _message.text = GameManager.decline_label_offer(offer.id).message)
	buttons.add_child(decline)
	return card


func _benefits_text(marketing: float, video: float, release: float, discovery: float, shows: float) -> String:
	var parts := PackedStringArray()
	if marketing > 0:
		parts.append("paga %d%% do marketing" % roundi(marketing * 100))
	if video > 0:
		parts.append("%d%% dos clipes" % roundi(video * 100))
	if release > 0:
		parts.append("%d%% dos lançamentos" % roundi(release * 100))
	if discovery > 0:
		parts.append("+%d%% de alcance nas plataformas" % roundi(discovery * 100))
	if shows > 0:
		parts.append("+%d%% propostas de show" % roundi(shows * 100))
	return "Benefícios: " + (", ".join(parts) if not parts.is_empty() else "nenhum") + "."


func _build_directory(career: CareerData) -> void:
	var flow := HFlowContainer.new()
	flow.name = "LabelDirectory"
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 12)
	_content.add_child(flow)
	for label in GameManager.labels.rules().labels:
		var card := _card("Label_%s" % label.id)
		card.custom_minimum_size = Vector2(290, 0)
		flow.add_child(card)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 4)
		card.add_child(column)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 10)
		column.add_child(top)
		var logo := LabelLogo.new().setup_from(label)
		logo.custom_minimum_size = Vector2(48, 48)
		top.add_child(logo)
		var names := VBoxContainer.new()
		names.add_theme_constant_override("separation", 0)
		top.add_child(names)
		names.add_child(_label(label.tier_label().to_upper(), &"Kicker"))
		names.add_child(_label(label.display_name, &"ChipLabel"))
		var profile := _label(label.profile, &"MutedLabel")
		profile.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(profile)
		column.add_child(_label("%d%% para o artista  •  a partir de %s de fama" % [roundi(label.artist_share * 100), Fmt.number(label.min_fame)], &"StatCaption"))
		var roster := PackedStringArray()
		for artist_id in label.roster:
			roster.append(GameManager.social.display_name(artist_id))
		var cast := _label("Elenco: " + ", ".join(roster), &"StatCaption")
		cast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(cast)


func _build_create(career: CareerData) -> void:
	var rules := GameManager.labels.rules()
	var card := _card("CreateLabelCard")
	_content.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	card.add_child(row)
	_create_logo.custom_minimum_size = Vector2(120, 120)
	_create_logo.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if _create_logo.get_parent() != null:
		_create_logo.get_parent().remove_child(_create_logo)
	row.add_child(_create_logo)
	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 8)
	row.add_child(form)
	form.add_child(_label("SUA GRAVADORA", &"Kicker"))
	var explain := _label("Com selo próprio você não divide receitas com ninguém, ganha alcance conforme a gravadora cresce e pode contratar artistas do jogo. Custa %s (precisa de %s de fama); %d%% vira o caixa inicial da gravadora." % [
		Fmt.money(rules.creation_cost), Fmt.number(rules.creation_min_fame), roundi(LabelSystem.STARTING_BALANCE_RATE * 100)], &"MutedLabel")
	explain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(explain)
	var names := HBoxContainer.new()
	names.add_theme_constant_override("separation", 8)
	form.add_child(names)
	for edit: LineEdit in [_create_name, _create_short]:
		if edit.get_parent() != null:
			edit.get_parent().remove_child(edit)
		names.add_child(edit)
	_create_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_create_short.custom_minimum_size.x = 170
	var shapes := HBoxContainer.new()
	shapes.add_theme_constant_override("separation", 6)
	form.add_child(shapes)
	var shape_group := ButtonGroup.new()
	for shape: String in LabelSystem.SHAPES:
		var chip := Button.new()
		chip.name = "Shape_%s" % shape
		chip.text = {"circle": "Círculo", "hex": "Hexágono", "diamond": "Losango", "square": "Quadrado", "shield": "Escudo"}[shape]
		chip.theme_type_variation = &"ChipButton"
		chip.toggle_mode = true
		chip.button_group = shape_group
		chip.focus_mode = Control.FOCUS_NONE
		chip.button_pressed = shape == _create_shape
		chip.pressed.connect(func() -> void:
			_create_shape = shape
			_update_create_logo())
		shapes.add_child(chip)
	var colors := HBoxContainer.new()
	colors.add_theme_constant_override("separation", 6)
	form.add_child(colors)
	var color_group := ButtonGroup.new()
	for index in PRESET_COLORS.size():
		var pair: Array = PRESET_COLORS[index]
		var swatch := Button.new()
		swatch.name = "Color_%d" % index
		swatch.theme_type_variation = &"SwatchButton"
		swatch.custom_minimum_size = Vector2(40, 40)
		swatch.toggle_mode = true
		swatch.button_group = color_group
		swatch.focus_mode = Control.FOCUS_NONE
		swatch.button_pressed = pair == _create_colors
		var dot := LabelLogo.new()
		dot.color = Color(pair[0])
		dot.color2 = Color(pair[1])
		dot.text = ""
		dot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dot.offset_left = 5
		dot.offset_top = 5
		dot.offset_right = -5
		dot.offset_bottom = -5
		swatch.add_child(dot)
		swatch.pressed.connect(func() -> void:
			_create_colors = pair
			_update_create_logo())
		colors.add_child(swatch)
	var create := Button.new()
	create.name = "CreateLabelButton"
	create.text = "Fundar gravadora (%s)" % Fmt.money(rules.creation_cost)
	create.theme_type_variation = &"PrimaryButton"
	create.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var block := GameManager.labels.create_block(career, _create_name.text if not _create_name.text.is_empty() else "XX")
	create.disabled = not block.is_empty()
	create.tooltip_text = block
	create.pressed.connect(func() -> void:
		_message.text = GameManager.create_label(_create_name.text, _create_short.text, _create_shape, Color(_create_colors[0]), Color(_create_colors[1])).message)
	form.add_child(create)
	if not block.is_empty():
		var why := _label(block, &"StatCaption")
		why.name = "CreateBlock"
		form.add_child(why)
	_update_create_logo()


func _update_create_logo() -> void:
	_create_logo.shape = _create_shape
	_create_logo.color = Color(_create_colors[0])
	_create_logo.color2 = Color(_create_colors[1])
	var short := _create_short.text.strip_edges()
	if short.is_empty():
		for word in _create_name.text.split(" ", false):
			short += word.left(1)
	_create_logo.text = short.to_upper().left(4) if not short.is_empty() else "?"


func _build_history(career: CareerData) -> void:
	if career.label.history.is_empty():
		_content.add_child(_note("Nada por aqui ainda. Propostas, contratos e a sua gravadora aparecem nesta linha do tempo."))
		return
	for index in range(career.label.history.size() - 1, -1, -1):
		var item: Dictionary = career.label.history[index]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var when := _label("SEM. %d" % int(item["week"]), &"Kicker")
		when.custom_minimum_size.x = 70
		row.add_child(when)
		var text := _label(item["text"], &"")
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		_content.add_child(row)


# ---- contratado

func _build_contract(career: CareerData) -> void:
	var contract := career.label.contract
	var label := GameManager.labels.find_label(contract.label_id)
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 12)
	_content.add_child(tiles)
	var recoup := StatTile.new("A recuperar", "money", Color("#f5b82e"))
	recoup.set_value(Fmt.money(contract.recoup_left), "de %s de adiantamento" % Fmt.money(contract.advance))
	var budget := StatTile.new("Orçamento", "marketing", Color("#4fa3ff"))
	budget.set_value(Fmt.money(contract.budget_left), "de %s para custos" % Fmt.money(contract.budget))
	var covered := StatTile.new("Custos pagos", "release", Color("#46d483"))
	covered.set_value(Fmt.money(contract.covered_total), "marketing, clipes e lançamentos")
	var weeks := StatTile.new("Prazo", "calendar", Color("#b07cff"))
	weeks.set_value("%d sem." % contract.weeks_left(career.current_week), "termina na semana %d" % contract.end_week)
	for tile in [recoup, budget, covered, weeks]:
		tiles.add_child(tile)
	# O caminho do dinheiro das receitas de música.
	var flow := _card("RevenueFlow")
	_content.add_child(flow)
	var flow_column := VBoxContainer.new()
	flow_column.add_theme_constant_override("separation", 8)
	flow.add_child(flow_column)
	flow_column.add_child(_label("CAMINHO DO DINHEIRO  •  STREAMS E VENDAS", &"SectionLabel"))
	var steps := HBoxContainer.new()
	steps.add_theme_constant_override("separation", 14)
	flow_column.add_child(steps)
	var artist_net := contract.gross_total - contract.label_total - contract.recouped_total
	for index in 4:
		var pair: Array = [[contract.gross_total, "Receita bruta", Color("#f3f0f7")], [contract.label_total, "Gravadora (%d%%)" % roundi((1.0 - contract.artist_share) * 100), Color("#ff8a94")],
			[contract.recouped_total, "Adiantamento recuperado", Color("#f5b82e")], [artist_net, "Você recebeu", Color("#46d483")]][index]
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", -2)
		var value := _label(Fmt.money(pair[0]), &"BigNumber")
		value.add_theme_font_size_override("font_size", 24)
		value.add_theme_color_override("font_color", pair[2])
		box.add_child(value)
		box.add_child(_label(pair[1], &"StatCaption"))
		steps.add_child(box)
		if index < 3:
			steps.add_child(_label("→", &"MutedLabel"))
	var benefits := _label(_benefits_text(contract.marketing_support, contract.video_support, contract.release_support, contract.discovery_bonus, contract.show_bonus), &"MutedLabel")
	benefits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(benefits)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	_content.add_child(actions)
	var terminate := Button.new()
	terminate.name = "TerminateButton"
	terminate.text = "Rescindir contrato (%s)" % Fmt.money(GameManager.labels.termination_fee(career))
	terminate.theme_type_variation = &"DangerButton"
	terminate.tooltip_text = "Paga o que falta recuperar do adiantamento mais a multa e volta a ser independente."
	terminate.pressed.connect(func() -> void: _message.text = GameManager.terminate_label_contract().message)
	actions.add_child(terminate)
	var after := _label("Ao terminar o contrato, a %s propõe renovar; você também pode seguir independente ou abrir sua gravadora." % label.display_name, &"StatCaption")
	after.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	after.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	after.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	terminate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	actions.add_child(after)


func _build_catalog(career: CareerData) -> void:
	var entries: Array[Dictionary] = GameManager.labels.player_catalog(career)
	for item in career.label.catalog:
		entries.append({"title": item["title"], "kind": "song", "week": item["week"], "streams": item["streams"], "revenue": item["revenue"],
			"label": career.label.own.name if career.label.own != null else "", "artist": GameManager.social.display_name(item["artist_id"])})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["week"] > b["week"])
	if entries.is_empty():
		_content.add_child(_note("Ainda não há lançamentos sob o selo. O que você lançar a partir de agora entra aqui, junto com as faixas dos artistas da gravadora."))
		return
	var table := DataTable.new()
	table.name = "LabelCatalog"
	table.custom_minimum_size = Vector2(0, 320)
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(table)
	table.set_headers(["Título", "Artista", "Tipo", "Semana", "Streams", "Receita"])
	table.set_column_expand_ratio(0, 3)
	for item in entries:
		table.add_row([item["title"], item["artist"], "Single" if item["kind"] == "song" else "Projeto", Fmt.number(item["week"]),
			Fmt.number(item["streams"]), Fmt.money(item["revenue"])])


# ---- dono

func _build_artists(career: CareerData) -> void:
	var own := career.label.own
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 12)
	_content.add_child(tiles)
	var totals := own.totals()
	for spec: Array in [["Caixa", own.balance, 0, "money"], ["Receitas", totals["income"], 1, "plus"], ["Despesas", totals["expenses"], -1, "release"], ["Lucro", totals["profit"], signi(totals["profit"]), "chart"]]:
		var tile := StatTile.new(spec[0], spec[3], Color("#f5b82e"))
		tile.set_value(Fmt.money(spec[1]) if spec[0] != "Lucro" else Fmt.signed_money(spec[1]), "", spec[2])
		tiles.add_child(tile)
	if own.artists.is_empty():
		_content.add_child(_note("Nenhum artista contratado. Em \"Contratar\", escolha artistas do jogo que ainda não têm gravadora."))
		return
	for signed in own.artists:
		var person := GameManager.social.person(signed.artist_id)
		var card := _card("Signed_%s" % signed.artist_id)
		_content.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		card.add_child(row)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 0)
		row.add_child(texts)
		texts.add_child(_label(GameManager.social.display_name(signed.artist_id), &"ChipLabel"))
		texts.add_child(_label("%s  •  contrato até a semana %d  •  %d lançamento(s)" % [person.tier_label() if person != null else "", signed.end_week, signed.releases], &"StatCaption"))
		row.add_child(_big_value(Fmt.money(signed.last_week_revenue), "ÚLTIMA SEMANA"))
		row.add_child(_big_value(Fmt.money(signed.label_revenue_total), "PARA A GRAVADORA"))
		var release := Button.new()
		release.name = "ReleaseArtist_%s" % signed.artist_id
		release.text = "Liberar"
		release.theme_type_variation = &"GhostButton"
		release.tooltip_text = "Encerra o contrato. O artista fica livre."
		release.pressed.connect(func() -> void: _message.text = GameManager.release_label_artist(signed.artist_id).message)
		row.add_child(release)


func _build_sign(career: CareerData) -> void:
	var own := career.label.own
	var lvl := GameManager.labels.level(career)
	_content.add_child(_note("Vagas: %d de %d no nível %s. A contratação sai do caixa da gravadora; cada artista recebe salário semanal e a gravadora fica com %d%% do que ele faturar. Amigos fazem desconto; rivais recusam." % [
		own.artists.size(), lvl.max_artists, lvl.display_name, roundi(GameManager.labels.rules().label_share_of_artists * 100)]))
	for person in GameManager.labels.signable_artists(career):
		var artist_id := String(person.id)
		var row := HBoxContainer.new()
		row.name = "Signable_%s" % artist_id
		row.add_theme_constant_override("separation", 12)
		_content.add_child(row)
		var name_label := _label("%s  ·  %s, %s" % [person.display_name, person.tier_label(), person.country], &"")
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		row.add_child(_label(GameManager.social.status(career, artist_id)["label"], &"StatCaption"))
		var fee := _label(Fmt.money(GameManager.labels.signing_fee(career, artist_id)), &"ChipLabel")
		fee.custom_minimum_size.x = 100
		fee.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(fee)
		var sign := Button.new()
		sign.name = "Sign_%s" % artist_id
		sign.text = "Contratar"
		var block := GameManager.labels.sign_block(career, artist_id)
		sign.disabled = not block.is_empty()
		sign.tooltip_text = block
		sign.pressed.connect(func() -> void: _message.text = GameManager.sign_label_artist(artist_id).message)
		row.add_child(sign)


func _build_finance(career: CareerData) -> void:
	var own := career.label.own
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_content.add_child(row)
	row.add_child(_label("Caixa: %s  •  seu dinheiro: %s" % [Fmt.money(own.balance), Fmt.money(career.money)], &"ChipLabel"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	if _amount.get_parent() != null:
		_amount.get_parent().remove_child(_amount)
	row.add_child(_amount)
	var deposit := Button.new()
	deposit.name = "DepositButton"
	deposit.text = "Depositar"
	deposit.pressed.connect(func() -> void: _message.text = GameManager.label_deposit(int(_amount.value)).message)
	row.add_child(deposit)
	var withdraw := Button.new()
	withdraw.name = "WithdrawButton"
	withdraw.text = "Sacar"
	withdraw.pressed.connect(func() -> void: _message.text = GameManager.label_withdraw(int(_amount.value)).message)
	row.add_child(withdraw)
	var table := DataTable.new()
	table.name = "LabelLedger"
	table.custom_minimum_size = Vector2(0, 300)
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(table)
	table.set_headers(["Descrição", "Semana", "Valor"])
	table.set_column_expand_ratio(0, 4)
	for index in range(own.ledger.size() - 1, maxi(own.ledger.size() - 60, 0) - 1, -1):
		var entry: Dictionary = own.ledger[index]
		table.add_row([entry["description"], Fmt.number(int(entry["week"])), Fmt.signed_money(int(entry["amount"]))])


func _build_growth(career: CareerData) -> void:
	var own := career.label.own
	var levels := GameManager.labels.rules().levels
	var flow := HBoxContainer.new()
	flow.add_theme_constant_override("separation", 12)
	_content.add_child(flow)
	for index in levels.size():
		var lvl: LabelLevelDefinition = levels[index]
		var card := _card("Level_%d" % index)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if index == own.level:
			card.theme_type_variation = &"HeroPanel"
		flow.add_child(card)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 2)
		card.add_child(column)
		column.add_child(_label("ATUAL" if index == own.level else ("FEITO" if index < own.level else "PRÓXIMO" if index == own.level + 1 else "DEPOIS"), &"Kicker"))
		column.add_child(_label(lvl.display_name, &"ChipLabel"))
		column.add_child(_label("Até %d artistas" % lvl.max_artists, &"StatCaption"))
		column.add_child(_label("+%d%% alcance  •  +%d%% shows" % [roundi(lvl.reach_bonus * 100), roundi(lvl.show_bonus * 100)], &"StatCaption"))
		if index > 0:
			column.add_child(_label("%s  •  reputação %d" % [Fmt.money(lvl.upgrade_cost), lvl.min_reputation], &"StatCaption"))
	var upgrade := Button.new()
	upgrade.name = "UpgradeLabelButton"
	var next := GameManager.labels.next_level(career)
	upgrade.text = "Expandir para %s (%s)" % [next.display_name, Fmt.money(next.upgrade_cost)] if next != null else "Nível máximo"
	upgrade.theme_type_variation = &"PrimaryButton"
	upgrade.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var block := GameManager.labels.upgrade_block(career)
	upgrade.disabled = not block.is_empty()
	upgrade.tooltip_text = block
	upgrade.pressed.connect(func() -> void: _message.text = GameManager.upgrade_label().message)
	_content.add_child(upgrade)
	if not block.is_empty():
		_content.add_child(_label(block, &"StatCaption"))


# ---- apoio

func _card(node_name: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = node_name
	card.theme_type_variation = &"Card"
	return card


func _note(text: String) -> Label:
	var label := _label(text, &"MutedLabel")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	return label


## Os campos do formulário sobrevivem às atualizações da tela (o texto digitado não se perde).
func _clear(node: Node) -> void:
	for keep: Control in [_create_logo, _create_name, _create_short, _amount]:
		if keep.get_parent() != null and node.is_ancestor_of(keep):
			keep.get_parent().remove_child(keep)
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
