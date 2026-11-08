extends Screen
## Discografia: capas das músicas com nota e estado. Clique abre a música.

const FILTERS := ["Todas", "Inéditas", "Lançadas"]

var _subtitle := Label.new()
var _grid := CardGrid.new()
var _filter := 0


func _ready() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	var title := Label.new()
	title.text = "Músicas"
	title.theme_type_variation = &"TitleLabel"
	titles.add_child(title)
	_subtitle.name = "StatsLabel"
	_subtitle.theme_type_variation = &"MutedLabel"
	titles.add_child(_subtitle)
	var create := Button.new()
	create.name = "NewButton"
	create.text = "Nova música"
	create.icon = load("res://assets/icons/plus.svg")
	create.theme_type_variation = &"PrimaryButton"
	create.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	create.pressed.connect(navigate.bind(Screen.SONG_EDITOR))
	header.add_child(create)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 8)
	column.add_child(filters)
	var group := ButtonGroup.new()
	for index in FILTERS.size():
		var chip := Button.new()
		chip.name = "Filter%d" % index
		chip.text = FILTERS[index]
		chip.theme_type_variation = &"ChipButton"
		chip.toggle_mode = true
		chip.button_group = group
		chip.button_pressed = index == 0
		chip.focus_mode = Control.FOCUS_NONE
		chip.pressed.connect(func() -> void:
			_filter = index
			refresh())
		filters.add_child(chip)
	_grid.name = "SongsGrid"
	_grid.card_pressed.connect(func(song_id: Variant) -> void: navigate.call_deferred(Screen.SONG_DETAIL, {"song_id": song_id}))
	column.add_child(_grid)
	var row := HBoxContainer.new()
	column.add_child(row)
	var back := Button.new()
	back.name = "BackButton"
	back.text = "Voltar ao início"
	back.pressed.connect(navigate.bind(Screen.HUB))
	row.add_child(back)
	super()


func refresh() -> void:
	var career := GameManager.career
	var released := career.songs.filter(func(song: SongData) -> bool: return song.is_released()).size()
	_subtitle.text = "%d música(s)  •  %d lançada(s)  •  %d inédita(s)" % [career.songs.size(), released, career.songs.size() - released]
	_grid.clear_cards("Nenhuma música ainda. Grave a primeira em \"Nova música\": escolha colaboradores, pague a produção e melhore com energia antes de lançar." if career.songs.is_empty() else "")
	for song in career.songs:
		if (_filter == 1 and song.is_released()) or (_filter == 2 and not song.is_released()):
			continue
		var album := career.find_album_of_song(song.id)
		var subtitle := album.title if album != null else "Single"
		var performance := career.find_performance(song.id)
		if performance != null and performance.total_plays > 0:
			subtitle = "%s streams" % Fmt.number(performance.total_plays)
		_grid.add_card(song.id, song.title, subtitle, CoverArt.texture_for(song.cover_file, song.title), song.display_status(), Color.TRANSPARENT, str(song.quality))
