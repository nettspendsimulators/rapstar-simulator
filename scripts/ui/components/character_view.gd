class_name CharacterView
extends Control
## Desenha o personagem em camadas a partir da aparência: corpo e pele, calça, calçado, parte de
## cima, jaqueta, rosto, olhos, sobrancelhas, barba, cabelo, cabeça e acessórios.
## Cada camada lê só a sua peça (estilo e cores vêm de data/character.tres), então novas peças
## com um estilo existente não mudam este script; um estilo novo é uma função de desenho nova.
## Coordenadas em um quadro de 200 x 400, ajustado ao tamanho do controle.

const BASE := Vector2(200, 400)
const HEAD := Vector2(100, 80)
const HEAD_RADIUS := Vector2(36, 44)

var appearance: CharacterAppearance:
	set(value):
		appearance = value
		queue_redraw()

var _opt: Dictionary = {}


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var scale_factor := minf(size.x / BASE.x, size.y / BASE.y)
	if scale_factor <= 0.0:
		return
	var offset := (size - BASE * scale_factor) / 2.0
	draw_set_transform(offset, 0.0, Vector2(scale_factor, scale_factor))
	_resolve()
	var skin: Color = _color("skin")
	_draw_back_hair()
	_draw_hood_back()
	_draw_legs(skin)
	_draw_shoes()
	_draw_arms(skin)
	_draw_top(skin)
	_draw_jacket()
	_draw_neck(skin)
	_draw_chain()
	_draw_head(skin)
	_draw_eyes()
	_draw_brows()
	_draw_mouth(skin)
	_draw_beard()
	_draw_front_hair()
	_draw_headwear()
	_draw_face_accessories()
	_draw_watch()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---- peças

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


func _has_hood() -> bool:
	return _style("top") == "hoodie"


func _headwear_covers_hair() -> bool:
	return _style("headwear") in ["beanie", "durag", "bucket"]


# ---- auxiliares de desenho

func _ellipse(center: Vector2, radius: Vector2, color: Color, from_angle: float = 0.0, to_angle: float = TAU, points: int = 40) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for i in points + 1:
		var angle := lerpf(from_angle, to_angle, float(i) / points)
		polygon.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	if color.a > 0.0:
		if to_angle - from_angle < TAU:
			polygon.append(center)
		draw_colored_polygon(polygon, color)
	return polygon


func _poly(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)


func _shade(color: Color, amount: float = 0.18) -> Color:
	return color.darkened(amount)


# ---- corpo

func _draw_back_hair() -> void:
	if _headwear_covers_hair() and _style("hair") != "long":
		return
	var color := _color("hair_color")
	match _style("hair"):
		"afro":
			_ellipse(HEAD + Vector2(0, -14), Vector2(60, 54), color)
		"long":
			_poly([HEAD + Vector2(-42, -20), HEAD + Vector2(42, -20), HEAD + Vector2(48, 90), HEAD + Vector2(-48, 90)], color)
			_ellipse(HEAD + Vector2(0, -8), Vector2(44, 48), color)
		"dreads", "braids":
			var count := 9 if _style("hair") == "dreads" else 11
			for i in count:
				var x := lerpf(-40, 40, float(i) / (count - 1))
				var length := 70.0 + 18.0 * absf(sin(i * 1.7))
				var width := 7.0 if _style("hair") == "dreads" else 5.0
				draw_line(HEAD + Vector2(x * 0.8, -30), HEAD + Vector2(x * 1.15, length), color, width)
		"bun":
			_ellipse(HEAD + Vector2(0, -50), Vector2(16, 13), color)


func _draw_hood_back() -> void:
	if _has_hood():
		_ellipse(Vector2(100, 132), Vector2(40, 16), _shade(_color("top"), 0.25))


func _draw_legs(skin: Color) -> void:
	var color := _color("bottom")
	var dark := _color2("bottom")
	var left := [Vector2(66, 250), Vector2(99, 250), Vector2(97, 372), Vector2(72, 372)]
	var right := [Vector2(101, 250), Vector2(134, 250), Vector2(128, 372), Vector2(103, 372)]
	if _style("bottom") == "shorts":
		_poly([Vector2(72, 300), Vector2(96, 300), Vector2(95, 372), Vector2(76, 372)], skin)
		_poly([Vector2(104, 300), Vector2(128, 300), Vector2(124, 372), Vector2(105, 372)], skin)
		left = [Vector2(64, 250), Vector2(99, 250), Vector2(98, 308), Vector2(68, 308)]
		right = [Vector2(101, 250), Vector2(136, 250), Vector2(132, 308), Vector2(102, 308)]
	_poly(left, color)
	_poly(right, color)
	_poly([Vector2(64, 246), Vector2(136, 246), Vector2(136, 262), Vector2(64, 262)], dark)
	match _style("bottom"):
		"jeans":
			draw_line(Vector2(84, 266), Vector2(85, 368), dark, 1.5)
			draw_line(Vector2(116, 266), Vector2(115, 368), dark, 1.5)
		"cargo":
			_poly([Vector2(66, 292), Vector2(80, 292), Vector2(80, 318), Vector2(67, 318)], dark)
			_poly([Vector2(120, 292), Vector2(134, 292), Vector2(133, 318), Vector2(120, 318)], dark)
		"sweatpants":
			_poly([Vector2(71, 362), Vector2(98, 362), Vector2(97, 374), Vector2(72, 374)], dark)
			_poly([Vector2(102, 362), Vector2(129, 362), Vector2(128, 374), Vector2(103, 374)], dark)


func _draw_shoes() -> void:
	var color := _color("shoes")
	var sole := _color2("shoes")
	match _style("shoes"):
		"boots":
			_poly([Vector2(70, 356), Vector2(98, 356), Vector2(99, 382), Vector2(64, 382)], color)
			_poly([Vector2(102, 356), Vector2(130, 356), Vector2(136, 382), Vector2(101, 382)], color)
			_poly([Vector2(62, 382), Vector2(100, 382), Vector2(100, 388), Vector2(62, 388)], sole)
			_poly([Vector2(100, 382), Vector2(138, 382), Vector2(138, 388), Vector2(100, 388)], sole)
		"slides":
			var skin := _color("skin")
			_ellipse(Vector2(84, 381), Vector2(15, 6), skin)
			_ellipse(Vector2(116, 381), Vector2(15, 6), skin)
			_poly([Vector2(70, 384), Vector2(100, 384), Vector2(100, 389), Vector2(68, 389)], sole)
			_poly([Vector2(100, 384), Vector2(130, 384), Vector2(132, 389), Vector2(100, 389)], sole)
			_poly([Vector2(72, 374), Vector2(97, 374), Vector2(97, 382), Vector2(72, 382)], color)
			_poly([Vector2(103, 374), Vector2(128, 374), Vector2(128, 382), Vector2(103, 382)], color)
		_:
			_ellipse(Vector2(82, 378), Vector2(19, 10), color)
			_ellipse(Vector2(118, 378), Vector2(19, 10), color)
			_poly([Vector2(62, 382), Vector2(101, 382), Vector2(101, 389), Vector2(63, 389)], sole)
			_poly([Vector2(99, 382), Vector2(138, 382), Vector2(137, 389), Vector2(99, 389)], sole)


func _sleeve_length() -> float:
	if _style("jacket") != "none" and _style("jacket") != "":
		return 1.0
	match _style("top"):
		"tank":
			return 0.0
		"tshirt", "jersey":
			return 0.3
	return 1.0


func _draw_arms(skin: Color) -> void:
	var left := [Vector2(54, 146), Vector2(70, 152), Vector2(56, 250), Vector2(40, 246)]
	var right := [Vector2(146, 146), Vector2(130, 152), Vector2(144, 250), Vector2(160, 246)]
	_poly(left, skin)
	_poly(right, skin)
	_ellipse(Vector2(47, 256), Vector2(10, 11), skin)
	_ellipse(Vector2(153, 256), Vector2(10, 11), skin)
	var length := _sleeve_length()
	if length <= 0.0:
		return
	var color := _color("top")
	var end := lerpf(152, 250, length)
	var t := length
	_poly([left[0], left[1], left[1].lerp(left[2], t), left[0].lerp(left[3], t)], color)
	_poly([right[0], right[1], right[1].lerp(right[2], t), right[0].lerp(right[3], t)], color)
	if length >= 1.0:
		_poly([Vector2(39, 238), Vector2(57, 242), Vector2(56, 250), Vector2(40, 246)], _shade(color))
		_poly([Vector2(161, 238), Vector2(143, 242), Vector2(144, 250), Vector2(160, 246)], _shade(color))
	elif end > 0:
		pass


func _draw_top(skin: Color) -> void:
	var color := _color("top")
	var detail := _color2("top")
	var torso := [Vector2(56, 146), Vector2(88, 136), Vector2(112, 136), Vector2(144, 146), Vector2(136, 256), Vector2(64, 256)]
	match _style("top"):
		"tank":
			_poly([Vector2(56, 146), Vector2(144, 146), Vector2(136, 256), Vector2(64, 256)], skin)
			_poly([Vector2(70, 150), Vector2(80, 140), Vector2(120, 140), Vector2(130, 150), Vector2(134, 256), Vector2(66, 256)], color)
			_ellipse(Vector2(100, 140), Vector2(17, 13), skin, 0.0, PI)
		_:
			_poly(torso, color)
	match _style("top"):
		"tshirt":
			_ellipse(Vector2(100, 138), Vector2(15, 9), skin, 0.0, PI)
			draw_arc(Vector2(100, 138), 15, 0.0, PI, 16, detail, 2.0)
		"jersey":
			_poly([Vector2(88, 136), Vector2(112, 136), Vector2(100, 156)], detail)
			_poly([Vector2(60, 196), Vector2(140, 196), Vector2(139, 206), Vector2(61, 206)], detail)
			draw_string(ThemeDB.fallback_font, Vector2(88, 238), "10", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, detail)
		"shirt":
			_poly([Vector2(88, 136), Vector2(100, 152), Vector2(84, 156)], _shade(color, 0.1))
			_poly([Vector2(112, 136), Vector2(116, 156), Vector2(100, 152)], _shade(color, 0.1))
			draw_line(Vector2(100, 152), Vector2(100, 256), detail, 1.5)
			for y in [170, 192, 214, 236]:
				draw_circle(Vector2(103, y), 1.8, detail)
			if detail.v < 0.4:
				for x in [72, 88, 112, 128]:
					draw_line(Vector2(x, 150), Vector2(x - 2, 254), _shade(color, 0.3), 2.0)
				for y in [180, 214, 246]:
					draw_line(Vector2(60, y), Vector2(140, y), _shade(color, 0.3), 2.0)
		"hoodie":
			_ellipse(Vector2(100, 140), Vector2(26, 10), _shade(color, 0.25))
			_poly([Vector2(76, 214), Vector2(124, 214), Vector2(130, 246), Vector2(70, 246)], detail)
			draw_line(Vector2(94, 144), Vector2(92, 180), Color(0.95, 0.95, 0.95), 2.0)
			draw_line(Vector2(106, 144), Vector2(108, 180), Color(0.95, 0.95, 0.95), 2.0)
			_poly([Vector2(64, 248), Vector2(136, 248), Vector2(136, 258), Vector2(64, 258)], detail)


func _draw_jacket() -> void:
	var style := _style("jacket")
	if style == "none" or style == "":
		return
	var color := _color("jacket")
	var detail := _color2("jacket")
	var sleeve_color := detail if style == "varsity" else color
	var left := [Vector2(54, 146), Vector2(70, 152), Vector2(56, 250), Vector2(40, 246)]
	var right := [Vector2(146, 146), Vector2(130, 152), Vector2(144, 250), Vector2(160, 246)]
	var bulk := 4.0 if style == "puffer" else 0.0
	_poly([left[0] + Vector2(-bulk, 0), left[1], left[2], left[3] + Vector2(-bulk, 0)], sleeve_color)
	_poly([right[0] + Vector2(bulk, 0), right[1], right[2], right[3] + Vector2(bulk, 0)], sleeve_color)
	var panel_left := [Vector2(54 - bulk, 146), Vector2(88, 136), Vector2(90, 256), Vector2(62 - bulk, 260)]
	var panel_right := [Vector2(112, 136), Vector2(146 + bulk, 146), Vector2(138 + bulk, 260), Vector2(110, 256)]
	_poly(panel_left, color)
	_poly(panel_right, color)
	match style:
		"bomber", "varsity":
			_poly([Vector2(62, 248), Vector2(90, 248), Vector2(90, 260), Vector2(62, 260)], detail if style == "bomber" else _shade(color))
			_poly([Vector2(110, 248), Vector2(138, 248), Vector2(138, 260), Vector2(110, 260)], detail if style == "bomber" else _shade(color))
			_poly([Vector2(84, 134), Vector2(116, 134), Vector2(112, 142), Vector2(88, 142)], _shade(color, 0.3))
			if style == "varsity":
				draw_string(ThemeDB.fallback_font, Vector2(64, 196), "R", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, detail)
		"denim":
			for panel in [panel_left, panel_right]:
				draw_line(panel[0].lerp(panel[3], 0.25), panel[1].lerp(panel[2], 0.25), detail, 1.5)
			draw_line(Vector2(89, 140), Vector2(90, 254), detail, 1.5)
			draw_line(Vector2(111, 140), Vector2(110, 254), detail, 1.5)
		"leather":
			_poly([Vector2(88, 136), Vector2(98, 176), Vector2(78, 168)], detail)
			_poly([Vector2(112, 136), Vector2(122, 168), Vector2(102, 176)], detail)
			draw_line(Vector2(80, 190), Vector2(86, 236), detail, 2.0)
		"puffer":
			for y in [170, 196, 222]:
				draw_line(Vector2(50, y), Vector2(90, y), detail, 2.0)
				draw_line(Vector2(110, y), Vector2(150, y), detail, 2.0)


func _draw_neck(skin: Color) -> void:
	_poly([Vector2(89, 112), Vector2(111, 112), Vector2(112, 138), Vector2(88, 138)], _shade(skin, 0.08))


func _draw_chain() -> void:
	for option in _accessories():
		if option.style == "chain":
			draw_arc(Vector2(100, 128), 24, deg_to_rad(20), deg_to_rad(160), 24, option.color, 3.0)
			draw_circle(Vector2(100, 154), 5.5, option.color2)
			draw_circle(Vector2(100, 154), 3.0, option.color)


# ---- rosto

func _draw_head(skin: Color) -> void:
	_ellipse(HEAD + Vector2(-35, 4), Vector2(7, 10), _shade(skin, 0.06))
	_ellipse(HEAD + Vector2(35, 4), Vector2(7, 10), _shade(skin, 0.06))
	_ellipse(HEAD, HEAD_RADIUS, skin)


func _draw_eyes() -> void:
	var iris := _color("eye_color")
	for side in [-1, 1]:
		var center := HEAD + Vector2(side * 14, 2)
		_ellipse(center, Vector2(7.5, 4.8), Color(0.97, 0.96, 0.94))
		draw_circle(center + Vector2(0, 0.5), 3.6, iris)
		draw_circle(center + Vector2(0, 0.5), 1.7, Color(0.06, 0.05, 0.05))
		draw_circle(center + Vector2(1.2, -0.8), 0.9, Color(1, 1, 1, 0.9))


func _draw_brows() -> void:
	var color := _shade(_color("hair_color"), 0.1)
	if _style("hair") == "bald" and _color("hair_color").v > 0.8:
		color = _shade(_color("skin"), 0.45)
	var thickness := 3.5
	var lift := 0.0
	match _style("brows"):
		"thin":
			thickness = 2.0
		"thick":
			thickness = 5.5
		"arched":
			lift = 4.0
	for side in [-1, 1]:
		var inner := HEAD + Vector2(side * 6, -9)
		var top := HEAD + Vector2(side * 14, -12 - lift)
		var outer := HEAD + Vector2(side * 22, -9)
		draw_polyline(PackedVector2Array([inner, top, outer]), color, thickness)
		if _style("brows") == "cut" and side == 1:
			draw_line(HEAD + Vector2(15, -15), HEAD + Vector2(17, -7), _color("skin"), 2.5)


func _draw_mouth(skin: Color) -> void:
	draw_polyline(PackedVector2Array([HEAD + Vector2(-2, 6), HEAD + Vector2(-4, 16), HEAD + Vector2(2, 17)]), _shade(skin, 0.3), 2.0)
	draw_arc(HEAD + Vector2(0, 20), 9, deg_to_rad(25), deg_to_rad(155), 12, _shade(skin, 0.45), 2.5)


func _jaw(top: float, bottom_extra: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 21:
		var angle := lerpf(deg_to_rad(-8), deg_to_rad(188), float(i) / 20)
		var stretch := 1.0 + bottom_extra * sin(angle) * sin(angle)
		points.append(HEAD + Vector2(cos(angle) * HEAD_RADIUS.x, sin(angle) * HEAD_RADIUS.y * stretch))
	points.append(HEAD + Vector2(-HEAD_RADIUS.x + 4, top))
	points.append(HEAD + Vector2(-16, top + 4))
	points.append(HEAD + Vector2(-10, 26))
	points.append(HEAD + Vector2(10, 26))
	points.append(HEAD + Vector2(16, top + 4))
	points.append(HEAD + Vector2(HEAD_RADIUS.x - 4, top))
	points.reverse()
	return points


func _draw_beard() -> void:
	var color := _color("hair_color")
	var mustache := [HEAD + Vector2(-12, 14), HEAD + Vector2(0, 10), HEAD + Vector2(12, 14), HEAD + Vector2(10, 17), HEAD + Vector2(0, 14), HEAD + Vector2(-10, 17)]
	match _style("beard"):
		"stubble":
			var stubble := color
			stubble.a = 0.35
			draw_colored_polygon(_jaw(2), stubble)
		"mustache":
			_poly(mustache, color)
		"goatee":
			_poly(mustache, color)
			_poly([HEAD + Vector2(-9, 27), HEAD + Vector2(9, 27), HEAD + Vector2(7, 42), HEAD + Vector2(0, 45), HEAD + Vector2(-7, 42)], color)
		"chinstrap":
			var points := PackedVector2Array()
			for i in 21:
				var angle := lerpf(deg_to_rad(-5), deg_to_rad(185), float(i) / 20)
				points.append(HEAD + Vector2(cos(angle) * (HEAD_RADIUS.x - 1), sin(angle) * (HEAD_RADIUS.y - 1)))
			draw_polyline(points, color, 4.0)
		"short":
			draw_colored_polygon(_jaw(4), color)
			_poly(mustache, color)
		"full":
			draw_colored_polygon(_jaw(0, 0.12), color)
			_poly(mustache, color)
		"long":
			draw_colored_polygon(_jaw(0, 0.45), color)
			_poly(mustache, color)
	if _style("beard") in ["short", "full", "long"]:
		draw_arc(HEAD + Vector2(0, 20), 8, deg_to_rad(25), deg_to_rad(155), 12, _shade(_color("skin"), 0.45), 2.5)


func _hair_cap(color: Color, depth: float) -> void:
	_ellipse(HEAD + Vector2(0, -6), Vector2(HEAD_RADIUS.x + 2, HEAD_RADIUS.y - 2), color, PI, TAU)
	_poly([HEAD + Vector2(-HEAD_RADIUS.x - 2, -6), HEAD + Vector2(HEAD_RADIUS.x + 2, -6), HEAD + Vector2(HEAD_RADIUS.x, depth), HEAD + Vector2(HEAD_RADIUS.x - 5, depth - 6),
		HEAD + Vector2(-HEAD_RADIUS.x + 5, depth - 6), HEAD + Vector2(-HEAD_RADIUS.x, depth)], color)


func _draw_front_hair() -> void:
	if _headwear_covers_hair():
		return
	var color := _color("hair_color")
	match _style("hair"):
		"buzz":
			var buzz := color
			buzz.a = 0.7
			_ellipse(HEAD + Vector2(0, -4), Vector2(HEAD_RADIUS.x + 1, HEAD_RADIUS.y - 4), buzz, PI + 0.15, TAU - 0.15)
		"short", "waves", "dreads", "braids", "twists":
			_hair_cap(color, -14)
			if _style("hair") == "waves":
				for y in [-38, -30, -22]:
					draw_arc(HEAD + Vector2(0, y + 40), 34, deg_to_rad(240), deg_to_rad(300), 10, _shade(color, 0.4), 1.5)
			elif _style("hair") == "braids":
				for x in [-24, -12, 0, 12, 24]:
					draw_line(HEAD + Vector2(x * 0.6, -44), HEAD + Vector2(x, -14), _shade(color, 0.4), 1.5)
			elif _style("hair") == "twists":
				for i in 14:
					var angle := lerpf(PI + 0.2, TAU - 0.2, float(i) / 13)
					draw_circle(HEAD + Vector2(cos(angle) * 36, -6 + sin(angle) * 44), 6.5, color)
		"curly":
			_hair_cap(color, -16)
			for i in 16:
				var angle := lerpf(PI - 0.1, TAU + 0.1, float(i) / 15)
				draw_circle(HEAD + Vector2(cos(angle) * 38, -8 + sin(angle) * 44), 8.0, color)
		"afro":
			_hair_cap(color, -18)
		"long":
			_hair_cap(color, -10)
			draw_line(HEAD + Vector2(-4, -48), HEAD + Vector2(-8, -18), _shade(color, 0.3), 1.5)
		"mohawk":
			_poly([HEAD + Vector2(-9, -30), HEAD + Vector2(-6, -62), HEAD + Vector2(6, -62), HEAD + Vector2(9, -30)], color)
			var side := color
			side.a = 0.35
			_ellipse(HEAD + Vector2(0, -4), Vector2(HEAD_RADIUS.x, HEAD_RADIUS.y - 5), side, PI + 0.2, TAU - 0.2)
		"bun":
			_hair_cap(color, -14)


func _draw_headwear() -> void:
	var color := _color("headwear")
	var detail := _color2("headwear")
	match _style("headwear"):
		"cap":
			_ellipse(HEAD + Vector2(0, -16), Vector2(39, 34), color, PI, TAU)
			_poly([HEAD + Vector2(-40, -18), HEAD + Vector2(40, -18), HEAD + Vector2(40, -13), HEAD + Vector2(-40, -13)], color)
			_ellipse(HEAD + Vector2(0, -13), Vector2(44, 7), _shade(color, 0.2), 0.0, PI)
			draw_circle(HEAD + Vector2(0, -36), 5, detail)
		"cap_back":
			_ellipse(HEAD + Vector2(0, -16), Vector2(39, 34), color, PI, TAU)
			_poly([HEAD + Vector2(-40, -18), HEAD + Vector2(40, -18), HEAD + Vector2(40, -13), HEAD + Vector2(-40, -13)], color)
			_poly([HEAD + Vector2(-12, -18), HEAD + Vector2(12, -18), HEAD + Vector2(9, -26), HEAD + Vector2(-9, -26)], detail)
		"beanie":
			_ellipse(HEAD + Vector2(0, -12), Vector2(40, 40), color, PI, TAU)
			_poly([HEAD + Vector2(-41, -16), HEAD + Vector2(41, -16), HEAD + Vector2(40, -4), HEAD + Vector2(-40, -4)], detail)
		"bucket":
			_ellipse(HEAD + Vector2(0, -16), Vector2(36, 32), color, PI, TAU)
			_poly([HEAD + Vector2(-36, -18), HEAD + Vector2(36, -18), HEAD + Vector2(54, -6), HEAD + Vector2(-54, -6)], detail)
		"durag":
			_ellipse(HEAD + Vector2(0, -8), Vector2(39, 42), color, PI, TAU)
			_poly([HEAD + Vector2(-39, -8), HEAD + Vector2(39, -8), HEAD + Vector2(36, -2), HEAD + Vector2(-36, -2)], detail)
			_poly([HEAD + Vector2(30, -4), HEAD + Vector2(38, -4), HEAD + Vector2(48, 50), HEAD + Vector2(40, 52)], color)


func _draw_face_accessories() -> void:
	for option in _accessories():
		match option.style:
			"sunglasses":
				for side in [-1, 1]:
					_ellipse(HEAD + Vector2(side * 14, 2), Vector2(11, 7), option.color)
				draw_line(HEAD + Vector2(-4, 0), HEAD + Vector2(4, 0), option.color, 2.5)
				draw_line(HEAD + Vector2(-25, 0), HEAD + Vector2(-35, -2), option.color, 2.0)
				draw_line(HEAD + Vector2(25, 0), HEAD + Vector2(35, -2), option.color, 2.0)
			"glasses":
				for side in [-1, 1]:
					var lens := option.color2
					lens.a = 0.25
					_ellipse(HEAD + Vector2(side * 14, 2), Vector2(10, 7.5), lens)
					draw_arc(HEAD + Vector2(side * 14, 2), 9.5, 0.0, TAU, 24, option.color, 2.0)
				draw_line(HEAD + Vector2(-4.5, 1), HEAD + Vector2(4.5, 1), option.color, 2.0)
			"earrings":
				draw_circle(HEAD + Vector2(-36, 14), 3.0, option.color)
				draw_circle(HEAD + Vector2(36, 14), 3.0, option.color)


func _draw_watch() -> void:
	for option in _accessories():
		if option.style == "watch":
			_poly([Vector2(40, 238), Vector2(57, 241), Vector2(56, 249), Vector2(39, 246)], option.color)
			draw_circle(Vector2(48, 243), 3.0, option.color2)
