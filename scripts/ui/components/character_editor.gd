class_name CharacterEditor
extends VBoxContainer
## Escolha de cada peça da aparência, por miniaturas: cada opção aparece desenhada no próprio
## personagem, recortada na região do corpo onde fica (cabelo na cabeça, tênis nos pés...).
## Cores são amostras redondas; acessórios ligam e desligam. As abas agrupam as categorias.
## É o mesmo componente na criação da carreira e na personalização; as opções vêm de
## data/character.tres, então peças novas aparecem aqui sem mudar este script.

signal appearance_changed(appearance: CharacterAppearance)

const TILE_SIZE := Vector2(96, 96)

var _appearance := CharacterAppearance.new()
var _group := "face"
var _group_buttons: Dictionary[String, Button] = {}
var _pages: Dictionary[String, VBoxContainer] = {}
## option id -> botão da miniatura; a categoria fica em meta "category".
var _tiles: Dictionary[String, Button] = {}
var _previews: Dictionary[String, CharacterView] = {}
var _captions: Dictionary[String, Label] = {}


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var tabs := HBoxContainer.new()
	tabs.name = "Groups"
	tabs.add_theme_constant_override("separation", 6)
	add_child(tabs)
	var group_buttons := ButtonGroup.new()
	var rules: CharacterRules = GameManager.characters.rules()
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
		var page := VBoxContainer.new()
		page.name = "Page_%s" % group_id
		page.add_theme_constant_override("separation", 6)
		add_child(page)
		_pages[group_id] = page
		for category: String in group["categories"]:
			_build_category(page, rules, category)
	set_appearance(GameManager.characters.default_appearance())
	show_group(_group)


func _build_category(page: VBoxContainer, rules: CharacterRules, category: String) -> void:
	var title := Label.new()
	title.text = _category_label(category).to_upper()
	title.theme_type_variation = &"SectionLabel"
	page.add_child(title)
	var flow := HFlowContainer.new()
	flow.name = "Options_%s" % category
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	page.add_child(flow)
	var multiple := CharacterRules.is_multiple(category)
	var group := ButtonGroup.new() if not multiple else null
	for option in rules.options_for(category):
		var tile := _swatch_tile(option) if category in CharacterRules.COLOR_CATEGORIES else _preview_tile(option, category)
		tile.name = ("Accessory_%s" if multiple else "Option_%s") % option.id
		tile.tooltip_text = option.display_name
		tile.toggle_mode = true
		tile.focus_mode = Control.FOCUS_NONE
		tile.set_meta("category", category)
		if group != null:
			tile.button_group = group
		if multiple:
			tile.toggled.connect(func(on: bool) -> void: _on_accessory_toggled(option.id, on))
		else:
			tile.pressed.connect(_on_choice_selected.bind(category, option.id))
		flow.add_child(tile)
		_tiles[option.id] = tile


## Miniatura: o personagem com a peça vestida, recortado na região dela, e o nome embaixo.
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
	_captions[option.id] = caption
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


## Mostra só as categorias de um grupo (Rosto, Cabelo, Roupas, Acessórios).
func show_group(group_id: String) -> void:
	if not _pages.has(group_id):
		return
	_group = group_id
	for id in _pages:
		_pages[id].visible = id == group_id
		# set_pressed_no_signal não solta os outros botões do grupo, então cada aba é marcada aqui.
		_group_buttons[id].set_pressed_no_signal(id == group_id)
	_refresh_previews()


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
	_appearance = GameManager.characters.sanitize(appearance)
	_sync_tiles()


## Cópia da aparência montada; alterar a cópia não muda o editor.
func get_appearance() -> CharacterAppearance:
	return _appearance.copy()


func randomize_appearance(rng: RandomNumberGenerator) -> void:
	set_appearance(GameManager.characters.random_appearance(rng))
	appearance_changed.emit(get_appearance())


func _sync_tiles() -> void:
	for option_id in _tiles:
		var tile := _tiles[option_id]
		var category: String = tile.get_meta("category")
		var on := _appearance.has_accessory(option_id) if CharacterRules.is_multiple(category) else _appearance.get_choice(category) == option_id
		tile.set_pressed_no_signal(on)
	_refresh_previews()


## Cada miniatura mostra a aparência atual com a sua peça no lugar; só o grupo visível é redesenhado.
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


func _on_choice_selected(category: String, option_id: String) -> void:
	_appearance.set_choice(category, option_id)
	_sync_tiles()
	appearance_changed.emit(get_appearance())


func _on_accessory_toggled(option_id: String, on: bool) -> void:
	_appearance.set_accessory(option_id, on)
	_refresh_previews()
	appearance_changed.emit(get_appearance())
