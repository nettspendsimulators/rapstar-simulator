class_name VehicleSystem
extends RefCounted
## Concessionária e garagem: compra paga à vista e cada modelo entra uma vez na garagem.

var _balance: GameBalance
var _economy: EconomySystem


func _init(balance: GameBalance, economy: EconomySystem) -> void:
	_balance = balance
	_economy = economy


func rules() -> VehicleRules:
	return _balance.vehicles


func catalog() -> Array[VehicleDefinition]:
	return rules().vehicles


func is_owned(career: CareerData, vehicle_id: String) -> bool:
	return find_owned(career, vehicle_id) != null


func find_owned(career: CareerData, vehicle_id: String) -> OwnedVehicle:
	for owned in career.vehicles:
		if owned.vehicle_id == vehicle_id:
			return owned
	return null


## Carros da garagem com a definição, do mais recente para o mais antigo.
func garage(career: CareerData) -> Array[VehicleDefinition]:
	var result: Array[VehicleDefinition] = []
	for index in range(career.vehicles.size() - 1, -1, -1):
		var definition := rules().find_vehicle(career.vehicles[index].vehicle_id)
		if definition != null:
			result.append(definition)
	return result


func garage_value(career: CareerData) -> int:
	var total := 0
	for owned in career.vehicles:
		total += owned.price_paid
	return total


## Por que não dá para comprar, ou texto vazio.
func purchase_block(career: CareerData, vehicle_id: String) -> String:
	var vehicle := rules().find_vehicle(vehicle_id)
	if vehicle == null:
		return "Carro não encontrado."
	if is_owned(career, vehicle_id):
		return "Já está na sua garagem."
	if not _economy.can_afford(career, vehicle.price):
		return "Faltam %s." % Fmt.money(vehicle.price - career.money)
	return ""


func buy(career: CareerData, vehicle_id: String) -> ActionResult:
	var block := purchase_block(career, vehicle_id)
	if not block.is_empty():
		return ActionResult.failure(block)
	var vehicle := rules().find_vehicle(vehicle_id)
	_economy.spend(career, vehicle.price, "Compra: %s %d" % [vehicle.display_name(), vehicle.year], FinanceEntry.CATEGORY_VEHICLE)
	var owned := OwnedVehicle.new()
	owned.vehicle_id = vehicle_id
	owned.bought_week = career.current_week
	owned.price_paid = vehicle.price
	career.vehicles.append(owned)
	return ActionResult.success("%s %d é seu! Já está na garagem." % [vehicle.display_name(), vehicle.year], owned)
