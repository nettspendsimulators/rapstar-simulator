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
	["_draw_arms", 112, 262], ["_draw_top", 108, 262], ["_draw_jacket", 108, 304], ["_draw_bag", 112, 250],
	["_draw_hands", 236, 268], ["_draw_wrist", 226, 262],
	["_draw_neck", 88, 126], ["_draw_chain", 110, 172], ["_draw_head", 20, 110], ["_draw_face", 40, 100],
	["_draw_beard", 55, 136], ["_draw_front_hair", 0, 112], ["_draw_headwear", 0, 110], ["_draw_face_accessories", 50, 82],
	["_draw_watch", 228, 248],
]
## Camadas do tronco (braços, roupas de cima, mãos) e das pernas: cada grupo é desenhado com a
## largura do corpo (sexo e tipo físico), com o centro no meio do quadro.
const UPPER_LAYERS := ["_draw_hood_back", "_draw_arms", "_draw_top", "_draw_jacket", "_draw_bag", "_draw_hands", "_draw_chain", "_draw_watch", "_draw_wrist"]
const LOWER_LAYERS := ["_draw_legs", "_draw_shoes"]
## Largura do tronco e das pernas por tipo físico.
const BUILD_WIDTHS := {"slim": [0.9, 0.93], "regular": [1.0, 1.0], "athletic": [1.1, 1.0], "heavy": [1.13, 1.1]}
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
var _female := false
var _upper_k := 1.0
var _lower_k := 1.0
var _neck_k := 1.0
var _base := Transform2D.IDENTITY


## Respiração sutil (personagem em destaque: Início, criação, menu). Só escala, sem redesenhar.
var idle: bool = false:
	set(value):
		idle = value
		_update_idle()

var _idle_tween: Tween


func _ready() -> void:
	resized.connect(queue_redraw)
	resized.connect(func() -> void: pivot_offset = Vector2(size.x / 2.0, size.y))
	_update_idle()


func _update_idle() -> void:
	if _idle_tween != null:
		_idle_tween.kill()
		_idle_tween = null
	scale = Vector2.ONE
	if not idle or not is_inside_tree():
		return
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_property(self, "scale", Vector2(1.0, 1.008), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(self, "scale", Vector2.ONE, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _draw() -> void:
	var region: Rect2 = CharacterLayout.FOCUS_RECTS.get(focus, CharacterLayout.FOCUS_RECTS["full"])
	var scale_factor := minf(size.x / region.size.x, size.y / region.size.y)
	if scale_factor <= 0.0:
		return
	var offset := (size - region.size * scale_factor) / 2.0 - region.position * scale_factor
	_base = Transform2D(0.0, Vector2(scale_factor, scale_factor), 0.0, offset)
	draw_set_transform_matrix(_base)
	_resolve()
	_skin = _color("skin")
	_body_metrics()
	# Só desenha as camadas que aparecem na área visível (miniaturas recortam uma parte do corpo).
	var top := -offset.y / scale_factor
	var bottom := top + size.y / scale_factor
	if focus == "full":
		_draw_ground_shadow()
	for layer: Array in LAYERS:
		if top < layer[2] and bottom > layer[1]:
			_set_width(_width_for(layer[0]))
			call(layer[0])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Corpo: sexo e tipo físico definem a largura do tronco, das pernas e do pescoço.
func _body_metrics() -> void:
	_female = _style("sex") == "female"
	var widths: Array = BUILD_WIDTHS.get(_style("build"), BUILD_WIDTHS["regular"])
	_upper_k = widths[0] * (0.87 if _female else 1.0)
	_lower_k = widths[1] * (1.03 if _female else 1.0)
	_neck_k = 0.84 if _female else (1.08 if _style("build") in ["athletic", "heavy"] else 1.0)


func _width_for(layer: String) -> float:
	if layer in UPPER_LAYERS:
		return _upper_k
	if layer in LOWER_LAYERS:
		return _lower_k
	if layer == "_draw_neck":
		return _neck_k
	return 1.0


## Estreita ou alarga o desenho a partir do centro do corpo (x = 100).
func _set_width(k: float) -> void:
	draw_set_transform_matrix(_base * Transform2D(Vector2(k, 0), Vector2(0, 1), Vector2(100.0 * (1.0 - k), 0)))


func _tier(category: String) -> String:
	var option: CharacterOptionDefinition = _opt.get(category)
	return option.tier if option != null else "basic"


## Brilho de pedra: estrela de quatro pontas com miolo branco.
func _sparkle(center: Vector2, radius: float, color: Color = Color(1, 1, 1, 0.95)) -> void:
	var star := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius * 0.22, -radius * 0.22), center + Vector2(radius, 0),
		center + Vector2(radius * 0.22, radius * 0.22), center + Vector2(0, radius), center + Vector2(-radius * 0.22, radius * 0.22),
		center + Vector2(-radius, 0), center + Vector2(-radius * 0.22, -radius * 0.22)])
	draw_colored_polygon(star, color)
	draw_circle(center, radius * 0.25, Color(1, 1, 1))


## Peças exclusivas cintilam: alguns brilhos espalhados pela área da peça.
func _exclusive_shine(area: Rect2, count: int = 5) -> void:
	for i in count:
		var p := area.position + Vector2(fmod(i * 0.618 + 0.13, 1.0) * area.size.x, fmod(i * 0.382 + 0.27, 1.0) * area.size.y)
		_sparkle(p, 2.6 + fmod(i * 1.7, 2.2))


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
	return _style("headwear") in ["beanie", "durag", "bucket", "bandana"]


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
	# Cores claras pedem sombra mais leve, senão o contraste vira mancha.
	var shadow := base.darkened(lerpf(0.3, 0.17, clampf((base.v - 0.55) / 0.4, 0.0, 1.0)))
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
	if _female:
		# Maxilar mais estreito e queixo mais delicado.
		return [Vector2(100, 25), Vector2(118, 29), Vector2(128, 42), Vector2(130, 60), Vector2(128, 75), Vector2(120, 89),
			Vector2(109, 98), Vector2(100, 101), Vector2(91, 98), Vector2(80, 89), Vector2(72, 75), Vector2(70, 60),
			Vector2(72, 42), Vector2(82, 29)]
	return [Vector2(100, 24), Vector2(118, 28), Vector2(129, 42), Vector2(131, 60), Vector2(129, 76), Vector2(122, 90),
		Vector2(110, 100), Vector2(100, 103), Vector2(90, 100), Vector2(78, 90), Vector2(71, 76), Vector2(69, 60),
		Vector2(71, 42), Vector2(82, 28)]


func _draw_neck() -> void:
	var neck := _shape([Vector2(90, 92), Vector2(110, 92), Vector2(112, 118), Vector2(100, 122), Vector2(88, 118)], _skin, true, 3.0, 0.0)
	_fill(_smooth([Vector2(89, 95), Vector2(111, 95), Vector2(111, 106), Vector2(100, 111), Vector2(89, 106)]), Color(_skin.darkened(0.4), 0.35))
	_fill(_smooth([Vector2(90, 96), Vector2(110, 96), Vector2(110, 104), Vector2(100, 108), Vector2(90, 104)]), Color(_skin.darkened(0.35), 0.5))
	# Clavículas sugeridas na base do pescoço.
	for side: int in [-1, 1]:
		_curve([Vector2(100 + side * 4, 119), Vector2(100 + side * 10, 117), Vector2(100 + side * 16, 118)], Color(_skin.darkened(0.3), 0.45), 1.0)


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
		# Cílios: o traço engrossa e sobe no canto de fora (mais marcados no rosto feminino).
		_curve([c + Vector2(8.6 * side, -1.2), c + Vector2(10.8 * side, -2.6), c + Vector2(12.6 * side, -4.0)], Color(lid, 0.85), 1.5)
		if _female:
			_curve([c + Vector2(-8 * side, -1.6), c + Vector2(-3 * side, -5.2), c + Vector2(5 * side, -5.2), c + Vector2(10 * side, -0.8)], Color(lid.darkened(0.3), 1.0), 2.6)
			for k in 3:
				var root := c + Vector2((3 + k * 2.6) * side, -4.6 + k * 1.2)
				_line(PackedVector2Array([root, root + Vector2(1.8 * side, -2.4)]), Color(lid.darkened(0.3), 0.9), 1.1)
		if _style("makeup") in ["liner", "glam"]:
			var liner := _color2("makeup")
			_curve([c + Vector2(-6 * side, -3.6), c + Vector2(3 * side, -4.8), c + Vector2(9.6 * side, -0.8)], liner, 2.4)
			_curve([c + Vector2(9 * side, -0.8), c + Vector2(13.6 * side, -4.2)], liner, 2.0)
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
	# Boca: lábio superior, inferior com brilho e a linha entre eles. O rosto feminino tem lábios
	# mais cheios; batom e gloss mudam a cor e o brilho.
	var lip := _lip_color()
	var full := 1.6 if _female else 0.0
	_fill(_smooth([Vector2(90, 91), Vector2(95, 88.6 - full * 0.5), Vector2(100, 90 - full * 0.3), Vector2(105, 88.6 - full * 0.5), Vector2(110, 91), Vector2(100, 92.5)]), lip.darkened(0.15))
	_fill(_smooth([Vector2(91, 91.5), Vector2(100, 92.5), Vector2(109, 91.5), Vector2(105, 96 + full), Vector2(100, 97 + full), Vector2(95, 96 + full)]), lip)
	if _style("makeup") == "gloss":
		_fill(_smooth(_ellipse_points(Vector2(99, 94.6 + full * 0.5), Vector2(5, 1.6), 8)), Color(1, 1, 1, 0.45))
	_curve([Vector2(89.5, 91), Vector2(100, 92.6), Vector2(110.5, 91)], Color(lip.darkened(0.6), 0.9), 1.4)
	_fill(_smooth(_ellipse_points(Vector2(100, 94.5), Vector2(4, 1.1), 8)), Color(1, 1, 1, 0.22))


func _lip_color() -> Color:
	var natural := _skin.lerp(Color("#b5525a"), 0.32 if not _female else 0.45).darkened(0.12)
	match _style("makeup"):
		"lips", "glam":
			return _color("makeup")
		"gloss":
			return natural.lerp(_color("makeup"), 0.5)
	return natural


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


## Faixa de brilho do cabelo, do lado da luz: dá volume e acabamento de fio.
func _hair_sheen(color: Color) -> void:
	var sheen := Color(color.lightened(0.55), 0.28 if color.v < 0.5 else 0.2)
	_curve([Vector2(76, 36), Vector2(84, 27), Vector2(96, 23), Vector2(106, 23)], sheen, 3.2)
	_curve([Vector2(80, 39), Vector2(88, 31), Vector2(98, 28)], Color(sheen, sheen.a * 0.6), 1.6)


func _draw_back_hair() -> void:
	var color := _color("hair_color")
	if _headwear_covers_hair() and _style("hair") not in ["long", "wavy", "ponytail"]:
		return
	match _style("hair"):
		"wavy":
			var mass := []
			for i in 14:
				var t := float(i) / 13.0
				mass.append(Vector2(138 + sin(t * 9.0) * 4.0, 50 + t * 100))
			for i in 14:
				var t := 1.0 - float(i) / 13.0
				mass.append(Vector2(62 - sin(t * 9.0) * 4.0, 50 + t * 100))
			mass.push_front(Vector2(100, 18))
			_shape(mass, color, true, 7.0, 0.14)
			for k in 4:
				_curve([Vector2(66 + k * 3, 80), Vector2(60 + k * 3, 110), Vector2(66 + k * 3, 140)], Color(color.darkened(0.3), 0.5), 1.2)
				_curve([Vector2(134 - k * 3, 80), Vector2(140 - k * 3, 110), Vector2(134 - k * 3, 140)], Color(color.darkened(0.3), 0.5), 1.2)
		"ponytail":
			# Rabo preso atrás, caindo sobre o ombro.
			_shape([Vector2(116, 30), Vector2(132, 26), Vector2(144, 46), Vector2(146, 90), Vector2(140, 132), Vector2(130, 140), Vector2(132, 96), Vector2(126, 54)], color, true, 5.0, 0.18)
			for k in 3:
				_curve([Vector2(130 + k * 4, 50), Vector2(136 + k * 3, 90), Vector2(134 + k * 2, 132)], Color(color.lightened(0.25), 0.35), 1.2)
			_shape(_ellipse_points(Vector2(126, 34), Vector2(5, 4), 8), color.darkened(0.5), true, 1.0, 0.0)
		"bob":
			_shape([Vector2(66, 50), Vector2(76, 26), Vector2(100, 16), Vector2(124, 26), Vector2(134, 50), Vector2(138, 98), Vector2(124, 104),
				Vector2(100, 96), Vector2(76, 104), Vector2(62, 98)], color, true, 7.0, 0.15)
		"spacebuns":
			for side: int in [-1, 1]:
				_shape(_ellipse_points(Vector2(100 + side * 22, 18), Vector2(14, 12), 12), color, true, 4.0, 0.2)
				_curve([Vector2(100 + side * 14, 14), Vector2(100 + side * 22, 10), Vector2(100 + side * 30, 16)], Color(color.lightened(0.3), 0.4), 1.4)
		"puff":
			var puff := []
			for i in 14:
				var angle := TAU * i / 14.0
				var r := 20.0 + (3.0 if i % 2 == 0 else 0.0)
				puff.append(Vector2(100, 15) + Vector2(cos(angle) * r * 1.0, sin(angle) * r * 0.75))
			_shape(puff, color, true, 6.0, 0.15)
			for i in 18:
				draw_circle(Vector2(100, 15) + Vector2(cos(i * 2.4) * (i % 9) * 2.2, sin(i * 2.4) * (i % 7) * 1.8), 1.3, Color(color.lightened(0.25), 0.3))
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
			_hair_sheen(color)
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
			_hair_sheen(color)
			_curve([Vector2(106, 20), Vector2(104, 30), Vector2(100, 42)], Color(shade, 0.8), 1.4)
			for side: int in [-1, 1]:
				_shape([Vector2(100 + side * 30, 44), Vector2(100 + side * 33, 70), Vector2(100 + side * 34, 98), Vector2(100 + side * 28, 96), Vector2(100 + side * 26, 66)], color, true, 3.0, 0.15)
		"fade", "hightop":
			# Laterais raspadas em degradê e volume só em cima.
			var sides := _smooth(_hairline_cap(3.0))
			for i in 90:
				var p := Vector2(68 + fmod(i * 41.3, 64.0), 34 + fmod(i * 17.7, 30.0))
				if Geometry2D.is_point_in_polygon(p, sides):
					draw_circle(p, 0.7, Color(color, clampf(0.85 - (p.y - 34) / 34.0, 0.15, 0.85)))
			if _style("hair") == "hightop":
				var box := _shape([Vector2(74, 44), Vector2(72, 16), Vector2(76, 4), Vector2(100, 1), Vector2(124, 4), Vector2(128, 16), Vector2(126, 44), Vector2(100, 40)], color, true, 6.0, 0.18)
				for i in 30:
					draw_circle(Vector2(76 + fmod(i * 13.7, 48.0), 4 + fmod(i * 7.9, 38.0)), 1.0, Color(color.lightened(0.18), 0.16))
			else:
				_shape([Vector2(74, 42), Vector2(76, 26), Vector2(90, 18), Vector2(110, 18), Vector2(124, 26), Vector2(126, 42), Vector2(112, 38), Vector2(88, 38)], color, true, 4.0, 0.2)
				_hair_sheen(color)
		"sidepart":
			_shape(_hairline_cap(8.0), color, true, 5.0, 0.2)
			_shape([Vector2(86, 22), Vector2(110, 16), Vector2(128, 26), Vector2(132, 40), Vector2(118, 32), Vector2(96, 30), Vector2(80, 38)], color.lightened(0.04), true, 3.0, 0.25)
			_curve([Vector2(86, 22), Vector2(84, 30), Vector2(82, 40)], Color(_skin, 0.9), 1.4)
			_hair_sheen(color)
		"ponytail", "spacebuns", "puff":
			# Cabelo puxado para trás: rente, com as linhas do penteado e repartido.
			_shape(_hairline_cap(5.0, _style("hair") == "spacebuns"), color, true, 4.0, 0.25)
			for k in 3:
				_curve([Vector2(80 + k * 8, 40), Vector2(88 + k * 8, 27), Vector2(102 + k * 8, 22)], Color(color.darkened(0.3), 0.35), 1.0)
			_hair_sheen(color)
		"bob":
			_shape(_hairline_cap(10.0), color, true, 4.0, 0.2)
			# Franja reta na testa.
			_shape([Vector2(72, 44), Vector2(78, 26), Vector2(100, 22), Vector2(122, 26), Vector2(128, 44), Vector2(114, 48), Vector2(100, 49), Vector2(86, 48)], color, true, 4.0, 0.25)
			for x in range(80, 124, 6):
				_curve([Vector2(x, 34), Vector2(x + 1, 46)], Color(color.darkened(0.35), 0.5), 1.0)
			_hair_sheen(color)
		"wavy":
			_shape(_hairline_cap(10.0, true), color, true, 5.0, 0.2)
			_hair_sheen(color)
			for side: int in [-1, 1]:
				var strand := []
				for i in 8:
					strand.append(Vector2(100 + side * (36 + sin(i * 1.3) * 2.5), 44 + i * 9))
				for i in 8:
					strand.append(Vector2(100 + side * (30 + sin((7 - i) * 1.3) * 2.0), 107 - i * 9))
				_shape(strand, color, true, 3.0, 0.15)
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
			for i in 160:
				var p := Vector2(72.0 + fmod(i * 37.71, 56.0), 66.0 + fmod(i * 23.37 + float(i * i % 7), 42.0))
				if Geometry2D.is_point_in_polygon(p, band):
					draw_circle(p, 0.6, Color(dots, 0.7))
		"mustache":
			_shape(mustache, color, true, 1.5, 0.2)
		"goatee":
			_shape(mustache, color, true, 1.5, 0.2)
			_shape([Vector2(93, 97), Vector2(100, 96), Vector2(107, 97), Vector2(106, 106), Vector2(100, 110), Vector2(94, 106)], color, true, 2.0, 0.2)
		"patch":
			_shape([Vector2(97, 99), Vector2(103, 99), Vector2(100, 106)], color, true, 1.0, 0.1)
		"anchor":
			_shape(mustache, color, true, 1.5, 0.2)
			_shape([Vector2(92, 99), Vector2(108, 99), Vector2(110, 103), Vector2(102, 104), Vector2(100, 112), Vector2(98, 104), Vector2(90, 103)], color, true, 2.0, 0.2)
		"chinstrap":
			var strap := _smooth([Vector2(70, 66), Vector2(74, 84), Vector2(84, 96), Vector2(100, 104), Vector2(116, 96), Vector2(126, 84), Vector2(130, 66)], false, 6)
			_line(strap, color.darkened(0.3), 5.5)
			_line(strap, color, 4.0)
		"short", "medium", "full", "long":
			var length: float = {"short": 0.0, "medium": 3.0, "full": 6.0, "long": 26.0}[_style("beard")]
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
	if _female:
		# Cintura marcada e quadril um pouco mais largo.
		return [Vector2(58, 126), Vector2(78, 116), Vector2(100, 118), Vector2(122, 116), Vector2(142, 126), Vector2(145, 152),
			Vector2(132, 202), Vector2(141, 252), Vector2(100, 256), Vector2(59, 252), Vector2(68, 202), Vector2(55, 152)]
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
		"tshirt", "graphic", "polo", "monogram", "iced_tee":
			return 0.32
		"crop":
			return 0.28
		"oversized":
			return 0.47
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
		_draw_sleeves(color, detail, _sleeve_to(), 4.0 if style == "oversized" else (2.0 if style.begins_with("hoodie") else 0.0))
	match style:
		"tank":
			_shape([Vector2(62, 128), Vector2(72, 122), Vector2(84, 122), Vector2(100, 140), Vector2(116, 122), Vector2(128, 122),
				Vector2(138, 128), Vector2(140, 160), Vector2(137, 252), Vector2(100, 256), Vector2(63, 252), Vector2(60, 160)], _skin, true, 4.0, 0.15)
			var tank := _shape([Vector2(70, 132), Vector2(80, 122), Vector2(86, 124), Vector2(100, 146), Vector2(114, 124), Vector2(120, 122),
				Vector2(130, 132), Vector2(136, 166), Vector2(137, 252), Vector2(100, 256), Vector2(63, 252), Vector2(64, 166)], color, true, 6.0, 0.15)
			_curve([Vector2(86, 125), Vector2(100, 146), Vector2(114, 125)], detail, 2.2)
		"crop":
			# Barriga à mostra: pele do tronco e o top curto por cima, com umbigo.
			_shape(_torso_points(), _skin, true, 5.0, 0.15)
			draw_circle(Vector2(100, 226), 1.4, _skin.darkened(0.4))
			_curve([Vector2(84, 214), Vector2(100, 220), Vector2(116, 214)], Color(_skin.darkened(0.25), 0.5), 1.0)
			var crop := _shape([Vector2(58, 126), Vector2(78, 116), Vector2(122, 116), Vector2(142, 126), Vector2(145, 152), Vector2(134, 196),
				Vector2(100, 200), Vector2(66, 196), Vector2(55, 152)], color, true, 6.0, 0.15)
			_fill(_smooth([Vector2(86, 118), Vector2(100, 116), Vector2(114, 118), Vector2(110, 130), Vector2(100, 134), Vector2(90, 130)]), _skin)
			_curve([Vector2(85, 118), Vector2(90, 130), Vector2(100, 135), Vector2(110, 130), Vector2(115, 118)], detail, 3.0)
			_curve([Vector2(66, 194), Vector2(100, 198), Vector2(134, 194)], Color(color.darkened(0.3), 0.8), 1.6)
		"oversized":
			# Ombro caído, corpo largo e barra comprida: o caimento solto da peça.
			var big := _shape([Vector2(50, 130), Vector2(78, 116), Vector2(122, 116), Vector2(150, 130), Vector2(152, 162), Vector2(147, 212),
				Vector2(148, 262), Vector2(100, 267), Vector2(52, 262), Vector2(53, 212), Vector2(48, 162)], color, true, 8.0, 0.14)
			_fill(_smooth([Vector2(86, 118), Vector2(100, 116), Vector2(114, 118), Vector2(110, 131), Vector2(100, 135), Vector2(90, 131)]), _skin)
			_curve([Vector2(84, 118), Vector2(90, 131), Vector2(100, 136), Vector2(110, 131), Vector2(116, 118)], color.darkened(0.2), 4.0)
			for fold: Array in [[Vector2(70, 150), Vector2(78, 200), Vector2(74, 250)], [Vector2(130, 156), Vector2(124, 206), Vector2(128, 254)], [Vector2(98, 200), Vector2(102, 230), Vector2(99, 262)]]:
				_curve(fold, Color(color.darkened(0.3), 0.5), 1.4)
			_curve([Vector2(52, 258), Vector2(100, 264), Vector2(148, 258)], Color(color.darkened(0.35), 0.7), 1.2)
		"hoodie", "hoodie_designer":
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
			if style == "hoodie_designer":
				# Grife: faixas e ponteiras douradas e um emblema no peito.
				_line(PackedVector2Array([Vector2(59, 239), Vector2(141, 239)]), detail, 2.4)
				_shape([Vector2(116, 150), Vector2(124, 158), Vector2(116, 166), Vector2(108, 158)], detail, true, 1.5, 0.35)
				_fill(_smooth([Vector2(116, 154), Vector2(120, 158), Vector2(116, 162), Vector2(112, 158)]), detail.lightened(0.4))
				for x: int in [94, 106]:
					draw_rect(Rect2(x - 1.6, 165, 3.2, 6), detail)
		_:
			var torso := _shape(_torso_points(), color, true, 7.0, 0.15)
			match style:
				"tshirt", "graphic", "monogram", "iced_tee", "polo":
					_fill(_smooth([Vector2(86, 118), Vector2(100, 116), Vector2(114, 118), Vector2(110, 130), Vector2(100, 134), Vector2(90, 130)]), _skin)
					_curve([Vector2(85, 118), Vector2(90, 130), Vector2(100, 135), Vector2(110, 130), Vector2(115, 118)], detail if style == "tshirt" else color.darkened(0.2), 3.0)
					_curve([Vector2(72, 170), Vector2(80, 190), Vector2(78, 214)], Color(color.darkened(0.25), 0.55), 1.2)
					_curve([Vector2(126, 176), Vector2(122, 198), Vector2(126, 224)], Color(color.darkened(0.25), 0.55), 1.2)
					match style:
						"tshirt":
							_fill(_smooth(_ellipse_points(Vector2(100, 170), Vector2(13, 9), 10)), Color(detail, 0.85))
						"graphic":
							_graphic_print(detail)
						"monogram":
							_monogram(torso, detail)
						"iced_tee":
							_iced_print(detail)
						"polo":
							_polo_collar(color, detail)
				"silk":
					_silk(torso, color, detail)
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
	if _female and style != "tank":
		_bust_shading(color)
	if _tier("top") == "exclusive" and style != "iced_tee":
		_exclusive_shine(Rect2(66, 140, 68, 100), 5)


## Estampa de camiseta: emblema com estrela e duas linhas de "texto".
func _graphic_print(detail: Color) -> void:
	_shape([Vector2(82, 150), Vector2(118, 150), Vector2(118, 186), Vector2(82, 186)], detail.darkened(0.55), true, 0.0, 0.0)
	var star := []
	for i in 10:
		var angle := -PI / 2 + TAU * i / 10.0
		star.append(Vector2(100, 166) + Vector2(cos(angle), sin(angle)) * (11.0 if i % 2 == 0 else 4.6))
	_fill(PackedVector2Array(star), detail)
	for y: int in [192, 198]:
		_line(PackedVector2Array([Vector2(86, y), Vector2(114, y)]), Color(detail, 0.8), 2.0)


## Padrão de grife: losangos e círculos repetidos por toda a peça.
func _monogram(torso: PackedVector2Array, detail: Color) -> void:
	for row in 9:
		for col in 7:
			var p := Vector2(62 + col * 13 + (6 if row % 2 else 0), 138 + row * 13)
			if not Geometry2D.is_point_in_polygon(p, torso):
				continue
			if (row + col) % 2 == 0:
				_fill(PackedVector2Array([p + Vector2(0, -3.4), p + Vector2(3.4, 0), p + Vector2(0, 3.4), p + Vector2(-3.4, 0)]), Color(detail, 0.75))
			else:
				draw_arc(p, 2.6, 0, TAU, 12, Color(detail, 0.7), 1.0, true)


## Camiseta cravejada: uma coroa de pedras no peito, cintilando.
func _iced_print(detail: Color) -> void:
	var crown := [Vector2(80, 186), Vector2(80, 160), Vector2(90, 172), Vector2(100, 152), Vector2(110, 172), Vector2(120, 160), Vector2(120, 186)]
	var path := _smooth(crown, false, 5)
	for i in path.size():
		draw_circle(path[i], 1.9, detail)
		draw_circle(path[i] + Vector2(-0.5, -0.5), 0.7, Color(1, 1, 1))
	for x in range(82, 120, 4):
		draw_circle(Vector2(x, 186), 1.6, detail)
	_exclusive_shine(Rect2(70, 140, 60, 60), 4)


func _polo_collar(color: Color, detail: Color) -> void:
	for side: int in [-1, 1]:
		_shape([Vector2(100, 120), Vector2(100 + side * 16, 114), Vector2(100 + side * 19, 124), Vector2(100 + side * 5, 134)], detail, true, 1.5, 0.15)
	_shape([Vector2(97, 128), Vector2(103, 128), Vector2(103, 156), Vector2(97, 156)], color.darkened(0.1), true, 1.0, 0.0)
	for y: int in [138, 150]:
		draw_circle(Vector2(100, y), 1.5, detail)


## Seda: gola aberta, faixas de brilho do tecido e botões dourados.
func _silk(torso: PackedVector2Array, color: Color, detail: Color) -> void:
	_fill(_smooth([Vector2(88, 118), Vector2(112, 118), Vector2(100, 150)]), _skin)
	for side: int in [-1, 1]:
		_shape([Vector2(100, 150), Vector2(100 + side * 13, 116), Vector2(100 + side * 22, 120), Vector2(100 + side * 6, 156)], color.lightened(0.08), true, 1.5, 0.3)
	for i in 5:
		var x := 58.0 + i * 20.0
		_clipped_line(Vector2(x, 120), Vector2(x + 30, 256), torso, Color(1, 1, 1, 0.12), 7.0)
		_clipped_line(Vector2(x + 6, 120), Vector2(x + 36, 256), torso, Color(1, 1, 1, 0.06), 3.0)
	_line(PackedVector2Array([Vector2(100, 156), Vector2(100, 254)]), Color(color.darkened(0.4), 0.9), 1.2)
	for y: int in [172, 196, 220, 244]:
		draw_circle(Vector2(103, y), 2.0, detail)
		draw_circle(Vector2(102.4, y - 0.6), 0.7, Color(1, 1, 1, 0.8))


func _bust_shading(color: Color) -> void:
	for side: int in [-1, 1]:
		_curve([Vector2(100 + side * 26, 150), Vector2(100 + side * 20, 166), Vector2(100 + side * 6, 168)], Color(color.darkened(0.35), 0.45), 1.6)
		_fill(_smooth(_ellipse_points(Vector2(100 + side * 16, 152), Vector2(9, 6), 8)), Color(color.lightened(0.3), 0.1))


func _draw_jacket() -> void:
	if not _has_jacket():
		return
	var style := _style("jacket")
	var color := _color("jacket")
	var detail := _color2("jacket")
	var bulk: float = {"puffer": 5.0, "fur": 6.0, "trench": 3.0}.get(style, 2.5)
	# Casacos longos descem até a coxa.
	var hem := 302.0 if style in ["trench", "fur"] else 256.0
	_draw_sleeves(detail if style == "varsity" else color, detail if style in ["bomber", "varsity"] else color.darkened(0.12), 1.0, bulk)
	if style == "fur":
		for side: int in [-1, 1]:
			_fur_edge(_arm_points(side, 0.86, 1.0, bulk + 3.0), color)
	if style == "track":
		for side: int in [-1, 1]:
			_curve([Vector2(100 + side * 52, 128), Vector2(100 + side * 63, 190), Vector2(100 + side * 63, 236)], detail, 2.4)
	for side: int in [-1, 1]:
		var panel := [Vector2(100 + side * 13, 116), Vector2(100 + side * 26, 116), Vector2(100 + side * (44 + bulk), 126),
			Vector2(100 + side * (48 + bulk), 154), Vector2(100 + side * (41 + bulk), 204), Vector2(100 + side * (42 + bulk), hem),
			Vector2(100 + side * 12, hem + 2), Vector2(100 + side * 10, 200), Vector2(100 + side * 9, 140)]
		if style == "fur":
			_fur_edge(panel, color)
		var shape := _shape(panel, color, true, 7.0, 0.2 if style in ["leather", "studded"] else 0.14)
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
			"leather", "studded":
				_shape([Vector2(100 + side * 12, 118), Vector2(100 + side * 26, 118), Vector2(100 + side * 30, 166), Vector2(100 + side * 14, 176)], detail if style == "leather" else color.lightened(0.1), true, 2.0, 0.25)
				_curve([Vector2(100 + side * 30, 136), Vector2(100 + side * 36, 190), Vector2(100 + side * 34, 240)], Color(1, 1, 1, 0.18), 3.0)
				if style == "studded":
					# Tachas nos ombros e na lapela, cada uma com o seu brilho.
					for i in 6:
						for row in 2:
							var stud := Vector2(100 + side * (28 + i * 3.6), 128 + row * 7 + i * 1.6)
							draw_circle(stud, 1.8, detail)
							draw_circle(stud + Vector2(-0.6, -0.6), 0.6, Color(1, 1, 1))
					for i in 7:
						var stud := Vector2(100 + side * (14 + i * 2.4), 122 + i * 7.4)
						draw_circle(stud, 1.6, detail)
			"track":
				_clipped_line(Vector2(100 + side * 40, 130), Vector2(100 + side * 44, 256), shape, detail, 3.0)
				_clipped_line(Vector2(100 + side * 34, 130), Vector2(100 + side * 38, 256), shape, Color(detail, 0.5), 1.4)
			"trench":
				_shape([Vector2(100 + side * 12, 118), Vector2(100 + side * 30, 120), Vector2(100 + side * 26, 150), Vector2(100 + side * 13, 168)], color.lightened(0.08), true, 1.5, 0.2)
				for y: int in [176, 226]:
					draw_circle(Vector2(100 + side * 22, y), 2.4, detail)
					draw_circle(Vector2(100 + side * 22 - 0.6, y - 0.6), 0.8, Color(1, 1, 1, 0.5))
				_curve([Vector2(100 + side * 36, 214), Vector2(100 + side * 30, 260), Vector2(100 + side * 34, 300)], Color(color.darkened(0.3), 0.6), 1.2)
			"fur":
				for i in 26:
					var p := Vector2(100 + side * (14 + fmod(i * 7.3, 34.0)), 126 + fmod(i * 23.7, 170.0))
					if Geometry2D.is_point_in_polygon(p, shape):
						_curve([p, p + Vector2(side * 2.5, 5), p + Vector2(side * 1.0, 10)], Color(color.lightened(0.25), 0.45), 1.6)
			"puffer":
				for i in 6:
					var y := 140 + i * 20
					_clipped_line(Vector2(100 + side * 4, y), Vector2(100 + side * 60, y), shape, Color(detail, 0.85), 1.6)
					_clipped_line(Vector2(100 + side * 4, y + 9), Vector2(100 + side * 60, y + 9), shape, Color(1, 1, 1, 0.14), 4.0)
	if style in ["bomber", "varsity", "puffer", "track"]:
		_shape([Vector2(80, 112), Vector2(120, 112), Vector2(124, 120), Vector2(76, 120)], (detail if style == "bomber" else color).darkened(0.2), true, 1.5, 0.0)
	if style in ["leather", "puffer", "track", "studded"]:
		_line(PackedVector2Array([Vector2(110, 120), Vector2(111, 256)]), Color(0.75, 0.75, 0.78), 1.4)
	if style == "trench":
		# Cinto amarrado na cintura, com fivela.
		_shape([Vector2(57, 198), Vector2(143, 198), Vector2(143, 208), Vector2(57, 208)], detail, true, 1.5, 0.15)
		_shape([Vector2(92, 196), Vector2(108, 196), Vector2(108, 210), Vector2(92, 210)], detail.darkened(0.2), true, 1.5, 0.0)
		draw_rect(Rect2(95, 199, 10, 8), color.darkened(0.2))
		_shape([Vector2(108, 206), Vector2(116, 206), Vector2(122, 236), Vector2(114, 238)], detail, true, 1.5, 0.0)
	if style == "fur":
		_fur_edge([Vector2(76, 116), Vector2(100, 108), Vector2(124, 116), Vector2(118, 134), Vector2(100, 128), Vector2(82, 134)], color.lightened(0.05))
		_shape([Vector2(76, 116), Vector2(100, 108), Vector2(124, 116), Vector2(118, 134), Vector2(100, 128), Vector2(82, 134)], color.lightened(0.05), true, 2.0, 0.2)
	if _tier("jacket") == "exclusive":
		_exclusive_shine(Rect2(56, 130, 88, 140), 6)


## Pelo: tufos ao longo da borda da peça, que quebram o contorno liso.
func _fur_edge(points: Array, color: Color) -> void:
	var outline := _smooth(points)
	for i in range(0, outline.size(), 2):
		draw_circle(outline[i], 4.4, color.darkened(0.15))
	for i in range(1, outline.size(), 2):
		draw_circle(outline[i], 3.6, color)


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
	if style == "skirt":
		# Pernas à mostra e a saia evasê por cima, com pregas.
		for side: int in [-1, 1]:
			_shape(_leg_points(side, 280, 374), _skin, true, 4.0, 0.15)
		var skirt := _shape([Vector2(62, 244), Vector2(138, 244), Vector2(146, 306), Vector2(100, 310), Vector2(54, 306)], color, true, 6.0, 0.15)
		for x: int in [70, 85, 100, 115, 130]:
			_clipped_line(Vector2(x + (x - 100) * 0.05, 256), Vector2(x + (x - 100) * 0.18, 310), skirt, Color(color.darkened(0.35), 0.7), 1.2)
		_shape([Vector2(62, 244), Vector2(138, 244), Vector2(139, 254), Vector2(61, 254)], detail, true, 1.5, 0.0)
		return
	if style == "shorts":
		for side: int in [-1, 1]:
			_shape(_leg_points(side, 300, 372), _skin, true, 4.0, 0.15)
			_shape([Vector2(100 + side * 9, 354), Vector2(100 + side * 27, 354), Vector2(100 + side * 27, 372), Vector2(100 + side * 9, 372)], Color(0.94, 0.94, 0.95), true, 2.0, 0.0)
	var bottom := 316.0 if style == "shorts" else 374.0
	var flare: float = {"cargo": 4.0, "camo": 4.0, "baggy": 8.0, "sweatpants": -2.0, "track": -1.0}.get(style, 0.0)
	if style == "baggy":
		bottom = 378.0
	for side: int in [-1, 1]:
		var leg := _shape(_leg_points(side, 244, bottom, flare), color, true, 6.0, 0.14)
		match style:
			"baggy":
				# Barra empilhada sobre o tênis e vincos largos.
				for k in 3:
					_curve([Vector2(100 + side * 6, 352 + k * 7), Vector2(100 + side * 22, 348 + k * 7), Vector2(100 + side * 36, 353 + k * 7)], Color(color.darkened(0.35), 0.7), 1.3)
				_clipped_line(Vector2(100 + side * 24, 260), Vector2(100 + side * 28, 340), leg, Color(1, 1, 1, 0.1), 5.0)
			"track":
				_clipped_line(Vector2(100 + side * 36, 250), Vector2(100 + side * 28, 374), leg, detail, 2.6)
				_clipped_line(Vector2(100 + side * 32, 250), Vector2(100 + side * 25, 374), leg, Color(detail, 0.6), 1.2)
				_shape([Vector2(100 + side * 9, 364), Vector2(100 + side * 27, 364), Vector2(100 + side * 26, 374), Vector2(100 + side * 9, 374)], color.darkened(0.2), true, 1.5, 0.0)
			"camo":
				for i in 9:
					var blob := _smooth(_ellipse_points(Vector2(100 + side * (12 + fmod(i * 9.7, 22.0)), 256 + fmod(i * 31.3, 112.0)), Vector2(7 + fmod(i * 3.1, 5.0), 4 + fmod(i * 1.7, 3.0)), 8))
					for piece: PackedVector2Array in Geometry2D.intersect_polygons(blob, leg):
						_fill(piece, detail if i % 2 == 0 else color.darkened(0.3))
				_shape([Vector2(100 + side * 26, 284), Vector2(100 + side * 38, 284), Vector2(100 + side * 38, 316), Vector2(100 + side * 26, 316)], color.darkened(0.1), true, 2.0, 0.1)
			"leather_pants":
				_clipped_line(Vector2(100 + side * 22, 250), Vector2(100 + side * 18, 370), leg, Color(1, 1, 1, 0.22), 3.0)
				_clipped_line(Vector2(100 + side * 26, 250), Vector2(100 + side * 22, 370), leg, Color(1, 1, 1, 0.08), 6.0)
				for k in 2:
					_curve([Vector2(100 + side * 10, 312 + k * 6), Vector2(100 + side * 20, 308 + k * 6), Vector2(100 + side * 30, 312 + k * 6)], Color(color.lightened(0.3), 0.4), 1.0)
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
			"hightop", "retro", "designer":
				var sole_h := 12.0 if style == "designer" else 8.0
				if style == "hightop":
					# Cano alto até o tornozelo, com remendo redondo.
					_shape([Vector2(cx - side * 12, 350), Vector2(cx + side * 10, 350), Vector2(cx + side * 13, 368), Vector2(cx - side * 14, 370)], color, true, 3.0, 0.2)
					_shape(_ellipse_points(Vector2(cx - side * 6, 360), Vector2(4, 4), 10), sole, true, 1.0, 0.2)
				_shape([Vector2(cx - side * 13, 366), Vector2(cx + side * 12, 366), Vector2(cx + side * 18, 376), Vector2(cx + side * 20, 386 - sole_h + 4), Vector2(cx - side * 18, 386 - sole_h + 4), Vector2(cx - side * 17, 374)], color, true, 4.0, 0.25)
				_shape([Vector2(cx - side * 19, 390 - sole_h), Vector2(cx + side * 21, 390 - sole_h), Vector2(cx + side * 22, 391), Vector2(cx - side * 20, 391)], Color(0.97, 0.97, 0.97) if style != "designer" else sole.lerp(Color.WHITE, 0.85), true, 1.5, 0.0)
				match style:
					"retro":
						_shape([Vector2(cx + side * 8, 368), Vector2(cx + side * 18, 376), Vector2(cx + side * 20, 382), Vector2(cx + side * 6, 382)], sole, true, 1.5, 0.2)
						_shape([Vector2(cx - side * 13, 366), Vector2(cx - side * 6, 366), Vector2(cx - side * 6, 382), Vector2(cx - side * 17, 380)], sole, true, 1.5, 0.2)
						_curve([Vector2(cx - side * 10, 380), Vector2(cx + side * 2, 374), Vector2(cx + side * 14, 372)], sole.darkened(0.2), 2.6)
					"designer":
						_line(PackedVector2Array([Vector2(cx - side * 19, 384), Vector2(cx + side * 21, 384)]), sole, 2.4)
						_line(PackedVector2Array([Vector2(cx - side * 10, 372), Vector2(cx + side * 10, 372)]), sole, 2.0)
						if _tier("shoes") == "exclusive":
							for k in 3:
								_sparkle(Vector2(cx + side * (-8 + k * 8), 370 + k % 2 * 4), 2.6)
					_:
						_line(PackedVector2Array([Vector2(cx - side * 6, 354), Vector2(cx + side * 6, 356)]), Color(0.95, 0.95, 0.95, 0.85), 1.0)
				for k in 3:
					_line(PackedVector2Array([Vector2(cx - side * 6, 368 + k * 3), Vector2(cx + side * 6, 368 + k * 3)]), Color(0.95, 0.95, 0.95, 0.85), 1.0)
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
		match option.style:
			"cuban":
				# Cordão grosso: elos ovais grandes, cada um com brilho.
				var links := _smooth([Vector2(82, 118), Vector2(88, 136), Vector2(100, 144), Vector2(112, 136), Vector2(118, 118)], false, 5)
				for i in links.size():
					var p := links[i]
					_shape(_ellipse_points(p, Vector2(3.6, 2.6), 8), option.color if i % 2 == 0 else option.color.darkened(0.15), true, 1.0, 0.3)
					draw_circle(p + Vector2(-1, -0.8), 0.8, Color(1, 1, 1, 0.8))
				continue
			"iced":
				var stones := _smooth([Vector2(80, 118), Vector2(88, 140), Vector2(100, 150), Vector2(112, 140), Vector2(120, 118)], false, 7)
				for p in stones:
					draw_circle(p, 2.0, option.color)
					draw_circle(p + Vector2(-0.6, -0.6), 0.8, Color(1, 1, 1))
				# Pingente grande cravejado.
				_shape(_ellipse_points(Vector2(100, 162), Vector2(10, 10), 12), option.color, true, 1.5, 0.3)
				for i in 8:
					var angle := TAU * i / 8.0
					draw_circle(Vector2(100, 162) + Vector2(cos(angle), sin(angle)) * 6.0, 1.6, Color(1, 1, 1, 0.95))
				_sparkle(Vector2(100, 162), 5.0)
				_sparkle(Vector2(90, 146), 3.0)
				continue
			"pearls":
				var beads := _smooth([Vector2(84, 118), Vector2(90, 132), Vector2(100, 138), Vector2(110, 132), Vector2(116, 118)], false, 4)
				for p in beads:
					draw_circle(p, 2.3, option.color.darkened(0.12))
					draw_circle(p + Vector2(-0.4, -0.4), 1.8, option.color)
					draw_circle(p + Vector2(-0.8, -0.9), 0.7, Color(1, 1, 1, 0.95))
				continue
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
		"bandana":
			# Lenço amarrado: cobre o topo e o nó fica atrás, com as pontas soltas.
			_shape([Vector2(128, 46), Vector2(138, 50), Vector2(148, 66), Vector2(140, 70), Vector2(134, 58)], color.darkened(0.1), true, 2.0, 0.1)
			_shape([Vector2(130, 50), Vector2(142, 54), Vector2(146, 78), Vector2(136, 74)], color.darkened(0.05), true, 2.0, 0.1)
			var cloth := _shape([Vector2(66, 54), Vector2(68, 32), Vector2(82, 17), Vector2(100, 13), Vector2(118, 17), Vector2(132, 32), Vector2(134, 54),
				Vector2(100, 46)], color, true, 5.0, 0.2)
			for i in 14:
				var p := Vector2(74 + fmod(i * 17.3, 52.0), 22 + fmod(i * 11.9, 24.0))
				if Geometry2D.is_point_in_polygon(p, cloth):
					draw_arc(p, 2.2, 0, PI * 1.5, 8, Color(detail, 0.85), 1.0, true)
					draw_circle(p, 0.8, Color(detail, 0.9))
			_curve([Vector2(66, 52), Vector2(100, 44), Vector2(134, 52)], Color(detail, 0.8), 1.6)
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
			"hoops":
				for side: int in [-1, 1]:
					draw_arc(Vector2(100 + side * 32, 80), 5.0, 0, TAU, 18, option.color.darkened(0.3), 2.6, true)
					draw_arc(Vector2(100 + side * 32, 80), 5.0, PI, TAU, 10, option.color, 1.6, true)
			"earrings":
				for side: int in [-1, 1]:
					draw_circle(Vector2(100 + side * 32, 75), 2.6, option.color)
					draw_circle(Vector2(100 + side * 32 - 0.8, 74.2), 0.9, Color(1, 1, 1, 0.9))


## Pulseira (pulso direito) e anéis (nas duas mãos).
func _draw_wrist() -> void:
	for option in _accessories():
		match option.style:
			"bracelet":
				_shape([Vector2(145, 236), Vector2(161, 236), Vector2(161, 242), Vector2(145, 242)], option.color, true, 1.2, 0.35)
				for x in range(147, 160, 3):
					draw_circle(Vector2(x, 239), 0.8, option.color2)
			"rings":
				for side: int in [-1, 1]:
					var wrist := Vector2(100 + side * 54, 244)
					for k in 2:
						var p := wrist + Vector2(-2 + k * 3.5, 15)
						draw_arc(p, 1.8, 0, TAU, 10, option.color, 1.4, true)
						draw_circle(p + Vector2(0, -1.6), 0.9, option.color2)


## Bolsa transversal: alça do ombro ao quadril e a bolsinha na lateral.
func _draw_bag() -> void:
	for option in _accessories():
		if option.style != "bag":
			continue
		_line(PackedVector2Array([Vector2(78, 120), Vector2(138, 226)]), option.color.darkened(0.3), 4.0)
		_line(PackedVector2Array([Vector2(78, 120), Vector2(138, 226)]), option.color, 2.6)
		_shape([Vector2(124, 216), Vector2(152, 216), Vector2(154, 240), Vector2(122, 240)], option.color, true, 3.0, 0.2)
		_line(PackedVector2Array([Vector2(124, 224), Vector2(152, 224)]), option.color.darkened(0.4), 1.2)
		draw_rect(Rect2(134, 222, 8, 5), option.color2)


func _draw_watch() -> void:
	for option in _accessories():
		if option.style == "watch":
			_shape([Vector2(39, 234), Vector2(55, 234), Vector2(55, 242), Vector2(39, 242)], option.color, true, 1.5, 0.3)
			_shape(_ellipse_points(Vector2(47, 238), Vector2(5, 5), 10), option.color2, true, 1.0, 0.0)
			draw_circle(Vector2(45.5, 236.5), 1.2, Color(1, 1, 1, 0.6))
			if option.tier == "exclusive":
				_sparkle(Vector2(42, 234), 3.0)
				_sparkle(Vector2(53, 241), 2.2)
