class_name CityDefinition
extends Resource
## Uma cidade onde o artista pode se apresentar.

@export var id: String = ""
@export var display_name: String = ""
@export var country: String = ""
@export var region: String = ""
@export var continent: String = ""
@export var latitude: float = 0.0
@export var longitude: float = 0.0
## Tamanho do público da cidade em relação a São Paulo.
@export var market: float = 1.0
## Força da cena de rap local.
@export var rap_scene: float = 1.0
