extends Screen


func _ready() -> void:
	%SongsTable.set_headers(["Nome", "Nota", "Status", "Projeto", "Streams"])
	%SongsTable.item_selected.connect(_on_selection_changed)
	%NewButton.text = "Nova música (%s)" % Fmt.money(GameManager.balance.song_production_cost)
	%NewButton.pressed.connect(navigate.bind(Screen.SONG_EDITOR))
	%EditButton.pressed.connect(_on_edit_pressed)
	%ImproveButton.text = "Melhorar (%d de energia)" % GameManager.balance.song_quality.improvement_energy_cost
	%ImproveButton.pressed.connect(_on_improve_pressed)
	%BackButton.pressed.connect(navigate.bind(Screen.HUB))
	super()


func refresh() -> void:
	var career := GameManager.career
	var selected_id: Variant = %SongsTable.selected_value()
	%StatsLabel.text = "Dinheiro: %s  |  Energia: %d/%d" % [
		Fmt.money(career.money), career.energy, GameManager.balance.max_energy
	]
	%SongsTable.clear_rows()
	for song in career.songs:
		var release := career.find_release(song.id)
		var album := career.find_album_of_song(song.id)
		%SongsTable.add_row([
			song.title,
			song.quality,
			song.status_label(),
			album.title if album != null else "—",
			Fmt.number(release.total_streams) if release != null else "—",
		], song.id, song.cover_file)
	if selected_id != null:
		%SongsTable.select_value(selected_id)
	_on_selection_changed()


func _selected_song() -> SongData:
	var song_id: Variant = %SongsTable.selected_value()
	return GameManager.career.find_song(song_id) if song_id != null else null


func _on_selection_changed() -> void:
	var song := _selected_song()
	%EditButton.disabled = song == null or song.is_released()
	%ImproveButton.disabled = song == null or song.is_released()
	%DetailCover.show_cover(song.cover_file if song != null else "")
	%DetailLabel.text = _describe(song) if song != null else "Selecione uma música para ver os detalhes."


func _describe(song: SongData) -> String:
	var catalog := GameManager.balance.collaborators
	var lines := PackedStringArray([
		"Nota: %d (limite %d)" % [song.quality, GameManager.music.improvement_limit(song)],
		"Beat: %s  |  Produção: %s  |  Feats: %s" % [
			_score_text(song.beat_quality), _score_text(song.production_quality), _score_text(song.feat_score)
		],
		"Produtores: %s" % _names_text(CollaboratorCatalog.names(catalog.producers, song.credits.producer_ids)),
		"Beatmakers: %s" % _names_text(CollaboratorCatalog.names(catalog.beatmakers, song.credits.beatmaker_ids)),
		"Feats: %s" % _names_text(CollaboratorCatalog.names(catalog.feats, song.credits.feat_ids)),
	])
	if song.is_released():
		lines.append("Lançada na semana %s. Atributos bloqueados." % Fmt.number(song.release_week))
	return "\n".join(lines)


func _score_text(score: int) -> String:
	return "—" if score == SongData.UNKNOWN_SCORE else str(score)


func _names_text(names: PackedStringArray) -> String:
	return "—" if names.is_empty() else ", ".join(names)


func _on_edit_pressed() -> void:
	var song := _selected_song()
	if song != null:
		navigate(Screen.SONG_EDITOR, {"song_id": song.id})


func _on_improve_pressed() -> void:
	var song := _selected_song()
	if song != null:
		%MessageLabel.text = GameManager.improve_song(song.id).message
