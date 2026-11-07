extends Screen
## Entrada do Marketing na navegação principal: lista tudo que pode ser promovido.


func _ready() -> void:
	%ContentTable.set_headers(["Nome", "Tipo", "Nota", "Status", "Campanha", "Investido", "Expectativa"])
	%ContentTable.item_mouse_selected.connect(func(_position: Vector2, _button: int) -> void: _open_selected())
	%ContentTable.item_activated.connect(_open_selected)
	%BackButton.pressed.connect(navigate.bind(Screen.HUB))
	super()


func refresh() -> void:
	var career := GameManager.career
	%MoneyLabel.text = "Orçamento disponível: %s" % Fmt.money(career.money)
	%ContentTable.clear_rows()
	for content: ReleasableContent in career.songs + career.albums:
		var campaign := career.find_campaign(content.id)
		if content.is_released() and campaign == null:
			continue
		%ContentTable.add_row([
			content.title,
			GameManager.releases.content_type_label(content),
			content.quality,
			content.display_status(),
			campaign.status_label() if campaign != null else "—",
			Fmt.money(campaign.invested()) if campaign != null else "—",
			campaign.hype if campaign != null else "—",
		], content.id, content.cover_file)


## Adiado porque esta tela é trocada enquanto a tabela ainda trata o clique.
func _open_selected() -> void:
	var content_id: Variant = %ContentTable.selected_value()
	if content_id != null:
		navigate.call_deferred(Screen.MARKETING, {"content_id": content_id, "back": Screen.MARKETING_HUB})
