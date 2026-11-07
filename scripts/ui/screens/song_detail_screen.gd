extends Screen
## Interface de uma música: nota geral, créditos e melhoria de cada atributo.
## context precisa ter song_id.

## Controles de cada atributo, por id.
var _rows: Dictionary[String, Dictionary] = {}
var _song: SongData


func _ready() -> void:
	_song = GameManager.career.find_song(context.get("song_id", ""))
	_build_attribute_rows()
	%EditButton.pressed.connect(func() -> void: navigate(Screen.SONG_EDITOR, {"song_id": _song.id}))
	%MarketingButton.pressed.connect(func() -> void: navigate(Screen.MARKETING, {"content_id": _song.id, "back": Screen.SONG_DETAIL}))
	%VideoButton.pressed.connect(_on_video_pressed)
	%BackButton.pressed.connect(navigate.bind(Screen.SONGS))
	super()


func _build_attribute_rows() -> void:
	for attribute in GameManager.balance.song_quality.attributes:
		var name_label := Label.new()
		name_label.text = attribute.display_name
		name_label.theme_type_variation = &"HeaderLabel"
		%AttributesGrid.add_child(name_label)

		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = 100
		bar.custom_minimum_size = Vector2(0, 16)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		%AttributesGrid.add_child(bar)

		var value_label := Label.new()
		%AttributesGrid.add_child(value_label)

		var cost_label := Label.new()
		cost_label.text = "%d de energia" % attribute.energy_cost
		%AttributesGrid.add_child(cost_label)

		var button := Button.new()
		button.name = "Improve_%s" % attribute.id
		button.text = "Melhorar"
		button.pressed.connect(_on_improve_pressed.bind(attribute.id))
		%AttributesGrid.add_child(button)

		_rows[attribute.id] = {"bar": bar, "value": value_label, "button": button}


func refresh() -> void:
	var career := GameManager.career
	%Title.text = _song.title
	%CoverView.show_cover(_song.cover_file)
	%StatsLabel.text = "Dinheiro: %s  |  Energia: %d/%d" % [
		Fmt.money(career.money), career.energy, GameManager.balance.max_energy
	]
	%QualityLabel.text = "Nota geral: %d" % _song.quality
	%StatusLabel.text = _status_text()
	%CreditsLabel.text = _credits_text()
	%EditButton.disabled = _song.is_released()
	for attribute_id in _rows:
		_refresh_row(attribute_id)


func _refresh_row(attribute_id: String) -> void:
	var row := _rows[attribute_id]
	var value := _song.attribute_value(attribute_id)
	var limit := GameManager.music.improvement_limit(_song, attribute_id)
	row["bar"].value = value
	row["value"].text = "%d / %d" % [value, limit]
	var button: Button = row["button"]
	if _song.is_released():
		button.text = "Bloqueado"
		button.disabled = true
	elif GameManager.music.improvement_room(_song, attribute_id) <= 0:
		button.text = "No limite"
		button.disabled = true


func _status_text() -> String:
	if _song.is_released():
		return "Lançada na semana %s. Atributos bloqueados.%s" % [Fmt.number(_song.release_week), _performance_text()]
	var album := GameManager.career.find_album_of_song(_song.id)
	if album != null:
		return "%s. Faz parte de \"%s\"." % [_song.display_status(), album.title]
	return "%s." % _song.display_status()


func _performance_text() -> String:
	var performance := GameManager.career.find_performance(_song.id)
	if performance == null:
		return ""
	return "\nReproduções: %s  |  %s" % [Fmt.number(performance.total_plays), GameManager.streaming.trend_label(performance)]


func _credits_text() -> String:
	var catalog := GameManager.balance.collaborators
	return "\n".join([
		"Produtores: %s" % _names_text(CollaboratorCatalog.names(catalog.producers, _song.credits.producer_ids)),
		"Beatmakers: %s" % _names_text(CollaboratorCatalog.names(catalog.beatmakers, _song.credits.beatmaker_ids)),
		"Feats: %s (nota %d)" % [_names_text(CollaboratorCatalog.names(catalog.feats, _song.credits.feat_ids)), _song.feat_score],
		"Sample: %s" % _sample_text(),
		"Investido: %s" % Fmt.money(_song.production_cost),
	])


func _sample_text() -> String:
	var definition := GameManager.balance.samples.find_sample(_song.sample.sample_id)
	if definition == null:
		return "—"
	if definition.is_own():
		return "%s (\"%s\")" % [definition.display_name, GameManager.career.find_song(_song.sample.song_id).title]
	return definition.display_name


func _on_video_pressed() -> void:
	var video := GameManager.career.find_video_for_song(_song.id)
	var next_context := {"song_id": _song.id, "back": Screen.SONG_DETAIL}
	if video != null:
		next_context["video_id"] = video.id
	navigate(Screen.VIDEO_EDITOR, next_context)


func _names_text(names: PackedStringArray) -> String:
	return "—" if names.is_empty() else ", ".join(names)


func _on_improve_pressed(attribute_id: String) -> void:
	%MessageLabel.text = GameManager.improve_song(_song.id, attribute_id).message
