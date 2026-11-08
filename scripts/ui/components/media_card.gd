class_name MediaCard
extends Button
## Cartão com capa grande, título, uma linha de apoio e um selo de estado.
## Mostra só o essencial; os detalhes ficam na tela do item.

const COVER := 150.0

var value: Variant
var _cover := TextureRect.new()
var _title := Label.new()
var _subtitle := Label.new()
var _badge := Label.new()
var _corner := Label.new()


func setup(card_value: Variant, title: String, subtitle: String, cover: Texture2D, badge: String = "", badge_color: Color = Color.TRANSPARENT, corner: String = "") -> MediaCard:
	value = card_value
	theme_type_variation = &"MediaCard"
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(COVER + 24, COVER + 104)
	clip_contents = false
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 12
	column.offset_top = 12
	column.offset_right = -12
	column.offset_bottom = -10
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	var art := Control.new()
	art.custom_minimum_size = Vector2(COVER, COVER)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(art)
	_cover.texture = cover
	_cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(_cover)
	if not corner.is_empty():
		_corner.text = corner
		_corner.theme_type_variation = &"BadgeLabel"
		_corner.position = Vector2(8, 8)
		_corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.add_child(_corner)
	_title.text = title
	_title.name = "CardTitle"
	_title.theme_type_variation = &"ChipLabel"
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.tooltip_text = title
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_title)
	_subtitle.text = subtitle
	_subtitle.theme_type_variation = &"MutedLabel"
	_subtitle.clip_text = true
	_subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_subtitle)
	if not badge.is_empty():
		_badge.text = badge
		_badge.theme_type_variation = &"StatCaption"
		_badge.add_theme_color_override("font_color", badge_color if badge_color != Color.TRANSPARENT else DataTable.cell_color(badge))
		_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(_badge)
	tooltip_text = title
	mouse_entered.connect(_hover.bind(true))
	mouse_exited.connect(_hover.bind(false))
	resized.connect(func() -> void: pivot_offset = size / 2.0)
	return self


func _hover(on: bool) -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * (1.03 if on else 1.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func badge_text() -> String:
	return _badge.text
