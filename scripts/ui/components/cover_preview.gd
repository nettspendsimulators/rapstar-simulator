class_name CoverPreview
extends TextureRect
## Mostra uma capa, ou um quadro neutro quando não há capa.

const PLACEHOLDER_COLOR := Color(0.17, 0.185, 0.23, 1)
const PLACEHOLDER_TEXT_COLOR := Color(1, 1, 1, 0.45)


func _ready() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


## Sem imagem e com um nome, mostra a arte gerada para o nome (CoverArt).
func show_cover(file_name: String, seed_text: String = "") -> void:
	texture = GameManager.covers.get_texture(file_name)
	if texture == null and not seed_text.is_empty():
		texture = CoverArt.generated(seed_text)
	queue_redraw()


func _draw() -> void:
	if texture != null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), PLACEHOLDER_COLOR)
	# Em miniaturas o texto não caberia.
	if size.x < 80.0:
		return
	var font := get_theme_default_font()
	var font_size := get_theme_default_font_size()
	var baseline := Vector2(0, (size.y + font_size) / 2.0)
	draw_string(font, baseline, "Sem capa", HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, PLACEHOLDER_TEXT_COLOR)
