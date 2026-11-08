extends Screen
## Carreira e finanças: a jornada pelas fases da carreira, os números gerais e para onde o
## dinheiro foi (receitas e despesas por área), com o histórico completo.

const CATEGORY_LABELS := {
	FinanceEntry.CATEGORY_WORK: "Trabalho", FinanceEntry.CATEGORY_PRODUCTION: "Produção",
	FinanceEntry.CATEGORY_COLLABORATOR: "Colaboradores", FinanceEntry.CATEGORY_MARKETING: "Marketing",
	FinanceEntry.CATEGORY_SAMPLE: "Samples", FinanceEntry.CATEGORY_VIDEO: "Videoclipes",
	FinanceEntry.CATEGORY_RELEASE: "Lançamentos", FinanceEntry.CATEGORY_STREAMS: "Streams",
	FinanceEntry.CATEGORY_SALES: "Vendas", FinanceEntry.CATEGORY_LIVE: "Shows e turnês",
	FinanceEntry.CATEGORY_MERCH: "Merch", FinanceEntry.CATEGORY_SPONSOR: "Patrocínios",
}

var _journey := HBoxContainer.new()
var _finance := Label.new()


func _ready() -> void:
	%FinanceTable.set_headers(["Descrição", "Área", "Semana", "Valor"])
	%FinanceTable.set_column_expand_ratio(0, 4)
	%BackButton.pressed.connect(navigate.bind(Screen.HUB))
	_journey.name = "StageJourney"
	_journey.add_theme_constant_override("separation", 6)
	%Summary.add_child(_journey)
	%Summary.move_child(_journey, 1)
	_finance.name = "FinanceSummary"
	_finance.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	%Column.add_child(_finance)
	%Column.move_child(_finance, %FinanceTable.get_index())
	%FinanceHeader.text = "Para onde vai o dinheiro"
	super()


func refresh() -> void:
	var career := GameManager.career
	var progression := GameManager.progression
	var stage := progression.stage_for(career.fame)
	%Title.text = "Carreira e finanças"
	%ArtistLabel.text = "%s  —  %s" % [career.artist_name, stage.display_name]
	_fill_journey(career)
	%StatsLabel.text = "Semana %s  •  Dinheiro: %s  •  Fama: %s  •  Fãs: %s  •  Reputação: %s  •  Energia: %s" % [
		Fmt.number(career.current_week), Fmt.money(career.money), Fmt.number(career.fame),
		Fmt.number(GameManager.streaming.total_followers(career)), Fmt.signed_number(career.reputation), GameManager.energy_text()]
	var shows_done := GameManager.live.history(career).size()
	%CatalogLabel.text = "Músicas: %d  •  Projetos: %d  •  Lançamentos: %d  •  Videoclipes: %d  •  Shows realizados: %d" % [
		career.songs.size(), career.albums.size(), career.releases.size(), career.music_videos.size(), shows_done]
	%TotalsLabel.text = "Reproduções totais: %s  •  Ouvintes: %s" % [
		Fmt.number(GameManager.streaming.total_plays(career)), Fmt.number(GameManager.streaming.total_listeners(career))]
	_fill_finance(career)


func _fill_journey(career: CareerData) -> void:
	for child in _journey.get_children():
		_journey.remove_child(child)
		child.queue_free()
	var progression := GameManager.progression
	var current := progression.stage_index(career.fame)
	for index in progression.stages().size():
		var stage := progression.stages()[index]
		var pill := Label.new()
		pill.text = stage.display_name
		pill.tooltip_text = "%s (a partir de %s de fama)" % [stage.description, Fmt.number(stage.min_fame)]
		pill.mouse_filter = Control.MOUSE_FILTER_PASS
		if index == current:
			pill.theme_type_variation = &"StageLabel"
		elif index < current:
			pill.add_theme_color_override("font_color", Color("#46d483"))
		else:
			pill.theme_type_variation = &"MutedLabel"
		_journey.add_child(pill)
		if index < progression.stages().size() - 1:
			var arrow := Label.new()
			arrow.text = "›"
			arrow.theme_type_variation = &"MutedLabel"
			_journey.add_child(arrow)


func _fill_finance(career: CareerData) -> void:
	var income := 0
	var expenses := 0
	var by_category := {}
	for entry in career.finance_history:
		by_category[entry.category] = int(by_category.get(entry.category, 0)) + entry.amount
		if entry.amount > 0:
			income += entry.amount
		else:
			expenses -= entry.amount
	var parts := PackedStringArray()
	var keys := by_category.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return absi(by_category[a]) > absi(by_category[b]))
	for key: String in keys:
		parts.append("%s %s" % [CATEGORY_LABELS.get(key, key), Fmt.signed_money(by_category[key])])
	_finance.text = "Receitas: %s  •  Despesas: %s  •  Resultado: %s\n%s" % [
		Fmt.money(income), Fmt.money(expenses), Fmt.signed_money(income - expenses), "  •  ".join(parts)]
	%FinanceTable.clear_rows()
	for index in range(career.finance_history.size() - 1, -1, -1):
		var entry := career.finance_history[index]
		%FinanceTable.add_row([entry.description, CATEGORY_LABELS.get(entry.category, entry.category), Fmt.number(entry.week), Fmt.signed_money(entry.amount)])
