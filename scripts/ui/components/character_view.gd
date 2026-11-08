class_name CharacterView
extends Control
## Personagem ilustrado em camadas, no estilo "cartoon premium streetwear": formas suaves
## (curvas Catmull-Rom), contorno colorido, sombra e brilho recortados da própria forma (luz vindo
## de cima à esquerda) e detalhes de material em cada peça.
## Cada camada lê só a sua peça (estilo e cores de data/character.tres): peças novas com um estilo
## existente não mudam este script; um estilo novo é uma função de desenho nova.
## Coordenadas num quadro de 200 x 400. "focus" recorta uma região para miniaturas.

const BASE := Vector2(200, 400)
## Camadas de trás para a frente, com a faixa vertical (no quadro de 200 x 400) que cada uma ocupa.
const LAYERS := [
	["_draw_back_hair", 0, 170], ["_draw_hood_back", 100, 136], ["_draw_legs", 240, 392], ["_draw_shoes", 345, 392],
	["_draw_arms", 112, 262], ["_draw_top", 108, 262], ["_draw_jacket", 108, 264], ["_draw_hands", 236, 268],
	["_draw_neck", 88, 126], ["_draw_chain", 110, 172], ["_draw_head", 20, 110], ["_draw_face", 40, 100],
	["_draw_beard", 55, 136], ["_draw_front_hair", 0, 112], ["_draw_headwear", 0, 110], ["_draw_face_accessories", 50, 82],
	["_draw_watch", 228, 248],
]
## Direção oposta à luz: a sombra fica do lado de baixo/direita das formas.
const LIGHT := Vector2(-1.0, -0.8)

var appearance: CharacterAppearance:
	set(value):
		appearance = value
		queue_redraw()

## Região do corpo mostrada (chaves de CharacterLayout.FOCUS_RECTS); fora de "full", recorta.
var focus: String = "full":
	set(value):
		focus = value
		clip_contents = value != "full"
		queue_redraw()

var _opt: Dictionary = {}
var _skin: Color


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var region: Rect2 = CharacterLayout.FOCUS_RECTS.get(focus, CharacterLayout.FOCUS_RECTS["full"])
	var scale_factor := minf(size.x / region.size.x, size.y / region.size.y)
	if scale_factor <= 0.0:
		return
	var offset := (size - region.size * scale_factor) / 2.0 - region.position * scale_factor
	draw_set_transform(offset, 0.0, Vector2(scale_factor, scale_factor))
	_resolve()
	_skin = _color("skin")
	# Só desenha as camadas que aparecem na área visível (miniaturas recortam uma parte do corpo).
	var top := -offset.y / scale_factor
	var bottom := top + size.y / scale_factor
	if focus == "full":
		_draw_ground_shadow()
	for layer: Array in LAYERS:
		if top < layer[2] and bottom > layer[1]:
			call(layer[0])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---- peças escolhidas

func _resolve() -> void:
	_opt.clear()
	var characters: CharacterSystem = GameManager.characters
	for item: Dictionary in CharacterRules.CATEGORIES:
		var category: String = item["id"]
		if not CharacterRules.is_multiple(category):
			_opt[category] = characters.option(appearance, category)


func _style(category: String) -> String:
	var option: CharacterOptionDefinition = _opt.get(category)
	return option.style if option != null else ""


func _color(category: String) -> Color:
	var option: CharacterOptionDefinition = _opt.get(category)
	return option.color if option != null else Color.GRAY


func _color2(category: String) -> Color:
	var option: CharacterOptionDefinition = _opt.get(category)
	return option.color2 if option != null else Color.GRAY


func _accessories() -> Array[CharacterOptionDefinition]:
	var result: Array[CharacterOptionDefinition] = []
	if appearance == null:
		return result
	for option_id in appearance.accessories:
		var option := GameManager.characters.rules().find_option("accessory", option_id)
		if option != null:
			result.append(option)
	return result


func _has_jacket() -> bool:
	return _style("jacket") not in ["", "none"]


func _headwear_covers_hair() -> bool:
	return _style("headwear") in ["beanie", "durag", "bucket"]


# ---- ferramentas de desenho

## Curva suave (Catmull-Rom) passando pelos pontos de controle.
func _smooth(points: Array, closed: bool = true, steps: int = 6) -> PackedVector2Array:
	var result := PackedVector2Array()
	var count := points.size()
	var last := count if closed else count - 1
	for i in last:
		var p0: Vector2 = points[(i - 1 + count) % count] if closed or i > 0 else points[0]
		var p1: Vector2 = points[i]
		var p2: Vector2 = points[(i + 1) % count]
		var p3: Vector2 = points[(i + 2) % count] if closed or i + 2 < count else points[count - 1]
		for s in steps:
			var t := float(s) / steps
			var t2 := t * t
			var t3 := t2 * t
			result.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	if not closed:
		result.append(points[count - 1])
	return result


func _offset(points: PackedVector2Array, delta: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(point + delta)
	return result


func _fill(points: PackedVector2Array, color: Color) -> void:
	if points.size() >= 3:
		draw_colored_polygon(points, color)


func _fill_all(polygons: Array, color: Color) -> void:
	# Uma forma deslocada nunca fica inteira dentro da original, então o recorte não gera furos.
	for polygon: PackedVector2Array in polygons:
		_fill(polygon, color)


## Forma completa: base, sombra do lado oposto à luz, brilho do lado da luz e contorno.
func _shape(points: Array, base: Color, outline: bool = true, depth: float = 5.0, shine: float = 0.18) -> PackedVector2Array:
	var polygon := _smooth(points)
	if polygon.size() < 3:
		return polygon
	_fill(polygon, base)
	if depth > 0.0:
		_fill_all(Geometry2D.clip_polygons(polygon, _offset(polygon, LIGHT * depth)), _shadow_of(base))
		if shine > 0.0:
			_fill_all(Geometry2D.clip_polygons(polygon, _offset(polygon, -LIGHT * depth * 0.45)), Color(base.lightened(0.35), shine))
	if outline:
		_line(polygon, _ink(base), 1.6, true)
	return polygon


func _shadow_of(base: Color) -> Color:
	var shadow := base.darkened(0.28)
	shadow.h = fposmod(base.h + wrapf(0.72 - base.h, -0.5, 0.5) * 0.1, 1.0)
	return shadow


func _ink(base: Color) -> Color:
	return Color(base.darkened(0.62), 0.9)


func _line(points: PackedVector2Array, color: Color, width: float = 1.4, closed: bool = false) -> void:
	if points.size() < 2:
		return
	var path := points
	if closed:
		path = points.duplicate()
		path.append(points[0])
	draw_polyline(path, color, width, true)


func _curve(points: Array, color: Color, width: float = 1.4) -> void:
	_line(_smooth(points, false, 6), color, width)


## Linhas recortadas pela forma (xadrez, costuras, nervuras).
func _clipped_line(from: Vector2, to: Vector2, polygon: PackedVector2Array, color: Color, width: float = 1.2) -> void:
	for segment: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([from, to]), polygon):
		_line(segment, color, width)


func _ellipse_points(center: Vector2, radius: Vector2, count: int = 12) -> Array:
	var points := []
	for i in count:
		var angle := TAU * i / count
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points


# ---- corpo

func _draw_ground_shadow() -> void:
	_fill(_smooth(_ellipse_points(Vector2(100, 389), Vector2(58, 7))), Color(0, 0, 0, 0.35))


## Silhueta da cabeça: crânio, maçãs do rosto e queixo.
func _head_points() -> Array:
	return [Vector2(100, 24), Vector2(118, 28), Vector2(129, 42), Vector2(131, 60), Vector2(129, 76), Vector2(122, 90),
		Vector2(110, 100), Vector2(100, 103), Vector2(90, 100), Vector2(78, 90), Vector2(71, 76), Vector2(69, 60),
		Vector2(71, 42), Vector2(82, 28)]


func _draw_neck() -> void:
	var neck := _shape([Vector2(90, 92), Vector2(110, 92), Vector2(112, 118), Vector2(100, 122), Vector2(88, 118)], _skin, true, 3.0, 0.0)
	_fill(_smooth([Vector2(90, 96), Vector2(110, 96), Vector2(110, 104), Vector2(100, 108), Vector2(90, 104)]), Color(_skin.darkened(0.35), 0.55))


func _draw_head() -> void:
	for side: int in [-1, 1]:
		var ear_center := Vector2(100 + side * 31, 66)
		_shape(_ellipse_points(ear_center, Vector2(6, 10), 10), _skin, true, 2.0, 0.0)
		_curve([ear_center + Vector2(-side * 1, -5), ear_center + Vector2(side * 2, 0), ear_center + Vector2(-side * 1, 5)], Color(_skin.darkened(0.35), 0.8), 1.2)
	_shape(_head_points(), _skin, true, 4.5, 0.22)
	# Maçãs do rosto e sombra lateral suave.
	for side: int in [-1, 1]:
		_fill(_smooth(_ellipse_points(Vector2(100 + side * 19, 80), Vector2(8, 5))), Color(_skin.lerp(Color("#e0605a"), 0.25), 0.18))


func _draw_face() -> void:
	var iris := _color("eye_color")
	var lid := _skin.darkened(0.55)
	for side: int in [-1, 1]:
		var c := Vector2(100 + side * 14, 64)
		var eye := _smooth([c + Vector2(-9 * side, 0.5), c + Vector2(-4 * side, -4), c + Vector2(4 * side, -4.2), c + Vector2(9 * side, -0.5),
			c + Vector2(4 * side, 3.2), c + Vector2(-4 * side, 3.4)])
		_fill(eye, Color(0.97, 0.95, 0.93))
		draw_circle(c + Vector2(side * 0.5, 0), 3.9, iris.darkened(0.35))
		draw_circle(c + Vector2(side * 0.5, 0), 3.2, iris)
		draw_circle(c + Vector2(side * 0.5, 0.4), 1.6, Color(0.05, 0.04, 0.05))
		draw_circle(c + Vector2(side * 0.5 - 1.3, -1.3), 1.0, Color(1, 1, 1, 0.95))
		# Pálpebra superior marcada e inferior suave.
		_curve([c + Vector2(-9.5 * side, 0.8), c + Vector2(-4 * side, -4.4), c + Vector2(4 * side, -4.6), c + Vector2(9.8 * side, -0.2)], Color(lid, 0.95), 2.2)
		_curve([c + Vector2(-7 * side, 2.6), c + Vector2(0, 3.8), c + Vector2(7 * side, 2.2)], Color(lid, 0.35), 1.0)
		_curve([c + Vector2(-8 * side, -6.5), c + Vector2(0, -8), c + Vector2(8 * side, -6.2)], Color(_skin.darkened(0.18), 0.6), 1.2)
	_draw_brows()
	# Nariz: sombra lateral, ponta e narinas.
	var nose := _skin.darkened(0.3)
	_curve([Vector2(101, 66), Vector2(104, 76), Vector2(104, 81)], Color(nose, 0.55), 1.6)
	_fill(_smooth(_ellipse_points(Vector2(99, 82), Vector2(6, 3.4), 10)), Color(_skin.darkened(0.12), 0.9))
	_curve([Vector2(93, 82), Vector2(95, 85), Vector2(98, 84.5)], Color(nose, 0.9), 1.4)
	_curve([Vector2(102, 84.5), Vector2(105, 85), Vector2(107, 82)], Color(nose, 0.9), 1.4)
	draw_circle(Vector2(97, 79), 1.2, Color(1, 1, 1, 0.25))
	# Boca: lábio superior, inferior com brilho e a linha entre eles.
	var lip := _skin.lerp(Color("#b5525a"), 0.32).darkened(0.12)
	_fill(_smooth([Vector2(90, 91), Vector2(96, 89), Vector2(100, 90), Vector2(104, 89), Vector2(110, 91), Vector2(100, 92.5)]), lip.darkened(0.15))
	_fill(_smooth([Vector2(91, 91.5), Vector2(100, 92.5), Vector2(109, 91.5), Vector2(105, 96), Vector2(100, 97), Vector2(95, 96)]), lip)
	_curve([Vector2(89.5, 91), Vector2(100, 92.6), Vector2(110.5, 91)], Color(lip.darkened(0.6), 0.9), 1.4)
	_fill(_smooth(_ellipse_points(Vector2(100, 94.5), Vector2(4, 1.1), 8)), Color(1, 1, 1, 0.22))


func _draw_brows() -> void:
	var color := _color("hair_color").darkened(0.15)
	if _color("hair_color").v > 0.8:
		color = _skin.darkened(0.5)
	var weight := 3.0
	var lift := 0.0
	match _style("brows"):
		"thin":
			weight = 1.8
		"thick":
			weight = 4.6
		"arched":
			lift = 3.0
	for side: int in [-1, 1]:
		var inner := Vector2(100 + side * 5, 55)
		var peak := Vector2(100 + side * 16, 51 - lift)
		var outer := Vector2(100 + side * 25, 54)
		var top := _smooth([inner + Vector2(0, -weight * 0.7), peak + Vector2(0, -weight * 0.55), outer], false, 5)
		var bottom := _smooth([outer, peak + Vector2(0, weight * 0.45), inner + Vector2(0, weight * 0.5)], false, 5)
		var brow := top.duplicate()
		brow.append_array(bottom)
		_fill(brow, color)
		if _style("brows") == "cut" and side == 1:
			draw_line(Vector2(114, 47), Vector2(117, 57), _skin, 2.4)


# ---- cabelo

func _hairline_cap(depth: float, part: bool = false) -> Array:
	return [Vector2(68, 64), Vector2(68, 44), Vector2(76, 28), Vector2(90, 20), Vector2(110, 20), Vector2(124, 28),
		Vector2(132, 44), Vector2(132, 64), Vector2(127, 56), Vector2(122, 44 + depth * 0.2), Vector2(112, 40 + depth * 0.15),
		Vector2(100 + (6 if part else 0), 41 + depth * 0.1), Vector2(88, 40 + depth * 0.15), Vector2(78, 44 + depth * 0.2), Vector2(73, 56)]


func _draw_back_hair() -> void:
	var color := _color("hair_color")
	if _headwear_covers_hair() and _style("hair") != "long":
		return
	match _style("hair"):
		"afro":
			var cloud := []
			for i in 16:
				var angle := PI + TAU * i / 16.0
				var r := 50.0 + (5.0 if i % 2 == 0 else 0.0)
				cloud.append(Vector2(100, 46) + Vector2(cos(angle) * r * 1.08, sin(angle) * r * 0.86))
			var shape := _shape(cloud, color, true, 8.0, 0.12)
			for i in 40:
				var p := Vector2(100, 46) + Vector2(cos(i * 2.39) * (i % 40) * 1.1, sin(i * 2.39) * (i % 37) * 0.9)
				draw_circle(p, 1.4, Color(color.lightened(0.25), 0.25))
		"long":
			_shape([Vector2(70, 40), Vector2(100, 18), Vector2(130, 40), Vector2(138, 90), Vector2(142, 148), Vector2(120, 156),
				Vector2(100, 140), Vector2(80, 156), Vector2(58, 148), Vector2(62, 90)], color, true, 7.0, 0.14)
		"dreads", "braids":
			var count := 10 if _style("hair") == "dreads" else 12
			var width := 7.0 if _style("hair") == "dreads" else 5.0
			for i in count:
				var x := lerpf(-38, 38, float(i) / (count - 1))
				var length := 68.0 + 16.0 * absf(sin(i * 1.7))
				var start := Vector2(100 + x * 0.85, 34)
				var end := Vector2(100 + x * 1.18, 34 + length)
				var strand := _smooth([start, start.lerp(end, 0.5) + Vector2(sin(i) * 3, 0), end], false, 6)
				_line(strand, color.darkened(0.35), width + 2.0)
				_line(strand, color, width)
				for k in 6:
					var p := strand[mini(k * strand.size() / 6, strand.size() - 1)]
					draw_line(p + Vector2(-width * 0.45, 0), p + Vector2(width * 0.45, 1.5), Color(color.darkened(0.4), 0.7), 1.0)
		"bun":
			_shape(_ellipse_points(Vector2(100, 16), Vector2(15, 12), 12), color, true, 4.0, 0.2)


func _draw_front_hair() -> void:
	if _headwear_covers_hair():
		return
	var color := _color("hair_color")
	var shade := color.darkened(0.35)
	match _style("hair"):
		"bald":
			_fill(_smooth(_ellipse_points(Vector2(90, 34), Vector2(10, 5), 10)), Color(1, 1, 1, 0.22))
		"buzz":
			var buzz := Color(color, 0.78)
			var cap := _smooth(_hairline_cap(4.0))
			_fill(cap, buzz)
			for i in 60:
				var p := Vector2(72 + (i * 37) % 56, 26 + (i * 23) % 20)
				if Geometry2D.is_point_in_polygon(p, cap):
					draw_circle(p, 0.7, Color(shade, 0.6))
		"short", "waves", "twists", "dreads", "braids", "bun", "afro":
			var cap := _shape(_hairline_cap(6.0), color, true, 5.0, 0.2)
			match _style("hair"):
				"waves":
					for row in 4:
						_curve([Vector2(76, 30 + row * 5), Vector2(100, 24 + row * 5), Vector2(124, 30 + row * 5)], Color(color.lightened(0.35), 0.55), 1.4)
				"braids":
					for x: int in [-24, -12, 0, 12, 24]:
						_curve([Vector2(100 + x * 0.55, 22), Vector2(100 + x * 0.85, 32), Vector2(100 + x, 42)], Color(shade, 0.9), 2.0)
						for k in 4:
							var p := Vector2(100 + x * (0.6 + k * 0.12), 25 + k * 5)
							_fill(_smooth([p + Vector2(-2, 0), p + Vector2(0, -2), p + Vector2(2, 0), p + Vector2(0, 2)], true, 2), Color(color.lightened(0.25), 0.7))
				"twists":
					for i in 16:
						var angle := PI + 0.25 + (PI - 0.5) * i / 15.0
						var p := Vector2(100, 46) + Vector2(cos(angle) * 31, sin(angle) * 26)
						_shape(_ellipse_points(p, Vector2(3.6, 6.5), 8), color, true, 2.0, 0.2)
				_:
					for i in 7:
						var x := 78 + i * 7
						_curve([Vector2(x, 26), Vector2(x + 3, 33), Vector2(x + 2, 40)], Color(shade, 0.45), 1.0)
		"curly":
			_shape(_hairline_cap(8.0), color, true, 4.0, 0.15)
			for i in 18:
				var angle := PI - 0.15 + (PI + 0.3) * i / 17.0
				var p := Vector2(100, 48) + Vector2(cos(angle) * 34, sin(angle) * 30)
				_shape(_ellipse_points(p, Vector2(6.5, 6.5), 8), color, true, 2.5, 0.25)
		"long":
			_shape(_hairline_cap(10.0, true), color, true, 5.0, 0.2)
			_curve([Vector2(106, 20), Vector2(104, 30), Vector2(100, 42)], Color(shade, 0.8), 1.4)
			for side: int in [-1, 1]:
				_shape([Vector2(100 + side * 30, 44), Vector2(100 + side * 33, 70), Vector2(100 + side * 34, 98), Vector2(100 + side * 28, 96), Vector2(100 + side * 26, 66)], color, true, 3.0, 0.15)
		"mohawk":
			var faded := Color(color, 0.42)
			_fill(_smooth(_hairline_cap(2.0)), faded)
			_shape([Vector2(92, 40), Vector2(90, 22), Vector2(94, 8), Vector2(100, 2), Vector2(106, 8), Vector2(110, 22), Vector2(108, 40)], color, true, 4.0, 0.25)


# ---- barba

func _jaw_band(top: float, length: float) -> Array:
	return [Vector2(70, top), Vector2(73, top + 18), Vector2(80, top + 30), Vector2(90, top + 38 + length), Vector2(100, top + 41 + length * 1.2),
		Vector2(110, top + 38 + length), Vector2(120, top + 30), Vector2(127, top + 18), Vector2(130, top), Vector2(124, top + 14),
		Vector2(116, top + 22), Vector2(108, top + 24), Vector2(100, top + 21), Vector2(92, top + 24), Vector2(84, top + 22), Vector2(76, top + 14)]


func _draw_beard() -> void:
	var color := _color("hair_color")
	var mustache := [Vector2(90, 89), Vector2(95, 86), Vector2(100, 87.5), Vector2(105, 86), Vector2(110, 89), Vector2(106, 89.5), Vector2(100, 89), Vector2(94, 89.5)]
	match _style("beard"):
		"stubble":
			var band := _smooth(_jaw_band(62.0, 0.0))
			var dots := _skin.lerp(color.darkened(0.4), 0.55)
			_fill(band, Color(dots, 0.28))
			for i in 90:
				var p := Vector2(72 + (i * 29) % 56, 70 + (i * 17) % 34)
				if Geometry2D.is_point_in_polygon(p, band):
					draw_circle(p, 0.6, Color(dots, 0.7))
		"mustache":
			_shape(mustache, color, true, 1.5, 0.2)
		"goatee":
			_shape(mustache, color, true, 1.5, 0.2)
			_shape([Vector2(93, 97), Vector2(100, 96), Vector2(107, 97), Vector2(106, 106), Vector2(100, 110), Vector2(94, 106)], color, true, 2.0, 0.2)
		"chinstrap":
			var strap := _smooth([Vector2(70, 66), Vector2(74, 84), Vector2(84, 96), Vector2(100, 104), Vector2(116, 96), Vector2(126, 84), Vector2(130, 66)], false, 6)
			_line(strap, color.darkened(0.3), 5.5)
			_line(strap, color, 4.0)
		"short", "full", "long":
			var length: float = {"short": 0.0, "full": 6.0, "long": 26.0}[_style("beard")]
			var beard := _shape(_jaw_band(62.0, length), color, true, 4.0, 0.15)
			_shape(mustache, color, true, 1.5, 0.2)
			for i in 14:
				var x := 78.0 + i * 3.4
				_clipped_line(Vector2(x, 70), Vector2(x + 2, 104 + length), beard, Color(color.lightened(0.2), 0.3), 0.8)
			# A boca aparece por cima da barba.
			var lip := _skin.lerp(Color("#b5525a"), 0.32).darkened(0.12)
			_fill(_smooth([Vector2(93, 91.5), Vector2(100, 92.5), Vector2(107, 91.5), Vector2(104, 95), Vector2(100, 96), Vector2(96, 95)]), lip)


# ---- roupas

func _torso_points() -> Array:
	return [Vector2(58, 126), Vector2(78, 116), Vector2(100, 118), Vector2(122, 116), Vector2(142, 126), Vector2(146, 152),
		Vector2(138, 200), Vector2(137, 252), Vector2(100, 256), Vector2(63, 252), Vector2(62, 200), Vector2(54, 152)]


func _arm_points(side: int, from_t: float = 0.0, to_t: float = 1.0, bulk: float = 0.0) -> Array:
	# Ombro, cotovelo e punho; o braço afasta um pouco do corpo, com caimento natural.
	var shoulder := Vector2(100 + side * 41, 128)
	var elbow := Vector2(100 + side * 52, 190)
	var wrist := Vector2(100 + side * 54, 242)
	var path := [shoulder, elbow, wrist]
	var widths := [12.0 + bulk, 9.5 + bulk, 7.5 + bulk * 0.6]
	var outer := []
	var inner := []
	for i in 3:
		var t := float(i) / 2.0
		if t < from_t - 0.01 or t > to_t + 0.01:
			continue
		var p: Vector2 = path[i]
		outer.append(p + Vector2(side * widths[i], 0))
		inner.append(p - Vector2(side * widths[i], 0))
	if from_t > 0.0:
		var p := _lerp_path(path, from_t)
		var w := lerpf(widths[0], widths[2], from_t)
		outer.push_front(p + Vector2(side * w, 0))
		inner.push_front(p - Vector2(side * w, 0))
	if to_t < 1.0:
		var p := _lerp_path(path, to_t)
		var w := lerpf(widths[0], widths[2], to_t)
		outer.append(p + Vector2(side * w, 0))
		inner.append(p - Vector2(side * w, 0))
	inner.reverse()
	return outer + inner


func _lerp_path(path: Array, t: float) -> Vector2:
	if t <= 0.5:
		return (path[0] as Vector2).lerp(path[1], t * 2.0)
	return (path[1] as Vector2).lerp(path[2], (t - 0.5) * 2.0)


func _draw_arms() -> void:
	for side: int in [-1, 1]:
		_shape(_arm_points(side), _skin, true, 4.0, 0.18)


func _sleeve_to() -> float:
	if _has_jacket():
		return 1.0
	match _style("top"):
		"tank":
			return 0.0
		"tshirt":
			return 0.32
		"jersey":
			return 0.36
	return 1.0


func _draw_sleeves(color: Color, detail: Color, to_t: float, bulk: float = 0.0, cuff: bool = true) -> void:
	if to_t <= 0.0:
		return
	for side: int in [-1, 1]:
		var sleeve := _shape(_arm_points(side, 0.0, to_t, bulk + 1.5), color, true, 4.0, 0.15)
		_curve([Vector2(100 + side * 46, 160), Vector2(100 + side * 49, 168), Vector2(100 + side * 47, 176)], Color(color.darkened(0.3), 0.6), 1.0)
		if cuff and to_t >= 1.0:
			_shape(_arm_points(side, 0.9, 1.0, bulk + 2.0), detail if detail != color else color.darkened(0.15), true, 2.0, 0.1)
		elif to_t < 1.0:
			var p := _lerp_path([Vector2(100 + side * 41, 128), Vector2(100 + side * 52, 190), Vector2(100 + side * 54, 242)], to_t)
			_line(PackedVector2Array([p + Vector2(-11, 0), p + Vector2(11, 0)]), detail.darkened(0.2), 2.0)


func _draw_top() -> void:
	var color := _color("top")
	var detail := _color2("top")
	var style := _style("top")
	if not _has_jacket():
		_draw_sleeves(color, detail, _sleeve_to(), 2.0 if style == "hoodie" else 0.0)
	match style:
		"tank":
			_shape([Vector2(62, 128), Vector2(72, 122), Vector2(84, 122), Vector2(100, 140), Vector2(116, 122), Vector2(128, 122),
				Vector2(138, 128), Vector2(140, 160), Vector2(137, 252), Vector2(100, 256), Vector2(63, 252), Vector2(60, 160)], _skin, true, 4.0, 0.15)
			var tank := _shape([Vector2(70, 132), Vector2(80, 122), Vector2(86, 124), Vector2(100, 146), Vector2(114, 124), Vector2(120, 122),
				Vector2(130, 132), Vector2(136, 166), Vector2(137, 252), Vector2(100, 256), Vector2(63, 252), Vector2(64, 166)], color, true, 6.0, 0.15)
			_curve([Vector2(86, 125), Vector2(100, 146), Vector2(114, 125)], detail, 2.2)
		"hoodie":
			var body := _shape([Vector2(56, 126), Vector2(78, 116), Vector2(122, 116), Vector2(144, 126), Vector2(149, 156),
				Vector2(142, 204), Vector2(141, 246), Vector2(100, 250), Vector2(59, 246), Vector2(58, 204), Vector2(51, 156)], color, true, 7.0, 0.15)
			# Capuz caído em volta do pescoço.
			_shape([Vector2(76, 118), Vector2(88, 110), Vector2(112, 110), Vector2(124, 118), Vector2(118, 132), Vector2(100, 140), Vector2(82, 132)], color.darkened(0.08), true, 3.0, 0.1)
			_fill(_smooth([Vector2(86, 118), Vector2(100, 114), Vector2(114, 118), Vector2(108, 128), Vector2(100, 131), Vector2(92, 128)]), color.darkened(0.42))
			for x: int in [94, 106]:
				_curve([Vector2(x, 130), Vector2(x - 1, 150), Vector2(x + 1, 166)], Color(0.95, 0.95, 0.95), 1.6)
				draw_rect(Rect2(x - 1.5, 165, 3, 5), Color(0.82, 0.82, 0.84))
			_shape([Vector2(74, 206), Vector2(126, 206), Vector2(132, 238), Vector2(68, 238)], color.darkened(0.06), true, 2.0, 0.08)
			_curve([Vector2(76, 210), Vector2(72, 234)], Color(color.darkened(0.35), 0.8), 1.2)
			_curve([Vector2(124, 210), Vector2(128, 234)], Color(color.darkened(0.35), 0.8), 1.2)
			_shape([Vector2(59, 240), Vector2(141, 240), Vector2(141, 252), Vector2(59, 252)], color.darkened(0.12), true, 2.0, 0.0)
			for i in 20:
				var x := 61.0 + i * 4.0
				draw_line(Vector2(x, 241), Vector2(x, 251), Color(color.darkened(0.28), 0.7), 1.0)
		_:
			var torso := _shape(_torso_points(), color, true, 7.0, 0.15)
			match style:
				"tshirt":
					_fill(_smooth([Vector2(86, 118), Vector2(100, 116), Vector2(114, 118), Vector2(110, 130), Vector2(100, 134), Vector2(90, 130)]), _skin)
					_curve([Vector2(85, 118), Vector2(90, 130), Vector2(100, 135), Vector2(110, 130), Vector2(115, 118)], detail, 3.0)
					_curve([Vector2(72, 170), Vector2(80, 190), Vector2(78, 214)], Color(color.darkened(0.25), 0.55), 1.2)
					_curve([Vector2(126, 176), Vector2(122, 198), Vector2(126, 224)], Color(color.darkened(0.25), 0.55), 1.2)
					_fill(_smooth(_ellipse_points(Vector2(100, 170), Vector2(13, 9), 10)), Color(detail, 0.85))
				"jersey":
					_fill(_smooth([Vector2(86, 118), Vector2(114, 118), Vector2(100, 144)]), _skin)
					_curve([Vector2(84, 117), Vector2(100, 146), Vector2(116, 117)], detail, 3.4)
					for x: int in [66, 134]:
						_clipped_line(Vector2(x, 140), Vector2(x, 250), torso, detail, 4.0)
					var number_size := 18 if _has_jacket() else 30
					draw_string(ThemeDB.fallback_font, Vector2(70, 200 + number_size * 0.4), "23", HORIZONTAL_ALIGNMENT_CENTER, 60, number_size, detail)
				"shirt":
					if detail.v < 0.4:
						for i in 9:
							_clipped_line(Vector2(56 + i * 11, 116), Vector2(52 + i * 11, 256), torso, Color(detail, 0.35), 3.0)
						for i in 8:
							_clipped_line(Vector2(50, 130 + i * 16), Vector2(150, 130 + i * 16), torso, Color(detail, 0.3), 2.4)
					_line(PackedVector2Array([Vector2(100, 132), Vector2(100, 254)]), Color(color.darkened(0.3), 0.9), 1.4)
					for y: int in [150, 174, 198, 222, 246]:
						draw_circle(Vector2(103, y), 1.8, color.lightened(0.5))
					for side: int in [-1, 1]:
						_shape([Vector2(100, 120), Vector2(100 + side * 15, 114), Vector2(100 + side * 18, 122), Vector2(100 + side * 4, 136)], color.lightened(0.06), true, 1.5, 0.15)


func _draw_jacket() -> void:
	if not _has_jacket():
		return
	var style := _style("jacket")
	var color := _color("jacket")
	var detail := _color2("jacket")
	var bulk := 5.0 if style == "puffer" else 2.5
	_draw_sleeves(detail if style == "varsity" else color, detail if style in ["bomber", "varsity"] else color.darkened(0.12), 1.0, bulk)
	for side: int in [-1, 1]:
		var panel := [Vector2(100 + side * 13, 116), Vector2(100 + side * 26, 116), Vector2(100 + side * (44 + bulk), 126),
			Vector2(100 + side * (48 + bulk), 154), Vector2(100 + side * (41 + bulk), 204), Vector2(100 + side * (41 + bulk), 256),
			Vector2(100 + side * 12, 258), Vector2(100 + side * 10, 200), Vector2(100 + side * 9, 140)]
		var shape := _shape(panel, color, true, 7.0, 0.2 if style == "leather" else 0.14)
		match style:
			"bomber", "varsity":
				var rib := detail if style == "bomber" else color.darkened(0.25)
				_shape([Vector2(100 + side * 12, 246), Vector2(100 + side * (41 + bulk), 246), Vector2(100 + side * (41 + bulk), 258), Vector2(100 + side * 12, 258)], rib, true, 1.5, 0.0)
				for i in 8:
					var x := 100 + side * (14 + i * 4)
					draw_line(Vector2(x, 247), Vector2(x, 257), Color(rib.darkened(0.3), 0.7), 1.0)
				if style == "varsity" and side == -1:
					draw_string(ThemeDB.fallback_font, Vector2(66, 182), "R", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, detail)
			"denim":
				_clipped_line(Vector2(100 + side * 8, 168), Vector2(100 + side * 50, 168), shape, Color(detail, 0.9), 1.2)
				_clipped_line(Vector2(100 + side * 26, 150), Vector2(100 + side * 26, 250), shape, Color(detail, 0.7), 1.0)
				_shape([Vector2(100 + side * 18, 174), Vector2(100 + side * 34, 174), Vector2(100 + side * 34, 196), Vector2(100 + side * 18, 196)], color.darkened(0.06), true, 1.5, 0.0)
			"leather":
				_shape([Vector2(100 + side * 12, 118), Vector2(100 + side * 26, 118), Vector2(100 + side * 30, 166), Vector2(100 + side * 14, 176)], detail, true, 2.0, 0.25)
				_curve([Vector2(100 + side * 30, 136), Vector2(100 + side * 36, 190), Vector2(100 + side * 34, 240)], Color(1, 1, 1, 0.18), 3.0)
			"puffer":
				for i in 6:
					var y := 140 + i * 20
					_clipped_line(Vector2(100 + side * 4, y), Vector2(100 + side * 60, y), shape, Color(detail, 0.85), 1.6)
					_clipped_line(Vector2(100 + side * 4, y + 9), Vector2(100 + side * 60, y + 9), shape, Color(1, 1, 1, 0.14), 4.0)
	if style in ["bomber", "varsity", "puffer"]:
		_shape([Vector2(80, 112), Vector2(120, 112), Vector2(124, 120), Vector2(76, 120)], (detail if style == "bomber" else color).darkened(0.2), true, 1.5, 0.0)
	if style == "leather" or style == "puffer":
		_line(PackedVector2Array([Vector2(110, 120), Vector2(111, 256)]), Color(0.75, 0.75, 0.78), 1.4)


func _draw_hands() -> void:
	for side: int in [-1, 1]:
		var wrist := Vector2(100 + side * 54, 244)
		_shape([wrist + Vector2(-7, -2), wrist + Vector2(7, -2), wrist + Vector2(8, 10), wrist + Vector2(5, 19), wrist + Vector2(-1, 21),
			wrist + Vector2(-6, 17), wrist + Vector2(-8, 8)], _skin, true, 3.0, 0.15)
		_shape([wrist + Vector2(-side * 6, 2), wrist + Vector2(-side * 11, 9), wrist + Vector2(-side * 9, 13), wrist + Vector2(-side * 5, 9)], _skin, true, 1.5, 0.0)
		for k in 3:
			_curve([wrist + Vector2(-4 + k * 3.5, 12), wrist + Vector2(-4 + k * 3.5, 18)], Color(_skin.darkened(0.35), 0.6), 0.9)


func _leg_points(side: int, top: float, bottom: float, flare: float = 0.0) -> Array:
	var hip_out := Vector2(100 + side * 37, top)
	var hip_in := Vector2(100 + side * 2, top)
	var knee := lerpf(top, bottom, 0.52)
	return [hip_in, hip_out, Vector2(100 + side * (32 + flare * 0.5), knee), Vector2(100 + side * (27 + flare), bottom),
		Vector2(100 + side * (8 - flare * 0.3), bottom), Vector2(100 + side * 9, knee)]


func _draw_legs() -> void:
	var color := _color("bottom")
	var detail := _color2("bottom")
	var style := _style("bottom")
	if style == "shorts":
		for side: int in [-1, 1]:
			_shape(_leg_points(side, 300, 372), _skin, true, 4.0, 0.15)
			_shape([Vector2(100 + side * 9, 354), Vector2(100 + side * 27, 354), Vector2(100 + side * 27, 372), Vector2(100 + side * 9, 372)], Color(0.94, 0.94, 0.95), true, 2.0, 0.0)
	var bottom := 316.0 if style == "shorts" else 374.0
	var flare := 4.0 if style == "cargo" else (-2.0 if style == "sweatpants" else 0.0)
	for side: int in [-1, 1]:
		var leg := _shape(_leg_points(side, 244, bottom, flare), color, true, 6.0, 0.14)
		match style:
			"jeans":
				_clipped_line(Vector2(100 + side * 33, 260), Vector2(100 + side * 25, 374), leg, Color(detail.lightened(0.3), 0.7), 1.0)
				_fill(_smooth(_ellipse_points(Vector2(100 + side * 20, 312), Vector2(8, 22), 10)), Color(1, 1, 1, 0.1))
				for k in 3:
					_curve([Vector2(100 + side * 9, 360 + k * 4), Vector2(100 + side * 18, 357 + k * 4), Vector2(100 + side * 27, 360 + k * 4)], Color(color.darkened(0.35), 0.7), 1.0)
			"cargo":
				_shape([Vector2(100 + side * 26, 284), Vector2(100 + side * 38, 284), Vector2(100 + side * 38, 316), Vector2(100 + side * 26, 316)], color.darkened(0.08), true, 2.0, 0.1)
				_line(PackedVector2Array([Vector2(100 + side * 26, 290), Vector2(100 + side * 38, 290)]), Color(color.darkened(0.4), 0.9), 1.2)
				_curve([Vector2(100 + side * 14, 336), Vector2(100 + side * 22, 340), Vector2(100 + side * 30, 336)], Color(color.darkened(0.3), 0.6), 1.0)
			"sweatpants":
				_shape([Vector2(100 + side * 8, 360), Vector2(100 + side * 26, 360), Vector2(100 + side * 25, 374), Vector2(100 + side * 9, 374)], detail, true, 1.5, 0.0)
				_clipped_line(Vector2(100 + side * 34, 252), Vector2(100 + side * 27, 362), leg, Color(1, 1, 1, 0.5), 2.0)
			"shorts":
				_line(PackedVector2Array([Vector2(100 + side * 7, 310), Vector2(100 + side * 36, 310)]), Color(detail.darkened(0.2), 0.9), 1.4)
	_shape([Vector2(62, 244), Vector2(138, 244), Vector2(139, 256), Vector2(61, 256)], detail.darkened(0.1), true, 1.5, 0.0)
	draw_rect(Rect2(95, 245, 10, 10), Color(0.8, 0.72, 0.4))
	draw_rect(Rect2(97, 247, 6, 6), Color(0.6, 0.52, 0.28))


func _draw_shoes() -> void:
	var color := _color("shoes")
	var sole := _color2("shoes")
	var style := _style("shoes")
	for side: int in [-1, 1]:
		var cx := 100 + side * 18
		match style:
			"boots":
				_shape([Vector2(cx - side * 12, 350), Vector2(cx + side * 12, 350), Vector2(cx + side * 14, 376), Vector2(cx + side * 20, 380), Vector2(cx - side * 16, 382)], color, true, 4.0, 0.18)
				_shape([Vector2(cx - side * 17, 380), Vector2(cx + side * 20, 380), Vector2(cx + side * 20, 389), Vector2(cx - side * 17, 389)], sole, true, 2.0, 0.0)
				for k in 4:
					_line(PackedVector2Array([Vector2(cx - side * 5, 356 + k * 5), Vector2(cx + side * 5, 358 + k * 5)]), Color(0.9, 0.85, 0.7, 0.8), 1.2)
			"slides":
				_shape(_ellipse_points(Vector2(cx, 381), Vector2(15, 6), 12), _skin, true, 2.0, 0.0)
				_shape([Vector2(cx - side * 17, 383), Vector2(cx + side * 17, 383), Vector2(cx + side * 16, 390), Vector2(cx - side * 16, 390)], sole, true, 1.5, 0.0)
				_shape([Vector2(cx - side * 13, 372), Vector2(cx + side * 13, 372), Vector2(cx + side * 14, 382), Vector2(cx - side * 14, 382)], color, true, 2.0, 0.2)
			_:
				_shape([Vector2(cx - side * 13, 366), Vector2(cx + side * 12, 366), Vector2(cx + side * 18, 376), Vector2(cx + side * 20, 384), Vector2(cx - side * 18, 384), Vector2(cx - side * 17, 374)], color, true, 4.0, 0.25)
				_shape([Vector2(cx - side * 19, 382), Vector2(cx + side * 21, 382), Vector2(cx + side * 21, 390), Vector2(cx - side * 19, 390)], sole, true, 1.5, 0.0)
				_line(PackedVector2Array([Vector2(cx - side * 19, 386), Vector2(cx + side * 21, 386)]), Color(sole.darkened(0.25), 0.8), 1.0)
				_curve([Vector2(cx - side * 14, 380), Vector2(cx, 374), Vector2(cx + side * 16, 378)], sole if sole.v > 0.5 else color.lightened(0.5), 2.2)
				for k in 3:
					_line(PackedVector2Array([Vector2(cx - side * 6, 368 + k * 3), Vector2(cx + side * 6, 368 + k * 3)]), Color(0.95, 0.95, 0.95, 0.85), 1.0)


func _draw_hood_back() -> void:
	if _style("top") == "hoodie" and not _has_jacket():
		_shape(_ellipse_points(Vector2(100, 118), Vector2(36, 14), 12), _color("top").darkened(0.3), true, 2.0, 0.0)


# ---- acessórios

func _draw_chain() -> void:
	for option in _accessories():
		if option.style != "chain":
			continue
		var points := _smooth([Vector2(80, 118), Vector2(88, 140), Vector2(100, 150), Vector2(112, 140), Vector2(120, 118)], false, 8)
		for i in points.size():
			var p := points[i]
			_fill(_smooth(_ellipse_points(p, Vector2(2.2, 1.5) if i % 2 == 0 else Vector2(1.5, 2.2), 8)), option.color if i % 2 == 0 else option.color.darkened(0.2))
		_shape([Vector2(100, 150), Vector2(107, 158), Vector2(100, 168), Vector2(93, 158)], option.color, true, 2.0, 0.3)
		_fill(_smooth([Vector2(100, 153), Vector2(104, 158), Vector2(100, 163), Vector2(96, 158)]), option.color2)
		draw_circle(Vector2(98, 156), 1.2, Color(1, 1, 1, 0.9))


func _draw_headwear() -> void:
	var color := _color("headwear")
	var detail := _color2("headwear")
	match _style("headwear"):
		"cap":
			var crown := _shape([Vector2(67, 50), Vector2(70, 32), Vector2(82, 18), Vector2(100, 14), Vector2(118, 18), Vector2(130, 32), Vector2(133, 50)], color, true, 6.0, 0.2)
			for x: int in [-14, 14]:
				_clipped_line(Vector2(100, 14), Vector2(100 + x * 2.2, 50), crown, Color(color.darkened(0.35), 0.7), 1.0)
			draw_circle(Vector2(100, 15), 2.5, color.darkened(0.2))
			_shape([Vector2(64, 50), Vector2(100, 44), Vector2(136, 50), Vector2(138, 58), Vector2(100, 62), Vector2(62, 58)], color.darkened(0.08), true, 3.0, 0.1)
			_shape(_ellipse_points(Vector2(100, 31), Vector2(10, 6), 10), detail, true, 1.0, 0.2)
		"cap_back":
			var crown := _shape([Vector2(67, 50), Vector2(70, 32), Vector2(82, 18), Vector2(100, 14), Vector2(118, 18), Vector2(130, 32), Vector2(133, 50)], color, true, 6.0, 0.2)
			_shape([Vector2(86, 50), Vector2(114, 50), Vector2(112, 40), Vector2(88, 40)], detail, true, 1.5, 0.0)
			_line(PackedVector2Array([Vector2(68, 50), Vector2(132, 50)]), color.darkened(0.3), 2.0)
		"beanie":
			_shape([Vector2(66, 52), Vector2(68, 30), Vector2(82, 14), Vector2(100, 9), Vector2(118, 14), Vector2(132, 30), Vector2(134, 52)], color, true, 6.0, 0.15)
			var band := _shape([Vector2(65, 40), Vector2(135, 40), Vector2(136, 56), Vector2(64, 56)], detail, true, 2.0, 0.1)
			for i in 18:
				var x := 66.0 + i * 4.0
				draw_line(Vector2(x, 41), Vector2(x, 55), Color(detail.darkened(0.3), 0.7), 1.0)
		"bucket":
			_shape([Vector2(70, 46), Vector2(74, 24), Vector2(100, 16), Vector2(126, 24), Vector2(130, 46)], color, true, 5.0, 0.15)
			_shape([Vector2(56, 52), Vector2(70, 42), Vector2(100, 40), Vector2(130, 42), Vector2(144, 52), Vector2(100, 58)], detail, true, 3.0, 0.1)
			for r: float in [0.0, 3.0]:
				_curve([Vector2(72, 42 + r), Vector2(100, 37 + r), Vector2(128, 42 + r)], Color(color.darkened(0.35), 0.6), 1.0)
		"durag":
			_shape([Vector2(67, 56), Vector2(68, 30), Vector2(84, 16), Vector2(100, 13), Vector2(116, 16), Vector2(132, 30), Vector2(133, 56), Vector2(100, 48)], color, true, 5.0, 0.35)
			_curve([Vector2(100, 13), Vector2(100, 30), Vector2(100, 48)], Color(detail, 0.9), 1.4)
			_shape([Vector2(128, 50), Vector2(136, 52), Vector2(146, 104), Vector2(138, 106)], color, true, 3.0, 0.3)


func _draw_face_accessories() -> void:
	for option in _accessories():
		match option.style:
			"sunglasses":
				for side: int in [-1, 1]:
					var lens := _shape([Vector2(100 + side * 4, 58), Vector2(100 + side * 25, 57), Vector2(100 + side * 24, 68), Vector2(100 + side * 17, 72), Vector2(100 + side * 6, 69)], option.color, true, 2.0, 0.0)
					_line(PackedVector2Array([Vector2(100 + side * 8, 60), Vector2(100 + side * 13, 66)]), Color(1, 1, 1, 0.35), 2.0)
				_line(PackedVector2Array([Vector2(96, 60), Vector2(104, 60)]), option.color, 2.4)
			"glasses":
				for side: int in [-1, 1]:
					var frame := _smooth(_ellipse_points(Vector2(100 + side * 14, 64), Vector2(10, 7.5), 12))
					_fill(frame, Color(option.color2, 0.2))
					_line(frame, option.color, 2.0, true)
				_line(PackedVector2Array([Vector2(96, 63), Vector2(104, 63)]), option.color, 2.0)
			"earrings":
				for side: int in [-1, 1]:
					draw_circle(Vector2(100 + side * 32, 75), 2.6, option.color)
					draw_circle(Vector2(100 + side * 32 - 0.8, 74.2), 0.9, Color(1, 1, 1, 0.9))


func _draw_watch() -> void:
	for option in _accessories():
		if option.style == "watch":
			_shape([Vector2(39, 234), Vector2(55, 234), Vector2(55, 242), Vector2(39, 242)], option.color, true, 1.5, 0.3)
			_shape(_ellipse_points(Vector2(47, 238), Vector2(5, 5), 10), option.color2, true, 1.0, 0.0)
			draw_circle(Vector2(45.5, 236.5), 1.2, Color(1, 1, 1, 0.6))
