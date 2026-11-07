extends Screen

const COVER_SIZE := 40


func _ready() -> void:
	%ContinueButton.pressed.connect(navigate.bind(Screen.HUB))
	super()


func refresh() -> void:
	var report := GameManager.career.last_report()
	%Title.text = "RELATÓRIO DA SEMANA %s" % Fmt.number(report.week)
	var body: RichTextLabel = %Body
	body.clear()
	if report.entries.is_empty():
		body.add_text("Nada aconteceu nesta semana.\n")
	# add_text evita que nomes digitados pelo jogador sejam lidos como BBCode.
	for entry in report.entries:
		var cover := GameManager.covers.get_texture(entry.cover_file)
		if cover != null:
			body.add_image(cover, COVER_SIZE, COVER_SIZE)
			body.add_text("  ")
		body.push_bold()
		body.add_text(entry.title + "\n")
		body.pop()
		for line in _entry_lines(entry):
			body.add_text("  •  %s\n" % line)
		body.add_text("\n")
	%MoneyTotal.text = "Dinheiro recebido: %s" % Fmt.money(report.total_money())
	%FameTotal.text = "Fama recebida: %s" % Fmt.signed_number(report.total_fame())


func _entry_lines(entry: WeekReportEntry) -> PackedStringArray:
	var lines := PackedStringArray()
	if not entry.note.is_empty():
		lines.append(entry.note)
	if entry.streams > 0:
		lines.append("%s streams" % Fmt.number(entry.streams))
	if entry.sales > 0:
		lines.append("%s vendas" % Fmt.number(entry.sales))
	if entry.money != 0:
		lines.append(Fmt.signed_money(entry.money))
	if entry.fame > 0:
		lines.append("%s fama" % Fmt.number(entry.fame))
	return lines
