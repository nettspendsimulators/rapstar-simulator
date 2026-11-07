class_name SponsorDefinition
extends Resource
## Marca que pode patrocinar turnês.

@export var id: String = ""
@export var display_name: String = ""
@export var category: String = ""
@export var min_fame: int = 0
## Valor em dinheiro, antes da escala da turnê.
@export var base_value: int = 0
## cash, transport, lodging, equipment ou promotion.
@export var benefit: String = "cash"
## Para reduções e divulgação, a fração aplicada.
@export var benefit_value: float = 1.0
@export var obligations: String = ""
