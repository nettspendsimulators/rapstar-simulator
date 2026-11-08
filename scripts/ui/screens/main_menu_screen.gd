extends Screen
## Menu principal: arte de abertura com artistas no palco à direita e, à esquerda, a marca, o
## atalho para continuar a última carreira e as demais opções em ordem de importância.

const VERSION := "v17"

var _continue_card := PanelContainer.new()
var _continue_view := CharacterView.new()
var _continue_name := Label.new()
var _continue_label := Label.new()
var _continue := Button.new()
var _new_game := Button.new()
var _careers := Button.new()
var _message := Label.new()
var _crew: Array[CharacterView] = []
var _last_slot: String = ""


func _ready() -> void:
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	add_child(body)
	_build_menu(body)
	_build_key_art(body)
	super()


func _build_menu(body: HBoxContainer) -> void:
	var margin := MarginContainer.new()
	margin.custom_minimum_size = Vector2(470, 0)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 56)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 32)
	body.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(column)
	var kicker := Label.new()
	kicker.text = "SIMULADOR DE CARREIRA MUSICAL"
	kicker.theme_type_variation = &"Kicker"
	column.add_child(kicker)
	var logo := Label.new()
	logo.text = "RAPSTAR"
	logo.theme_type_variation = &"Logo"
	logo.add_theme_font_size_override("font_size", 86)
	column.add_child(logo)
	var tagline := Label.new()
	tagline.text = "Do primeiro beat ao estrelato. Grave, lance, faça shows, feche feats e construa seu nome."
	tagline.theme_type_variation = &"MutedLabel"
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(tagline)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	column.add_child(gap)

	# Continuar: a última carreira, com o artista, a fase e a semana.
	_continue_card.name = "ContinueCard"
	_continue_card.theme_type_variation = &"HeroPanel"
	column.add_child(_continue_card)
	var card_row := HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 14)
	_continue_card.add_child(card_row)
	_continue_view.focus = "head"
	_continue_view.custom_minimum_size = Vector2(64, 64)
	_continue_view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card_row.add_child(_continue_view)
	var card_column := VBoxContainer.new()
	card_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_column.alignment = BoxContainer.ALIGNMENT_CENTER
	card_column.add_theme_constant_override("separation", 0)
	card_row.add_child(card_column)
	var continue_kicker := Label.new()
	continue_kicker.text = "CONTINUAR"
	continue_kicker.theme_type_variation = &"Kicker"
	card_column.add_child(continue_kicker)
	_continue_name.theme_type_variation = &"ChipLabel"
	_continue_name.add_theme_font_size_override("font_size", 20)
	_continue_name.clip_text = true
	_continue_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card_column.add_child(_continue_name)
	_continue_label.name = "ContinueLabel"
	_continue_label.theme_type_variation = &"MutedLabel"
	card_column.add_child(_continue_label)
	_continue.name = "ContinueCareerButton"
	_continue.text = "Jogar"
	_continue.icon = load("res://assets/icons/next.svg")
	_continue.theme_type_variation = &"PrimaryButton"
	_continue.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_continue.pressed.connect(_on_continue)
	card_row.add_child(_continue)

	_new_game.name = "NewGameButton"
	_new_game.text = "Nova carreira"
	_new_game.icon = load("res://assets/icons/plus.svg")
	_new_game.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_new_game.pressed.connect(navigate.bind(Screen.NEW_CAREER))
	column.add_child(_new_game)
	_careers.name = "LoadGameButton"
	_careers.text = "Carreiras salvas"
	_careers.icon = load("res://assets/icons/career.svg")
	_careers.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_careers.pressed.connect(navigate.bind(Screen.CAREERS))
	column.add_child(_careers)
	var quit := Button.new()
	quit.name = "QuitButton"
	quit.text = "Sair do jogo"
	quit.icon = load("res://assets/icons/exit.svg")
	quit.alignment = HORIZONTAL_ALIGNMENT_LEFT
	quit.theme_type_variation = &"GhostButton"
	quit.pressed.connect(func() -> void: get_tree().quit())
	column.add_child(quit)
	_message.name = "MessageLabel"
	_message.theme_type_variation = &"MessageLabel"
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_message)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	column.add_child(spacer)
	var version := Label.new()
	version.text = "Rapstar %s" % VERSION
	version.theme_type_variation = &"SectionLabel"
	column.add_child(version)


## Arte de abertura: o artista da última carreira ao centro e dois outros no fundo, na sombra.
func _build_key_art(body: HBoxContainer) -> void:
	var art := Control.new()
	art.name = "KeyArt"
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(art)
	var backdrop := StageBackdrop.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.floor_ratio = 0.9
	backdrop.light = Color("#a25cff")
	art.add_child(backdrop)
	var rng := RandomNumberGenerator.new()
	rng.seed = Time.get_ticks_msec()
	# Ordem de desenho: os de trás primeiro.
	for spec: Array in [[0.06, 0.52, 0.16, 0.86, 0.45], [0.48, 0.94, 0.16, 0.86, 0.45], [0.2, 0.8, 0.06, 0.93, 1.0]]:
		var view := CharacterView.new()
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.anchor_left = spec[0]
		view.anchor_right = spec[1]
		view.anchor_top = spec[2]
		view.anchor_bottom = spec[3]
		view.modulate = Color(spec[4], spec[4], spec[4] * 1.1, 1.0)
		view.appearance = GameManager.characters.random_appearance(rng)
		view.idle = true
		art.add_child(view)
		_crew.append(view)
	_lift_in(art)


func _lift_in(art: Control) -> void:
	art.modulate.a = 0.0
	var tween := art.create_tween()
	tween.tween_interval(0.05)
	tween.tween_property(art, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_QUAD)


func refresh() -> void:
	var careers := GameManager.list_careers()
	_careers.disabled = careers.is_empty()
	_continue_card.visible = not careers.is_empty()
	# Sem carreira, criar é a ação principal; com carreira, continuar é.
	_new_game.theme_type_variation = &"PrimaryButton" if careers.is_empty() else &""
	if careers.is_empty():
		return
	var last: Dictionary = careers[0]
	_last_slot = last["slot"]
	var appearance := CharacterAppearance.from_dict(last["appearance"])
	_continue_view.appearance = appearance
	_crew[-1].appearance = appearance
	_continue_name.text = last["artist_name"]
	_continue_label.text = "%s  •  Semana %s  •  Fama %s" % [GameManager.progression.stage_for(last["fame"]).display_name,
		Fmt.number(last["week"]), Fmt.number(last["fame"])]


func _on_continue() -> void:
	var result := GameManager.load_game(_last_slot)
	if result.ok:
		navigate.call_deferred(Screen.HUB)
	else:
		_message.text = result.message
