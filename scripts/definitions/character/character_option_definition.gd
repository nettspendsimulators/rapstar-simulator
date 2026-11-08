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
