extends Screen


func _ready() -> void:
	%SongsTable.set_headers(["Nome", "Nota", "Status", "Projeto", "Streams"])
	%SongsTable.item_mouse_selected.connect(func(_position: Vector2, _button: int) -> void: _open_selected())
	%SongsTable.item_activated.connect(_open_selected)
	%NewButton.pressed.connect(navigate.bind(Screen.SONG_EDITOR))
	%BackButton.pressed.connect(navigate.bind(Screen.HUB))
	super()


func refresh() -> void:
	var career := GameManager.career
	%StatsLabel.text = "Dinheiro: %s  |  Energia: %d/%d" % [
		Fmt.money(career.money), career.energy, GameManager.balance.max_energy
	]
	%SongsTable.clear_rows()
	for song in career.songs:
		var album := career.find_album_of_song(song.id)
		%SongsTable.add_row([
			song.title,
			song.quality,
			song.display_status(),
			album.title if album != null else "—",
			_plays_text(song),
		], song.id, song.cover_file)


func _plays_text(song: SongData) -> String:
	var performance := GameManager.career.find_performance(song.id)
	return Fmt.number(performance.total_plays) if performance != null else "—"


## Adiado porque esta tela é trocada enquanto a tabela ainda trata o clique.
func _open_selected() -> void:
	var song_id: Variant = %SongsTable.selected_value()
	if song_id != null:
		navigate.call_deferred(Screen.SONG_DETAIL, {"song_id": song_id})
