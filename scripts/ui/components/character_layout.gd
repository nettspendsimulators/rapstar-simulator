class_name CharacterLayout
extends RefCounted
## Medidas compartilhadas pelo desenho do personagem e pelo editor por miniaturas: regiões do
## corpo (no quadro de 200 x 400 do CharacterView), as abas do editor e a região de cada miniatura.

const FOCUS_RECTS := {
	"full": Rect2(0, 0, 200, 400), "head": Rect2(52, 8, 96, 104), "upper": Rect2(26, 92, 148, 176),
	"lower": Rect2(46, 236, 108, 164), "feet": Rect2(54, 342, 92, 56), "eyes": Rect2(68, 42, 64, 36),
	"jaw": Rect2(60, 50, 80, 72), "hand": Rect2(26, 216, 50, 50), "hand_right": Rect2(124, 216, 50, 50),
	"body": Rect2(10, 0, 180, 400),
}
const GROUPS := [
	{"id": "body", "label": "Corpo", "categories": ["sex", "build", "skin"]},
	{"id": "face", "label": "Rosto", "categories": ["eye_color", "brows", "makeup", "beard"]},
	{"id": "hair", "label": "Cabelo", "categories": ["hair", "hair_color"]},
	{"id": "clothes", "label": "Roupas", "categories": ["top", "jacket", "bottom", "shoes"]},
	{"id": "extras", "label": "Acessórios", "categories": ["headwear", "accessory"]},
]
## Região do corpo mostrada na miniatura de cada categoria.
const FOCUS := {
	"sex": "body", "build": "body", "skin": "head", "eye_color": "eyes", "brows": "eyes", "makeup": "jaw", "beard": "jaw",
	"hair": "head", "headwear": "head", "top": "upper", "jacket": "upper", "bottom": "lower", "shoes": "feet",
}
const ACCESSORY_FOCUS := {
	"chain": "upper", "cuban": "upper", "iced": "upper", "pearls": "upper", "bag": "upper", "watch": "hand",
	"rings": "hand", "bracelet": "hand_right", "sunglasses": "eyes", "glasses": "eyes", "earrings": "head", "hoops": "head",
}
