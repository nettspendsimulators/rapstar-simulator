class_name StageBackdrop
extends Control
## Palco do personagem: holofote vindo de cima, brilho de fundo e sombra no chão.
## A cor da luz acompanha a fase da carreira.

var light: Color = Color("#a25cff"):
	set(value):
		light = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	var center := Vector2(w / 2.0, h * 0.5)
	# Brilho de fundo em camadas, do mais largo ao mais forte.
	for i in 10:
		var t := float(i) / 10.0
		var radius := lerpf(w * 0.62, w * 0.12, t)
		draw_circle(center, radius, Color(light, 0.035))
	# Cone de luz de cima até o chão.
	var floor_y := h * 0.7
	var cone := PackedVector2Array([Vector2(w * 0.44, 0), Vector2(w * 0.56, 0), Vector2(w * 0.86, floor_y), Vector2(w * 0.14, floor_y)])
	draw_colored_polygon(cone, Color(light.lightened(0.4), 0.07))
	# Chão iluminado e sombra.
	_ellipse(Vector2(w / 2.0, floor_y), Vector2(w * 0.36, h * 0.035), Color(light, 0.22))
	_ellipse(Vector2(w / 2.0, floor_y), Vector2(w * 0.2, h * 0.018), Color(0, 0, 0, 0.45))


func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 40:
		var angle := TAU * i / 40.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)
