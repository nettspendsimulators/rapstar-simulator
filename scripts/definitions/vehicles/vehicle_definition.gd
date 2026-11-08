class_name VehicleDefinition
extends Resource
## Um carro à venda na concessionária. A lista fica em data/vehicles.tres.

@export var id: String = ""
@export var brand: String = ""
@export var model: String = ""
@export var year: int = 2025
## Uma das categorias de VehicleRules.CATEGORIES.
@export var category: String = "normal"
@export var price: int = 0
@export var image: Texture2D


func display_name() -> String:
	return "%s %s" % [brand, model]
