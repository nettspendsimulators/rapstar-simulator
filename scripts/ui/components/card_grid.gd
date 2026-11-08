class_name CardGrid
extends ScrollContainer
## Grade de MediaCard com rolagem, seleção de um cartão e entrada suave.

signal card_pressed(value: Variant)

var _flow := HFlowContainer.new()
var _selected: Variant = null
var _empty := Label.new()


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flow.add_theme_constant_override("h_separation", 14)
	_flow.add_theme_constant_override("v_separation", 14)
	add_child(_flow)
	_empty.theme_type_variation = &"MutedLabel"
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.visible = false
	_empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func clear_cards(empty_text: String = "") -> void:
	for child in _flow.get_children():
		_flow.remove_child(child)
		child.queue_free()
	_empty.text = empty_text
	_empty.visible = not empty_text.is_empty()
	if _empty.visible:
		_flow.add_child(_empty)


func add_card(value: Variant, title: String, subtitle: String, cover: Texture2D, badge: String = "", badge_color: Color = Color.TRANSPARENT, corner: String = "") -> MediaCard:
	if _empty.get_parent() == _flow:
		_flow.remove_child(_empty)
	var card := MediaCard.new().setup(value, title, subtitle, cover, badge, badge_color, corner)
	card.name = "Card%d" % _flow.get_child_count()
	card.button_pressed = value == _selected and value != null
	card.pressed.connect(_on_card_pressed.bind(card))
	# Entrada em sequência, curta para não atrasar o jogador.
	card.modulate.a = 0.0
	_flow.add_child(card)
	var tween := card.create_tween()
	tween.tween_interval(minf(_flow.get_child_count() * 0.025, 0.3))
	tween.tween_property(card, "modulate:a", 1.0, 0.18)
	return card


func card(index: int) -> MediaCard:
	var cards := cards()
	return cards[index] if index < cards.size() else null


func cards() -> Array[MediaCard]:
	var result: Array[MediaCard] = []
	for child in _flow.get_children():
		if child is MediaCard:
			result.append(child)
	return result


func selected_value() -> Variant:
	return _selected


func select_value(value: Variant) -> void:
	_selected = value
	for item in cards():
		item.set_pressed_no_signal(item.value == value)


func _on_card_pressed(pressed_card: MediaCard) -> void:
	select_value(pressed_card.value)
	card_pressed.emit(pressed_card.value)
