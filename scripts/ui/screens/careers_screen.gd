extends Screen
## Carreiras salvas: cada uma é um save independente, mostrada como um pôster com o artista no
## palco, a fase e os números principais. Jogar, criar uma nova ou excluir.

const STAGE_LIGHTS := ["#8c86a0", "#2ec4b6", "#a25cff", "#4fa3ff", "#f5b82e", "#ff5ea8"]

var _list := HFlowContainer.new()
var _message := Label.new()
var _confirm := ConfirmationDialog.new()
var _pending_delete: String = ""


func _ready() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var kicker := Label.new()
	kicker.text = "RAPSTAR"
	kicker.theme_type_variation = &"Kicker"
	column.add_child(kicker)
	var title := Label.new()
	title.text = "Suas carreiras"
	title.theme_type_variation = &"TitleLabel"
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Cada carreira tem o próprio save. Excluir uma não afeta as outras."
	subtitle.theme_type_variation = &"MutedLabel"
	column.add_child(subtitle)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_list.name = "CareerList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("h_separation", 18)
	_list.add_theme_constant_override("v_separation", 18)
	scroll.add_child(_list)
	_message.name = "MessageLabel"
	_message.theme_type_variation = &"MessageLabel"
	column.add_child(_message)
	var row := HBoxContainer.new()
	column.add_child(row)
	var back := Button.new()
	back.name = "BackButton"
	back.text = "Voltar"
	back.pressed.connect(navigate.bind(Screen.MAIN_MENU))
	row.add_child(back)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var create := Button.new()
	create.name = "NewCareerButton"
	create.text = "Nova carreira"
	create.icon = load("res://assets/icons/plus.svg")
	create.theme_type_variation = &"PrimaryButton"
	create.pressed.connect(navigate.bind(Screen.NEW_CAREER))
	row.add_child(create)
	_confirm.name = "DeleteConfirm"
	_confirm.title = "Excluir carreira"
	_confirm.ok_button_text = "Excluir"
	_confirm.cancel_button_text = "Cancelar"
	_confirm.confirmed.connect(_on_delete_confirmed)
	add_child(_confirm)
	super()


func refresh() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var careers := GameManager.list_careers()
	if careers.is_empty():
		var empty := Label.new()
		empty.text = "Nenhuma carreira salva ainda."
		_list.add_child(empty)
	for index in careers.size():
		_list.add_child(_card(index + 1, careers[index]))


func _card(number: int, info: Dictionary) -> PanelContainer:
	var characters := GameManager.characters
	var progression := GameManager.progression
	var panel := PanelContainer.new()
	panel.name = "Career_%s" % info["slot"]
	panel.theme_type_variation = &"Card"
	panel.custom_minimum_size = Vector2(260, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	# Pôster: o artista no palco, com a luz da fase da carreira.
	var poster := PanelContainer.new()
	poster.theme_type_variation = &"StagePanel"
	poster.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	poster.custom_minimum_size = Vector2(0, 230)
	column.add_child(poster)
	var holder := Control.new()
	poster.add_child(holder)
	var backdrop := StageBackdrop.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.floor_ratio = 0.93
	backdrop.light = Color(STAGE_LIGHTS[mini(progression.stage_index(info["fame"]), STAGE_LIGHTS.size() - 1)])
	holder.add_child(backdrop)
	var view := CharacterView.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.offset_top = 12
	view.offset_bottom = -6
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.appearance = CharacterAppearance.from_dict(info["appearance"])
	holder.add_child(view)
	var kicker := Label.new()
	kicker.theme_type_variation = &"Kicker"
	kicker.text = "CARREIRA %d  •  %s" % [number, progression.stage_for(info["fame"]).display_name.to_upper()]
	column.add_child(kicker)
	var name_label := Label.new()
	name_label.theme_type_variation = &"ChipLabel"
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.text = info["artist_name"]
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.tooltip_text = "Carreira %d — %s" % [number, info["artist_name"]]
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(name_label)
	var details := Label.new()
	details.theme_type_variation = &"MutedLabel"
	var parts := PackedStringArray()
	if not String(info["real_name"]).is_empty():
		parts.append(info["real_name"])
	parts.append("%d anos" % characters.age_at(info["age"], info["week"]))
	if not String(info["country"]).is_empty():
		parts.append(characters.location_label(info["country"], info["city"]))
	details.text = "%s
Semana %s  •  Fama %s  •  %s
Energia infinita: %s  •  Salvo: %s" % [
		"  •  ".join(parts), Fmt.number(info["week"]), Fmt.number(info["fame"]), Fmt.money(info["money"]),
		"ON" if info["infinite_energy"] else "OFF", _when(info["saved_at"])]
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(details)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	column.add_child(buttons)
	var play := Button.new()
	play.name = "LoadButton"
	play.text = "Jogar"
	play.icon = load("res://assets/icons/next.svg")
	play.theme_type_variation = &"PrimaryButton"
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play.pressed.connect(_on_load.bind(info["slot"]))
	buttons.add_child(play)
	var delete := Button.new()
	delete.name = "DeleteButton"
	delete.text = "Excluir"
	delete.theme_type_variation = &"DangerButton"
	delete.tooltip_text = "Apaga esta carreira (pede confirmação)"
	delete.pressed.connect(_ask_delete.bind(info["slot"], info["artist_name"]))
	buttons.add_child(delete)
	return panel


func _when(timestamp: int) -> String:
	var now := Time.get_unix_time_from_system()
	var today := Time.get_date_dict_from_unix_time(int(now))
	var saved := Time.get_date_dict_from_unix_time(timestamp)
	var days := int((Time.get_unix_time_from_datetime_dict(today) - Time.get_unix_time_from_datetime_dict(saved)) / 86400)
	if days <= 0:
		return "Hoje"
	if days == 1:
		return "Ontem"
	if days < 7:
		return "Há %d dias" % days
	return "%02d/%02d/%d" % [saved["day"], saved["month"], saved["year"]]


func _on_load(slot: String) -> void:
	var result := GameManager.load_game(slot)
	if result.ok:
		navigate.call_deferred(Screen.HUB)
	else:
		_message.text = result.message


func _ask_delete(slot: String, artist_name: String) -> void:
	_pending_delete = slot
	_confirm.dialog_text = "Excluir a carreira de %s? O progresso dela será apagado e não poderá ser recuperado. As outras carreiras não são afetadas." % artist_name
	_confirm.popup_centered()


func _on_delete_confirmed() -> void:
	_message.text = GameManager.delete_career(_pending_delete).message
	_pending_delete = ""
	refresh()
