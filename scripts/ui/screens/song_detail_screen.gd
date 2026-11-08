extends Screen
## Uma música: capa, nota e estado em destaque, com as ações principais. Melhorias, créditos e
## desempenho ficam em abas, para a tela mostrar primeiro o que importa.
## context precisa ter song_id.

var _rows: Dictionary[String, Dictionary] = {}
var _song: SongData
var _cover := CoverPreview.new()
var _kicker := Label.new()
var _title := Label.new()
var _status := Label.new()
var _grade := Label.new()
var _energy := Label.new()
var _grid := GridContainer.new()
var _credits := Label.new()
var _performance := Label.new()
var _message := Label.new()
var _edit := Button.new()
var _video := Button.new()
var _marketing := Button.new()


func _ready() -> void:
	_song = GameManager.career.find_song(context.get("song_id", ""))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	add_child(column)
	_build_header(column)
	var tabs := TabContainer.new()
	tabs.name = "DetailTabs"
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tabs)
	_build_improvements(tabs)
	_build_text_tab(tabs, "Créditos", _credits, "CreditsLabel")
	_build_text_tab(tabs, "Desempenho", _performance, "PerformanceLabel")
	_message.name = "MessageLabel"
	_message.theme_type_variation = &"MessageLabel"
	column.add_child(_message)
	var row := HBoxContainer.new()
	column.add_child(row)
	var back := Button.new()
	back.name = "BackButton"
	back.text = "Voltar às músicas"
	back.pressed.connect(navigate.bind(Screen.SONGS))
	row.add_child(back)
	super()


func _build_header(parent: Container) -> void:
	var hero := PanelContainer.new()
	hero.name = "Header"
	hero.theme_type_variation = &"HeroPanel"
	parent.add_child(hero)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	hero.add_child(row)
	_cover.name = "CoverView"
	_cover.custom_minimum_size = Vector2(150, 150)
	row.add_child(_cover)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 4)
	row.add_child(texts)
	_kicker.theme_type_variation = &"SectionLabel"
	texts.add_child(_kicker)
	_title.name = "Title"
	_title.theme_type_variation = &"TitleLabel"
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(_title)
	_status.name = "StatusLabel"
	_status.theme_type_variation = &"MutedLabel"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(_status)
	var grade_box := VBoxContainer.new()
	grade_box.alignment = BoxContainer.ALIGNMENT_CENTER
	grade_box.add_theme_constant_override("separation", 0)
	row.add_child(grade_box)
	_grade.name = "QualityLabel"
	_grade.theme_type_variation = &"StatValue"
	_grade.add_theme_font_size_override("font_size", 52)
	_grade.add_theme_color_override("font_color", Color("#f5b82e"))
	_grade.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grade_box.add_child(_grade)
	var grade_caption := Label.new()
	grade_caption.text = "NOTA"
	grade_caption.theme_type_variation = &"SectionLabel"
	grade_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grade_box.add_child(grade_caption)
	var actions := VBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.custom_minimum_size = Vector2(190, 0)
	row.add_child(actions)
	_marketing.name = "MarketingButton"
	_marketing.text = "Marketing"
	_marketing.icon = load("res://assets/icons/marketing.svg")
	_marketing.theme_type_variation = &"PrimaryButton"
	_marketing.pressed.connect(func() -> void: navigate(Screen.MARKETING, {"content_id": _song.id, "back": Screen.SONG_DETAIL}))
	actions.add_child(_marketing)
	_video.name = "VideoButton"
	_video.text = "Videoclipe"
	_video.icon = load("res://assets/icons/video.svg")
	_video.pressed.connect(_on_video_pressed)
	actions.add_child(_video)
	_edit.name = "EditButton"
	_edit.text = "Editar música"
	_edit.pressed.connect(func() -> void: navigate(Screen.SONG_EDITOR, {"song_id": _song.id}))
	actions.add_child(_edit)


func _build_improvements(tabs: TabContainer) -> void:
	var page := VBoxContainer.new()
	page.name = "Melhorias"
	page.add_theme_constant_override("separation", 12)
	tabs.add_child(page)
	_energy.name = "StatsLabel"
	_energy.theme_type_variation = &"MutedLabel"
	page.add_child(_energy)
	_grid.name = "AttributesGrid"
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 10)
	page.add_child(_grid)
	for attribute in GameManager.balance.song_quality.attributes:
		var name_label := Label.new()
		name_label.text = attribute.display_name
		name_label.theme_type_variation = &"ChipLabel"
		name_label.custom_minimum_size = Vector2(100, 0)
		_grid.add_child(name_label)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = 100
		bar.custom_minimum_size = Vector2(0, 12)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_grid.add_child(bar)
		var value_label := Label.new()
		value_label.custom_minimum_size = Vector2(70, 0)
		_grid.add_child(value_label)
		var cost_label := Label.new()
		cost_label.theme_type_variation = &"MutedLabel"
		cost_label.text = "sem custo (energia infinita)" if GameManager.career.infinite_energy else "%d de energia" % attribute.energy_cost
		_grid.add_child(cost_label)
		var button := Button.new()
		button.name = "Improve_%s" % attribute.id
		button.text = "Melhorar"
		button.custom_minimum_size = Vector2(130, 0)
		button.pressed.connect(_on_improve_pressed.bind(attribute.id))
		_grid.add_child(button)
		_rows[attribute.id] = {"bar": bar, "value": value_label, "button": button}


func _build_text_tab(tabs: TabContainer, title: String, label: Label, node_name: String) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	label.name = node_name
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(label)


func refresh() -> void:
	var album := GameManager.career.find_album_of_song(_song.id)
	_kicker.text = ("FAIXA DE %s" % album.title.to_upper()) if album != null else "SINGLE"
	_title.text = _song.title
	_title.tooltip_text = _song.title
	_cover.show_cover(_song.cover_file, _song.title)
	_grade.text = str(_song.quality)
	_status.text = _status_text()
	_energy.text = "Energia: %s  •  cada melhoria usa energia, não dinheiro. Depois de lançada, a música não muda mais." % GameManager.energy_text()
	_credits.text = _credits_text()
	_performance.text = _performance_full_text()
	_edit.disabled = _song.is_released()
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
		return "Lançada na semana %s.%s" % [Fmt.number(_song.release_week), _performance_text()]
	var album := GameManager.career.find_album_of_song(_song.id)
	if album != null:
		return "%s  •  faz parte de \"%s\"" % [_song.display_status(), album.title]
	return _song.display_status()


func _performance_text() -> String:
	var performance := GameManager.career.find_performance(_song.id)
	if performance == null:
		return ""
	return "  Reproduções: %s  •  %s" % [Fmt.number(performance.total_plays), GameManager.streaming.trend_label(performance)]


func _performance_full_text() -> String:
	var performance := GameManager.career.find_performance(_song.id)
	if performance == null:
		return "Ainda sem números: lance a música para acompanhar reproduções, plataformas e tendência."
	var lines := PackedStringArray(["Reproduções totais: %s" % Fmt.number(performance.total_plays), "Tendência: %s" % GameManager.streaming.trend_label(performance), ""])
	for platform_id: String in performance.platform_plays:
		var platform := GameManager.balance.streaming.find_platform(platform_id)
		lines.append("%s: %s" % [platform.display_name if platform != null else platform_id, Fmt.number(performance.platform_plays[platform_id])])
	return "\n".join(lines)


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
	_message.text = GameManager.improve_song(_song.id, attribute_id).message
