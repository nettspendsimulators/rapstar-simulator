class_name AppBackground
extends Control
## Fundo de todas as telas: gradiente escuro com luzes suaves, como um palco antes do show.
## A luz principal assume a cor da área aberta (set_accent), então cada área tem o seu clima.

var _key_light: TextureRect
var _accent_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer(_linear(Color("#17132a"), Color("#09080d")), Control.PRESET_FULL_RECT, Vector2.ZERO)
	_key_light = _glow(Color(1, 1, 1, 0.24), Vector2(0.78, -0.05), 0.75)
	_key_light.modulate = Color(0.48, 0.24, 1.0)
	_glow(Color(0.96, 0.72, 0.18, 0.10), Vector2(0.05, 1.05), 0.6)


func _linear(top: Color, bottom: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, top)
	gradient.set_color(1, bottom)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 64
	texture.height = 256
	return texture


## Troca a cor da luz principal com uma transição suave.
func set_accent(color: Color) -> void:
	if _key_light == null:
		return
	if _accent_tween != null:
		_accent_tween.kill()
	_accent_tween = create_tween()
	_accent_tween.tween_property(_key_light, "modulate", color, 0.6).set_trans(Tween.TRANS_SINE)


func _glow(color: Color, where: Vector2, radius: float) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 256
	texture.height = 256
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.anchor_left = where.x - radius
	rect.anchor_right = where.x + radius
	rect.anchor_top = where.y - radius * 1.2
	rect.anchor_bottom = where.y + radius * 1.2
	add_child(rect)
	return rect


func _layer(texture: Texture2D, preset: int, _offset: Vector2) -> void:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(preset)
	add_child(rect)
