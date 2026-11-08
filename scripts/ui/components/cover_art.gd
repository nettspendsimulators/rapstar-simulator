class_name CoverArt
extends RefCounted
## Capas das músicas, projetos e eventos. Sem imagem escolhida, gera uma arte própria a partir
## do nome (gradiente e sulcos de vinil), para nada aparecer como um quadro vazio.

const SIZE := 160
static var _cache: Dictionary[String, Texture2D] = {}


## A capa escolhida pelo jogador, ou a arte gerada para o nome.
static func texture_for(cover_file: String, seed_text: String) -> Texture2D:
	var cover := GameManager.covers.get_texture(cover_file)
	if cover != null:
		return cover
	return generated(seed_text)


static func generated(seed_text: String) -> Texture2D:
	var key := seed_text if not seed_text.is_empty() else "?"
	if _cache.has(key):
		return _cache[key]
	var hue := float(absi(hash(key)) % 360) / 360.0
	var top := Color.from_hsv(hue, 0.65, 0.55)
	var bottom := Color.from_hsv(fmod(hue + 0.12, 1.0), 0.75, 0.18)
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var center := Vector2(SIZE * 0.62, SIZE * 0.6)
	for y in SIZE:
		for x in SIZE:
			var t := (x * 0.35 + y * 0.65) / SIZE
			var color := top.lerp(bottom, t)
			var distance := Vector2(x, y).distance_to(center)
			if distance < SIZE * 0.42:
				# Disco: escuro, com sulcos e um rótulo central na cor da capa.
				var groove := 0.06 if int(distance) % 4 == 0 else 0.0
				color = Color(0.07, 0.06, 0.09).lightened(groove)
				if distance < SIZE * 0.13:
					color = top.lightened(0.15)
				if distance < SIZE * 0.02:
					color = Color(0.05, 0.05, 0.06)
			image.set_pixel(x, y, color)
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture
