class_name LabelLogo
extends Control
## Logo de gravadora desenhado no jogo: formato, cores e sigla. Serve às gravadoras do jogo e à
## do jogador (que escolhe tudo na fundação).

var shape: String = "circle":
	set(value):
		shape = value
		queue_redraw()
var color: Color = Color("#f5b82e"):
	set(value):
		color = value
		queue_redraw()
var color2: Color = Color("#16131c"):
	set(value):
		color2 = value
		queue_redraw()
var text: String = "R":
	set(value):
		text = value
		queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup_from(label: LabelDefinition) -> LabelLogo:
	shape = label.shape
	color = label.color
	color2 = label.color2
	text = label.short
	return self


func setup_own(own: OwnLabel) -> LabelLogo:
	shape = own.shape
	color = own.color
	color2 = own.color2
	text = own.short
	return self


func _draw() -> void:
	var side := minf(size.x, size.y)
	if side <= 0.0:
		return
	var center := size / 2.0
	var radius := side * 0.46
	var outline := _points(center, radius)
	draw_colored_polygon(_points(center + Vector2(0, side * 0.04), radius), Color(0, 0, 0, 0.35))
	draw_colored_polygon(outline, color)
	# Brilho na metade de cima e anel interno: dá cara de selo impresso.
	var inner := _points(center, radius * 0.82)
	draw_polyline(_closed(inner), Color(color2, 0.5), maxf(side * 0.025, 1.0), true)
	draw_polyline(_closed(outline), color.darkened(0.45), maxf(side * 0.03, 1.0), true)
	var font := ThemeDB.fallback_font
	var font_size := int(side * (0.42 if text.length() <= 2 else (0.32 if text.length() == 3 else 0.25)))
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline := center + Vector2(-width / 2.0, font_size * 0.36)
	draw_string(font, baseline + Vector2(0, side * 0.015), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.3))
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color2)


func _points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	match shape:
		"hex":
			for i in 6:
				points.append(center + Vector2.from_angle(TAU * i / 6.0 + PI / 6.0) * radius)
		"diamond":
			for i in 4:
				points.append(center + Vector2.from_angle(TAU * i / 4.0) * radius)
		"square":
			var r := radius * 0.86
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				points.append(center + corner * r)
		"shield":
			var r := radius * 0.9
			points.append_array([center + Vector2(-r, -r), center + Vector2(r, -r), center + Vector2(r, r * 0.2),
				center + Vector2(0, r * 1.1), center + Vector2(-r, r * 0.2)])
		_:
			for i in 32:
				points.append(center + Vector2.from_angle(TAU * i / 32.0) * radius)
	return points


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var path := points.duplicate()
	path.append(points[0])
	return path
