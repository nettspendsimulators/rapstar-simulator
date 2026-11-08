extends Screen
## Personagem da carreira aberta: identidade, aparência e configuração de energia infinita.
## Usa o mesmo editor da criação; salvar troca só a aparência e grava no save desta carreira.

var _editor := CharacterEditor.new()
var _stage := CharacterStage.new()
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

	# Esquerda: o personagem grande no palco, os botões de visual e a identidade.
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)
	_stage.name = "CharacterStage"
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.custom_minimum_size = Vector2(280, 380)
	left.add_child(_stage)
	var look_row := HBoxContainer.new()
	look_row.add_theme_constant_override("separation", 6)
	left.add_child(look_row)
	var random := Button.new()
	random.name = "RandomButton"
	random.text = "Sortear"
	random.icon = load("res://assets/icons/character.svg")
	random.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	random.pressed.connect(func() -> void: _editor.randomize_appearance(_rng))
	look_row.add_child(random)
	var undo := Button.new()
	undo.name = "UndoButton"
	undo.text = "Desfazer"
	undo.tooltip_text = "Volta para a aparência salva."
	undo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	undo.pressed.connect(_load_saved_appearance)
	look_row.add_child(undo)
	# Direita: identidade e energia numa faixa compacta e o editor por miniaturas.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	body.add_child(right)
	var info_panel := PanelContainer.new()
	info_panel.theme_type_variation = &"Card"
	right.add_child(info_panel)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	info_panel.add_child(info)
	var identity_header := Label.new()
	identity_header.text = "IDENTIDADE"
	identity_header.theme_type_variation = &"SectionLabel"
	info.add_child(identity_header)
	_identity.name = "IdentityLabel"
	_identity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_identity)
	var energy_row := HBoxContainer.new()
	energy_row.add_theme_constant_override("separation", 8)
	info.add_child(energy_row)
	var energy_label := Label.new()
	energy_label.text = "Energia infinita"
	energy_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	energy_label.tooltip_text = "Vale só para esta carreira. Ligada, as atividades não gastam energia."
	energy_label.mouse_filter = Control.MOUSE_FILTER_PASS
	energy_row.add_child(energy_label)
	_energy.name = "InfiniteEnergyOption"
	_energy.add_item("OFF")
	_energy.add_item("ON")
	_energy.custom_minimum_size = Vector2(90, 0)
	_energy.item_selected.connect(_on_energy_selected)
	energy_row.add_child(_energy)

	var editor_panel := PanelContainer.new()
	editor_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(editor_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	editor_panel.add_child(scroll)
	_editor.name = "CharacterEditor"
	_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_editor)

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

	_editor.appearance_changed.connect(func(appearance: CharacterAppearance) -> void: _stage.appearance = appearance)
	_load_saved_appearance()
	super()


func refresh() -> void:
	var career := GameManager.career
	var characters := GameManager.characters
	_identity.text = "%s%s  •  %d anos  •  %s" % [career.artist_name,
		"  (%s)" % career.real_name if not career.real_name.is_empty() else "",
		characters.current_age(career), characters.location_label(career.country, career.city)]
	_energy.select(1 if career.infinite_energy else 0)


func _load_saved_appearance() -> void:
	_editor.set_appearance(GameManager.career.appearance)
	_stage.appearance = _editor.get_appearance()


func _on_energy_selected(index: int) -> void:
	_message.text = GameManager.set_infinite_energy(index == 1).message
