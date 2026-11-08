extends Screen
## Nova carreira: identidade (nome artístico, nome real, idade, país e cidade) e aparência.
## A carreira ganha um save próprio e não substitui nenhuma outra.

var _name := LineEdit.new()
var _real_name := LineEdit.new()
var _age := SpinBox.new()
var _country := OptionButton.new()
var _city := LineEdit.new()
var _editor := CharacterEditor.new()
var _preview := CharacterView.new()
var _message := Label.new()
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var rules: CharacterRules = GameManager.characters.rules()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var title := Label.new()
	title.text = "Nova carreira"
	title.theme_type_variation = &"TitleLabel"
	column.add_child(title)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	column.add_child(body)

	var identity_panel := PanelContainer.new()
	identity_panel.custom_minimum_size = Vector2(320, 0)
	body.add_child(identity_panel)
	var identity := VBoxContainer.new()
	identity.add_theme_constant_override("separation", 6)
	identity_panel.add_child(identity)
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
	var hint := Label.new()
	hint.text = "O nome artístico é a sua identidade pública. A idade aumenta com os anos da carreira."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity.add_child(hint)

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

	_editor.appearance_changed.connect(func(appearance: CharacterAppearance) -> void: _preview.appearance = appearance)
	_preview.appearance = _editor.get_appearance()
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


func _start() -> void:
	var identity := {
		"real_name": _real_name.text, "age": int(_age.value),
		"country": _country.get_item_text(_country.selected), "city": _city.text,
	}
	var result := GameManager.create_career(_name.text, identity, _editor.get_appearance())
	if result.ok:
		navigate(Screen.HUB)
	else:
		_message.text = result.message
