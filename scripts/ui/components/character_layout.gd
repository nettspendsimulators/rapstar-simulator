class_name CharacterLayout
extends RefCounted
## Medidas compartilhadas pelo desenho do personagem e pelo editor por miniaturas: regiões do
## corpo (no quadro de 200 x 400 do CharacterView), as abas do editor e a região de cada miniatura.

const FOCUS_RECTS := {
	"full": Rect2(0, 0, 200, 400), "head": Rect2(52, 8, 96, 104), "upper": Rect2(26, 92, 148, 176),
	"lower": Rect2(46, 236, 108, 164), "feet": Rect2(54, 342, 92, 56), "eyes": Rect2(68, 42, 64, 36),
	"jaw": Rect2(60, 50, 80, 72), "hand": Rect2(26, 216, 50, 50),
}
const GROUPS := [
	{"id": "face", "label": "Rosto", "categories": ["skin", "eye_color", "brows", "beard"]},
	{"id": "hair", "label": "Cabelo", "categories": ["hair", "hair_color", "headwear"]},
	{"id": "clothes", "label": "Roupas", "categories": ["top", "jacket", "bottom", "shoes"]},
	{"id": "extras", "label": "Acessórios", "categories": ["accessory"]},
]
## Região do corpo mostrada na miniatura de cada categoria.
const FOCUS := {
	"skin": "head", "eye_color": "eyes", "brows": "eyes", "beard": "jaw", "hair": "head",
	"headwear": "head", "top": "upper", "jacket": "upper", "bottom": "lower", "shoes": "feet",
}
const ACCESSORY_FOCUS := {"chain": "upper", "watch": "hand", "sunglasses": "eyes", "glasses": "eyes", "earrings": "head"}
