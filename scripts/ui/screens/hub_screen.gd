extends Screen
## Início: "esta é a minha carreira". À esquerda, o artista no palco com nome, fase, progresso e
## o carro; à direita, o próximo passo, três atalhos com contexto e, embaixo, a agenda e o
## resultado da última semana. Os números do dia a dia ficam na barra superior, não aqui.

const STAGE_LIGHTS := ["#8c86a0", "#2ec4b6", "#a25cff", "#4fa3ff", "#f5b82e", "#ff5ea8"]
const KIND_ICONS := {"release": "release", "show": "mic", "video": "video", "marketing": "marketing", "tour": "tour"}
const ACTION_SCREENS := {
	"new_song": [Screen.SONG_EDITOR, {}], "releases": [Screen.RELEASES, {}], "offers": [Screen.LIVE, {"tab": 1}],
	"marketing": [Screen.MARKETING_HUB, {}], "merch": [Screen.LIVE, {"tab": 4}], "work": [Screen.WORK, {}],
	"social": [Screen.SOCIAL, {}],
}

var _backdrop := StageBackdrop.new()
var _character := CharacterView.new()
var _week_kicker := Label.new()
var _stage := Label.new()
var _name := Label.new()
var _identity := Label.new()
var _stage_bar := ProgressBar.new()
var _stage_hint := Label.new()
var _car := PanelContainer.new()
var _car_photo := TextureRect.new()
var _car_name := Label.new()
var _focus_text := Label.new()
var _focus_button := Button.new()
var _more_steps := VBoxContainer.new()
var _tiles: Dictionary[String, Button] = {}
var _tile_hints: Dictionary[String, Label] = {}
var _agenda := VBoxContainer.new()
var _week_title := Label.new()
var _week_values := GridContainer.new()
var _message := Label.new()


func _ready() -> void:
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	add_child(body)
	_build_hero(body)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.25
	right.add_theme_constant_override("separation", 16)
	body.add_child(right)
	_build_focus(right)
	_build_tiles(right)
	var bottom := HBoxContainer.new()
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom.add_theme_constant_override("separation", 16)
	right.add_child(bottom)
	_build_agenda(bottom)
	_build_week(bottom)
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
	_week_kicker.text = "SEMANA %s" % Fmt.number(career.current_week)
	_name.text = career.artist_name
	_stage.text = stage.display_name.to_upper()
	_stage.tooltip_text = stage.description
	_identity.text = "%d anos  •  %s" % [GameManager.characters.current_age(career), GameManager.characters.location_label(career.country, career.city)]
	_stage_bar.value = progression.stage_progress(career.fame) * 100.0
	_stage_hint.text = "Rumo a %s: faltam %s de fama" % [following.display_name, Fmt.number(following.min_fame - career.fame)] if following != null else "Você chegou ao topo."
	var garage := GameManager.vehicles.garage(career)
	_car.visible = not garage.is_empty()
	if not garage.is_empty():
		_car_photo.texture = garage[0].image
		_car_name.text = garage[0].display_name() + ("  +%d" % (garage.size() - 1) if garage.size() > 1 else "")
	_fill_focus(career)
	_fill_tiles(career)
	_fill_agenda(career)
	_fill_week(career.last_report())


# ---- montagem

## O artista no palco: holofote na cor da fase, personagem grande e, sobre o chão, nome e progresso.
func _build_hero(body: HBoxContainer) -> void:
	var hero := PanelContainer.new()
	hero.name = "Stage"
	hero.theme_type_variation = &"StagePanel"
	hero.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	hero.custom_minimum_size = Vector2(400, 0)
	hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(hero)
	var holder := Control.new()
	hero.add_child(holder)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.floor_ratio = 0.66
	holder.add_child(_backdrop)
	_character.name = "HubCharacter"
	_character.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_character.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_character.anchor_bottom = 0.69
	_character.offset_top = 46
	holder.add_child(_character)
	# Escurece o pé do palco para o texto ler bem sobre a luz.
	var fade := TextureRect.new()
	fade.texture = _vertical_fade()
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.anchor_top = 0.5
	holder.add_child(fade)
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 20
	top.offset_top = 16
	top.offset_right = -16
	holder.add_child(top)
	_week_kicker.name = "WeekKicker"
	_week_kicker.theme_type_variation = &"Kicker"
	_week_kicker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_week_kicker)
	var customize := Button.new()
	customize.name = "CustomizeButton"
	customize.icon = load("res://assets/icons/character.svg")
	customize.text = "Visual"
	customize.tooltip_text = "Mudar a aparência do personagem"
	customize.theme_type_variation = &"ChipButton"
	customize.focus_mode = Control.FOCUS_NONE
	customize.pressed.connect(navigate.bind(Screen.CHARACTER))
	top.add_child(customize)
	var info := VBoxContainer.new()
	info.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	info.offset_left = 24
	info.offset_right = -24
	info.offset_bottom = -20
	info.grow_vertical = Control.GROW_DIRECTION_BEGIN
	info.add_theme_constant_override("separation", 4)
	holder.add_child(info)
	_stage.name = "StageLabel"
	_stage.theme_type_variation = &"Kicker"
	_stage.mouse_filter = Control.MOUSE_FILTER_PASS
	info.add_child(_stage)
	_name.name = "ArtistLabel"
	_name.theme_type_variation = &"HeroTitle"
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.max_lines_visible = 2
	info.add_child(_name)
	_identity.name = "IdentityLabel"
	_identity.theme_type_variation = &"MutedLabel"
	info.add_child(_identity)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	info.add_child(gap)
	var progress := HBoxContainer.new()
	progress.add_theme_constant_override("separation", 14)
	info.add_child(progress)
	var bars := VBoxContainer.new()
	bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bars.size_flags_vertical = Control.SIZE_SHRINK_END
	bars.add_theme_constant_override("separation", 6)
	progress.add_child(bars)
	_stage_bar.name = "StageProgress"
	_stage_bar.theme_type_variation = &"StageBar"
	_stage_bar.show_percentage = false
	_stage_bar.custom_minimum_size = Vector2(0, 8)
	bars.add_child(_stage_bar)
	_stage_hint.name = "StageHint"
	_stage_hint.theme_type_variation = &"StatCaption"
	bars.add_child(_stage_hint)
	# O carro mais recente, como um detalhe do estilo de vida.
	_car.name = "HubCarCard"
	_car.theme_type_variation = &"GlassPanel"
	_car.add_theme_stylebox_override("panel", _car_style())
	_car.tooltip_text = "Sua garagem"
	progress.add_child(_car)
	var car_row := HBoxContainer.new()
	car_row.name = "HubCar"
	car_row.add_theme_constant_override("separation", 8)
	_car.add_child(car_row)
	_car_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_car_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_car_photo.custom_minimum_size = Vector2(72, 40)
	_car_photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	car_row.add_child(_car_photo)
	_car_name.theme_type_variation = &"StatCaption"
	_car_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_car_name.custom_minimum_size = Vector2(90, 0)
	_car_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	car_row.add_child(_car_name)


func _car_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.06)
	style.border_color = Color(1, 1, 1, 0.1)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(6)
	return style


func _vertical_fade() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.05, 0.04, 0.08, 0.0))
	gradient.set_color(1, Color(0.05, 0.04, 0.08, 0.92))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 8
	texture.height = 128
	return texture


func _card(parent: Container, kicker: String, variation: StringName, node_name: String) -> VBoxContainer:
	var card := PanelContainer.new()
	card.name = node_name
	card.theme_type_variation = variation
	parent.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	card.add_child(column)
	var header := Label.new()
	header.text = kicker
	header.theme_type_variation = &"Kicker" if variation == &"HeroPanel" else &"SectionLabel"
	column.add_child(header)
	return column


func _build_focus(parent: Container) -> void:
	var column := _card(parent, "PRÓXIMO PASSO", &"HeroPanel", "FocusCard")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	column.add_child(row)
	_focus_text.name = "FocusText"
	_focus_text.theme_type_variation = &"ChipLabel"
	_focus_text.add_theme_font_size_override("font_size", 21)
	_focus_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_focus_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_focus_text)
	_focus_button.name = "FocusButton"
	_focus_button.theme_type_variation = &"PrimaryButton"
	_focus_button.icon = load("res://assets/icons/next.svg")
	_focus_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_focus_button)
	_more_steps.name = "MoreSteps"
	_more_steps.add_theme_constant_override("separation", 2)
	column.add_child(_more_steps)


## Atalhos: o que é, o estado atual e a ação, sem precisar abrir a área para descobrir.
func _build_tiles(parent: Container) -> void:
	var row := HBoxContainer.new()
	row.name = "QuickActions"
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	for spec: Array in [["song", "plus", "Nova música", Screen.SONG_EDITOR, {}], ["release", "release", "Lançamentos", Screen.RELEASES, {}],
			["offers", "mic", "Ofertas de show", Screen.LIVE, {"tab": 1}]]:
		var tile := Button.new()
		tile.name = "Tile_%s" % spec[0]
		tile.theme_type_variation = &"ActionTile"
		tile.icon = load("res://assets/icons/%s.svg" % spec[1])
		tile.text = spec[2]
		tile.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tile.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		tile.custom_minimum_size = Vector2(0, 74)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.focus_mode = Control.FOCUS_NONE
		tile.pressed.connect(navigate.bind(spec[3], spec[4]))
		_lift_on_hover(tile)
		row.add_child(tile)
		var hint := Label.new()
		hint.theme_type_variation = &"StatCaption"
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		hint.offset_left = 48
		hint.offset_bottom = -12
		hint.offset_top = -30
		hint.clip_text = true
		hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tile.add_child(hint)
		_tiles[spec[0]] = tile
		_tile_hints[spec[0]] = hint


func _lift_on_hover(control: Control) -> void:
	control.resized.connect(func() -> void: control.pivot_offset = control.size / 2.0)
	for on in [true, false]:
		(control.mouse_entered if on else control.mouse_exited).connect(func() -> void:
			control.create_tween().tween_property(control, "scale", Vector2.ONE * (1.025 if on else 1.0), 0.12).set_trans(Tween.TRANS_QUAD))


func _build_agenda(parent: Container) -> void:
	var column := _card(parent, "AGENDA", &"Card", "AgendaCard")
	column.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.get_parent().size_flags_stretch_ratio = 1.4
	_agenda.name = "AgendaList"
	_agenda.add_theme_constant_override("separation", 10)
	column.add_child(_agenda)


func _build_week(parent: Container) -> void:
	var card := PanelContainer.new()
	card.name = "LastWeekCard"
	card.theme_type_variation = &"Card"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	card.add_child(column)
	_week_title.theme_type_variation = &"SectionLabel"
	column.add_child(_week_title)
	_week_values.name = "WeekValues"
	_week_values.columns = 2
	_week_values.add_theme_constant_override("h_separation", 20)
	_week_values.add_theme_constant_override("v_separation", 12)
	_week_values.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_week_values)
	var open := Button.new()
	open.name = "OpenReportButton"
	open.text = "Relatório da semana"
	open.theme_type_variation = &"ChipButton"
	open.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	open.pressed.connect(func() -> void:
		if GameManager.career.last_report() != null:
			navigate(Screen.WEEK_REPORT))
	column.add_child(open)


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
	# Só mais uma dica: o resto fica nas áreas, para o Início não virar uma lista de tarefas.
	for item in steps:
		if item != main and _more_steps.get_child_count() < 1:
			var label := Label.new()
			label.text = "Depois: " + item["text"]
			label.theme_type_variation = &"MutedLabel"
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_more_steps.add_child(label)


func _fill_tiles(career: CareerData) -> void:
	var unreleased := 0
	for song in career.songs:
		unreleased += 0 if song.is_released() else 1
	var offers := GameManager.live.shows_with_status(career, LiveShow.STATUS_OFFER).size()
	_tile_hints["song"].text = "Compor e gravar"
	_tile_hints["release"].text = "%d pronta(s) para lançar" % unreleased if unreleased > 0 else "Nada inédito agora"
	_tile_hints["offers"].text = "%d esperando resposta" % offers if offers > 0 else "Nenhuma proposta nova"


func _fill_agenda(career: CareerData) -> void:
	_clear(_agenda)
	var items := GameManager.progression.agenda(career)
	if items.is_empty():
		var empty := Label.new()
		empty.text = "Nada marcado. Lançamentos, shows e turnês aparecem aqui."
		empty.theme_type_variation = &"MutedLabel"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_agenda.add_child(empty)
		return
	for item in items.slice(0, 3):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var weeks: int = item["week"] - career.current_week
		var when := Label.new()
		when.text = "AGORA" if weeks <= 0 else ("+1 SEM" if weeks == 1 else "+%d SEM" % weeks)
		when.theme_type_variation = &"Kicker"
		when.custom_minimum_size = Vector2(62, 0)
		row.add_child(when)
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
		_agenda.add_child(row)
	if items.size() > 3:
		var more := Label.new()
		more.text = "+ %d compromisso(s)" % (items.size() - 3)
		more.theme_type_variation = &"MutedLabel"
		_agenda.add_child(more)


func _fill_week(report: WeekReport) -> void:
	_clear(_week_values)
	if report == null:
		_week_title.text = "SUA CARREIRA COMEÇA AGORA"
		var hint := Label.new()
		hint.text = "Avance a semana para ver os primeiros resultados."
		hint.theme_type_variation = &"MutedLabel"
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size = Vector2(160, 0)
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
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
