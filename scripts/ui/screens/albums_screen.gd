extends Screen


func _ready() -> void:
	%ProjectsTable.set_headers(["Nome", "Formato", "Músicas", "Nota", "Status", "Semana"])
	%ProjectsTable.item_selected.connect(_on_selection_changed)
	%NewButton.pressed.connect(navigate.bind(Screen.PROJECT_EDITOR))
	%EditButton.pressed.connect(_on_edit_pressed)
	%MarketingButton.pressed.connect(_on_marketing_pressed)
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
			_songs_text(album),
			album.quality if not album.song_ids.is_empty() else "—",
			album.display_status(),
			Fmt.number(album.release_week) if album.is_released() else "—",
		], album.id, album.cover_file)
	_on_selection_changed()


## Projetos não lançados mostram o progresso até o mínimo para lançar.
func _songs_text(album: AlbumData) -> String:
	if album.is_released():
		return str(album.song_ids.size())
	var album_format := GameManager.balance.find_album_format(album.format_id)
	return "%d/%d" % [album.song_ids.size(), album_format.min_songs]


func _selected_album() -> AlbumData:
	var album_id: Variant = %ProjectsTable.selected_value()
	return GameManager.career.find_content(album_id) as AlbumData if album_id != null else null


func _on_selection_changed() -> void:
	var album := _selected_album()
	%EditButton.disabled = album == null or album.is_released()
	%MarketingButton.disabled = album == null
	%DetailCover.show_cover(album.cover_file if album != null else "")
	%DetailLabel.text = _detail_text(album) if album != null else "Selecione um projeto para ver a tracklist."


func _detail_text(album: AlbumData) -> String:
	var lines := PackedStringArray()
	if not album.is_released():
		var album_format := GameManager.balance.find_album_format(album.format_id)
		var count := album.song_ids.size()
		lines.append(album_format.progress_text(count))
		lines.append("Lançamento liberado." if album_format.accepts_song_count(count) else "Lançamento bloqueado.")
	for index in album.song_ids.size():
		var song := GameManager.career.find_song(album.song_ids[index])
		lines.append("%d. %s (%d)" % [index + 1, song.title, song.quality])
	return "\n".join(lines)


func _on_marketing_pressed() -> void:
	var album := _selected_album()
	if album != null:
		navigate(Screen.MARKETING, {"content_id": album.id, "back": Screen.ALBUMS})


func _on_edit_pressed() -> void:
	var album := _selected_album()
	if album != null:
		navigate(Screen.PROJECT_EDITOR, {"album_id": album.id})
