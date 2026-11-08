extends Screen
## Finanças: quanto entrou, quanto saiu e para onde foi. Em cima, quatro números; à esquerda, o
## peso de cada área em barras; à direita, o histórico completo.

const CATEGORY_LABELS := {
	FinanceEntry.CATEGORY_WORK: "Trabalho", FinanceEntry.CATEGORY_PRODUCTION: "Produção",
	FinanceEntry.CATEGORY_COLLABORATOR: "Colaboradores", FinanceEntry.CATEGORY_MARKETING: "Marketing",
	FinanceEntry.CATEGORY_SAMPLE: "Samples", FinanceEntry.CATEGORY_VIDEO: "Videoclipes",
	FinanceEntry.CATEGORY_RELEASE: "Lançamentos", FinanceEntry.CATEGORY_STREAMS: "Streams",
	FinanceEntry.CATEGORY_SALES: "Vendas", FinanceEntry.CATEGORY_LIVE: "Shows e turnês",
	FinanceEntry.CATEGORY_MERCH: "Merch", FinanceEntry.CATEGORY_SPONSOR: "Patrocínios", FinanceEntry.CATEGORY_SOCIAL: "Relações", FinanceEntry.CATEGORY_VEHICLE: "Carros", FinanceEntry.CATEGORY_STYLE: "Roupas", FinanceEntry.CATEGORY_LABEL: "Gravadora",
}
const MAX_AREAS := 8

var _balance := StatTile.new("Saldo", "money", Color("#46d483"))
var _income := StatTile.new("Receitas", "plus", Color("#46d483"))
var _expenses := StatTile.new("Despesas", "release", Color("#ff5f6d"))
var _result := StatTile.new("Resultado", "chart", Color("#f5b82e"))
var _areas := VBoxContainer.new()


func _ready() -> void:
	%Title.text = "Finanças"
	$Column/SummaryPanel.visible = false
	var subtitle := Label.new()
	subtitle.text = "De onde o dinheiro vem e para onde ele vai, desde o começo da carreira."
	subtitle.theme_type_variation = &"MutedLabel"
	%Column.add_child(subtitle)
	%Column.move_child(subtitle, 1)
	var tiles := HBoxContainer.new()
	tiles.name = "FinanceTiles"
	tiles.add_theme_constant_override("separation", 14)
	for tile in [_balance, _income, _expenses, _result]:
		tiles.add_child(tile)
	%Column.add_child(tiles)
	%Column.move_child(tiles, 2)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	%Column.add_child(body)
	%Column.move_child(body, 3)
	var areas_card := PanelContainer.new()
	areas_card.name = "AreasCard"
	areas_card.theme_type_variation = &"Card"
	areas_card.custom_minimum_size = Vector2(330, 0)
	body.add_child(areas_card)
	var areas_column := VBoxContainer.new()
	areas_column.add_theme_constant_override("separation", 10)
	areas_card.add_child(areas_column)
	var areas_title := Label.new()
	areas_title.text = "POR ÁREA"
	areas_title.theme_type_variation = &"SectionLabel"
	areas_column.add_child(areas_title)
	_areas.name = "FinanceAreas"
	_areas.add_theme_constant_override("separation", 9)
	areas_column.add_child(_areas)
	var history := VBoxContainer.new()
	history.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history.add_theme_constant_override("separation", 8)
	body.add_child(history)
	%FinanceHeader.reparent(history)
	%FinanceHeader.text = "HISTÓRICO"
	%FinanceHeader.theme_type_variation = &"SectionLabel"
	%FinanceTable.reparent(history)
	%FinanceTable.set_headers(["Descrição", "Área", "Semana", "Valor"])
	%FinanceTable.set_column_expand_ratio(0, 4)
	%BackButton.pressed.connect(navigate.bind(Screen.HUB))
	super()


func refresh() -> void:
	var career := GameManager.career
	var income := 0
	var expenses := 0
	var by_category := {}
	for entry in career.finance_history:
		by_category[entry.category] = int(by_category.get(entry.category, 0)) + entry.amount
		if entry.amount > 0:
			income += entry.amount
		else:
			expenses -= entry.amount
	_balance.set_value(Fmt.money(career.money), "Semana %s" % Fmt.number(career.current_week))
	_income.set_value(Fmt.money(income), "%d área(s) rendendo" % by_category.values().filter(func(v: int) -> bool: return v > 0).size(), 1 if income > 0 else 0)
	_expenses.set_value(Fmt.money(expenses), "produção, equipe, divulgação...", -1 if expenses > 0 else 0)
	_result.set_value(Fmt.signed_money(income - expenses), "receitas menos despesas", signi(income - expenses))
	_fill_areas(by_category)
	%FinanceTable.clear_rows()
	for index in range(career.finance_history.size() - 1, -1, -1):
		var entry := career.finance_history[index]
		%FinanceTable.add_row([entry.description, CATEGORY_LABELS.get(entry.category, entry.category), Fmt.number(entry.week), Fmt.signed_money(entry.amount)])


## Uma barra por área, do maior peso ao menor: verde quando rende, vermelha quando custa.
func _fill_areas(by_category: Dictionary) -> void:
	for child in _areas.get_children():
		_areas.remove_child(child)
		child.queue_free()
	if by_category.is_empty():
		var empty := Label.new()
		empty.text = "Nenhum movimento ainda."
		empty.theme_type_variation = &"MutedLabel"
		_areas.add_child(empty)
		return
	var keys := by_category.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return absi(by_category[a]) > absi(by_category[b]))
	var biggest := maxi(absi(by_category[keys[0]]), 1)
	for key: String in keys.slice(0, MAX_AREAS):
		var amount: int = by_category[key]
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		var line := HBoxContainer.new()
		row.add_child(line)
		var name_label := Label.new()
		name_label.text = CATEGORY_LABELS.get(key, key)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_label)
		var value := Label.new()
		value.text = Fmt.signed_money(amount)
		value.add_theme_color_override("font_color", Color("#46d483") if amount > 0 else Color("#ff8a94"))
		line.add_child(value)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 6)
		bar.max_value = biggest
		bar.value = absi(amount)
		bar.theme_type_variation = &"EnergyBar" if amount > 0 else &"DangerBar"
		row.add_child(bar)
		_areas.add_child(row)
	if keys.size() > MAX_AREAS:
		var more := Label.new()
		more.text = "+ %d área(s) menores no histórico" % (keys.size() - MAX_AREAS)
		more.theme_type_variation = &"MutedLabel"
		_areas.add_child(more)
