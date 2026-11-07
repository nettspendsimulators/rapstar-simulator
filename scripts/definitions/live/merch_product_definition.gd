class_name MerchProductDefinition
extends Resource
## Produto oficial que pode ser fabricado e vendido.

@export var id: String = ""
@export var display_name: String = ""
@export var category: String = ""
@export var unit_cost: int = 0
@export var suggested_price: int = 0
## Interesse do público, de 0 a 1.
@export var appeal: float = 1.0
