extends Screen
## Carros: a concessionária (com filtro por categoria) e a garagem do jogador. Escolher um carro
## mostra foto grande, preço, quanto sobra e a compra. context pode ter view ("dealer" ou "garage").

const VIEWS := ["Concessionária", "Minha garagem"]

var _view := 0
var _category := ""
var _subtitle := Label.new()
var _categories := HFlowContainer.new()
var _grid := CardGrid.new()
var _photo := TextureRect.new()
var _name := Label.new()
var _details := Label.new()
var _price := Label.new()
var _balance := Label.new()
var _buy := Button.new()
var _message := Label.new()


func _ready() -> void:
	_view = 1 if context.get("view", "") == "garage" else 0
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 0)
	column.add_child(header)
	var title := Label.new()
	title.text = "Carros"
	title.theme_type_variation = &"TitleLabel"
	header.add_child(title)
	_subtitle.name = "GarageSummary"
	_subtitle.theme_type_variation = &"MutedLabel"
	header.add_child(_subtitle)
	var views := HBoxContainer.new()
	views.add_theme_constant_override("separation", 8)
	column.add_child(views)
	var group := ButtonGroup.new()
	for index in VIEWS.size():
		var chip := Button.new()
		chip.name = "View%d" % index
		chip.text = VIEWS[index]
		chip.theme_type_variation = &"ChipButton"
		chip.toggle_mode = true
		chip.button_group = group
		chip.button_pressed = index == _view
		chip.focus_mode = Control.FOCUS_NONE
		chip.pressed.connect(func() -> void:
			_view = index
			_grid.select_value(null)
			refresh())
		views.add_child(chip)
	_categories.name = "Categories"
	_categories.add_theme_constant_override("h_separation", 6)
	_categories.add_theme_constant_override("v_separation", 6)
	column.add_child(_categories)
	_build_categories()
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	column.add_child(body)
	_grid.name = "VehiclesGrid"
	_grid.art_size = Vector2(200, 112)
	_grid.card_pressed.connect(func(_value: Variant) -> void: _show_detail())
	body.add_child(_grid)
	_build_detail(body)
	_message.name = "MessageLabel"
	_message.theme_type_variation = &"MessageLabel"
	column.add_child(_message)
	super()


func _build_categories() -> void:
	var group := ButtonGroup.new()
	var options := [["", "Todas"]]
	for key: String in VehicleRules.CATEGORIES:
		options.append([key, VehicleRules.CATEGORIES[key]])
	for item: Array in options:
		var chip := Button.new()
		chip.name = "Category_%s" % (item[0] if item[0] != "" else "all")
		chip.text = item[1]
		chip.theme_type_variation = &"ChipButton"
		chip.toggle_mode = true
		chip.button_group = group
		chip.button_pressed = item[0] == _category
		chip.focus_mode = Control.FOCUS_NONE
		chip.pressed.connect(func() -> void:
			_category = item[0]
			refresh())
		_categories.add_child(chip)


func _build_detail(body: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.name = "VehicleDetail"
	panel.theme_type_variation = &"HeroPanel"
	panel.custom_minimum_size = Vector2(330, 0)
	body.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	_photo.name = "VehiclePhoto"
	_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_photo.custom_minimum_size = Vector2(0, 170)
	_photo.clip_contents = true
	column.add_child(_photo)
	_name.name = "VehicleName"
	_name.theme_type_variation = &"HeaderLabel"
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_name)
	_details.name = "VehicleDetails"
	_details.theme_type_variation = &"MutedLabel"
	column.add_child(_details)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	_price.name = "VehiclePrice"
	_price.theme_type_variation = &"StatValue"
	column.add_child(_price)
	_balance.name = "BalanceAfter"
	_balance.theme_type_variation = &"MutedLabel"
	_balance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_balance)
	_buy.name = "BuyButton"
	_buy.theme_type_variation = &"PrimaryButton"
	_buy.icon = load("res://assets/icons/car.svg")
	_buy.pressed.connect(_on_buy)
	column.add_child(_buy)


func refresh() -> void:
	var career := GameManager.career
	var vehicles := GameManager.vehicles
	_subtitle.text = "Na garagem: %d carro(s)  •  valor pago %s" % [career.vehicles.size(), Fmt.money(vehicles.garage_value(career))]
	_categories.visible = _view == 0
	var selected: Variant = _grid.selected_value()
	var list: Array[VehicleDefinition] = vehicles.garage(career) if _view == 1 else _dealer_list()
	_grid.clear_cards("Sua garagem está vazia. Escolha um carro na concessionária." if list.is_empty() and _view == 1 else "")
	for vehicle in list:
		var owned := vehicles.is_owned(career, vehicle.id)
		var badge := "Na sua garagem" if owned else Fmt.money(vehicle.price)
		var color := Color("#46d483") if owned else (Color("#f3f0f7") if career.money >= vehicle.price else Color("#8c86a0"))
		_grid.add_card(vehicle.id, vehicle.display_name(), "%d  •  %s" % [vehicle.year, VehicleRules.category_label(vehicle.category)], vehicle.image, badge, color)
	if (selected == null or not list.any(func(item: VehicleDefinition) -> bool: return item.id == selected)) and not list.is_empty():
		selected = list[0].id
	_grid.select_value(selected)
	_show_detail()


func _dealer_list() -> Array[VehicleDefinition]:
	var result: Array[VehicleDefinition] = []
	for vehicle in GameManager.vehicles.catalog():
		if _category.is_empty() or vehicle.category == _category:
			result.append(vehicle)
	result.sort_custom(func(a: VehicleDefinition, b: VehicleDefinition) -> bool: return a.price < b.price)
	return result


func _show_detail() -> void:
	var career := GameManager.career
	var vehicles := GameManager.vehicles
	var vehicle := vehicles.rules().find_vehicle(String(_grid.selected_value())) if _grid.selected_value() != null else null
	_photo.texture = vehicle.image if vehicle != null else null
	_name.text = vehicle.display_name() if vehicle != null else "Escolha um carro"
	if vehicle == null:
		_details.text = ""
		_price.text = ""
		_balance.text = ""
		_buy.visible = false
		return
	_details.text = "%d  •  %s" % [vehicle.year, VehicleRules.category_label(vehicle.category)]
	_price.text = Fmt.money(vehicle.price)
	_buy.visible = true
	var owned := vehicles.find_owned(career, vehicle.id)
	if owned != null:
		_balance.text = "Comprado na semana %s por %s." % [Fmt.number(owned.bought_week), Fmt.money(owned.price_paid)]
		_buy.text = "Na sua garagem"
		_buy.disabled = true
		return
	var block := vehicles.purchase_block(career, vehicle.id)
	_balance.text = ("Dinheiro: %s  →  depois: %s" % [Fmt.money(career.money), Fmt.money(career.money - vehicle.price)]) if block.is_empty() else block
	_buy.text = "Comprar" if block.is_empty() else "Dinheiro insuficiente"
	_buy.disabled = not block.is_empty()


func _on_buy() -> void:
	var vehicle_id: Variant = _grid.selected_value()
	if vehicle_id == null:
		return
	var result := GameManager.buy_vehicle(vehicle_id)
	_message.text = result.message
	if result.ok:
		var shell: GameShell = get_tree().root.find_child("GameShell", true, false)
		if shell != null:
			shell.show_toast(result.message)
