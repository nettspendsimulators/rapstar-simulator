class_name WardrobeSystem
extends RefCounted
## Loja de roupas e guarda-roupa. Peças básicas são de todos; as outras são compradas uma vez,
## com o dinheiro da carreira, e ficam no guarda-roupa dela (CareerData.wardrobe).
## O preço vem de data/character.tres: quanto melhor o nível da peça, mais cara.

var _balance: GameBalance
var _economy: EconomySystem


func _init(balance: GameBalance, economy: EconomySystem) -> void:
	_balance = balance
	_economy = economy


func rules() -> CharacterRules:
	return _balance.character


func find_item(option_id: String) -> CharacterOptionDefinition:
	for option in rules().options:
		if option.id == option_id:
			return option
	return null


## Básicas, características do corpo e peças compradas estão sempre disponíveis.
func owns(career: CareerData, option_id: String) -> bool:
	var item := find_item(option_id)
	if item == null:
		return false
	if not CharacterRules.is_wear(item.category) or item.price <= 0:
		return true
	return option_id in career.wardrobe


## Peças de um visual que ainda não foram compradas.
func missing(career: CareerData, appearance: CharacterAppearance) -> Array[CharacterOptionDefinition]:
	var result: Array[CharacterOptionDefinition] = []
	for option_id in appearance.worn_ids():
		if not owns(career, option_id):
			var item := find_item(option_id)
			if item != null:
				result.append(item)
	return result


func missing_cost(career: CareerData, appearance: CharacterAppearance) -> int:
	var total := 0
	for item in missing(career, appearance):
		total += item.price
	return total


## Peças compradas, da mais cara para a mais barata.
func owned_items(career: CareerData) -> Array[CharacterOptionDefinition]:
	var result: Array[CharacterOptionDefinition] = []
	for option_id in career.wardrobe:
		var item := find_item(option_id)
		if item != null:
			result.append(item)
	result.sort_custom(func(a: CharacterOptionDefinition, b: CharacterOptionDefinition) -> bool: return a.price > b.price)
	return result


func wardrobe_value(career: CareerData) -> int:
	var total := 0
	for item in owned_items(career):
		total += item.price
	return total


## Por que não dá para comprar, ou texto vazio.
func purchase_block(career: CareerData, option_id: String) -> String:
	var item := find_item(option_id)
	if item == null or not CharacterRules.is_wear(item.category):
		return "Esta peça não está à venda."
	if owns(career, option_id):
		return "Já está no seu guarda-roupa."
	if not _economy.can_afford(career, item.price):
		return "Faltam %s para comprar %s." % [Fmt.money(item.price - career.money), item.display_name]
	return ""


func buy(career: CareerData, option_id: String) -> ActionResult:
	var block := purchase_block(career, option_id)
	if not block.is_empty():
		return ActionResult.failure(block)
	var item := find_item(option_id)
	_economy.spend(career, item.price, "Loja de roupas: %s" % item.display_name, FinanceEntry.CATEGORY_STYLE)
	career.wardrobe.append(option_id)
	return ActionResult.success("%s comprado(a) por %s. Já está no seu guarda-roupa." % [item.display_name, Fmt.money(item.price)], item)


## Compra de uma vez tudo o que falta num visual. Não compra nada se o dinheiro não der.
func buy_look(career: CareerData, appearance: CharacterAppearance) -> ActionResult:
	var items := missing(career, appearance)
	if items.is_empty():
		return ActionResult.success("Você já tem todas as peças deste visual.")
	var total := missing_cost(career, appearance)
	if not _economy.can_afford(career, total):
		return ActionResult.failure("O visual custa %s e faltam %s." % [Fmt.money(total), Fmt.money(total - career.money)])
	for item in items:
		buy(career, item.id)
	return ActionResult.success("%d peça(s) comprada(s) por %s." % [items.size(), Fmt.money(total)])
