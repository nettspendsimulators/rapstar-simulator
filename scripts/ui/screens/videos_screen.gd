extends Screen
## Lista de videoclipes e entrada para produzir um novo.


func _ready() -> void:
	%VideosTable.set_headers(["Música", "Status", "Lançamento", "Nota", "Visualizações", "Receita"])
	%VideosTable.set_column_expand_ratio(1, 3)
	%VideosTable.item_mouse_selected.connect(func(_position: Vector2, _button: int) -> void: _open_selected())
	%VideosTable.item_activated.connect(_open_selected)
	%NewButton.pressed.connect(navigate.bind(Screen.VIDEO_EDITOR, {"back": Screen.VIDEOS}))
	%BackButton.pressed.connect(navigate.bind(Screen.HUB))
	super()


func refresh() -> void:
	var career := GameManager.career
	%MoneyLabel.text = "Dinheiro: %s" % Fmt.money(career.money)
	%NewButton.disabled = GameManager.videos.eligible_songs(career).is_empty()
	%VideosTable.clear_rows()
	for video in career.music_videos:
		var song := career.find_song(video.song_id)
		%VideosTable.add_row([
			song.title,
			GameManager.videos.status_label(career, video),
			GameManager.videos.release_label(career, video),
			video.score,
			Fmt.number(video.total_views) if video.is_released() else "—",
			Fmt.money(video.revenue),
		], video.id, video.cover_file if not video.cover_file.is_empty() else song.cover_file)


## Adiado porque esta tela é trocada enquanto a tabela ainda trata o clique.
func _open_selected() -> void:
	var video_id: Variant = %VideosTable.selected_value()
	if video_id != null:
		navigate.call_deferred(Screen.VIDEO_EDITOR, {"video_id": video_id, "back": Screen.VIDEOS})
