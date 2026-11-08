extends Screen
## Um artista: quem é, como está a relação, o que dá para fazer agora e, em abas, o histórico,
## a rede dele e o que vocês já fizeram juntos. context precisa ter artist_id.

var _artist_id: String
var _status := Label.new()
var _bar_slot := HBoxContainer.new()
var _price := Label.new()
var _actions := VBoxContainer.new()
var _beef := VBoxContainer.new()
var _history := VBoxContainer.new()
var _network := Label.new()
var _together := Label.new()
var _message := Label.new()


func _ready() -> void:
	_artist_id = context.get("artist_id", "")
	var social := GameManager.social
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	_build_header(column, social)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	column.add_child(body)
	var left := PanelContainer.new()
	left.name = "ActionsCard"
	left.custom_minimum_size = Vector2(330, 0)
	body.add_child(left)
	var left_scroll := ScrollContainer.new()
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(left_scroll)
	var left_column := VBoxContainer.new()
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_column.add_theme_constant_override("separation", 8)
	left_scroll.add_child(left_column)
	_beef.name = "BeefPanel"
	_beef.add_theme_constant_override("separation", 6)
	left_column.add_child(_beef)
	var header := Label.new()
	header.text = "O QUE FAZER"
	header.theme_type_variation = &"SectionLabel"
	left_column.add_child(header)
	_actions.name = "Actions"
	_actions.add_theme_constant_override("separation", 6)
	left_column.add_child(_actions)
	var tabs := TabContainer.new()
	tabs.name = "RelationTabs"
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(tabs)
	var history_scroll := ScrollContainer.new()
	history_scroll.name = "Histórico"
	history_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(history_scroll)
	_history.name = "HistoryList"
	_history.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_scroll.add_child(_history)
	_text_tab(tabs, "Rede", _network, "NetworkLabel")
	_text_tab(tabs, "Juntos", _together, "TogetherLabel")
	_message.name = "MessageLabel"
	_message.theme_type_variation = &"MessageLabel"
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_message)
	var row := HBoxContainer.new()
	column.add_child(row)
	var back := Button.new()
	back.name = "BackButton"
	back.text = "Voltar às relações"
	back.pressed.connect(navigate.bind(Screen.SOCIAL))
	row.add_child(back)
	super()


func _build_header(parent: Container, social: SocialSystem) -> void:
	var hero := PanelContainer.new()
	hero.name = "Header"
	hero.theme_type_variation = &"HeroPanel"
	parent.add_child(hero)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	hero.add_child(row)
	var avatar := TextureRect.new()
	avatar.texture = CoverArt.generated(social.display_name(_artist_id) + " perfil")
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.custom_minimum_size = Vector2(96, 96)
	row.add_child(avatar)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 4)
	row.add_child(texts)
	var name := Label.new()
	name.name = "Title"
	name.text = social.display_name(_artist_id)
	name.theme_type_variation = &"TitleLabel"
	texts.add_child(name)
	_status.name = "StatusLabel"
	_status.theme_type_variation = &"ChipLabel"
	texts.add_child(_status)
	_bar_slot.name = "BarSlot"
	texts.add_child(_bar_slot)
	var personality := Label.new()
	personality.text = "Jeito: %s" % social.personality_text(_artist_id)
	personality.theme_type_variation = &"MutedLabel"
	texts.add_child(personality)
	_price.name = "PriceLabel"
	_price.theme_type_variation = &"ChipLabel"
	_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_price.custom_minimum_size = Vector2(220, 0)
	_price.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(_price)


func _text_tab(tabs: TabContainer, title: String, label: Label, node_name: String) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	label.name = node_name
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(label)


func refresh() -> void:
	var career := GameManager.career
	var social := GameManager.social
	var current := social.peek(career, _artist_id)
	var met := current != null and current.met
	var value := current.value if current != null else 0
	_status.text = social.status(career, _artist_id)["label"]
	_status.add_theme_color_override("font_color", RelationVisuals.color(value, met))
	for child in _bar_slot.get_children():
		_bar_slot.remove_child(child)
		child.queue_free()
	var bar := RelationVisuals.bar(value, met)
	bar.custom_minimum_size = Vector2(260, 10)
	_bar_slot.add_child(bar)
	_price.text = ("Feat: %s" % social.price_text(career, _artist_id)) if met else "Feat: %s\nVocês ainda não se conhecem." % Fmt.money(social.size_of(_artist_id))
	_fill_beef(career, social)
	_fill_actions(career, social)
	_fill_history(current)
	_fill_network(career, social)
	_fill_together(career, current)


func _fill_beef(career: CareerData, social: SocialSystem) -> void:
	_clear(_beef)
	var beef := career.social.active_beef_with(_artist_id)
	if beef == null:
		return
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"Card"
	_beef.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	var title := Label.new()
	title.text = "BEEF  •  %s" % beef.intensity_label().to_upper()
	title.theme_type_variation = &"SectionLabel"
	title.add_theme_color_override("font_color", RelationVisuals.NEGATIVE)
	column.add_child(title)
	var turn := Label.new()
	turn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	turn.text = "Sua vez de reagir." if beef.awaiting == Beef.TURN_PLAYER else ("Esperando a reação de %s." % social.display_name(_artist_id) if beef.awaiting == Beef.TURN_ARTIST else "Sem resposta pendente.")
	column.add_child(turn)
	var diss := Button.new()
	diss.name = "DissButton"
	diss.text = "Gravar uma diss"
	diss.icon = load("res://assets/icons/music.svg")
	diss.theme_type_variation = &"PrimaryButton" if beef.awaiting == Beef.TURN_PLAYER else &""
	diss.tooltip_text = "Abre a criação de música com %s como alvo. A diss sai quando você lançar." % social.display_name(_artist_id)
	diss.pressed.connect(navigate.bind(Screen.SONG_EDITOR, {"diss_target": _artist_id}))
	column.add_child(diss)
	if beef.awaiting == Beef.TURN_PLAYER:
		var ignore := Button.new()
		ignore.name = "IgnoreButton"
		ignore.text = "Ignorar"
		ignore.tooltip_text = "O beef perde força e sua reputação agradece."
		ignore.pressed.connect(func() -> void: _message.text = GameManager.ignore_beef(_artist_id).message)
		column.add_child(ignore)


func _fill_actions(career: CareerData, social: SocialSystem) -> void:
	_clear(_actions)
	var options := social.interactions(career, _artist_id)
	if options.is_empty():
		var none := Label.new()
		none.text = "Nada a fazer agora."
		none.theme_type_variation = &"MutedLabel"
		_actions.add_child(none)
	for option in options:
		var definition: SocialInteractionDefinition = option["definition"]
		var button := Button.new()
		button.name = "Action_%s" % definition.id
		var cost := PackedStringArray()
		if definition.money_cost > 0:
			cost.append(Fmt.money(definition.money_cost))
		if definition.energy_cost > 0:
			cost.append("%d de energia" % definition.energy_cost)
		button.text = definition.display_name + ("  (%s)" % ", ".join(cost) if not cost.is_empty() else "")
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = not option["available"]
		button.tooltip_text = definition.description + ("" if option["available"] else "\n" + option["reason"])
		if definition.kind in ["provoke", "respond"]:
			button.theme_type_variation = &"DangerButton"
		button.pressed.connect(func() -> void: _message.text = GameManager.social_interact(_artist_id, definition.id).message)
		_actions.add_child(button)
		if not option["available"]:
			var reason := Label.new()
			reason.text = "   " + option["reason"]
			reason.theme_type_variation = &"MutedLabel"
			_actions.add_child(reason)


func _fill_history(current: Relationship) -> void:
	_clear(_history)
	if current == null or current.history.is_empty():
		var empty := Label.new()
		empty.text = "Nenhuma história ainda."
		empty.theme_type_variation = &"MutedLabel"
		_history.add_child(empty)
		return
	for index in range(current.history.size() - 1, -1, -1):
		var item: Dictionary = current.history[index]
		var line := Label.new()
		line.text = "Semana %s  —  %s" % [Fmt.number(item["week"]), item["text"]]
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_history.add_child(line)


func _fill_network(career: CareerData, social: SocialSystem) -> void:
	var friends := social.friends_of(career, _artist_id).map(func(id: String) -> String: return social.display_name(id))
	var rivals := social.rivals_of(career, _artist_id).map(func(id: String) -> String: return social.display_name(id))
	_network.text = "Amigos: %s\n\nRivais: %s\n\nAmigos dele se afastam de quem briga com ele; rivais dele gostam de quem o enfrenta." % [
		", ".join(friends) if not friends.is_empty() else "—", ", ".join(rivals) if not rivals.is_empty() else "—"]


func _fill_together(career: CareerData, current: Relationship) -> void:
	if current == null:
		_together.text = "Nada ainda."
		return
	var beefs := career.social.beefs.filter(func(item: Beef) -> bool: return item.artist_id == _artist_id)
	_together.text = "Feats: %d\nShows juntos: %d\nBeefs: %d (%d encerrado(s))" % [current.feats, current.shows, beefs.size(),
		beefs.filter(func(item: Beef) -> bool: return not item.is_active()).size()]


func _clear(node: Container) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
