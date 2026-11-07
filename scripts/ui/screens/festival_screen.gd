extends Screen
## Edição de um festival: identidade, condições e lineup completo por dia e palco.
## context: edition_id.

const FEE_MODELS := {"fixed": "Cachê fixo", "variable": "Cachê variável conforme o público", "covered": "Sem cachê, despesas pagas"}

var _edition: FestivalEdition
var _info := Label.new()
var _lineup := DataTable.new()
var _message := Label.new()
var _apply := Button.new()


func _ready() -> void:
	_edition = GameManager.career.find_edition(context.get("edition_id", ""))
	_info.name = "InfoLabel"
	_lineup.name = "LineupTable"
	_message.name = "MessageLabel"
	_apply.name = "ApplyButton"
	var festival := GameManager.balance.live.find_festival(_edition.festival_id)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = GameManager.festivals.edition_title(_edition)
	column.add_child(title)
	var panel := PanelContainer.new()
	column.add_child(panel)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_info)
	var header := Label.new()
	header.theme_type_variation = &"HeaderLabel"
	header.text = "Lineup"
	column.add_child(header)
	_lineup.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_lineup)
	_lineup.set_headers(["Artista", "Dia", "Palco", "Horário", "Duração", "Posição"])
	_message.theme_type_variation = &"MessageLabel"
	column.add_child(_message)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	var back := Button.new()
	back.text = "Voltar"
	back.name = "BackButton"
	back.pressed.connect(navigate.bind(Screen.LIVE, {"tab": 3}))
	row.add_child(back)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_apply.text = "Inscrever-se"
	_apply.theme_type_variation = &"PrimaryButton"
	_apply.pressed.connect(func() -> void: _message.text = GameManager.apply_to_festival(_edition.id).message)
	row.add_child(_apply)
	_info.set_meta("festival", festival)
	super()


func refresh() -> void:
	var career := GameManager.career
	var festivals := GameManager.festivals
	var festival: FestivalDefinition = _info.get_meta("festival")
	var relevance := festivals.relevance(career, festival)
	_info.text = "%s, %s • Gêneros: %s • Prestígio %d/100 • Público de até %s pessoas por dia\nPalcos: %s • Semana %s (%d dia(s)) • %s • Merch %s\nSua posição provável: %s%s" % [
		GameManager.live.city_label(festival.city_id), festival.country, festival.genres, festival.prestige,
		Fmt.number(festival.capacity), ", ".join(PackedStringArray(festival.stages)), Fmt.number(_edition.week), festival.days,
		FEE_MODELS.get(festival.fee_model, ""), "permitido" if festival.merch_allowed else "não permitido",
		LiveRules.POSITION_LABELS[festivals.position_for(relevance)],
		"" if career.fame >= festival.min_fame else " (fama mínima para tocar: %s)" % Fmt.number(festival.min_fame)]
	_lineup.clear_rows()
	var slots := _edition.lineup.duplicate()
	slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["day"] != b["day"]:
			return a["day"] < b["day"]
		if a["stage"] != b["stage"]:
			return festival.stages.find(a["stage"]) < festival.stages.find(b["stage"])
		return a["start"] < b["start"])
	for slot: Dictionary in slots:
		var you: bool = slot.get("artist_id", "") == FestivalEdition.PLAYER_ID
		_lineup.add_row(["%s%s" % [slot["name"], " (você)" if you else ""], "Dia %d" % int(slot["day"]), slot["stage"],
			festivals.time_label(int(slot["start"])), "%d min" % int(slot["minutes"]), LiveRules.POSITION_LABELS.get(slot["position"], "")])
	_apply.disabled = _edition.has_player() or _edition.application_status != FestivalEdition.APPLICATION_NONE
