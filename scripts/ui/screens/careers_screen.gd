extends Screen
## Carreiras salvas: cada uma é um save independente. Carregar, criar uma nova ou excluir.

var _list := VBoxContainer.new()
var _message := Label.new()
var _confirm := ConfirmationDialog.new()
var _pending_delete: String = ""


func _ready() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var title := Label.new()
	title.text = "Carreiras"
	title.theme_type_variation = &"TitleLabel"
	column.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_list.name = "CareerList"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
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
	create.text = "+ NOVA CARREIRA"
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
	var panel := PanelContainer.new()
	panel.name = "Career_%s" % info["slot"]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	var view := CharacterView.new()
	view.custom_minimum_size = Vector2(70, 140)
	view.appearance = CharacterAppearance.from_dict(info["appearance"])
	row.add_child(view)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var name_label := Label.new()
	name_label.theme_type_variation = &"HeaderLabel"
	name_label.text = "Carreira %d — %s" % [number, info["artist_name"]]
	text.add_child(name_label)
	var details := Label.new()
	var parts := PackedStringArray()
	if not String(info["real_name"]).is_empty():
		parts.append(info["real_name"])
	parts.append("%d anos" % characters.age_at(info["age"], info["week"]))
	if not String(info["country"]).is_empty():
		parts.append(characters.location_label(info["country"], info["city"]))
	details.text = "%s\nFama: %s  •  Dinheiro: %s  •  Semana %s  •  Energia infinita: %s\nÚltimo salvamento: %s" % [
		"  •  ".join(parts), Fmt.number(info["fame"]), Fmt.money(info["money"]), Fmt.number(info["week"]),
		"ON" if info["infinite_energy"] else "OFF", _when(info["saved_at"])]
	text.add_child(details)
	var buttons := VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(buttons)
	var load := Button.new()
	load.name = "LoadButton"
	load.text = "Carregar"
	load.theme_type_variation = &"PrimaryButton"
	load.pressed.connect(_on_load.bind(info["slot"]))
	buttons.add_child(load)
	var delete := Button.new()
	delete.name = "DeleteButton"
	delete.text = "Excluir"
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
