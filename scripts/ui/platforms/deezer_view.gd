extends RefCounted
## Visual escuro com roxo: abas no topo, número de fãs em destaque e lista de faixas com corações.

const BACKGROUND := Color("#0f0d13")
const CARD := Color("#1e1b26")
const ACCENT := Color("#a238ff")
const TEXT := Color("#ffffff")
const SUBTLE := Color("#a7a3b3")


func build(page: PlatformPage) -> void:
	var career := page.career()
	var stats := page.stats()
	page.set_background(BACKGROUND)
	var column := page.scroll_column(32, 18)

	var top := page.hbox(20)
	column.add_child(top)
	top.add_child(page.back_button(CARD, TEXT))
	top.add_child(page.spacer())
	for tab in ["Discografia", "Top faixas", "Fãs"]:
		top.add_child(page.label(tab, 16, ACCENT if tab == "Top faixas" else SUBTLE, tab == "Top faixas"))

	var hero := page.panel(CARD, 16, 24)
	column.add_child(hero)
	var hero_row := page.hbox(24)
	hero.add_child(hero_row)
	var circle := page.panel(ACCENT, 999, 4)
	circle.add_child(page.cover(career.artist_cover, 120))
	hero_row.add_child(circle)
	var info := page.vbox(4)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hero_row.add_child(info)
	info.add_child(page.label(career.artist_name, 40, TEXT, true, "PlatformName"))
	info.add_child(page.label("%s fãs" % Fmt.number(stats.followers), 22, ACCENT, true))
	info.add_child(page.label("%s ouvintes  •  %s plays" % [Fmt.number(stats.listeners), Fmt.number(stats.total_plays)], 16, SUBTLE, false, "ListenersLabel"))
	hero_row.add_child(page.spacer())
	var flow := page.panel(ACCENT, 999, 18)
	flow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	flow.add_child(page.label("Flow  ▶", 20, TEXT, true))
	hero_row.add_child(flow)

	column.add_child(page.label("Top faixas", 24, TEXT, true))
	var list := page.vbox(6)
	list.name = "TrackList"
	column.add_child(list)
	var songs := page.songs_here()
	if songs.is_empty():
		column.add_child(page.empty_message("Seus lançamentos aparecem aqui.", SUBTLE))
	for index in mini(songs.size(), 10):
		var performance := songs[index]
		var song := page.song_of(performance)
		var row := page.panel(CARD, 10, 10)
		var line := page.hbox(14)
		row.add_child(line)
		line.add_child(page.cover(song.cover_file, 40))
		var text_column := page.vbox(0)
		text_column.add_child(page.label(song.title, 17, TEXT))
		text_column.add_child(page.label(career.artist_name, 13, SUBTLE))
		line.add_child(text_column)
		line.add_child(page.spacer())
		line.add_child(page.label("♥", 18, ACCENT))
		line.add_child(page.label(Fmt.number(page.plays(performance)), 16, SUBTLE))
		list.add_child(row)
