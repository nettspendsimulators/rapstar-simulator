extends Screen
## Central da carreira: quem é o artista, em que fase está, o que vem pela frente, o que fazer
## agora e como foi a última semana. Os indicadores principais ficam na barra superior.

var _character := CharacterView.new()
var _name := Label.new()
var _identity := Label.new()
var _stage := Label.new()
var _stage_bar := ProgressBar.new()
var _stage_hint := Label.new()
var _stats: Dictionary[String, Array] = {}
var _agenda := VBoxContainer.new()
var _steps := VBoxContainer.new()
var _week_title := Label.new()
var _week_summary := Label.new()
var _message := Label.new()


func _ready() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	column.add_child(body)
	_build_hero(body)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	body.add_child(right)
	_build_stats(right)
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 12)
	right.add_child(middle)
	_card(middle, "AGENDA", _agenda, "AgendaCard")
	_card(middle, "PRÓXIMOS PASSOS", _steps, "StepsCard")
	_build_last_week(right)
	_build_actions(column)
	_message.name = "MessageLabel"
	_message.theme_type_variation = &"MessageLabel"
	column.add_child(_message)
	super()


func refresh() -> void:
	var career := GameManager.career
	var progression := GameManager.progression
	var characters := GameManager.characters
	var streaming := GameManager.streaming
	_character.appearance = career.appearance
	_name.text = career.artist_name
	_identity.text = "%d anos  •  %s" % [characters.current_age(career), characters.location_label(career.country, career.city)]
	var stage := progression.stage_for(career.fame)
	var following := progression.next_stage(career.fame)
	_stage.text = stage.display_name
	_stage.tooltip_text = stage.description
	_stage_bar.value = progression.stage_progress(career.fame) * 100.0
	_stage_hint.text = "Faltam %s de fama para %s" % [Fmt.number(following.min_fame - career.fame), following.display_name] if following != null else "Topo da carreira: você é uma estrela."
	var report := career.last_report()
	_set_stat("fans", Fmt.number(streaming.total_followers(career)), _change_text(report.fans_change if report != null else 0))
	_set_stat("listeners", Fmt.number(streaming.total_listeners(career)), "nas plataformas")
	_set_stat("plays", Fmt.number(report.plays if report != null else 0), "na última semana")
	_set_stat("reputation", Fmt.signed_number(career.reputation), "lançamentos e shows")
	_fill_agenda(career)
	_fill_steps(career)
	_fill_last_week(report)


# ---- montagem

func _build_hero(body: HBoxContainer) -> void:
	var hero := PanelContainer.new()
	hero.name = "HeroCard"
	hero.theme_type_variation = &"HeroPanel"
	hero.custom_minimum_size = Vector2(290, 0)
	body.add_child(hero)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	hero.add_child(column)
	_character.name = "HubCharacter"
	_character.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_character.custom_minimum_size = Vector2(0, 200)
	column.add_child(_character)
	_name.name = "ArtistLabel"
	_name.theme_type_variation = &"HeaderLabel"
	_name.add_theme_font_size_override("font_size", 24)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.max_lines_visible = 2
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_name)
	_identity.name = "IdentityLabel"
	_identity.theme_type_variation = &"MutedLabel"
	_identity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_identity)
	var stage_row := CenterContainer.new()
	column.add_child(stage_row)
	_stage.name = "StageLabel"
	_stage.theme_type_variation = &"StageLabel"
	_stage.mouse_filter = Control.MOUSE_FILTER_PASS
	stage_row.add_child(_stage)
	_stage_bar.name = "StageProgress"
	_stage_bar.theme_type_variation = &"StageBar"
	_stage_bar.show_percentage = false
	_stage_bar.custom_minimum_size = Vector2(0, 10)
	column.add_child(_stage_bar)
	_stage_hint.name = "StageHint"
	_stage_hint.theme_type_variation = &"MutedLabel"
	_stage_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_stage_hint)
	var customize := Button.new()
	customize.name = "CustomizeButton"
	customize.text = "Personalizar"
	customize.icon = load("res://assets/icons/character.svg")
	customize.pressed.connect(navigate.bind(Screen.CHARACTER))
	column.add_child(customize)


func _build_stats(parent: Container) -> void:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	parent.add_child(grid)
	for item in [["fans", "FÃS", "fans", "#a25cff"], ["listeners", "OUVINTES", "platforms", "#4fa3ff"],
			["plays", "STREAMS", "music", "#46d483"], ["reputation", "REPUTAÇÃO", "reputation", "#ff7a9a"]]:
		var card := PanelContainer.new()
		card.name = "Stat_" + item[0]
		card.theme_type_variation = &"Card"
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		card.add_child(box)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 6)
		box.add_child(top)
		var icon := TextureRect.new()
		icon.texture = load("res://assets/icons/%s.svg" % item[2])
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(16, 16)
		icon.modulate = Color(item[3])
		top.add_child(icon)
		var caption := Label.new()
		caption.text = item[1]
		caption.theme_type_variation = &"SectionLabel"
		top.add_child(caption)
		var value := Label.new()
		value.theme_type_variation = &"StatValue"
		box.add_child(value)
		var detail := Label.new()
		detail.theme_type_variation = &"StatCaption"
		detail.clip_text = true
		detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		box.add_child(detail)
		_stats[item[0]] = [value, detail]


func _card(parent: Container, title: String, list: VBoxContainer, node_name: String) -> void:
	var card := PanelContainer.new()
	card.name = node_name
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)
	var header := Label.new()
	header.text = title
	header.theme_type_variation = &"SectionLabel"
	column.add_child(header)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)


func _build_last_week(parent: Container) -> void:
	var card := PanelContainer.new()
	card.name = "LastWeekCard"
	card.theme_type_variation = &"Card"
	parent.add_child(card)
	var row := HBoxContainer.new()
	card.add_child(row)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	row.add_child(texts)
	_week_title.theme_type_variation = &"SectionLabel"
	texts.add_child(_week_title)
	_week_summary.name = "WeekSummary"
	_week_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(_week_summary)
	var open := Button.new()
	open.name = "OpenReportButton"
	open.text = "Ver relatório"
	open.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	open.pressed.connect(func() -> void:
		if GameManager.career.last_report() != null:
			navigate(Screen.WEEK_REPORT))
	row.add_child(open)


func _build_actions(parent: Container) -> void:
	var row := HBoxContainer.new()
	row.name = "QuickActions"
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	for item in [["Nova música", "plus", Screen.SONG_EDITOR, {}, true, "QuickNewSong"], ["Lançar", "release", Screen.RELEASES, {}, false, "QuickRelease"],
			["Marketing", "marketing", Screen.MARKETING_HUB, {}, false, "QuickMarketing"], ["Shows e ofertas", "mic", Screen.LIVE, {"tab": 1}, false, "QuickLive"],
			["Trabalhar", "work", Screen.WORK, {}, false, "QuickWork"]]:
		var button := Button.new()
		button.name = item[5]
		button.text = item[0]
		button.icon = load("res://assets/icons/%s.svg" % item[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if item[4]:
			button.theme_type_variation = &"PrimaryButton"
		button.pressed.connect(navigate.bind(item[2], item[3]))
		row.add_child(button)


# ---- dados

func _set_stat(key: String, value: String, detail: String) -> void:
	_stats[key][0].text = value
	_stats[key][1].text = detail


func _change_text(change: int) -> String:
	if change == 0:
		return "estável na semana"
	return "%s na semana" % Fmt.signed_number(change)


func _fill_agenda(career: CareerData) -> void:
	_clear(_agenda)
	var items := GameManager.progression.agenda(career)
	if items.is_empty():
		_line(_agenda, "Nada marcado. Agende um lançamento, um show ou uma turnê para movimentar a carreira.", true)
		return
	for item in items.slice(0, 8):
		var weeks: int = item["week"] - career.current_week
		var when := "Agora" if weeks <= 0 else ("Próx. semana" if weeks == 1 else "Em %d semanas" % weeks)
		_line(_agenda, "%s  —  %s" % [when, item["text"]], false)


func _fill_steps(career: CareerData) -> void:
	_clear(_steps)
	for step in GameManager.progression.next_steps(career):
		_line(_steps, "•  " + step, false)


func _fill_last_week(report: WeekReport) -> void:
	if report == null:
		_week_title.text = "SUA CARREIRA COMEÇA AGORA"
		_week_summary.text = "Quando você avançar a semana, o resumo do que aconteceu aparece aqui."
		return
	_week_title.text = "SEMANA %s" % Fmt.number(report.week)
	var parts := PackedStringArray([
		"Dinheiro %s" % Fmt.signed_money(report.money_change), "Fama %s" % Fmt.signed_number(report.fame_change),
		"Fãs %s" % Fmt.signed_number(report.fans_change), "%s streams" % Fmt.number(report.plays)])
	var top := _top_entry(report)
	_week_summary.text = "  •  ".join(parts) + ("\nDestaque: %s" % top if not top.is_empty() else "")


func _top_entry(report: WeekReport) -> String:
	var best: WeekReportEntry = null
	for entry in report.entries:
		if entry.streams > 0 and (best == null or entry.streams > best.streams):
			best = entry
	return "%s (%s streams)" % [best.title, Fmt.number(best.streams)] if best != null else ""


func _line(list: VBoxContainer, text: String, muted: bool) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if muted:
		label.theme_type_variation = &"MutedLabel"
	list.add_child(label)


func _clear(list: Container) -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
