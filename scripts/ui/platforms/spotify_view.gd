extends RefCounted
## Visual de serviço de streaming escuro: grande cabeçalho do artista, populares numeradas e discografia.

const BACKGROUND := Color("#121212")
const HEADER := Color("#1f3d2b")
const CARD := Color("#181818")
const ACCENT := Color("#1db954")
const TEXT := Color("#ffffff")
const SUBTLE := Color("#b3b3b3")


func build(page: PlatformPage) -> void:
	var career := page.career()
	var stats := page.stats()
	page.set_background(BACKGROUND)
	var column := page.scroll_column(0, 0)

	var header := page.panel(HEADER, 0, 32)
	column.add_child(header)
	var header_row := page.hbox(28)
	header.add_child(header_row)
	header_row.add_child(page.artist_avatar(career, 180))
	var info := page.vbox(6)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_row.add_child(info)
	info.add_child(page.back_button(Color(0, 0, 0, 0.4), TEXT))
	info.add_child(page.label("ARTISTA", 14, TEXT, true))
	info.add_child(page.label(career.artist_name, 56, TEXT, true, "PlatformName"))
	info.add_child(page.label("%s ouvintes mensais" % Fmt.number(stats.listeners), 18, TEXT, false, "ListenersLabel"))

	var body := page.vbox(14)
	var body_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		body_margin.add_theme_constant_override("margin_" + side, 32)
	body_margin.add_child(body)
	column.add_child(body_margin)

	var actions := page.hbox(16)
	actions.add_child(page.pill("▶  Ouvir", ACCENT, Color.BLACK, 18))
	actions.add_child(page.pill("%s seguidores" % Fmt.number(stats.followers), Color(1, 1, 1, 0.08), TEXT))
	actions.add_child(page.pill("%s streams" % Fmt.number(stats.total_plays), Color(1, 1, 1, 0.08), TEXT))
	body.add_child(actions)

	body.add_child(page.label("Populares", 26, TEXT, true))
	var songs := page.songs_here()
	if songs.is_empty():
		body.add_child(page.empty_message("Lance uma música para ela aparecer aqui.", SUBTLE))
	var list := page.vbox(2)
	list.name = "TrackList"
	body.add_child(list)
	for index in mini(songs.size(), 10):
		var performance := songs[index]
		var song := page.song_of(performance)
		var row := page.panel(CARD if index % 2 == 0 else BACKGROUND, 6, 8)
		var line := page.hbox(16)
		row.add_child(line)
		line.add_child(page.label(str(index + 1), 18, SUBTLE))
		line.add_child(page.cover(song.cover_file, 44, song.title))
		var name_column := page.vbox(0)
		name_column.add_child(page.label(song.title, 18, TEXT))
		name_column.add_child(page.label(GameManager.streaming.trend_label(performance), 14, SUBTLE))
		line.add_child(name_column)
		line.add_child(page.spacer())
		line.add_child(page.label(Fmt.number(page.plays(performance)), 18, SUBTLE))
		list.add_child(row)

	body.add_child(page.label("Discografia", 26, TEXT, true))
	var discography := page.hbox(18)
	body.add_child(discography)
	for release in page.releases_newest_first():
		var content := page.content_of(release)
		var card := page.panel(CARD, 8, 12)
		var card_column := page.vbox(6)
		card.add_child(card_column)
		card_column.add_child(page.cover(content.cover_file, 140, content.title))
		card_column.add_child(page.label(content.title, 16, TEXT, true))
		card_column.add_child(page.label("%s • semana %s" % [page.type_of(content), Fmt.number(release.release_week)], 14, SUBTLE))
		discography.add_child(card)
