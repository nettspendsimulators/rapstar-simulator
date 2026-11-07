class_name MerchSystem
extends RefCounted
## Produtos oficiais: fabricação paga antes, estoque e vendas em shows, turnês, festivais e na
## loja oficial. Nunca vende sem estoque.

var _balance: GameBalance
var _economy: EconomySystem
var _rng: RandomNumberGenerator


func _init(balance: GameBalance, economy: EconomySystem, rng: RandomNumberGenerator) -> void:
	_balance = balance
	_economy = economy
	_rng = rng


## Custo de fabricação, com desconto por volume.
func manufacture_cost(product_id: String, quantity: int) -> int:
	var product := _rules().find_product(product_id)
	if product == null or quantity <= 0:
		return 0
	var discount := 0.0
	for threshold: int in _rules().volume_discounts:
		if quantity >= threshold:
			discount = maxf(discount, _rules().volume_discounts[threshold])
	return roundi(product.unit_cost * quantity * (1.0 - discount))


func manufacture(career: CareerData, product_id: String, quantity: int, price: int, exclusive_kind: String, exclusive_id: String, limited: bool) -> ActionResult:
	var product := _rules().find_product(product_id)
	if product == null:
		return ActionResult.failure("Escolha um produto.")
	if quantity <= 0:
		return ActionResult.failure("Escolha a quantidade.")
	if price <= 0:
		return ActionResult.failure("Escolha o preço de venda.")
	if exclusive_kind != MerchItem.EXCLUSIVE_NONE and exclusive_id.is_empty():
		return ActionResult.failure("Escolha a turnê, o projeto ou o show do produto exclusivo.")
	var cost := manufacture_cost(product_id, quantity)
	if not _economy.can_afford(career, cost):
		return _economy.insufficient_funds(cost)

	_economy.spend(career, cost, "Fabricação: %d x %s" % [quantity, product.display_name], FinanceEntry.CATEGORY_MERCH)
	var item := MerchItem.new()
	item.id = career.new_id("merch")
	item.product_id = product_id
	item.price = price
	item.stock = quantity
	item.made = quantity
	item.cost_total = cost
	item.exclusive_kind = exclusive_kind
	item.exclusive_id = exclusive_id
	item.limited = limited
	career.merch_items.append(item)
	return ActionResult.success("%d unidades de %s fabricadas por %s." % [quantity, product.display_name, Fmt.money(cost)], item)


func set_price(career: CareerData, item_id: String, price: int) -> ActionResult:
	var item := career.find_merch(item_id)
	if item == null:
		return ActionResult.failure("Produto não encontrado.")
	if price <= 0:
		return ActionResult.failure("O preço precisa ser maior que zero.")
	item.price = price
	return ActionResult.success("Preço atualizado.", item)


## Vende no show. Devolve {"units", "gross", "net"} e já registra estoque, receita e dinheiro.
func sell_at_show(career: CareerData, show: LiveShow, attendance: int, quality: int, venue_cut: float, merch_bonus: float) -> Dictionary:
	var rules := _rules()
	var totals := {"units": 0, "gross": 0, "net": 0}
	if not show.merch_enabled or attendance <= 0:
		return totals
	var budget := roundi(attendance * rules.max_show_buy_rate)
	for item in career.merch_items:
		if item.stock <= 0 or not _sells_at_show(item, show) or budget <= 0:
			continue
		var product := rules.find_product(item.product_id)
		var buyers := attendance * rules.show_buy_rate * product.appeal * _price_factor(item, product) \
			* (quality / 60.0) * _bonus(career, item) * (1.0 + merch_bonus) * _rng.randf_range(0.85, 1.15)
		var units := mini(mini(roundi(buyers), item.stock), budget)
		budget -= units
		_register(item, units, totals, venue_cut)
	_pay(career, totals, "Merch no show: %s" % show.venue_name)
	return totals


## Etapa da semana: vendas na loja oficial do artista.
func sell_online(career: CareerData, followers: int) -> Dictionary:
	var rules := _rules()
	var totals := {"units": 0, "gross": 0, "net": 0}
	for item in career.merch_items:
		if item.stock <= 0 or item.exclusive_kind == MerchItem.EXCLUSIVE_TOUR or item.exclusive_kind == MerchItem.EXCLUSIVE_SHOW:
			continue
		var product := rules.find_product(item.product_id)
		var buyers := followers * rules.online_rate * product.appeal * _price_factor(item, product) * _bonus(career, item) * _rng.randf_range(0.8, 1.2)
		_register(item, mini(roundi(buyers), item.stock), totals, rules.online_fee)
	_pay(career, totals, "Loja oficial")
	return totals


func total_stock(career: CareerData) -> int:
	var total := 0
	for item in career.merch_items:
		total += item.stock
	return total


func item_label(career: CareerData, item: MerchItem) -> String:
	var product := _rules().find_product(item.product_id)
	var label := product.display_name
	match item.exclusive_kind:
		MerchItem.EXCLUSIVE_TOUR:
			var tour := career.find_tour(item.exclusive_id)
			label += " (turnê %s)" % (tour.name if tour != null else "?")
		MerchItem.EXCLUSIVE_PROJECT:
			var content := career.find_content(item.exclusive_id)
			label += " (%s)" % (content.title if content != null else "?")
		MerchItem.EXCLUSIVE_SHOW:
			label += " (exclusivo de show)"
	if item.limited:
		label += " — edição limitada"
	return label


func _sells_at_show(item: MerchItem, show: LiveShow) -> bool:
	match item.exclusive_kind:
		MerchItem.EXCLUSIVE_TOUR:
			return item.exclusive_id == show.tour_id
		MerchItem.EXCLUSIVE_SHOW:
			return item.exclusive_id == show.id
	return true


func _price_factor(item: MerchItem, product: MerchProductDefinition) -> float:
	return clampf(pow(float(product.suggested_price) / maxf(item.price, 1.0), _rules().merch_price_elasticity), 0.05, 2.0)


func _bonus(career: CareerData, item: MerchItem) -> float:
	var bonus := _rules().limited_bonus if item.limited else 1.0
	if item.exclusive_kind == MerchItem.EXCLUSIVE_TOUR or item.exclusive_kind == MerchItem.EXCLUSIVE_SHOW:
		bonus *= _rules().exclusive_bonus
	elif item.exclusive_kind == MerchItem.EXCLUSIVE_PROJECT:
		var content := career.find_content(item.exclusive_id)
		if content != null and content.is_released() and career.current_week - content.release_week <= _rules().recent_release_weeks:
			bonus *= _rules().exclusive_bonus
	return bonus


func _register(item: MerchItem, units: int, totals: Dictionary, cut: float) -> void:
	if units <= 0:
		return
	var gross := units * item.price
	item.stock -= units
	item.sold += units
	var net := roundi(gross * (1.0 - cut))
	item.revenue += net
	totals["units"] += units
	totals["gross"] += gross
	totals["net"] += net


func _pay(career: CareerData, totals: Dictionary, description: String) -> void:
	if totals["net"] > 0:
		_economy.earn(career, totals["net"], description, FinanceEntry.CATEGORY_MERCH)


func _rules() -> LiveRules:
	return _balance.live
