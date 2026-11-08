class_name StatTile
extends PanelContainer
## Indicador em destaque: ícone, legenda curta, número grande e uma linha de contexto.
## Peça do design system para resumos (Finanças, Desempenho, relatórios).

var _icon := TextureRect.new()
var _caption := Label.new()
var _value := Label.new()
var _detail := Label.new()


func _init(caption: String = "", icon_name: String = "", accent: Color = Color("#f5b82e")) -> void:
	theme_type_variation = &"Card"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	column.add_child(head)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.custom_minimum_size = Vector2(16, 16)
	_icon.modulate = accent
	_icon.visible = not icon_name.is_empty()
	if not icon_name.is_empty():
		_icon.texture = load("res://assets/icons/%s.svg" % icon_name)
	head.add_child(_icon)
	_caption.text = caption.to_upper()
	_caption.theme_type_variation = &"SectionLabel"
	head.add_child(_caption)
	_value.name = "Value"
	_value.theme_type_variation = &"BigNumber"
	_value.clip_text = true
	_value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_value)
	_detail.name = "Detail"
	_detail.theme_type_variation = &"StatCaption"
	_detail.clip_text = true
	_detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(_detail)


## Atualiza o número; "tone" > 0 pinta de verde, < 0 de vermelho, 0 mantém a cor normal.
func set_value(value: String, detail: String = "", tone: int = 0) -> void:
	_value.text = value
	_value.tooltip_text = value
	_detail.text = detail
	_detail.visible = not detail.is_empty()
	if tone > 0:
		_value.add_theme_color_override("font_color", Color("#46d483"))
	elif tone < 0:
		_value.add_theme_color_override("font_color", Color("#ff5f6d"))
	else:
		_value.remove_theme_color_override("font_color")
