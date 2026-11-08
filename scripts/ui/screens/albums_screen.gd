extends Screen
## Projetos (EPs, álbuns e mixtapes): capas em grade e, ao escolher um, capa grande,
## progresso, tracklist e ações do projeto.

var _subtitle := Label.new()
var _grid := CardGrid.new()
var _detail := PanelContainer.new()
var _cover := CoverPreview.new()
var _name := Label.new()
var _detail_label := Label.new()
var _edit := Button.new()
var _marketing := Button.new()


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
	title.text = "Projetos"
	title.theme_type_variation = &"TitleLabel"
	titles.add_child(title)
	_subtitle.name = "MoneyLabel"
	_subtitle.theme_type_variation = &"MutedLabel"
	titles.add_child(_subtitle)
	var create := Button.new()
	create.name = "NewButton"
	create.text = "Criar projeto"
	create.icon = load("res://assets/icons/plus.svg")
	create.theme_type_variation = &"PrimaryButton"
	create.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	create.pressed.connect(navigate.bind(Screen.PROJECT_EDITOR))
	header.add_child(create)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	column.add_child(body)
	_grid.name = "ProjectsGrid"
	_grid.card_pressed.connect(func(_value: Variant) -> void: _show_detail())
	body.add_child(_grid)
	_build_detail(body)
	var row := HBoxContainer.new()
	column.add_child(row)
	var back := Button.new()
	back.name = "BackButton"
	back.text = "Voltar ao início"
	back.pressed.connect(navigate.bind(Screen.HUB))
	row.add_child(back)
	super()


func _build_detail(body: HBoxContainer) -> void:
	_detail.name = "Detail"
	_detail.theme_type_variation = &"HeroPanel"
	_detail.custom_minimum_size = Vector2(300, 0)
	body.add_child(_detail)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_detail.add_child(column)
	_cover.name = "DetailCover"
	_cover.custom_minimum_size = Vector2(0, 180)
	column.add_child(_cover)
	_name.name = "DetailTitle"
	_name.theme_type_variation = &"HeaderLabel"
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_name)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_detail_label.name = "DetailLabel"
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_detail_label)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	_edit.name = "EditButton"
	_edit.text = "Editar"
	_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit.pressed.connect(_on_edit_pressed)
	actions.add_child(_edit)
	_marketing.name = "MarketingButton"
	_marketing.text = "Marketing"
	_marketing.icon = load("res://assets/icons/marketing.svg")
	_marketing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_marketing.pressed.connect(_on_marketing_pressed)
	actions.add_child(_marketing)


func refresh() -> void:
	var career := GameManager.career
	var released := career.albums.filter(func(album: AlbumData) -> bool: return album.is_released()).size()
	_subtitle.text = "%d projeto(s)  •  %d lançado(s)  •  EPs, álbuns e mixtapes podem começar vazios" % [career.albums.size(), released]
	var selected: Variant = _grid.selected_value()
	_grid.clear_cards("Nenhum projeto ainda. Crie um EP, álbum ou mixtape e adicione músicas ao longo da carreira." if career.albums.is_empty() else "")
	for album in career.albums:
		var label := GameManager.releases.content_type_label(album)
		_grid.add_card(album.id, album.title, "%s  •  %s música(s)" % [label, _songs_text(album)], CoverArt.texture_for(album.cover_file, album.title),
			album.display_status(), Color.TRANSPARENT, str(album.quality) if not album.song_ids.is_empty() else "")
	if selected == null and not career.albums.is_empty():
		selected = career.albums[-1].id
	_grid.select_value(selected)
	_show_detail()


func _songs_text(album: AlbumData) -> String:
	if album.is_released():
		return str(album.song_ids.size())
	var album_format := GameManager.balance.find_album_format(album.format_id)
	return "%d/%d" % [album.song_ids.size(), album_format.min_songs]


func _selected_album() -> AlbumData:
	var album_id: Variant = _grid.selected_value()
	return GameManager.career.find_content(album_id) as AlbumData if album_id != null else null


func _show_detail() -> void:
	var album := _selected_album()
	_edit.disabled = album == null or album.is_released()
	_marketing.disabled = album == null
	_cover.show_cover(album.cover_file if album != null else "", album.title if album != null else "")
	_name.text = album.title if album != null else "Escolha um projeto"
	_detail_label.text = _detail_text(album) if album != null else "Clique em uma capa para ver a tracklist e as ações."


func _detail_text(album: AlbumData) -> String:
	var lines := PackedStringArray()
	lines.append("%s  •  %s" % [GameManager.releases.content_type_label(album), album.display_status()])
	if not album.is_released():
		var album_format := GameManager.balance.find_album_format(album.format_id)
		var count := album.song_ids.size()
		lines.append(album_format.progress_text(count))
		lines.append("Lançamento liberado." if album_format.accepts_song_count(count) else "Lançamento bloqueado: faltam músicas.")
	lines.append("")
	for index in album.song_ids.size():
		var song := GameManager.career.find_song(album.song_ids[index])
		lines.append("%d. %s  (%d)" % [index + 1, song.title, song.quality])
	return "\n".join(lines)


func _on_marketing_pressed() -> void:
	var album := _selected_album()
	if album != null:
		navigate(Screen.MARKETING, {"content_id": album.id, "back": Screen.ALBUMS})


func _on_edit_pressed() -> void:
	var album := _selected_album()
	if album != null:
		navigate(Screen.PROJECT_EDITOR, {"album_id": album.id})
