extends Screen


func _ready() -> void:
	%FinanceTable.set_headers(["Descrição", "Semana", "Valor"])
	%BackButton.pressed.connect(navigate.bind(Screen.HUB))
	super()


func refresh() -> void:
	var career := GameManager.career
	%ArtistLabel.text = career.artist_name
	%StatsLabel.text = "Semana %s  |  Dinheiro: %s  |  Fama: %s  |  Reputação: %s  |  Energia: %d/%d" % [
		Fmt.number(career.current_week),
		Fmt.money(career.money),
		Fmt.number(career.fame),
		Fmt.number(career.reputation),
		career.energy,
		GameManager.balance.max_energy,
	]
	%CatalogLabel.text = "Músicas: %d  |  Projetos: %d  |  Lançamentos: %d" % [
		career.songs.size(), career.albums.size(), career.releases.size()
	]

	var total_streams := 0
	var total_sales := 0
	for release in career.releases:
		total_streams += release.total_streams
		total_sales += release.total_sales
	%TotalsLabel.text = "Streams totais: %s  |  Vendas totais: %s" % [
		Fmt.number(total_streams), Fmt.number(total_sales)
	]

	%FinanceTable.clear_rows()
	for index in range(career.finance_history.size() - 1, -1, -1):
		var entry := career.finance_history[index]
		%FinanceTable.add_row([entry.description, Fmt.number(entry.week), Fmt.signed_money(entry.amount)])
