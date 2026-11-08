class_name VehicleRules
extends Resource
## Carros da concessionária. A instância fica em data/vehicles.tres.

const CATEGORIES := {
	"normal": "Normal", "premium": "Premium", "luxury_sedan": "Sedã de luxo", "suv": "SUV", "luxury_suv": "SUV de luxo",
	"sport": "Esportivo", "muscle": "Muscle car", "pickup": "Picape", "supercar": "Supercarro", "ultra_luxury": "Ultra-luxo",
}

@export var vehicles: Array[VehicleDefinition] = []


func find_vehicle(id: String) -> VehicleDefinition:
	for vehicle in vehicles:
		if vehicle.id == id:
			return vehicle
	return null


static func category_label(category: String) -> String:
	return CATEGORIES.get(category, category)
