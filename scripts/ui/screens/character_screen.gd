extends Screen
## Personagem da carreira aberta: identidade, aparência e configuração de energia infinita.
## Usa o mesmo editor da criação; salvar troca só a aparência e grava no save desta carreira.

var _editor := CharacterEditor.new()
var _preview := CharacterView.new()
var _identity := Label.new()
var _energy := OptionButton.new()
var _message := Label.new()
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var title := Label.new()
	title.text = "Personagem"
	title.theme_type_variation = &"TitleLabel"
	column.add_child(title)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	column.add_child(body)

	var info_panel := PanelContainer.new()
	info_panel.custom_minimum_size = Vector2(300, 0)
	body.add_child(info_panel)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 8)
	info_panel.add_child(info)
	var identity_header := Label.new()
	identity_header.text = "Identidade"
	identity_header.theme_type_variation = &"HeaderLabel"
	info.add_child(identity_header)
	_identity.name = "IdentityLabel"
	_identity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_identity)
	var settings_header := Label.new()
	settings_header.text = "Configurações da carreira"
	settings_header.theme_type_variation = &"HeaderLabel"
	info.add_child(settings_header)
	var energy_label := Label.new()
	energy_label.text = "Energia infinita"
	info.add_child(energy_label)
	_energy.name = "InfiniteEnergyOption"
	_energy.add_item("OFF")
	_energy.add_item("ON")
	_energy.item_selected.connect(_on_energy_selected)
	info.add_child(_energy)
	var energy_hint := Label.new()
	energy_hint.text = "Vale só para esta carreira. Ligada, as atividades não gastam energia."
	energy_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(energy_hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_editor.name = "CharacterEditor"
	_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_editor)

	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(260, 0)
	body.add_child(preview_panel)
	var preview_column := VBoxContainer.new()
	preview_panel.add_child(preview_column)
	_preview.name = "CharacterPreview"
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_column.add_child(_preview)
	var random := Button.new()
	random.name = "RandomButton"
	random.text = "Aleatório"
	random.pressed.connect(func() -> void: _editor.randomize_appearance(_rng))
	preview_column.add_child(random)
	var undo := Button.new()
	undo.name = "UndoButton"
	undo.text = "Desfazer alterações"
	undo.pressed.connect(_load_saved_appearance)
	preview_column.add_child(undo)

	_message.name = "MessageLabel"
	_message.theme_type_variation = &"MessageLabel"
	column.add_child(_message)
	var row := HBoxContainer.new()
	column.add_child(row)
	var back := Button.new()
	back.name = "BackButton"
	back.text = "Voltar"
	back.pressed.connect(navigate.bind(context.get("back", Screen.HUB)))
	row.add_child(back)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var save := Button.new()
	save.name = "SaveAppearanceButton"
	save.text = "Salvar aparência"
	save.theme_type_variation = &"PrimaryButton"
	save.pressed.connect(func() -> void: _message.text = GameManager.set_appearance(_editor.get_appearance()).message)
	row.add_child(save)

	_editor.appearance_changed.connect(func(appearance: CharacterAppearance) -> void: _preview.appearance = appearance)
	_load_saved_appearance()
	super()


func refresh() -> void:
	var career := GameManager.career
	var characters := GameManager.characters
	_identity.text = "Nome artístico: %s\nNome real: %s\nIdade: %d anos\nMora em: %s" % [
		career.artist_name, career.real_name if not career.real_name.is_empty() else "—",
		characters.current_age(career), characters.location_label(career.country, career.city)]
	_energy.select(1 if career.infinite_energy else 0)


func _load_saved_appearance() -> void:
	_editor.set_appearance(GameManager.career.appearance)
	_preview.appearance = _editor.get_appearance()


func _on_energy_selected(index: int) -> void:
	_message.text = GameManager.set_infinite_energy(index == 1).message
