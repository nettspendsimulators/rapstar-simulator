extends RefCounted
## Visual claro com laranja: faixa de capa no topo, avatar redondo e faixas com forma de onda.

const BACKGROUND := Color("#f2f2f2")
const BANNER := Color("#ff7700")
const CARD := Color("#ffffff")
const ACCENT := Color("#ff5500")
const TEXT := Color("#333333")
const SUBTLE := Color("#999999")


func build(page: PlatformPage) -> void:
	var career := page.career()
	var stats := page.stats()
	page.set_background(BACKGROUND)
	var column := page.scroll_column(0, 0)

	var banner := page.panel(BANNER, 0, 28)
	column.add_child(banner)
	var banner_row := page.hbox(24)
	banner.add_child(banner_row)
	var avatar := page.panel(CARD, 999, 4)
	avatar.add_child(page.cover(career.artist_cover, 150))
	banner_row.add_child(avatar)
	var info := page.vbox(8)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	banner_row.add_child(info)
	var name_box := page.panel(Color.BLACK, 0, 8)
	name_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	name_box.add_child(page.label(career.artist_name, 34, Color.WHITE, true, "PlatformName"))
	info.add_child(name_box)
	var bio_box := page.panel(Color.BLACK, 0, 6)
	bio_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bio_box.add_child(page.label(GameManager.streaming.artist_bio(career), 15, Color("#dddddd")))
	info.add_child(bio_box)
	banner_row.add_child(page.spacer())
	var back := page.back_button(Color.BLACK, Color.WHITE)
	back.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	banner_row.add_child(back)

	var body := page.vbox(14)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	margin.add_child(body)
	column.add_child(margin)

	var songs := page.songs_here()
	var counters := page.hbox(40)
	body.add_child(counters)
	for item in [["Seguidores", stats.followers], ["Faixas", songs.size()], ["Plays", stats.total_plays], ["Curtidas", roundi(stats.total_plays * page.platform.likes_per_play)]]:
		var counter := page.vbox(0)
		counter.add_child(page.label(item[0], 14, SUBTLE))
		counter.add_child(page.label(Fmt.number(item[1]), 22, TEXT, true, "%sLabel" % item[0]))
		counters.add_child(counter)

	body.add_child(page.label("Faixas", 22, TEXT, true))
	var list := page.vbox(10)
	list.name = "TrackList"
	body.add_child(list)
	if songs.is_empty():
		body.add_child(page.empty_message("Nenhuma faixa publicada.", SUBTLE))
	var top_plays: int = page.plays(songs[0]) if not songs.is_empty() else 1
	for performance in songs.slice(0, 8):
		var song := page.song_of(performance)
		var card := page.panel(CARD, 4, 14)
		var line := page.hbox(16)
		card.add_child(line)
		line.add_child(page.cover(song.cover_file, 90))
		var track := page.vbox(6)
		track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(track)
		var title_row := page.hbox(10)
		title_row.add_child(page.pill("▶", ACCENT, Color.WHITE, 14))
		var names := page.vbox(0)
		names.add_child(page.label(career.artist_name, 13, SUBTLE))
		names.add_child(page.label(song.title, 17, TEXT))
		title_row.add_child(names)
		track.add_child(title_row)
		var wave := PlatformPage.Waveform.new()
		wave.seed_text = song.id
		wave.progress = float(page.plays(performance)) / maxf(top_plays, 1)
		wave.custom_minimum_size = Vector2(0, 40)
		wave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		track.add_child(wave)
		var plays := page.plays(performance)
		track.add_child(page.label("▶ %s    ♥ %s" % [Fmt.number(plays), Fmt.number(roundi(plays * page.platform.likes_per_play))], 14, SUBTLE))
		list.add_child(card)
