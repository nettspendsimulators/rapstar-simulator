class_name CharacterRules
extends Resource
## Identidade e aparência do personagem. A instância fica em data/character.tres.

## Categorias na ordem do editor. "multiple" permite várias peças ao mesmo tempo.
const CATEGORIES := [
	{"id": "sex", "label": "Sexo"},
	{"id": "build", "label": "Corpo"},
	{"id": "skin", "label": "Pele"},
	{"id": "eye_color", "label": "Cor dos olhos"},
	{"id": "brows", "label": "Sobrancelhas"},
	{"id": "makeup", "label": "Maquiagem"},
	{"id": "beard", "label": "Barba"},
	{"id": "hair", "label": "Cabelo"},
	{"id": "hair_color", "label": "Cor do cabelo"},
	{"id": "top", "label": "Parte de cima"},
	{"id": "jacket", "label": "Jaqueta"},
	{"id": "bottom", "label": "Parte de baixo"},
	{"id": "shoes", "label": "Calçado"},
	{"id": "headwear", "label": "Cabeça"},
	{"id": "accessory", "label": "Acessórios", "multiple": true},
]
## Categorias vendidas na loja de roupas: têm nível e preço. As outras são o próprio corpo.
const WEAR_CATEGORIES := ["top", "jacket", "bottom", "shoes", "headwear", "accessory"]
## Níveis das peças, do mais simples ao mais raro, com rótulo e cor.
const TIERS := {
	"basic": {"label": "Básica", "color": Color("#a39eb4"), "rank": 0},
	"common": {"label": "Comum", "color": Color("#46d483"), "rank": 1},
	"premium": {"label": "Premium", "color": Color("#4fa3ff"), "rank": 2},
	"luxury": {"label": "Luxo", "color": Color("#b07cff"), "rank": 3},
	"exclusive": {"label": "Exclusiva", "color": Color("#f5b82e"), "rank": 4},
}
## Categorias que são só uma cor: o editor mostra uma amostra da cor.
const COLOR_CATEGORIES := ["skin", "hair_color", "eye_color"]

@export var options: Array[CharacterOptionDefinition] = []
## Peça usada quando a carreira ainda não tem uma escolha (saves antigos e carreiras novas).
@export var defaults: Dictionary = {}

@export_group("Identidade")
@export var countries: Array[String] = []
@export var default_country: String = "Brasil"
@export var default_age: int = 20
@export var min_age: int = 16
@export var max_age: int = 60
@export var weeks_per_year: int = 52


func find_option(category: String, id: String) -> CharacterOptionDefinition:
	for option in options:
		if option.category == category and option.id == id:
			return option
	return null


func options_for(category: String) -> Array[CharacterOptionDefinition]:
	var result: Array[CharacterOptionDefinition] = []
	for option in options:
		if option.category == category:
			result.append(option)
	return result


static func is_multiple(category: String) -> bool:
	for item: Dictionary in CATEGORIES:
		if item["id"] == category:
			return item.get("multiple", false)
	return false


static func is_wear(category: String) -> bool:
	return category in WEAR_CATEGORIES


static func tier_label(tier: String) -> String:
	return TIERS.get(tier, TIERS["basic"])["label"]


static func tier_color(tier: String) -> Color:
	return TIERS.get(tier, TIERS["basic"])["color"]


static func tier_rank(tier: String) -> int:
	return TIERS.get(tier, TIERS["basic"])["rank"]
