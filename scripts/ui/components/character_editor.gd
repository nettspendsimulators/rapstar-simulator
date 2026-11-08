class_name CharacterEditor
extends VBoxContainer
## Escolha de cada peça da aparência, por miniaturas: cada opção aparece desenhada no próprio
## personagem, recortada na região do corpo onde fica (cabelo na cabeça, tênis nos pés...).
## Cores são amostras redondas; acessórios ligam e desligam. As abas agrupam as categorias
## (Corpo, Rosto, Cabelo, Roupas, Acessórios).
## Dois modos:
## - criação (starter = true): roupas e acessórios só das peças básicas;
## - carreira: o catálogo inteiro, com o nível de cada peça, o preço das que ainda não foram
##   compradas e um filtro Tudo / Meus itens / Loja. Vestir uma peça não comprada é uma prova:
##   quem usa o editor decide o que fazer (comprar, salvar).
## Peças que não combinam com o sexo escolhido somem da lista.
## As opções vêm de data/character.tres: peças novas aparecem aqui sem mudar este script.

signal appearance_changed(appearance: CharacterAppearance)
## Uma peça foi tocada (para mostrar nome, nível e preço dela).
signal option_selected(option: CharacterOptionDefinition)

const TILE_SIZE := Vector2(96, 96)
const FILTERS := [["all", "Tudo"], ["owned", "Meus itens"], ["shop", "Loja"]]

## Só peças básicas (criação da carreira).
var starter := false
## option_id -> bool: se a peça já é do jogador. Sem isso, tudo conta como dele.
var owned_check: Callable

var _appearance := CharacterAppearance.new()
var _group := "body"
var _filter := "all"
var _group_buttons: Dictionary[String, Button] = {}
var _filter_buttons: Dictionary[String, Button] = {}
var _pages: Dictionary[String, VBoxContainer] = {}
## option id -> botão da miniatura; a categoria fica em meta "category" e a definição em "option".
var _tiles: Dictionary[String, Button] = {}
var _previews: Dictionary[String, CharacterView] = {}
var _badges: Dictionary[String, Label] = {}
var _titles: Dictionary[String, Label] = {}


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	add_child(bar)
	var tabs := HBoxContainer.new()
	tabs.name = "Groups"
	tabs.add_theme_constant_override("separation", 6)
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(tabs)
	var group_buttons := ButtonGroup.new()
	for group: Dictionary in CharacterLayout.GROUPS:
		var group_id: String = group["id"]
		var tab := Button.new()
		tab.name = "Group_%s" % group_id
		tab.text = group["label"]
		tab.theme_type_variation = &"ChipButton"
		tab.toggle_mode = true
		tab.button_group = group_buttons
		tab.focus_mode = Control.FOCUS_NONE
		tab.pressed.connect(show_group.bind(group_id))
		tabs.add_child(tab)
		_group_buttons[group_id] = tab
	# Filtro de posse, só durante a carreira (na criação tudo é básico e de graça).
	var filters := HBoxContainer.new()
	filters.name = "OwnershipFilter"
	filters.add_theme_constant_override("separation", 4)
	filters.visible = not starter
	bar.add_child(filters)
	var filter_group := ButtonGroup.new()
	for item: Array in FILTERS:
		var chip := Button.new()
		chip.name = "Filter_%s" % item[0]
		chip.text = item[1]
		chip.theme_type_variation = &"GhostButton"
		chip.toggle_mode = true
		chip.button_group = filter_group
		chip.focus_mode = Control.FOCUS_NONE
		chip.pressed.connect(set_filter.bind(item[0]))
		filters.add_child(chip)
		_filter_buttons[item[0]] = chip
	var rules: CharacterRules = GameManager.characters.rules()
	for group: Dictionary in CharacterLayout.GROUPS:
		var page := VBoxContainer.new()
		page.name = "Page_%s" % group["id"]
		page.add_theme_constant_override("separation", 6)
		add_child(page)
		_pages[group["id"]] = page
		for category: String in group["categories"]:
			_build_category(page, rules, category)
	set_appearance(GameManager.characters.default_appearance())
	set_filter("all")
	show_group(_group)


func _build_category(page: VBoxContainer, rules: CharacterRules, category: String) -> void:
	var title := Label.new()
	title.text = _category_label(category).to_upper()
	title.theme_type_variation = &"SectionLabel"
	page.add_child(title)
	_titles[category] = title
	var flow := HFlowContainer.new()
	flow.name = "Options_%s" % category
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	page.add_child(flow)
	var multiple := CharacterRules.is_multiple(category)
	var group := ButtonGroup.new() if not multiple else null
	# Do nível mais simples ao mais raro: a progressão fica visível na própria lista.
	var options := rules.options_for(category)
	options.sort_custom(func(a: CharacterOptionDefinition, b: CharacterOptionDefinition) -> bool:
		var ra := CharacterRules.tier_rank(a.tier)
		var rb := CharacterRules.tier_rank(b.tier)
		return ra < rb or (ra == rb and a.price < b.price))
	for option in options:
		var tile := _swatch_tile(option) if category in CharacterRules.COLOR_CATEGORIES else _preview_tile(option, category)
		tile.name = ("Accessory_%s" if multiple else "Option_%s") % option.id
		tile.tooltip_text = _tooltip(option)
		tile.toggle_mode = true
		tile.focus_mode = Control.FOCUS_NONE
		tile.set_meta("category", category)
		tile.set_meta("option", option)
		if group != null:
			tile.button_group = group
		if multiple:
			tile.toggled.connect(func(on: bool) -> void: _on_accessory_toggled(option, on))
		else:
			tile.pressed.connect(_on_choice_selected.bind(option))
		flow.add_child(tile)
		_tiles[option.id] = tile


func _tooltip(option: CharacterOptionDefinition) -> String:
	if not CharacterRules.is_wear(option.category):
		return option.display_name
	var text := "%s  •  %s" % [option.display_name, CharacterRules.tier_label(option.tier)]
	return text + ("  •  %s" % Fmt.money(option.price) if option.price > 0 else "  •  grátis")


## Miniatura: o personagem com a peça vestida, recortado na região dela, o nome embaixo, uma
## faixa na cor do nível e, no canto, o preço (ou o sinal de que já é sua).
func _preview_tile(option: CharacterOptionDefinition, category: String) -> Button:
	var tile := Button.new()
	tile.theme_type_variation = &"MediaCard"
	tile.custom_minimum_size = TILE_SIZE + Vector2(0, 22)
	tile.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var view := CharacterView.new()
	view.focus = CharacterLayout.ACCESSORY_FOCUS.get(option.style, "head") if category == "accessory" else CharacterLayout.FOCUS.get(category, "full")
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.position = Vector2(4, 4)
	view.size = TILE_SIZE - Vector2(8, 4)
	tile.add_child(view)
	_previews[option.id] = view
	var caption := Label.new()
	caption.text = option.display_name
	caption.theme_type_variation = &"StatCaption"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption.clip_text = true
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.position = Vector2(4, TILE_SIZE.y - 2)
	caption.size = Vector2(TILE_SIZE.x - 8, 20)
	tile.add_child(caption)
	if CharacterRules.is_wear(category) and option.tier != "basic":
		var stripe := ColorRect.new()
		stripe.color = CharacterRules.tier_color(option.tier)
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stripe.position = Vector2(0, TILE_SIZE.y + 19)
		stripe.size = Vector2(TILE_SIZE.x, 3)
		tile.add_child(stripe)
		var badge := Label.new()
		badge.name = "PriceBadge"
		badge.theme_type_variation = &"PriceBadge"
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.position = Vector2(4, 4)
		badge.add_theme_color_override("font_color", CharacterRules.tier_color(option.tier).lightened(0.3))
		tile.add_child(badge)
		_badges[option.id] = badge
	return tile


## Amostra de cor redonda; o anel dourado marca a escolhida.
func _swatch_tile(option: CharacterOptionDefinition) -> Button:
	var tile := Button.new()
	tile.theme_type_variation = &"SwatchButton"
	tile.custom_minimum_size = Vector2(46, 46)
	var dot := Panel.new()
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dot.offset_left = 6
	dot.offset_top = 6
	dot.offset_right = -6
	dot.offset_bottom = -6
	var style := StyleBoxFlat.new()
	style.bg_color = option.color
	style.set_corner_radius_all(20)
	style.border_color = Color(1, 1, 1, 0.18)
	style.set_border_width_all(1)
	style.anti_aliasing = true
	dot.add_theme_stylebox_override("panel", style)
	tile.add_child(dot)
	return tile


func _category_label(category: String) -> String:
	for item: Dictionary in CharacterRules.CATEGORIES:
		if item["id"] == category:
			return item["label"]
	return category


## Mostra só as categorias de um grupo.
func show_group(group_id: String) -> void:
	if not _pages.has(group_id):
		return
	_group = group_id
	for id in _pages:
		_pages[id].visible = id == group_id
		# set_pressed_no_signal não solta os outros botões do grupo, então cada aba é marcada aqui.
		_group_buttons[id].set_pressed_no_signal(id == group_id)
	_refresh_previews()


## Tudo, só o que já é seu ou só o que está à venda.
func set_filter(filter_id: String) -> void:
	_filter = filter_id
	for id in _filter_buttons:
		_filter_buttons[id].set_pressed_no_signal(id == filter_id)
	_apply_visibility()


## Grupo onde fica uma opção (para quem precisa chegar até ela).
func group_of(option_id: String) -> String:
	var tile: Button = _tiles.get(option_id)
	if tile == null:
		return ""
	var category: String = tile.get_meta("category")
	for group: Dictionary in CharacterLayout.GROUPS:
		if category in group["categories"]:
			return group["id"]
	return ""


func set_appearance(appearance: CharacterAppearance) -> void:
	var characters := GameManager.characters
	_appearance = characters.starter_only(appearance) if starter else characters.sanitize(appearance)
	_sync_tiles()


## Cópia da aparência montada; alterar a cópia não muda o editor.
func get_appearance() -> CharacterAppearance:
	return _appearance.copy()


func randomize_appearance(rng: RandomNumberGenerator) -> void:
	set_appearance(GameManager.characters.random_appearance(rng, starter))
	appearance_changed.emit(get_appearance())


## Reaplica posse, preços e filtros (depois de uma compra, por exemplo).
func refresh_ownership() -> void:
	_apply_visibility()


func _owns(option: CharacterOptionDefinition) -> bool:
	return not owned_check.is_valid() or owned_check.call(option.id)


func _sync_tiles() -> void:
	for option_id in _tiles:
		var tile := _tiles[option_id]
		var category: String = tile.get_meta("category")
		var on := _appearance.has_accessory(option_id) if CharacterRules.is_multiple(category) else _appearance.get_choice(category) == option_id
		tile.set_pressed_no_signal(on)
	_apply_visibility()


## Esconde o que não combina com o sexo, o que não é básico na criação e o que o filtro tira;
## atualiza os selos de preço. Uma categoria sem nada para mostrar some inteira.
func _apply_visibility() -> void:
	var sex := _appearance.sex()
	var shown: Dictionary[String, int] = {}
	for option_id in _tiles:
		var tile := _tiles[option_id]
		var option: CharacterOptionDefinition = tile.get_meta("option")
		var category: String = tile.get_meta("category")
		var wear := CharacterRules.is_wear(category)
		var owned := _owns(option)
		var keep := option.allows_sex(sex)
		if starter and wear:
			keep = keep and option.tier == "basic"
		if wear and not starter:
			keep = keep and (_filter == "all" or (_filter == "owned") == owned or tile.button_pressed)
		tile.visible = keep
		shown[category] = shown.get(category, 0) + (1 if keep else 0)
		if _badges.has(option_id):
			_badges[option_id].text = "✓" if owned else Fmt.money(option.price)
			_badges[option_id].visible = not starter
	for category in _titles:
		var visible: bool = shown.get(category, 0) > 0
		_titles[category].visible = visible
		_titles[category].get_parent().get_child(_titles[category].get_index() + 1).visible = visible
	_refresh_previews()


## Cada miniatura mostra a aparência atual com a sua peça no lugar; só o que está visível é redesenhado.
func _refresh_previews() -> void:
	for option_id in _previews:
		var tile := _tiles[option_id]
		var category: String = tile.get_meta("category")
		if not tile.is_visible_in_tree():
			continue
		var preview := _appearance.copy()
		if CharacterRules.is_multiple(category):
			preview.set_accessory(option_id, true)
		else:
			preview.set_choice(category, option_id)
		_previews[option_id].appearance = preview


## Escolhe uma peça por código (os atalhos de sexo da criação usam isto).
func choose(option_id: String) -> void:
	var tile: Button = _tiles.get(option_id)
	if tile != null:
		_on_choice_selected(tile.get_meta("option"))


func _on_choice_selected(option: CharacterOptionDefinition) -> void:
	_appearance.set_choice(option.category, option.id)
	# Trocar o sexo tira peças que não combinam (barba, saia...).
	if option.category == "sex":
		_appearance = GameManager.characters.starter_only(_appearance) if starter else GameManager.characters.sanitize(_appearance)
	_sync_tiles()
	option_selected.emit(option)
	appearance_changed.emit(get_appearance())


func _on_accessory_toggled(option: CharacterOptionDefinition, on: bool) -> void:
	_appearance.set_accessory(option.id, on)
	_refresh_previews()
	option_selected.emit(option)
	appearance_changed.emit(get_appearance())
