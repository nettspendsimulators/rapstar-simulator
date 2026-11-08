extends Screen
## Relatório da semana: o balanço real (dinheiro, fama, fãs e streams), a nova fase da carreira
## quando houver, e um cartão para cada acontecimento.

const COVER_SIZE := 44

var _title := Label.new()
var _summary := GridContainer.new()
var _list := VBoxContainer.new()


func _ready() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	_title.name = "Title"
	_title.theme_type_variation = &"TitleLabel"
	column.add_child(_title)
	_summary.name = "Summary"
	_summary.columns = 4
	_summary.add_theme_constant_override("h_separation", 12)
	column.add_child(_summary)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_list.name = "Entries"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	var row := HBoxContainer.new()
	column.add_child(row)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var continue_button := Button.new()
	continue_button.name = "ContinueButton"
	continue_button.text = "CONTINUAR"
	continue_button.theme_type_variation = &"PrimaryButton"
	continue_button.custom_minimum_size = Vector2(240, 0)
	continue_button.pressed.connect(navigate.bind(Screen.HUB))
	row.add_child(continue_button)
	super()


func refresh() -> void:
	var report := GameManager.career.last_report()
	if report == null:
		_title.text = "Nenhuma semana jogada ainda"
		return
	_title.text = "Relatório da semana %s" % Fmt.number(report.week)
	_clear(_summary)
	_summary_card("DINHEIRO", Fmt.signed_money(report.money_change), report.money_change, "money", "saldo da semana, com ganhos e gastos")
	_summary_card("FAMA", Fmt.signed_number(report.fame_change), report.fame_change, "fame", "popularidade")
	_summary_card("FÃS", Fmt.signed_number(report.fans_change), report.fans_change, "fans", "seguidores e inscritos")
	_summary_card("STREAMS", Fmt.number(report.plays), 1 if report.plays > 0 else 0, "music", "reproduções nas plataformas")
	_clear(_list)
	if report.entries.is_empty():
		var empty := Label.new()
		empty.text = "Semana tranquila: nada de novo aconteceu."
		empty.theme_type_variation = &"MutedLabel"
		_list.add_child(empty)
	for entry in report.entries:
		_entry_card(entry, report)


func _summary_card(caption: String, value: String, sign_value: int, icon_name: String, detail: String) -> void:
	var card := PanelContainer.new()
	card.theme_type_variation = &"Card"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	card.add_child(box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	box.add_child(top)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/icons/%s.svg" % icon_name)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(16, 16)
	top.add_child(icon)
	var label := Label.new()
	label.text = caption
	label.theme_type_variation = &"SectionLabel"
	top.add_child(label)
	var number := Label.new()
	number.text = value
	number.theme_type_variation = &"StatValue"
	if sign_value > 0:
		number.add_theme_color_override("font_color", Color("#46d483"))
	elif sign_value < 0:
		number.add_theme_color_override("font_color", Color("#ff5f6d"))
	box.add_child(number)
	var note := Label.new()
	note.text = detail
	note.theme_type_variation = &"StatCaption"
	box.add_child(note)


func _entry_card(entry: WeekReportEntry, report: WeekReport) -> void:
	var card := PanelContainer.new()
	var milestone := entry.title.begins_with("Nova fase") or entry.title.begins_with("Turnê concluída")
	card.theme_type_variation = &"HeroPanel" if milestone else &"Card"
	_list.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var cover := GameManager.covers.get_texture(entry.cover_file)
	if cover != null:
		var image := TextureRect.new()
		image.texture = cover
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.custom_minimum_size = Vector2(COVER_SIZE, COVER_SIZE)
		row.add_child(image)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	row.add_child(texts)
	var title := Label.new()
	title.text = entry.title
	title.theme_type_variation = &"HeaderLabel" if milestone else &"ChipLabel"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(title)
	if not entry.note.is_empty():
		var note := Label.new()
		note.text = entry.note
		note.theme_type_variation = &"MutedLabel"
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texts.add_child(note)
	var chips := PackedStringArray()
	if entry.streams > 0:
		chips.append("%s streams" % Fmt.number(entry.streams))
	if entry.sales > 0:
		chips.append("%s vendas" % Fmt.number(entry.sales))
	if entry.fame > 0:
		chips.append("%s fama" % Fmt.signed_number(entry.fame))
	if not chips.is_empty():
		var line := Label.new()
		line.text = "  •  ".join(chips)
		texts.add_child(line)
	if entry.money != 0:
		var money := Label.new()
		money.text = Fmt.signed_money(entry.money)
		money.theme_type_variation = &"ChipLabel"
		money.add_theme_color_override("font_color", Color("#46d483") if entry.money > 0 else Color("#ff5f6d"))
		money.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(money)


func _clear(node: Container) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
