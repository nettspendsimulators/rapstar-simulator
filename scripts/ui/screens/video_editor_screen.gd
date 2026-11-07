extends Screen
## Montagem de um videoclipe novo, ou produção, lançamento e desempenho de um existente.
## context pode ter video_id (existente), song_id (música já escolhida) e back (tela de volta).

const MODES := [VideoRules.MODE_WITH_SONG, VideoRules.MODE_DATE]
const MODE_LABELS := ["Automático, junto com a música", "Data específica"]

var _video: MusicVideo
## Controles de cada etapa: OptionButton, ou a lista de CheckBox das locações.
var _controls: Dictionary[String, Variant] = {}


func _ready() -> void:
	var career := GameManager.career
	_video = career.find_video(context.get("video_id", ""))
	_build_choice_controls()
	_fill_song_option()
	for index in MODES.size():
		%ModeOption.add_item(MODE_LABELS[index])
		%ModeOption.set_item_metadata(index, MODES[index])
	%WeekInput.min_value = career.current_week + 1
	%WeekInput.max_value = career.current_week + GameManager.balance.max_schedule_weeks_ahead
	%WeekInput.value = career.current_week + 4

	if _video != null:
		%Title.text = "Videoclipe: %s" % career.find_song(_video.song_id).title
		%CoverPicker.set_cover(_video.cover_file)
		_select_choices(_video.choices)
		_select_mode(_video.release_mode)
		if _video.scheduled_week != MusicVideo.NO_WEEK:
			%WeekInput.value = _video.scheduled_week
		_set_choices_enabled(false)
	else:
		_select_choices(GameManager.videos.default_choices())

	%SongOption.item_selected.connect(func(_index: int) -> void: _update_summary())
	%ModeOption.item_selected.connect(func(_index: int) -> void: _update_release_controls())
	%CoverPicker.message_requested.connect(%MessageLabel.set_text)
	%ConfirmButton.pressed.connect(_on_confirm_pressed)
	%BackButton.pressed.connect(_go_back)
	_update_release_controls()
	super()


func refresh() -> void:
	_update_summary()


func _build_choice_controls() -> void:
	for category in GameManager.balance.videos.categories:
		var label := Label.new()
		label.text = category.label
		%ChoicesGrid.add_child(label)
		if category.multiple:
			var flow := HFlowContainer.new()
			flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var checks: Array[CheckBox] = []
			for option in category.options:
				var check := CheckBox.new()
				check.text = option.display_name
				check.name = "Location_%s" % option.id
				check.set_meta("option_id", option.id)
				check.toggled.connect(func(_on: bool) -> void: _on_location_toggled(category))
				flow.add_child(check)
				checks.append(check)
			%ChoicesGrid.add_child(flow)
			_controls[category.id] = checks
		else:
			var option_button := OptionButton.new()
			option_button.name = "Choice_%s" % category.id
			option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for option in category.options:
				option_button.add_item(option.display_name)
				option_button.set_item_metadata(option_button.item_count - 1, option.id)
			option_button.item_selected.connect(func(_index: int) -> void: _update_summary())
			%ChoicesGrid.add_child(option_button)
			_controls[category.id] = option_button


func _fill_song_option() -> void:
	var career := GameManager.career
	if _video != null:
		%SongOption.add_item(career.find_song(_video.song_id).title)
		%SongOption.disabled = true
		return
	%SongOption.add_item("Escolha a música")
	%SongOption.set_item_metadata(0, "")
	for song in GameManager.videos.eligible_songs(career):
		var album := career.find_album_of_song(song.id)
		var origin := (" (%s)" % album.title) if album != null else ""
		%SongOption.add_item("%s%s — %s" % [song.title, origin, song.display_status()])
		%SongOption.set_item_metadata(%SongOption.item_count - 1, song.id)
		if song.id == context.get("song_id", ""):
			%SongOption.select(%SongOption.item_count - 1)


func _select_choices(choices: Dictionary) -> void:
	for category_id in _controls:
		var ids: Array = choices.get(category_id, [])
		var control: Variant = _controls[category_id]
		if control is OptionButton:
			for index in control.item_count:
				if control.get_item_metadata(index) in ids:
					control.select(index)
		else:
			for check: CheckBox in control:
				check.set_pressed_no_signal(check.get_meta("option_id") in ids)


func _choices() -> Dictionary:
	var choices := {}
	for category_id in _controls:
		var control: Variant = _controls[category_id]
		var ids: Array[String] = []
		if control is OptionButton:
			ids.append(control.get_selected_metadata())
		else:
			for check: CheckBox in control:
				if check.button_pressed:
					ids.append(check.get_meta("option_id"))
		choices[category_id] = ids
	return choices


func _set_choices_enabled(enabled: bool) -> void:
	for category_id in _controls:
		var control: Variant = _controls[category_id]
		if control is OptionButton:
			control.disabled = not enabled
		else:
			for check: CheckBox in control:
				check.disabled = not enabled


func _on_location_toggled(category: VideoCategoryDefinition) -> void:
	var checks: Array = _controls[category.id]
	var count := checks.filter(func(check: CheckBox) -> bool: return check.button_pressed).size()
	for check: CheckBox in checks:
		check.disabled = _video != null or (count >= category.max_choices and not check.button_pressed)
	_update_summary()


func _selected_song() -> SongData:
	if _video != null:
		return GameManager.career.find_song(_video.song_id)
	return GameManager.career.find_song(%SongOption.get_selected_metadata())


func _select_mode(mode: String) -> void:
	%ModeOption.select(MODES.find(mode))


func _update_release_controls() -> void:
	var is_date: bool = %ModeOption.get_selected_metadata() == VideoRules.MODE_DATE
	%WeekInput.visible = is_date
	%WeekLabel.visible = is_date
	var locked := _video != null and _video.is_released()
	%ModeOption.disabled = locked
	%WeekInput.editable = not locked
	_update_summary()


func _update_summary() -> void:
	var career := GameManager.career
	var song := _selected_song()
	%InfoLabel.text = _song_info(song)
	if _video != null:
		_show_existing()
		return
	if song == null:
		%SummaryLabel.text = "Escolha a música para ver orçamento, prazo e notas."
		%ScoresLabel.text = ""
		%ConfirmButton.text = "Produzir"
		%ConfirmButton.disabled = true
		return
	var choices := _choices()
	var error := GameManager.videos.validate_choices(choices)
	var evaluation := GameManager.videos.evaluate(song, choices)
	%SummaryLabel.text = "Custo total: %s  |  Prazo: %d semana(s), pronto na semana %s  |  Risco de problemas: %d%%  |  Dinheiro: %s" % [
		Fmt.money(evaluation.cost),
		evaluation.weeks,
		Fmt.number(career.current_week + evaluation.weeks),
		roundi(evaluation.problem_chance * 100),
		Fmt.money(career.money),
	]
	%ScoresLabel.text = _scores_text(evaluation)
	%ConfirmButton.disabled = not error.is_empty() or evaluation.cost > career.money
	if evaluation.cost > career.money:
		%ConfirmButton.text = "Dinheiro insuficiente"
	elif not error.is_empty():
		%ConfirmButton.text = error
	else:
		%ConfirmButton.text = "Produzir (%s)" % Fmt.money(evaluation.cost)


func _show_existing() -> void:
	var career := GameManager.career
	var videos := GameManager.videos
	%SummaryLabel.text = "Custo: %s  |  %s  |  Lançamento: %s%s" % [
		Fmt.money(_video.cost),
		videos.status_label(career, _video),
		videos.release_label(career, _video),
		("  |  " + _video.problem_note) if not _video.problem_note.is_empty() else "",
	]
	var performance := "Visualizações oficiais: %s  |  Melhor semana: %s  |  Curtidas: %s  |  Receita: %s  |  Trajetória: %s" % [
		Fmt.number(_video.total_views),
		Fmt.number(_video.peak_week_views),
		Fmt.number(_video.likes),
		Fmt.money(_video.revenue),
		_trajectory_label(),
	]
	if _video.is_leaked():
		performance += "\nVazou na semana %s: %s visualizações não oficiais, sem receita." % [Fmt.number(_video.leak_week), Fmt.number(_video.leak_views)]
	%ScoresLabel.text = "%s\n%s" % [_scores_text(_video), performance]
	%ConfirmButton.disabled = false
	%ConfirmButton.text = "Salvar capa" if _video.is_released() else "Salvar capa e lançamento"


func _trajectory_label() -> String:
	var trajectory := GameManager.balance.streaming.find_trajectory(_video.trajectory_id)
	return trajectory.label if trajectory != null else "—"


func _scores_text(values: Variant) -> String:
	return "Nota do videoclipe: %d  |  Técnica %d  |  Visual %d  |  Criatividade %d  |  Identidade %d  |  Coerência %d  |  Comercial %d  |  Descoberta %d  |  Viral %d" % [
		values.score, values.technical, values.visual, values.creativity, values.identity,
		values.coherence, values.commercial, values.discovery, values.viral,
	]


func _song_info(song: SongData) -> String:
	if song == null:
		return ""
	var career := GameManager.career
	var album := career.find_album_of_song(song.id)
	var feats := CollaboratorCatalog.names(GameManager.balance.collaborators.feats, song.credits.feat_ids)
	var performance := career.find_performance(song.id)
	return "Artista: %s  |  Feats: %s  |  Nota da música: %d  |  %s%s  |  Reproduções: %s" % [
		career.artist_name,
		"—" if feats.is_empty() else ", ".join(feats),
		song.quality,
		song.display_status(),
		(" em \"%s\"" % album.title) if album != null else "",
		Fmt.number(performance.total_plays) if performance != null else "—",
	]


func _on_confirm_pressed() -> void:
	var mode: String = %ModeOption.get_selected_metadata()
	var week := int(%WeekInput.value)
	var result: ActionResult
	if _video != null:
		result = GameManager.update_video(_video.id, %CoverPicker.cover_file, mode, week)
	else:
		var song := _selected_song()
		result = GameManager.create_video(song.id if song != null else "", _choices(), %CoverPicker.cover_file, mode, week)
		if result.ok:
			_video = result.value
			_set_choices_enabled(false)
			_update_summary()
	%MessageLabel.text = result.message


func _go_back() -> void:
	var back: StringName = context.get("back", Screen.VIDEOS)
	var song := _selected_song()
	navigate(back, {"song_id": song.id if song != null else ""})
