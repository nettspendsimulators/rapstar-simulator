extends RefCounted
## Visual de loja: vitrine com produtos, preço, vendidos e receita.

const BACKGROUND := Color("#1c2433")
const CARD := Color("#263248")
const ACCENT := Color("#f2c14e")
const TEXT := Color("#ffffff")
const SUBTLE := Color("#9fb0c8")


func build(page: PlatformPage) -> void:
	var career := page.career()
	var stats := page.stats()
	page.set_background(BACKGROUND)
	var column := page.scroll_column(32, 18)

	var top := page.hbox(16)
	column.add_child(top)
	top.add_child(page.label("Loja Digital", 34, ACCENT, true, "PlatformName"))
	top.add_child(page.spacer())
	top.add_child(page.label("🛒  %s vendidos  •  %s em vendas" % [Fmt.number(stats.total_plays), Fmt.money(stats.revenue)], 18, TEXT, false, "PlaysLabel"))
	top.add_child(page.back_button(CARD, TEXT))

	column.add_child(page.label("Mais vendidos de %s" % career.artist_name, 22, TEXT, true))
	var releases := page.releases_newest_first()
	releases.sort_custom(func(a: ReleaseData, b: ReleaseData) -> bool: return a.total_sales > b.total_sales)
	var grid := GridContainer.new()
	grid.name = "ProductGrid"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	column.add_child(grid)
	if releases.is_empty():
		column.add_child(page.empty_message("Nada à venda ainda. Lançamentos oficiais entram na loja.", SUBTLE))
	for release in releases:
		var content := page.content_of(release)
		var card := page.panel(CARD, 12, 14)
		var card_column := page.vbox(6)
		card.add_child(card_column)
		var art := page.cover(content.cover_file, 200)
		art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card_column.add_child(art)
		card_column.add_child(page.label(content.title, 17, TEXT, true))
		card_column.add_child(page.label("%s  •  %s" % [page.type_of(content), career.artist_name], 14, SUBTLE))
		var price_row := page.hbox(8)
		price_row.add_child(page.pill(_price_text(content), ACCENT, Color.BLACK, 15))
		price_row.add_child(page.label("%s vendidos" % Fmt.number(release.total_sales), 14, SUBTLE))
		card_column.add_child(price_row)
		grid.add_child(card)


func _price_text(content: ReleasableContent) -> String:
	var price := GameManager.balance.streaming.single_sale_price
	if content is AlbumData:
		price = GameManager.balance.album_performance.money_per_unit
	return ("$%.2f" % price).replace(".", ",")
