class_name EconomySystem
extends RefCounted
## Único ponto que altera dinheiro, fama, reputação e energia, mantendo o histórico financeiro correto.


func can_afford(career: CareerData, cost: int) -> bool:
	return career.money >= cost


func insufficient_funds(cost: int) -> ActionResult:
	return ActionResult.failure("Dinheiro insuficiente: isso custa %s." % Fmt.money(cost))


func earn(career: CareerData, amount: int, description: String, category: String) -> void:
	_apply_transaction(career, amount, description, category)


## Quem chama deve verificar can_afford antes: gastar nunca deixa o saldo negativo.
func spend(career: CareerData, cost: int, description: String, category: String) -> void:
	assert(can_afford(career, cost))
	_apply_transaction(career, -cost, description, category)


func add_fame(career: CareerData, amount: int) -> void:
	career.fame += amount


func add_reputation(career: CareerData, amount: int) -> void:
	career.reputation += amount


## Com energia infinita, a carreira sempre pode agir e a energia não diminui.
func can_spend_energy(career: CareerData, amount: int) -> bool:
	return career.infinite_energy or career.energy >= amount


## Quem chama deve verificar can_spend_energy antes.
func spend_energy(career: CareerData, amount: int) -> void:
	assert(can_spend_energy(career, amount))
	if not career.infinite_energy:
		career.energy -= amount


func restore_energy(career: CareerData, amount: int, max_energy: int) -> void:
	career.energy = mini(career.energy + amount, max_energy)


func _apply_transaction(career: CareerData, amount: int, description: String, category: String) -> void:
	career.money += amount
	var entry := FinanceEntry.new()
	entry.week = career.current_week
	entry.amount = amount
	entry.description = description
	entry.category = category
	career.finance_history.append(entry)
