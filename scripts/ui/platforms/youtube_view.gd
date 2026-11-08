extends RefCounted
## Visual de canal de vídeos: banner, avatar, inscritos, grade de videoclipes e músicas.

const BACKGROUND := Color("#0f0f0f")
const BANNER := Color("#3a0d0d")
const CARD := Color("#272727")
const ACCENT := Color("#ff0000")
const TEXT := Color("#f1f1f1")
const SUBTLE := Color("#aaaaaa")


func build(page: PlatformPage) -> void:
	var career := page.career()
	var stats := page.stats()
	var videos := page.released_videos()
	page.set_background(BACKGROUND)
	var column := page.scroll_column(28, 16)

	var top := page.hbox(12)
	column.add_child(top)
	top.add_child(page.pill("▶", ACCENT, Color.WHITE, 16))
	top.add_child(page.label("Vídeos", 22, TEXT, true))
	top.add_child(page.spacer())
	top.add_child(page.back_button(CARD, TEXT))

	var banner := page.panel(BANNER, 14, 0)
	banner.custom_minimum_size = Vector2(0, 90)
	column.add_child(banner)

	var channel := page.hbox(20)
	column.add_child(channel)
	var avatar := page.panel(CARD, 999, 3)
	avatar.add_child(page.artist_avatar(career, 110))
	channel.add_child(avatar)
	var info := page.vbox(4)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	channel.add_child(info)
	info.add_child(page.label(career.artist_name, 34, TEXT, true, "PlatformName"))
	var handle := "@" + career.artist_name.to_lower().replace(" ", "")
	info.add_child(page.label("%s  •  %s inscritos  •  %d vídeos" % [handle, Fmt.number(stats.followers), videos.size()], 15, SUBTLE, false, "FollowersLabel"))
	info.add_child(page.label("%s visualizações no canal" % Fmt.number(stats.total_plays), 15, SUBTLE, false, "PlaysLabel"))
	info.add_child(page.pill("Inscrever-se", TEXT, Color.BLACK, 15))

	column.add_child(page.label("Videoclipes", 22, TEXT, true))
	var grid := GridContainer.new()
	grid.name = "VideoGrid"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	column.add_child(grid)
	if videos.is_empty():
		column.add_child(page.empty_message("Nenhum videoclipe lançado. Produza um em Videoclipes.", SUBTLE))
	for video in videos:
		var song := career.find_song(video.song_id)
		var card := page.vbox(6)
		var thumb := page.panel(Color.BLACK, 10, 0)
		thumb.custom_minimum_size = Vector2(260, 146)
		var art := page.cover(video.cover_file if not video.cover_file.is_empty() else song.cover_file, 146, song.title)
		art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		thumb.add_child(art)
		card.add_child(thumb)
		card.add_child(page.label("%s (Videoclipe Oficial)" % song.title, 15, TEXT, true))
		card.add_child(page.label("%s visualizações  •  %s" % [Fmt.number(video.total_views), page.weeks_ago(video.release_week)], 13, SUBTLE))
		grid.add_child(card)

	column.add_child(page.label("Músicas", 22, TEXT, true))
	var list := page.vbox(6)
	list.name = "TrackList"
	column.add_child(list)
	for performance in page.songs_here().slice(0, 8):
		var song := page.song_of(performance)
		var row := page.panel(CARD, 10, 8)
		var line := page.hbox(14)
		row.add_child(line)
		line.add_child(page.cover(song.cover_file, 40, song.title))
		line.add_child(page.label(song.title, 16, TEXT))
		line.add_child(page.spacer())
		line.add_child(page.label("%s visualizações" % Fmt.number(page.plays(performance)), 14, SUBTLE))
		list.add_child(row)
