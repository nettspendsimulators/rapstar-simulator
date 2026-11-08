class_name CharacterOptionDefinition
extends Resource
## Uma peça da aparência: tom de pele, corte de cabelo, cor, barba, roupa ou acessório.
## Novas peças com um estilo já existente só precisam de uma entrada em data/character.tres.

@export var id: String = ""
@export var display_name: String = ""
## Categoria da aparência (skin, hair, hair_color, brows, eye_color, beard, top, bottom, jacket,
## shoes, headwear, accessory).
@export var category: String = ""
## Forma desenhada pelo CharacterView (ex.: "afro", "hoodie", "cap"). Cores não usam.
@export var style: String = ""
@export var color: Color = Color.WHITE
## Segunda cor, para detalhes (manga do college, sola do tênis, lente dos óculos).
@export var color2: Color = Color.WHITE
## Nível da peça (basic, common, premium, luxury, exclusive). Só roupas e acessórios têm preço;
## peças básicas são de graça e as únicas disponíveis na criação da carreira.
@export var tier: String = "basic"
## Preço na loja de roupas. 0 para peças básicas e para características do corpo.
@export var price: int = 0
## Sexos que podem usar a peça ("male", "female"). Vazio: todos.
@export var sexes: Array[String] = []


func allows_sex(sex: String) -> bool:
	return sexes.is_empty() or sex in sexes
