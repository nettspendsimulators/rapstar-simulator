class_name SongAttributeDefinition
extends Resource
## Um atributo melhorável da música, como Vocal ou Beat.

@export var id: String
@export var display_name: String
## Peso do atributo na nota geral da música.
@export var weight: float = 0.25
@export var energy_cost: int = 20
@export var money_cost: int = 50
