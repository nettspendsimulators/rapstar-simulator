class_name CharacterEditor
extends GridContainer
## Escolha de cada peça da aparência. É o mesmo componente na criação da carreira e na
## personalização durante a carreira; as opções vêm de data/character.tres.

signal appearance_changed(appearance: CharacterAppearance)

var _appearance := CharacterAppearance.new()
var _options: Dictionary[String, OptionButton] = {}
var _checks: Dictionary[String, CheckBox] = {}


func _ready() -> void:
	columns = 2
	add_theme_constant_override("h_separation", 12)
	add_theme_constant_override("v_separation", 6)
	var rules: CharacterRules = GameManager.characters.rules()
	for item: Dictionary in CharacterRules.CATEGORIES:
		var category: String = item["id"]
		var label := Label.new()
		label.text = item["label"]
		add_child(label)
		if CharacterRules.is_multiple(category):
			var flow := HFlowContainer.new()
			flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for option in rules.options_for(category):
				var check := CheckBox.new()
				check.text = option.display_name
				check.name = "Accessory_%s" % option.id
				check.toggled.connect(func(on: bool) -> void: _on_accessory_toggled(option.id, on))
				flow.add_child(check)
				_checks[option.id] = check
			add_child(flow)
			continue
		var button := OptionButton.new()
		button.name = "Choice_%s" % category
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.fit_to_longest_item = false
		button.clip_text = true
		for option in rules.options_for(category):
			if category in CharacterRules.COLOR_CATEGORIES:
				button.add_icon_item(_swatch(option.color), option.display_name)
			else:
				button.add_item(option.display_name)
			button.set_item_metadata(button.item_count - 1, option.id)
		button.item_selected.connect(func(index: int) -> void: _on_choice_selected(category, index))
		add_child(button)
		_options[category] = button
	set_appearance(GameManager.characters.default_appearance())


func set_appearance(appearance: CharacterAppearance) -> void:
	_appearance = GameManager.characters.sanitize(appearance)
	for category in _options:
		var button := _options[category]
		for index in button.item_count:
			if button.get_item_metadata(index) == _appearance.get_choice(category):
				button.select(index)
	for option_id in _checks:
		_checks[option_id].set_pressed_no_signal(_appearance.has_accessory(option_id))


## Cópia da aparência montada; alterar a cópia não muda o editor.
func get_appearance() -> CharacterAppearance:
	return _appearance.copy()


func randomize_appearance(rng: RandomNumberGenerator) -> void:
	set_appearance(GameManager.characters.random_appearance(rng))
	appearance_changed.emit(get_appearance())


func _on_choice_selected(category: String, index: int) -> void:
	_appearance.set_choice(category, _options[category].get_item_metadata(index))
	appearance_changed.emit(get_appearance())


func _on_accessory_toggled(option_id: String, on: bool) -> void:
	_appearance.set_accessory(option_id, on)
	appearance_changed.emit(get_appearance())


func _swatch(color: Color) -> ImageTexture:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
