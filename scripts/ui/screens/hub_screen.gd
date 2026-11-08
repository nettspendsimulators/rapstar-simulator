extends Screen
## Início: o artista no palco, o próximo passo, o que vem por aí e como foi a semana.
## Os números do dia a dia (dinheiro, fama, fãs, energia) ficam na barra superior.

const STAGE_LIGHTS := ["#8c86a0", "#2ec4b6", "#a25cff", "#4fa3ff", "#f5b82e", "#ff5ea8"]
const KIND_ICONS := {"release": "release", "show": "mic", "video": "video", "marketing": "marketing", "tour": "tour"}
const ACTION_SCREENS := {
	"new_song": [Screen.SONG_EDITOR, {}], "releases": [Screen.RELEASES, {}], "offers": [Screen.LIVE, {"tab": 1}],
	"marketing": [Screen.MARKETING_HUB, {}], "merch": [Screen.LIVE, {"tab": 4}], "work": [Screen.WORK, {}],
	"social": [Screen.SOCIAL, {}],
}

var _backdrop := StageBackdrop.new()
var _character := CharacterView.new()
var _name := Label.new()
var _stage := Label.new()
var _week := Label.new()
var _stage_bar := ProgressBar.new()
var _stage_hint := Label.new()
var _car := HBoxContainer.new()
var _car_photo := TextureRect.new()
var _car_name := Label.new()
var _focus_text := Label.new()
var _focus_button := Button.new()
var _more_steps := VBoxContainer.new()
var _agenda := VBoxContainer.new()
var _week_title := Label.new()
var _week_values := HBoxContainer.new()
var _message := Label.new()


func _ready() -> void:
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	add_child(body)
	_build_stage(body)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 14)
	body.add_child(right)
	_build_focus(right)
	_build_agenda(right)
	_build_week(right)
	_message.name = "MessageLabel"
	_message.theme_type_variation = &"MessageLabel"
	right.add_child(_message)
	super()


func refresh() -> void:
	var career := GameManager.career
	var progression := GameManager.progression
	var index := progression.stage_index(career.fame)
	var stage := progression.stage_for(career.fame)
	var following := progression.next_stage(career.fame)
	_backdrop.light = Color(STAGE_LIGHTS[mini(index, STAGE_LIGHTS.size() - 1)])
	_character.appearance = career.appearance
	_name.text = career.artist_name
	_stage.text = stage.display_name
	_stage.tooltip_text = stage.description
	_week.text = "%d anos  •  %s" % [GameManager.characters.current_age(career), GameManager.characters.location_label(career.country, career.city)]
	_stage_bar.value = progression.stage_progress(career.fame) * 100.0
	_stage_hint.text = "Rumo a %s: faltam %s de fama" % [following.display_name, Fmt.number(following.min_fame - career.fame)] if following != null else "Você chegou ao topo."
	var garage := GameManager.vehicles.garage(career)
	_car.visible = not garage.is_empty()
	if not garage.is_empty():
		_car_photo.texture = garage[0].image
		_car_name.text = "Na garagem: %s%s" % [garage[0].display_name(), "  (+%d)" % (garage.size() - 1) if garage.size() > 1 else ""]
	_fill_focus(career)
	_fill_agenda(career)
	_fill_week(career.last_report())


# ---- montagem

func _build_stage(body: HBoxContainer) -> void:
	var stage := Control.new()
	stage.name = "Stage"
	stage.custom_minimum_size = Vector2(360, 0)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(stage)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(_backdrop)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 6)
	stage.add_child(column)
	_character.name = "HubCharacter"
	_character.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_character.custom_minimum_size = Vector2(0, 300)
	column.add_child(_character)
	_name.name = "ArtistLabel"
	_name.theme_type_variation = &"TitleLabel"
	_name.add_theme_font_size_override("font_size", 28)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.max_lines_visible = 2
	column.add_child(_name)
	var badges := HBoxContainer.new()
	badges.alignment = BoxContainer.ALIGNMENT_CENTER
	badges.add_theme_constant_override("separation", 8)
	column.add_child(badges)
	_stage.name = "StageLabel"
	_stage.theme_type_variation = &"StageLabel"
	_stage.mouse_filter = Control.MOUSE_FILTER_PASS
	badges.add_child(_stage)
	_week.name = "IdentityLabel"
	_week.theme_type_variation = &"MutedLabel"
	badges.add_child(_week)
	var bar_row := MarginContainer.new()
	bar_row.add_theme_constant_override("margin_left", 40)
	bar_row.add_theme_constant_override("margin_right", 40)
	bar_row.add_theme_constant_override("margin_top", 4)
	bar_row.add_theme_constant_override("margin_bottom", 0)
	column.add_child(bar_row)
	_stage_bar.name = "StageProgress"
	_stage_bar.theme_type_variation = &"StageBar"
	_stage_bar.show_percentage = false
	_stage_bar.custom_minimum_size = Vector2(0, 8)
	bar_row.add_child(_stage_bar)
	_stage_hint.name = "StageHint"
	_stage_hint.theme_type_variation = &"MutedLabel"
	_stage_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_stage_hint)
	# Último carro comprado, como um detalhe do estilo de vida do artista.
	_car.name = "HubCar"
	_car.alignment = BoxContainer.ALIGNMENT_CENTER
	_car.add_theme_constant_override("separation", 8)
	_car_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_car_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_car_photo.custom_minimum_size = Vector2(64, 36)
	_car.add_child(_car_photo)
	_car_name.theme_type_variation = &"MutedLabel"
	_car.add_child(_car_name)
	column.add_child(_car)
	var customize := Button.new()
	customize.name = "CustomizeButton"
	customize.text = "Personalizar visual"
	customize.icon = load("res://assets/icons/character.svg")
	customize.theme_type_variation = &"ChipButton"
	customize.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	customize.pressed.connect(navigate.bind(Screen.CHARACTER))
	column.add_child(customize)


func _section(parent: Container, title: String, variation: StringName, node_name: String) -> VBoxContainer:
	var card := PanelContainer.new()
	card.name = node_name
	card.theme_type_variation = variation
	parent.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	card.add_child(column)
	var header := Label.new()
	header.text = title
	header.theme_type_variation = &"SectionLabel"
	column.add_child(header)
	return column


func _build_focus(parent: Container) -> void:
	var column := _section(parent, "PRÓXIMO PASSO", &"HeroPanel", "FocusCard")
	_focus_text.name = "FocusText"
	_focus_text.theme_type_variation = &"ChipLabel"
	_focus_text.add_theme_font_size_override("font_size", 20)
	_focus_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_focus_text)
	var row := HBoxContainer.new()
	column.add_child(row)
	_focus_button.name = "FocusButton"
	_focus_button.theme_type_variation = &"PrimaryButton"
	_focus_button.icon = load("res://assets/icons/next.svg")
	_focus_button.custom_minimum_size = Vector2(220, 0)
	row.add_child(_focus_button)
	_more_steps.name = "MoreSteps"
	_more_steps.add_theme_constant_override("separation", 2)
	column.add_child(_more_steps)


func _build_agenda(parent: Container) -> void:
	var column := _section(parent, "AGENDA", &"Card", "AgendaCard")
	column.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	_agenda.name = "AgendaList"
	_agenda.add_theme_constant_override("separation", 8)
	column.add_child(_agenda)


func _build_week(parent: Container) -> void:
	var card := PanelContainer.new()
	card.name = "LastWeekCard"
	card.theme_type_variation = &"Card"
	parent.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	_week_title.theme_type_variation = &"SectionLabel"
	left.add_child(_week_title)
	_week_values.name = "WeekValues"
	_week_values.add_theme_constant_override("separation", 26)
	left.add_child(_week_values)
	var open := Button.new()
	open.name = "OpenReportButton"
	open.text = "Ver relatório"
	open.theme_type_variation = &"ChipButton"
	open.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	open.pressed.connect(func() -> void:
		if GameManager.career.last_report() != null:
			navigate(Screen.WEEK_REPORT))
	row.add_child(open)


# ---- dados

func _fill_focus(career: CareerData) -> void:
	var steps := GameManager.progression.actions(career)
	var main: Dictionary = steps[0]
	for item in steps:
		if not String(item["action"]).is_empty():
			main = item
			break
	_focus_text.text = main["text"]
	_focus_button.visible = not String(main["action"]).is_empty()
	_focus_button.text = main.get("label", "")
	for connection in _focus_button.pressed.get_connections():
		_focus_button.pressed.disconnect(connection["callable"])
	if _focus_button.visible:
		var target: Array = ACTION_SCREENS[main["action"]]
		_focus_button.pressed.connect(navigate.bind(target[0], target[1]))
	_clear(_more_steps)
	for item in steps:
		if item != main:
			var label := Label.new()
			label.text = "•  " + item["text"]
			label.theme_type_variation = &"MutedLabel"
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_more_steps.add_child(label)


func _fill_agenda(career: CareerData) -> void:
	_clear(_agenda)
	var items := GameManager.progression.agenda(career)
	if items.is_empty():
		var empty := Label.new()
		empty.text = "Nada marcado ainda. Lançamentos, shows e turnês aparecem aqui."
		empty.theme_type_variation = &"MutedLabel"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_agenda.add_child(empty)
		return
	for item in items.slice(0, 4):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var icon := TextureRect.new()
		icon.texture = load("res://assets/icons/%s.svg" % KIND_ICONS.get(item["kind"], "calendar"))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(18, 18)
		icon.modulate = Color("#a39eb4")
		row.add_child(icon)
		var text := Label.new()
		text.text = item["text"]
		text.clip_text = true
		text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.tooltip_text = item["text"]
		text.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(text)
		var weeks: int = item["week"] - career.current_week
		var when := Label.new()
		when.text = "agora" if weeks <= 0 else ("próx. semana" if weeks == 1 else "em %d semanas" % weeks)
		when.theme_type_variation = &"MutedLabel"
		row.add_child(when)
		_agenda.add_child(row)
	if items.size() > 4:
		var more := Label.new()
		more.text = "+ %d compromisso(s)" % (items.size() - 4)
		more.theme_type_variation = &"MutedLabel"
		_agenda.add_child(more)


func _fill_week(report: WeekReport) -> void:
	_clear(_week_values)
	if report == null:
		_week_title.text = "SUA CARREIRA COMEÇA AGORA"
		var hint := Label.new()
		hint.text = "Avance a semana para ver os primeiros resultados."
		hint.theme_type_variation = &"MutedLabel"
		_week_values.add_child(hint)
		return
	_week_title.text = "SEMANA %s" % Fmt.number(report.week)
	_metric(Fmt.signed_money(report.money_change), "dinheiro", report.money_change)
	_metric(Fmt.signed_number(report.fame_change), "fama", report.fame_change)
	_metric(Fmt.signed_number(report.fans_change), "fãs", report.fans_change)
	_metric(Fmt.number(report.plays), "streams", 0)


func _metric(value: String, caption: String, sign_value: int) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var number := Label.new()
	number.text = value
	number.theme_type_variation = &"StatValue"
	number.add_theme_font_size_override("font_size", 22)
	if sign_value > 0:
		number.add_theme_color_override("font_color", Color("#46d483"))
	elif sign_value < 0:
		number.add_theme_color_override("font_color", Color("#ff5f6d"))
	box.add_child(number)
	var label := Label.new()
	label.text = caption
	label.theme_type_variation = &"StatCaption"
	box.add_child(label)
	_week_values.add_child(box)


func _clear(node: Container) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
