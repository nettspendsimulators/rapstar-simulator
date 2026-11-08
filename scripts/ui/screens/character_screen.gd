extends Screen
## Guarda-roupa: o personagem grande funciona como provador. Tocar numa peça veste na hora (prova);
## o cartão da peça mostra nome, categoria, nível e preço, com Comprar. Salvar só veste peças que
## são suas; se o visual tiver peças da loja, o botão vira "Comprar e vestir" com o total.
## Também reúne a identidade e a energia infinita desta carreira.

var _editor := CharacterEditor.new()
var _stage := CharacterStage.new()
var _identity := Label.new()
var _energy := OptionButton.new()
var _message := Label.new()
var _summary := Label.new()
var _item_card := PanelContainer.new()
var _item_tier := Label.new()
var _item_name := Label.new()
var _item_info := Label.new()
var _item_price := Label.new()
var _item_buy := Button.new()
var _save := Button.new()
var _selected: CharacterOptionDefinition
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	_build_header(column)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	column.add_child(body)
	_build_left(body)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	body.add_child(right)
	_build_item_card(right)
	var editor_panel := PanelContainer.new()
	editor_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(editor_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	editor_panel.add_child(scroll)
	_editor.name = "CharacterEditor"
	_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor.owned_check = func(option_id: String) -> bool: return GameManager.wardrobe.owns(GameManager.career, option_id)
	scroll.add_child(_editor)
	_build_footer(column)
	_editor.appearance_changed.connect(_on_look_changed)
	_editor.option_selected.connect(_show_item)
	_load_saved_appearance()
	super()


func refresh() -> void:
	var career := GameManager.career
	var characters := GameManager.characters
	_identity.text = "%s%s  •  %d anos  •  %s" % [career.artist_name,
		"  (%s)" % career.real_name if not career.real_name.is_empty() else "",
		characters.current_age(career), characters.location_label(career.country, career.city)]
	_energy.select(1 if career.infinite_energy else 0)
	var wardrobe := GameManager.wardrobe
	_summary.text = "%d peça(s) compradas  •  %s em roupas e acessórios" % [career.wardrobe.size(), Fmt.money(wardrobe.wardrobe_value(career))]
	_editor.refresh_ownership()
	_update_item()
	_update_save()


# ---- montagem

func _build_header(parent: Container) -> void:
	var header := HBoxContainer.new()
	parent.add_child(header)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	var title := Label.new()
	title.text = "Guarda-roupa"
	title.theme_type_variation = &"TitleLabel"
	titles.add_child(title)
	_summary.name = "WardrobeSummary"
	_summary.theme_type_variation = &"MutedLabel"
	_summary.size_flags_vertical = Control.SIZE_SHRINK_END
	header.add_child(_summary)


func _build_left(body: HBoxContainer) -> void:
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(290, 0)
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)
	_stage.name = "CharacterStage"
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.custom_minimum_size = Vector2(270, 270)
	left.add_child(_stage)
	var look_row := HBoxContainer.new()
	look_row.add_theme_constant_override("separation", 6)
	left.add_child(look_row)
	var random := Button.new()
	random.name = "RandomButton"
	random.text = "Sortear"
	random.icon = load("res://assets/icons/character.svg")
	random.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	random.tooltip_text = "Sorteia um visual com qualquer peça do catálogo (só para provar)."
	random.pressed.connect(func() -> void: _editor.randomize_appearance(_rng))
	look_row.add_child(random)
	var undo := Button.new()
	undo.name = "UndoButton"
	undo.text = "Desfazer"
	undo.tooltip_text = "Volta para o visual que você está usando."
	undo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	undo.pressed.connect(_load_saved_appearance)
	look_row.add_child(undo)
	var info_panel := PanelContainer.new()
	info_panel.theme_type_variation = &"Card"
	left.add_child(info_panel)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info_panel.add_child(info)
	_identity.name = "IdentityLabel"
	_identity.theme_type_variation = &"MutedLabel"
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


## Cartão da peça tocada: nível, nome, categoria, preço e comprar.
func _build_item_card(parent: Container) -> void:
	_item_card.name = "ItemCard"
	_item_card.theme_type_variation = &"HeroPanel"
	_item_card.add_theme_stylebox_override("panel", _compact_hero())
	parent.add_child(_item_card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_item_card.add_child(row)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	row.add_child(texts)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	texts.add_child(top)
	_item_tier.name = "ItemTier"
	_item_tier.theme_type_variation = &"TierChip"
	_item_tier.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_item_tier)
	_item_name.name = "ItemName"
	_item_name.theme_type_variation = &"ChipLabel"
	_item_name.add_theme_font_size_override("font_size", 18)
	_item_name.clip_text = true
	_item_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_item_name)
	_item_info.name = "ItemInfo"
	_item_info.theme_type_variation = &"MutedLabel"
	texts.add_child(_item_info)
	_item_price.name = "ItemPrice"
	_item_price.theme_type_variation = &"BigNumber"
	_item_price.add_theme_font_size_override("font_size", 24)
	_item_price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_item_price)
	_item_buy.name = "ItemBuyButton"
	_item_buy.text = "Comprar"
	_item_buy.icon = load("res://assets/icons/money.svg")
	_item_buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_item_buy.pressed.connect(_on_buy_item)
	row.add_child(_item_buy)


func _compact_hero() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1d1729e6")
	style.border_color = Color("#4b3a6b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.content_margin_left = 16
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _build_footer(parent: Container) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var back := Button.new()
	back.name = "BackButton"
	back.text = "Voltar"
	back.pressed.connect(navigate.bind(context.get("back", Screen.HUB)))
	row.add_child(back)
	_message.name = "MessageLabel"
	_message.theme_type_variation = &"MessageLabel"
	_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_message)
	_save.name = "SaveAppearanceButton"
	_save.theme_type_variation = &"PrimaryButton"
	_save.pressed.connect(_on_save)
	row.add_child(_save)


# ---- estado

func _on_look_changed(appearance: CharacterAppearance) -> void:
	_stage.appearance = appearance
	_update_save()


func _show_item(option: CharacterOptionDefinition) -> void:
	_selected = option
	_update_item()


## Cartão da peça: só roupas e acessórios têm nível e preço; o resto é o próprio corpo.
func _update_item() -> void:
	var career := GameManager.career
	var item := _selected
	if item == null or not CharacterRules.is_wear(item.category):
		_item_tier.visible = false
		_item_name.text = "Toque numa peça para provar"
		_item_info.text = "Básicas são suas. As outras você prova aqui e compra quando quiser."
		_item_price.text = ""
		_item_buy.visible = false
		return
	var owned := GameManager.wardrobe.owns(career, item.id)
	_item_tier.visible = true
	_item_tier.text = CharacterRules.tier_label(item.tier).to_upper()
	var chip := StyleBoxFlat.new()
	chip.bg_color = CharacterRules.tier_color(item.tier)
	chip.set_corner_radius_all(8)
	chip.content_margin_left = 8
	chip.content_margin_right = 8
	chip.content_margin_top = 1
	chip.content_margin_bottom = 1
	_item_tier.add_theme_stylebox_override("normal", chip)
	_item_name.text = item.display_name
	_item_info.text = "%s  •  %s" % [_category_label(item.category), "no seu guarda-roupa" if owned else "à venda"]
	_item_price.text = "Sua" if owned else Fmt.money(item.price)
	_item_buy.visible = not owned
	var block := GameManager.wardrobe.purchase_block(career, item.id)
	_item_buy.disabled = not block.is_empty()
	_item_buy.tooltip_text = block if not block.is_empty() else "Compra a peça. Ela fica no seu guarda-roupa para sempre."


## Salvar veste o visual; se faltar comprar algo, o botão mostra o total e compra junto.
func _update_save() -> void:
	var career := GameManager.career
	var look := _editor.get_appearance()
	var cost := GameManager.wardrobe.missing_cost(career, look)
	if cost <= 0:
		_save.text = "Salvar visual"
		_save.disabled = false
		_save.tooltip_text = "Veste este visual. A carreira continua de onde está."
	else:
		_save.text = "Comprar e vestir (%s)" % Fmt.money(cost)
		_save.disabled = cost > career.money
		_save.tooltip_text = "Faltam %s para este visual." % Fmt.money(cost - career.money) if cost > career.money else "Compra as peças que faltam e veste o visual."


func _on_save() -> void:
	var look := _editor.get_appearance()
	var result := GameManager.set_appearance(look) if GameManager.wardrobe.missing(GameManager.career, look).is_empty() else GameManager.buy_and_wear(look)
	_message.text = result.message


func _on_buy_item() -> void:
	if _selected != null:
		_message.text = GameManager.buy_wardrobe_item(_selected.id).message


func _load_saved_appearance() -> void:
	_editor.set_appearance(GameManager.career.appearance)
	_stage.appearance = _editor.get_appearance()
	_update_save()


func _on_energy_selected(index: int) -> void:
	_message.text = GameManager.set_infinite_energy(index == 1).message


func _category_label(category: String) -> String:
	for item: Dictionary in CharacterRules.CATEGORIES:
		if item["id"] == category:
			return item["label"]
	return category
