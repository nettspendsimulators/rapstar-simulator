extends Screen
## Nova carreira: identidade (nome artístico, nome real, idade, país e cidade) e aparência.
## A carreira ganha um save próprio e não substitui nenhuma outra.

var _name := LineEdit.new()
var _real_name := LineEdit.new()
var _age := SpinBox.new()
var _country := OptionButton.new()
var _city := LineEdit.new()
var _infinite_energy := false
var _energy_on := Button.new()
var _editor := CharacterEditor.new()
var _stage := CharacterStage.new()
var _message := Label.new()
var _rng := RandomNumberGenerator.new()
var _sex_buttons: Dictionary[String, Button] = {}


func _ready() -> void:
	_rng.randomize()
	var rules: CharacterRules = GameManager.characters.rules()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var title := Label.new()
	title.text = "Crie seu artista"
	title.theme_type_variation = &"TitleLabel"
	column.add_child(title)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	column.add_child(body)

	var identity_panel := PanelContainer.new()
	identity_panel.custom_minimum_size = Vector2(290, 0)
	body.add_child(identity_panel)
	var identity_scroll := ScrollContainer.new()
	identity_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	identity_panel.add_child(identity_scroll)
	var identity := VBoxContainer.new()
	identity.add_theme_constant_override("separation", 6)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_scroll.add_child(identity)
	_header(identity, "Identidade")
	_name.name = "NameEdit"
	_name.placeholder_text = "Como o público vai te chamar?"
	_name.max_length = 40
	_name.text_submitted.connect(func(_text: String) -> void: _start())
	_field(identity, "Nome artístico", _name)
	_real_name.name = "RealNameEdit"
	_real_name.placeholder_text = "Nome de registro"
	_real_name.max_length = 60
	_field(identity, "Nome real", _real_name)
	_age.name = "AgeInput"
	_age.min_value = rules.min_age
	_age.max_value = rules.max_age
	_age.value = rules.default_age
	_age.suffix = "anos"
	_field(identity, "Idade", _age)
	_build_sex_toggle(identity)
	_country.name = "CountryOption"
	for country in rules.countries:
		_country.add_item(country)
		if country == rules.default_country:
			_country.select(_country.item_count - 1)
	_field(identity, "País", _country)
	_city.name = "CityEdit"
	_city.placeholder_text = "Onde você mora"
	_city.max_length = 40
	_field(identity, "Cidade", _city)
	_build_energy_toggle(identity)
	var hint := Label.new()
	hint.text = "O nome artístico é a sua identidade pública. A idade aumenta com os anos da carreira. Você começa com peças básicas; roupas e acessórios melhores ficam na loja do guarda-roupa."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity.add_child(hint)

	# Centro: o personagem grande, iluminado, com o sorteio logo abaixo.
	var center := VBoxContainer.new()
	center.custom_minimum_size = Vector2(300, 0)
	center.add_theme_constant_override("separation", 8)
	body.add_child(center)
	_stage.name = "CharacterStage"
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.custom_minimum_size = Vector2(300, 420)
	center.add_child(_stage)
	var random := Button.new()
	random.name = "RandomButton"
	random.text = "Sortear visual"
	random.icon = load("res://assets/icons/character.svg")
	random.pressed.connect(func() -> void: _editor.randomize_appearance(_rng))
	center.add_child(random)

	# Direita: o editor por miniaturas.
	var editor_panel := PanelContainer.new()
	editor_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(editor_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	editor_panel.add_child(scroll)
	_editor.name = "CharacterEditor"
	# Na criação só há peças básicas; o resto é comprado no guarda-roupa durante a carreira.
	_editor.starter = true
	_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_editor)

	_message.name = "MessageLabel"
	_message.theme_type_variation = &"MessageLabel"
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	var start := Button.new()
	start.name = "StartButton"
	start.text = "Começar carreira"
	start.theme_type_variation = &"PrimaryButton"
	start.pressed.connect(_start)
	row.add_child(start)

	_editor.appearance_changed.connect(func(appearance: CharacterAppearance) -> void:
		_stage.appearance = appearance
		for option_id in _sex_buttons:
			_sex_buttons[option_id].set_pressed_no_signal(appearance.get_choice("sex") == option_id))
	_stage.appearance = _editor.get_appearance()
	_name.grab_focus.call_deferred()
	super()


func _header(parent: Container, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"HeaderLabel"
	parent.add_child(label)


func _field(parent: Container, label_text: String, control: Control) -> void:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)
	parent.add_child(control)


## Sexo do personagem: muda o corpo, o rosto e as peças disponíveis. Também fica na aba Corpo.
func _build_sex_toggle(parent: Container) -> void:
	var label := Label.new()
	label.text = "Sexo"
	parent.add_child(label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var group := ButtonGroup.new()
	for spec: Array in [["SexMale", "Masculino", "sex_male"], ["SexFemale", "Feminino", "sex_female"]]:
		var button := Button.new()
		button.name = spec[0]
		button.text = spec[1]
		button.theme_type_variation = &"ChipButton"
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.button_pressed = spec[2] == "sex_male"
		button.pressed.connect(_editor.choose.bind(spec[2]))
		row.add_child(button)
		_sex_buttons[spec[2]] = button


## Energia Infinita: OFF usa a energia normal; ON, nenhuma atividade gasta energia nesta carreira.
func _build_energy_toggle(parent: Container) -> void:
	var label := Label.new()
	label.text = "Energia Infinita"
	parent.add_child(label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var group := ButtonGroup.new()
	var off := Button.new()
	off.name = "EnergyOff"
	off.text = "OFF"
	_energy_on.name = "EnergyOn"
	_energy_on.text = "ON"
	for button: Button in [off, _energy_on]:
		button.theme_type_variation = &"ChipButton"
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(64, 0)
		row.add_child(button)
	off.button_pressed = true
	off.pressed.connect(func() -> void: _infinite_energy = false)
	_energy_on.pressed.connect(func() -> void: _infinite_energy = true)
	var note := Label.new()
	note.text = "Quando ativada, sua energia não será consumida durante a carreira."
	note.theme_type_variation = &"MutedLabel"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(note)


func _start() -> void:
	var identity := {
		"real_name": _real_name.text, "age": int(_age.value),
		"country": _country.get_item_text(_country.selected), "city": _city.text,
		"infinite_energy": _infinite_energy,
	}
	var result := GameManager.create_career(_name.text, identity, _editor.get_appearance())
	if result.ok:
		navigate(Screen.HUB)
	else:
		_message.text = result.message
