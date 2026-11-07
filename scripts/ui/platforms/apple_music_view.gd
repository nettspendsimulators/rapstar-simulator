extends RefCounted
## Visual claro e elegante: barra lateral, arte grande com cantos arredondados e grade de faixas.

const BACKGROUND := Color("#f5f5f7")
const SIDEBAR := Color("#e8e8ed")
const CARD := Color("#ffffff")
const ACCENT := Color("#fa2d48")
const TEXT := Color("#1d1d1f")
const SUBTLE := Color("#6e6e73")


func build(page: PlatformPage) -> void:
	var career := page.career()
	var stats := page.stats()
	page.set_background(BACKGROUND)
	var root := page.hbox(0)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.content_root().add_child(root)

	var sidebar := page.panel(SIDEBAR, 0, 24)
	sidebar.custom_minimum_size = Vector2(230, 0)
	root.add_child(sidebar)
	var side_column := page.vbox(14)
	sidebar.add_child(side_column)
	side_column.add_child(page.label("Música", 26, TEXT, true))
	for item in ["Ouvir agora", "Explorar", "Rádio", "Biblioteca"]:
		side_column.add_child(page.label("●  " + item, 16, ACCENT if item == "Ouvir agora" else SUBTLE))
	side_column.add_child(page.spacer())
	side_column.add_child(page.back_button(ACCENT, Color.WHITE))

	var main_area := Control.new()
	main_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(main_area)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_area.add_child(scroll)
	var margins := MarginContainer.new()
	margins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, 36)
	scroll.add_child(margins)
	var column := page.vbox(18)
	margins.add_child(column)

	var header := page.hbox(28)
	column.add_child(header)
	var art := page.panel(CARD, 18, 6)
	art.add_child(page.cover(career.artist_cover, 170))
	header.add_child(art)
	var info := page.vbox(6)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(info)
	info.add_child(page.label(career.artist_name, 44, TEXT, true, "PlatformName"))
	info.add_child(page.label(GameManager.streaming.artist_bio(career), 16, SUBTLE))
	var numbers := page.hbox(24)
	numbers.add_child(page.label("%s ouvintes" % Fmt.number(stats.listeners), 16, TEXT, false, "ListenersLabel"))
	numbers.add_child(page.label("%s seguidores" % Fmt.number(stats.followers), 16, TEXT))
	numbers.add_child(page.label("%s plays" % Fmt.number(stats.total_plays), 16, TEXT, false, "PlaysLabel"))
	info.add_child(numbers)
	info.add_child(page.pill("▶  Reproduzir", ACCENT, Color.WHITE))

	column.add_child(page.label("Top músicas  ›", 24, TEXT, true))
	var grid := GridContainer.new()
	grid.name = "TrackList"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 10)
	column.add_child(grid)
	var songs := page.songs_here()
	if songs.is_empty():
		column.add_child(page.empty_message("Nenhuma música no catálogo ainda.", SUBTLE))
	for performance in songs.slice(0, 8):
		var song := page.song_of(performance)
		var row := page.hbox(12)
		row.custom_minimum_size = Vector2(380, 0)
		row.add_child(page.cover(song.cover_file, 48))
		var text_column := page.vbox(0)
		text_column.add_child(page.label(song.title, 17, TEXT))
		text_column.add_child(page.label("%s plays" % Fmt.number(page.plays(performance)), 14, SUBTLE))
		row.add_child(text_column)
		grid.add_child(row)

	column.add_child(page.label("Catálogo  ›", 24, TEXT, true))
	var albums := page.hbox(20)
	column.add_child(albums)
	for release in page.releases_newest_first():
		var content := page.content_of(release)
		var card := page.vbox(6)
		var art_card := page.panel(CARD, 12, 4)
		art_card.add_child(page.cover(content.cover_file, 130))
		card.add_child(art_card)
		card.add_child(page.label(content.title, 15, TEXT))
		card.add_child(page.label(page.type_of(content), 13, SUBTLE))
		albums.add_child(card)
