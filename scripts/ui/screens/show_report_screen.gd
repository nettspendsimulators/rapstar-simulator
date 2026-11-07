extends Screen
## Relatório de um show realizado. context: show_id e, opcionalmente, tour_id (para voltar à turnê).

const COST_LABELS := {
	"rent": "Aluguel do local", "production": "Produção", "addons": "Personalizações", "crew": "Equipe",
	"guests": "Convidados", "travel": "Transporte", "lodging": "Hospedagem", "food": "Alimentação",
	"security": "Segurança", "promotion": "Divulgação",
}


func _ready() -> void:
	var career := GameManager.career
	var live := GameManager.live
	var show := career.find_live_show(context.get("show_id", ""))
	var r := show.result
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = "Relatório: %s" % (show.event_name if not show.event_name.is_empty() else show.venue_name)
	column.add_child(title)
	var info := Label.new()
	info.text = "%s • %s • %s" % [show.venue_name, live.day_label(show.day), live.terms_text(show)]
	column.add_child(info)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	column.add_child(columns)
	_panel(columns, "PÚBLICO E REPERCUSSÃO", [
		"Público: %s de %s lugares" % [Fmt.number(r.get("attendance", 0)), Fmt.number(r.get("capacity", show.capacity))],
		"Ocupação: %d%%" % int(r.get("occupancy", 0)),
		"Ingressos vendidos: %s + %s VIP" % [Fmt.number(r.get("sold", 0)), Fmt.number(r.get("vip_sold", 0))],
		"Qualidade do show: %d/100" % int(r.get("quality", 0)),
		"Repercussão: %s" % r.get("buzz_label", "—"),
		"Novos fãs: %s" % Fmt.number(r.get("new_fans", 0)),
		"Fama: %s" % Fmt.signed_number(r.get("fame", 0)),
		"Reputação: %s" % Fmt.signed_number(r.get("reputation", 0)),
		"Desgaste: %d/100" % int(r.get("fatigue", 0)),
	])
	_panel(columns, "RECEITAS", [
		"Bilheteria bruta: %s" % Fmt.money(r.get("gross", 0)),
		"Taxas: -%s" % Fmt.money(r.get("ticket_fees", 0)),
		"Bilheteria líquida: %s" % Fmt.money(r.get("net_box", 0)),
		"Receita do artista: %s" % Fmt.money(r.get("income", 0)),
		"Parte do co-headliner: -%s" % Fmt.money(r.get("co_share", 0)),
		"Comissão: -%s" % Fmt.money(r.get("commission", 0)),
		"Merch: %s itens, %s líquidos" % [Fmt.number(r.get("merch_units", 0)), Fmt.money(r.get("merch_net", 0))],
	])
	var costs := PackedStringArray()
	var expenses: Dictionary = r.get("expenses", {})
	for key: String in COST_LABELS:
		if int(expenses.get(key, 0)) > 0:
			costs.append("%s: %s" % [COST_LABELS[key], Fmt.money(expenses[key])])
	costs.append("Total pago: %s" % Fmt.money(r.get("total_expenses", 0)))
	costs.append("")
	costs.append("RESULTADO: %s" % Fmt.signed_money(r.get("profit", 0)))
	_panel(columns, "DESPESAS", costs)
	var row := HBoxContainer.new()
	column.add_child(row)
	var back := Button.new()
	back.text = "Voltar"
	back.name = "BackButton"
	var tour_id: String = context.get("tour_id", "")
	if tour_id.is_empty():
		back.pressed.connect(navigate.bind(Screen.LIVE, {"tab": 5}))
	else:
		back.pressed.connect(navigate.bind(Screen.TOUR_EDITOR, {"tour_id": tour_id}))
	row.add_child(back)
	super()


func _panel(parent: Container, header: String, lines: Array) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	label.text = header + "\n\n" + "\n".join(PackedStringArray(lines))
	panel.add_child(label)
