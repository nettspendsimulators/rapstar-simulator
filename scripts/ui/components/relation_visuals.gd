class_name RelationVisuals
extends RefCounted
## Cores e barra de uma relação, iguais em todas as telas.

const POSITIVE := Color("#a25cff")
const CLOSE := Color("#f5b82e")
const NEGATIVE := Color("#ff5f6d")
const UNKNOWN := Color("#8c86a0")


static func color(value: int, met: bool) -> Color:
	if not met:
		return UNKNOWN
	if value <= -15:
		return NEGATIVE
	return CLOSE if value >= 50 else POSITIVE


## Barra cheia para amizade forte ou rivalidade forte; vermelha quando a relação é negativa.
static func bar(value: int, met: bool) -> ProgressBar:
	var result := ProgressBar.new()
	result.show_percentage = false
	result.max_value = 100
	result.value = absi(value) if met else 0
	result.custom_minimum_size = Vector2(120, 8)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = color(value, met)
	fill.set_corner_radius_all(6)
	result.add_theme_stylebox_override("fill", fill)
	return result
