extends RefCounted
## Visual de rádio: painel com dial, luz de "no ar" e músicas em rotação.

const BACKGROUND := Color("#1b1410")
const PANEL := Color("#2a1f17")
const ACCENT := Color("#ffb000")
const ON_AIR := Color("#e53935")
const TEXT := Color("#f5e6d0")
const SUBTLE := Color("#b59a7a")


func build(page: PlatformPage) -> void:
	var career := page.career()
	var stats := page.stats()
	var rotation := page.songs_here()
	page.set_background(BACKGROUND)
	var column := page.scroll_column(36, 20)

	var top := page.hbox(16)
	column.add_child(top)
	top.add_child(page.label("Rádio", 34, ACCENT, true, "PlatformName"))
	top.add_child(page.spacer())
	top.add_child(page.back_button(PANEL, TEXT))

	var console := page.panel(PANEL, 18, 28)
	column.add_child(console)
	var console_row := page.hbox(32)
	console.add_child(console_row)
	var dial := page.panel(Color.BLACK, 12, 18)
	dial.add_child(page.label("FM 98.7", 48, ACCENT, true))
	console_row.add_child(dial)
	var info := page.vbox(8)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	console_row.add_child(info)
	var on_air := not rotation.is_empty()
	info.add_child(page.pill("● NO AR" if on_air else "○ FORA DO AR", ON_AIR if on_air else Color("#555555"), Color.WHITE))
	info.add_child(page.label("%s execuções  •  %s em direitos" % [Fmt.number(stats.total_plays), Fmt.money(stats.revenue)], 18, TEXT, false, "PlaysLabel"))
	if on_air:
		info.add_child(page.label("Tocando agora: %s — %s" % [page.song_of(rotation[0]).title, career.artist_name], 16, SUBTLE))

	if not on_air:
		var platform := page.platform
		column.add_child(page.empty_message(
			"Suas músicas ainda não tocam nas rádios. É preciso ter fama %s ou incluir a ação de Rádio no marketing do lançamento." % Fmt.number(platform.required_fame),
			SUBTLE
		))
		return
	column.add_child(page.label("Em rotação", 22, TEXT, true))
	var list := page.vbox(6)
	list.name = "TrackList"
	column.add_child(list)
	for index in rotation.size():
		var performance := rotation[index]
		var row := page.panel(PANEL, 8, 12)
		var line := page.hbox(16)
		row.add_child(line)
		line.add_child(page.label("%02d" % (index + 1), 20, ACCENT, true))
		line.add_child(page.label(page.song_of(performance).title, 18, TEXT))
		line.add_child(page.spacer())
		line.add_child(page.label("%s execuções" % Fmt.number(page.plays(performance)), 16, SUBTLE))
		list.add_child(row)
