class_name StageBackdrop
extends Control
## Palco do personagem: parede com brilho em camadas, holofote vindo de cima, feixes de luz,
## piso com reflexo e sombra no chão. A cor da luz acompanha a fase da carreira.

var light: Color = Color("#a25cff"):
	set(value):
		light = value
		queue_redraw()

## Altura do chão, em fração da altura do palco.
var floor_ratio: float = 0.7:
	set(value):
		floor_ratio = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	var floor_y := h * floor_ratio
	var center := Vector2(w / 2.0, floor_y * 0.55)
	# Brilho de fundo em camadas, do mais largo ao mais forte.
	for i in 12:
		var t := float(i) / 12.0
		var radius := lerpf(maxf(w, h) * 0.7, w * 0.1, t)
		draw_circle(center, radius, Color(light, 0.03))
	# Feixes laterais e o cone central.
	for side in [-1.0, 1.0]:
		var beam := PackedVector2Array([Vector2(w * (0.5 + side * 0.42), 0), Vector2(w * (0.5 + side * 0.36), 0),
			Vector2(w * (0.5 + side * 0.08), floor_y), Vector2(w * (0.5 + side * 0.22), floor_y)])
		draw_colored_polygon(beam, Color(light.lightened(0.3), 0.035))
	var cone := PackedVector2Array([Vector2(w * 0.43, 0), Vector2(w * 0.57, 0), Vector2(w * 0.88, floor_y), Vector2(w * 0.12, floor_y)])
	draw_colored_polygon(cone, Color(light.lightened(0.45), 0.07))
	# Piso: reflexo da luz e sombra.
	_ellipse(Vector2(w / 2.0, floor_y), Vector2(w * 0.4, maxf(h * 0.035, 10.0)), Color(light, 0.2))
	_ellipse(Vector2(w / 2.0, floor_y), Vector2(w * 0.24, maxf(h * 0.02, 6.0)), Color(light.lightened(0.3), 0.18))
	_ellipse(Vector2(w / 2.0, floor_y), Vector2(w * 0.18, maxf(h * 0.014, 4.0)), Color(0, 0, 0, 0.4))
	# Poeira na luz.
	for i in 18:
		var p := Vector2(w * (0.3 + fmod(i * 0.381, 0.4)), floor_y * fmod(i * 0.613, 0.9))
		draw_circle(p, 1.2 + fmod(i * 0.7, 1.5), Color(1, 1, 1, 0.05 + fmod(i * 0.13, 0.08)))


func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 40:
		var angle := TAU * i / 40.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)
