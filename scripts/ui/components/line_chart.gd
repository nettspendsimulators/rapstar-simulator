class_name LineChart
extends Control
## Gráfico simples de evolução semanal, usado na tela de desempenho.

const LINE_COLOR := Color(0.9, 0.66, 0.14, 1)
const AXIS_COLOR := Color(1, 1, 1, 0.15)
const TEXT_COLOR := Color(1, 1, 1, 0.55)
const PADDING := 8.0

var _values: Array[int] = []
var _title: String = ""


func show_values(title: String, values: Array[int]) -> void:
	_title = title
	_values = values
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var font_size := get_theme_default_font_size()
	var top := PADDING + font_size + 4.0
	var bottom := size.y - PADDING
	draw_string(font, Vector2(PADDING, PADDING + font_size), _title, HORIZONTAL_ALIGNMENT_LEFT, size.x - PADDING * 2.0, font_size, TEXT_COLOR)
	draw_line(Vector2(PADDING, bottom), Vector2(size.x - PADDING, bottom), AXIS_COLOR, 1.0)
	if _values.size() < 2:
		draw_string(font, Vector2(PADDING, (top + bottom + font_size) / 2.0), "Ainda sem histórico", HORIZONTAL_ALIGNMENT_CENTER, size.x - PADDING * 2.0, font_size, TEXT_COLOR)
		return
	var highest := 1
	for value in _values:
		highest = maxi(highest, value)
	var points := PackedVector2Array()
	for index in _values.size():
		var x := lerpf(PADDING, size.x - PADDING, float(index) / (_values.size() - 1))
		var y := lerpf(bottom, top, float(_values[index]) / highest)
		points.append(Vector2(x, y))
	draw_polyline(points, LINE_COLOR, 2.0, true)
	var peak_text := Fmt.number(highest)
	draw_string(font, Vector2(PADDING, PADDING + font_size), peak_text, HORIZONTAL_ALIGNMENT_RIGHT, size.x - PADDING * 2.0, font_size, TEXT_COLOR)
