extends Screen


func _ready() -> void:
	%ProjectsTable.set_headers(["Nome", "Formato", "Músicas", "Nota", "Status", "Semana"])
	%ProjectsTable.item_selected.connect(_on_selection_changed)
	%NewButton.pressed.connect(navigate.bind(Screen.PROJECT_EDITOR))
	%EditButton.pressed.connect(_on_edit_pressed)
	%BackButton.pressed.connect(navigate.bind(Screen.HUB))
	super()


func refresh() -> void:
	var career := GameManager.career
	%MoneyLabel.text = "Dinheiro: %s" % Fmt.money(career.money)
	%ProjectsTable.clear_rows()
	for album in career.albums:
		%ProjectsTable.add_row([
			album.title,
			GameManager.releases.content_type_label(album),
			album.song_ids.size(),
			album.quality,
			album.status_label(),
			Fmt.number(album.release_week) if album.is_released() else "—",
		], album.id, album.cover_file)
	_on_selection_changed()


func _selected_album() -> AlbumData:
	var album_id: Variant = %ProjectsTable.selected_value()
	return GameManager.career.find_content(album_id) as AlbumData if album_id != null else null


func _on_selection_changed() -> void:
	var album := _selected_album()
	%EditButton.disabled = album == null or album.is_released()
	%DetailCover.show_cover(album.cover_file if album != null else "")
	%DetailLabel.text = _tracklist_text(album) if album != null else "Selecione um projeto para ver a tracklist."


func _tracklist_text(album: AlbumData) -> String:
	var lines := PackedStringArray()
	for index in album.song_ids.size():
		var song := GameManager.career.find_song(album.song_ids[index])
		lines.append("%d. %s (%d)" % [index + 1, song.title, song.quality])
	return "\n".join(lines)


func _on_edit_pressed() -> void:
	var album := _selected_album()
	if album != null:
		navigate(Screen.PROJECT_EDITOR, {"album_id": album.id})
