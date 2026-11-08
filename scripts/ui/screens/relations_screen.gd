extends Screen
## Relações: convites e conflitos que pedem resposta, e a lista de artistas com status e barra.
## Detalhes e ações de cada artista ficam na tela do artista.

const FILTERS := ["Conhecidos", "Amigos", "Rivais", "Descobrir"]

var _subtitle := Label.new()
var _inbox := VBoxContainer.new()
var _list := VBoxContainer.new()
var _message := Label.new()
var _filter := 0


func _ready() -> void:
	_filter = int(context.get("filter", 0))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 0)
	column.add_child(header)
	var title := Label.new()
	title.text = "Relações"
	title.theme_type_variation = &"TitleLabel"
	header.add_child(title)
	_subtitle.name = "Summary"
	_subtitle.theme_type_variation = &"MutedLabel"
	header.add_child(_subtitle)
	_inbox.name = "Inbox"
	_inbox.add_theme_constant_override("separation", 8)
	column.add_child(_inbox)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 8)
	column.add_child(filters)
	var group := ButtonGroup.new()
	for index in FILTERS.size():
		var chip := Button.new()
		chip.name = "Filter%d" % index
		chip.text = FILTERS[index]
		chip.theme_type_variation = &"ChipButton"
		chip.toggle_mode = true
		chip.button_group = group
		chip.button_pressed = index == _filter
		chip.focus_mode = Control.FOCUS_NONE
		chip.pressed.connect(func() -> void:
			_filter = index
			refresh())
		filters.add_child(chip)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_list.name = "ArtistList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	_message.name = "MessageLabel"
	_message.theme_type_variation = &"MessageLabel"
	column.add_child(_message)
	super()


func refresh() -> void:
	var career := GameManager.career
	var social := GameManager.social
	var known := 0
	var friends := 0
	var rivals := 0
	for artist_id in career.social.relations:
		var current := career.social.relations[artist_id]
		if current.met:
			known += 1
			friends += 1 if current.value >= 30 else 0
			rivals += 1 if current.value <= -15 else 0
	_subtitle.text = "%d conhecido(s)  •  %d amigo(s)  •  %d em conflito" % [known, friends, rivals]
	_fill_inbox(career)
	_fill_list(career, social)


func _fill_inbox(career: CareerData) -> void:
	_clear(_inbox)
	var social := GameManager.social
	for invite in social.pending_invites(career):
		var card := _inbox_card("CONVITE", social.invite_text(invite))
		var accept := Button.new()
		accept.name = "Accept_%s" % invite.id
		accept.text = "Aceitar"
		accept.theme_type_variation = &"PrimaryButton"
		accept.pressed.connect(func() -> void: _message.text = GameManager.accept_social_invite(invite.id).message)
		card.add_child(accept)
		var decline := Button.new()
		decline.name = "Decline_%s" % invite.id
		decline.text = "Recusar"
		decline.pressed.connect(func() -> void: _message.text = GameManager.decline_social_invite(invite.id).message)
		card.add_child(decline)
	for beef in career.social.beefs:
		if beef.is_active() and beef.awaiting == Beef.TURN_PLAYER:
			var card := _inbox_card("BEEF  •  SUA VEZ", "%s: %s" % [social.display_name(beef.artist_id), beef.events[-1]["text"] if not beef.events.is_empty() else beef.intensity_label()])
			var open := Button.new()
			open.text = "Ver conflito"
			open.icon = load("res://assets/icons/beef.svg")
			open.pressed.connect(navigate.bind(Screen.ARTIST_RELATION, {"artist_id": beef.artist_id}))
			card.add_child(open)


func _inbox_card(kicker: String, text: String) -> HBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"HeroPanel"
	_inbox.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	row.add_child(texts)
	var label := Label.new()
	label.text = kicker
	label.theme_type_variation = &"SectionLabel"
	texts.add_child(label)
	var body := Label.new()
	body.text = text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(body)
	return row


func _fill_list(career: CareerData, social: SocialSystem) -> void:
	_clear(_list)
	var ids: Array[String] = []
	for person in social.artists():
		var artist_id := String(person.id)
		var current := social.peek(career, artist_id)
		var met := current != null and current.met
		var value := current.value if current != null else 0
		var keep := false
		match _filter:
			0:
				keep = met
			1:
				keep = met and value >= 30
			2:
				keep = met and value <= -15
			3:
				keep = not met
		if keep:
			ids.append(artist_id)
	if _filter == 3:
		ids.sort_custom(func(a: String, b: String) -> bool: return social.size_of(a) < social.size_of(b))
	else:
		ids.sort_custom(func(a: String, b: String) -> bool: return social.peek(career, a).value > social.peek(career, b).value)
	if ids.is_empty():
		var empty := Label.new()
		empty.theme_type_variation = &"MutedLabel"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.text = ["Você ainda não conhece ninguém. Em \"Descobrir\", puxe conversa com artistas; feats, shows e festivais também apresentam você à cena.",
			"Nenhum amigo ainda. Conversas, rolês, feats e shows juntos aproximam vocês aos poucos.",
			"Nenhum conflito. Provocações e diss tracks criam rivalidades.", "Você já conhece todos os artistas."][_filter]
		_list.add_child(empty)
	for artist_id in ids:
		_list.add_child(_row(career, social, artist_id))


func _row(career: CareerData, social: SocialSystem, artist_id: String) -> Button:
	var current := social.peek(career, artist_id)
	var value := current.value if current != null else 0
	var state := social.status(career, artist_id)
	var button := Button.new()
	button.name = "Artist_%s" % artist_id
	button.theme_type_variation = &"MediaCard"
	button.custom_minimum_size = Vector2(0, 66)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(navigate.bind(Screen.ARTIST_RELATION, {"artist_id": artist_id}))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -14
	row.add_theme_constant_override("separation", 14)
	button.add_child(row)
	var avatar := TextureRect.new()
	avatar.texture = CoverArt.generated(social.display_name(artist_id) + " perfil")
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.custom_minimum_size = Vector2(44, 44)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(avatar)
	var texts := VBoxContainer.new()
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.custom_minimum_size = Vector2(240, 0)
	texts.add_theme_constant_override("separation", 0)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)
	var name := Label.new()
	name.text = social.display_name(artist_id)
	var person := social.person(artist_id)
	if person != null and not person.tier_label().is_empty():
		name.text += "   ·  %s, %s" % [person.tier_label(), person.country]
	name.theme_type_variation = &"ChipLabel"
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(name)
	var status_label := Label.new()
	status_label.text = "%s %s" % [_symbol(value, current != null and current.met), state["label"]]
	status_label.theme_type_variation = &"StatCaption"
	status_label.add_theme_color_override("font_color", RelationVisuals.color(value, current != null and current.met))
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(status_label)
	var bar := RelationVisuals.bar(value, current != null and current.met)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var info := Label.new()
	info.theme_type_variation = &"MutedLabel"
	info.custom_minimum_size = Vector2(200, 0)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.text = social.price_text(career, artist_id) if current != null and current.met else "Feat: %s" % Fmt.money(social.size_of(artist_id))
	if career.social.active_beef_with(artist_id) != null:
		info.text = "Beef: %s" % career.social.active_beef_with(artist_id).intensity_label()
	row.add_child(info)
	return button


func _symbol(value: int, met: bool) -> String:
	if not met:
		return "?"
	if value <= -15:
		return "⚔"
	return "♥" if value >= 30 else "○"


func _clear(node: Container) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
