class_name OwnedVehicle
extends RefCounted
## Um carro da garagem do jogador (referência ao catálogo de data/vehicles.tres).

var vehicle_id: String = ""
var bought_week: int = 0
var price_paid: int = 0


func to_dict() -> Dictionary:
	return {"vehicle_id": vehicle_id, "bought_week": bought_week, "price_paid": price_paid}


static func from_dict(data: Dictionary) -> OwnedVehicle:
	var owned := OwnedVehicle.new()
	owned.vehicle_id = data.get("vehicle_id", "")
	owned.bought_week = int(data.get("bought_week", 0))
	owned.price_paid = int(data.get("price_paid", 0))
	return owned
