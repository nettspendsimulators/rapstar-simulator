class_name VenueCategoryDefinition
extends Resource
## Uma categoria de local de show, do bar ao estádio.

@export var id: String = ""
@export var display_name: String = ""
@export var min_capacity: int = 50
@export var max_capacity: int = 200
## Aluguel por show, pago em shows independentes.
@export var rent: int = 0
## Fama a partir da qual o local costuma lotar. Locais maiores podem ser escolhidos antes, com risco.
@export var recommended_fame: int = 0
@export var base_ticket_price: float = 15.0
@export var has_vip: bool = false
@export var venue_names: Array[String] = []
