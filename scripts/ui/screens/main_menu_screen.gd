extends Screen
## Menu principal: continuar a última carreira com um clique, criar uma nova ou escolher entre
## as carreiras salvas.

var _continue_card := PanelContainer.new()
var _continue_view := CharacterView.new()
var _continue_label := Label.new()
var _continue := Button.new()
var _careers := Button.new()
var _message := Label.new()
var _last_slot: String = ""


func _ready() -> void:
	var center := CenterContainer.new()
	add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(440, 0)
	column.add_theme_constant_override("separation", 12)
	center.add_child(column)
	var logo := Label.new()
	logo.text = "RAPSTAR"
	logo.theme_type_variation = &"Logo"
	logo.add_theme_font_size_override("font_size", 72)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(logo)
	var tagline := Label.new()
	tagline.text = "Do primeiro beat ao estrelato"
	tagline.theme_type_variation = &"MutedLabel"
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(tagline)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 12)
	column.add_child(gap)

	_continue_card.theme_type_variation = &"HeroPanel"
	column.add_child(_continue_card)
	var card_row := HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 14)
	_continue_card.add_child(card_row)
	_continue_view.custom_minimum_size = Vector2(46, 92)
	card_row.add_child(_continue_view)
	var card_column := VBoxContainer.new()
	card_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_column.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_child(card_column)
	_continue_label.name = "ContinueLabel"
	_continue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_column.add_child(_continue_label)
	_continue.name = "ContinueCareerButton"
	_continue.text = "Continuar"
	_continue.icon = load("res://assets/icons/next.svg")
	_continue.theme_type_variation = &"PrimaryButton"
	_continue.pressed.connect(_on_continue)
	card_column.add_child(_continue)

	var new_game := Button.new()
	new_game.name = "NewGameButton"
	new_game.text = "Nova carreira"
	new_game.icon = load("res://assets/icons/plus.svg")
	new_game.pressed.connect(navigate.bind(Screen.NEW_CAREER))
	column.add_child(new_game)
	_careers.name = "LoadGameButton"
	_careers.text = "Carreiras salvas"
	_careers.icon = load("res://assets/icons/career.svg")
	_careers.pressed.connect(navigate.bind(Screen.CAREERS))
	column.add_child(_careers)
	var quit := Button.new()
	quit.name = "QuitButton"
	quit.text = "Sair"
	quit.icon = load("res://assets/icons/exit.svg")
	quit.pressed.connect(func() -> void: get_tree().quit())
	column.add_child(quit)
	_message.name = "MessageLabel"
	_message.theme_type_variation = &"MessageLabel"
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_message)
	super()


func refresh() -> void:
	var careers := GameManager.list_careers()
	_careers.disabled = careers.is_empty()
	_continue_card.visible = not careers.is_empty()
	if careers.is_empty():
		return
	var last: Dictionary = careers[0]
	_last_slot = last["slot"]
	_continue_view.appearance = CharacterAppearance.from_dict(last["appearance"])
	_continue_label.text = "%s\n%s  •  Semana %s  •  Fama %s" % [last["artist_name"],
		GameManager.progression.stage_for(last["fame"]).display_name, Fmt.number(last["week"]), Fmt.number(last["fame"])]


func _on_continue() -> void:
	var result := GameManager.load_game(_last_slot)
	if result.ok:
		navigate.call_deferred(Screen.HUB)
	else:
		_message.text = result.message
