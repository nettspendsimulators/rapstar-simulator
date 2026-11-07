extends Screen
## Cria um projeto ou edita um não lançado (quando context tem album_id).
## A tracklist só é aplicada ao confirmar.

var _album: AlbumData
var _track_ids: Array[String] = []


func _ready() -> void:
	%AvailableTable.set_headers(["Músicas disponíveis", "Nota", "Status"])
	%TracksTable.set_headers(["Tracklist", "Nota", "Status"])
	for album_format in GameManager.balance.album_formats:
		%FormatOption.add_item(album_format.display_name)
		%FormatOption.set_item_metadata(%FormatOption.item_count - 1, String(album_format.id))
	# O álbum é o formato principal, então vem selecionado em um projeto novo.
	_select_format("album")

	_album = GameManager.career.find_content(context.get("album_id", "")) as AlbumData
	if _album != null:
		%Title.text = "Editar projeto"
		%TitleEdit.text = _album.title
		%CoverPicker.set_cover(_album.cover_file)
		_select_format(_album.format_id)
		_track_ids = _album.song_ids.duplicate()
		%ConfirmButton.text = "Salvar alterações"
	else:
		%ConfirmButton.text = "Criar projeto"

	%CoverPicker.message_requested.connect(%MessageLabel.set_text)
	%FormatOption.item_selected.connect(func(_index: int) -> void: _update_summary())
	%AddButton.pressed.connect(_on_add_pressed)
	%RemoveButton.pressed.connect(_on_remove_pressed)
	%UpButton.pressed.connect(_move_selected.bind(-1))
	%DownButton.pressed.connect(_move_selected.bind(1))
	%ConfirmButton.pressed.connect(_on_confirm_pressed)
	%BackButton.pressed.connect(navigate.bind(Screen.ALBUMS))
	_rebuild_tables()
	super()


func _select_format(format_id: String) -> void:
	for index in %FormatOption.item_count:
		if %FormatOption.get_item_metadata(index) == format_id:
			%FormatOption.select(index)
			return


func _selected_format() -> AlbumFormatDefinition:
	return GameManager.balance.find_album_format(%FormatOption.get_selected_metadata())


func _rebuild_tables() -> void:
	var career := GameManager.career
	var album_id := _album.id if _album != null else ""
	%AvailableTable.clear_rows()
	for song in GameManager.albums.available_songs(career, album_id):
		if song.id not in _track_ids:
			%AvailableTable.add_row([song.title, song.quality, _short_status(song)], song.id, song.cover_file)
	%TracksTable.clear_rows()
	for index in _track_ids.size():
		var track := career.find_song(_track_ids[index])
		%TracksTable.add_row(["%d. %s" % [index + 1, track.title], track.quality, _short_status(track)], track.id, track.cover_file)
	_update_summary()


func _short_status(song: SongData) -> String:
	return "Lançada" if song.is_released() else "Inédita"


func _update_summary() -> void:
	var album_format := _selected_format()
	var count := _track_ids.size()
	%FormatInfo.text = album_format.summary()
	var cost := album_format.production_cost(count)
	var cost_text := "Custo: %s" % Fmt.money(cost)
	if _album != null:
		cost_text = "A pagar: %s" % Fmt.money(maxi(cost - _album.production_cost, 0))
	%SummaryLabel.text = "%d música(s), de %d a %d  |  Nota do projeto: %d  |  %s" % [
		count,
		album_format.min_songs,
		album_format.max_songs,
		GameManager.career.average_quality(_track_ids),
		cost_text,
	]


func _on_add_pressed() -> void:
	var song_id: Variant = %AvailableTable.selected_value()
	if song_id == null:
		%MessageLabel.text = "Selecione uma música disponível."
		return
	%MessageLabel.text = ""
	_track_ids.append(song_id)
	_rebuild_tables()
	%TracksTable.select_value(song_id)


func _on_remove_pressed() -> void:
	var song_id: Variant = %TracksTable.selected_value()
	if song_id == null:
		%MessageLabel.text = "Selecione uma música da tracklist."
		return
	%MessageLabel.text = ""
	_track_ids.erase(song_id)
	_rebuild_tables()


func _move_selected(direction: int) -> void:
	var song_id: Variant = %TracksTable.selected_value()
	if song_id == null:
		%MessageLabel.text = "Selecione uma música da tracklist."
		return
	%MessageLabel.text = ""
	var index := _track_ids.find(song_id)
	var target := index + direction
	if target < 0 or target >= _track_ids.size():
		return
	_track_ids[index] = _track_ids[target]
	_track_ids[target] = song_id
	_rebuild_tables()
	%TracksTable.select_value(song_id)


func _on_confirm_pressed() -> void:
	var format_id := _selected_format().id
	var result: ActionResult
	if _album != null:
		result = GameManager.update_album(_album.id, %TitleEdit.text, format_id, _track_ids, %CoverPicker.cover_file)
	else:
		result = GameManager.create_album(%TitleEdit.text, format_id, _track_ids, %CoverPicker.cover_file)
	if result.ok:
		navigate(Screen.ALBUMS)
	else:
		%MessageLabel.text = result.message
