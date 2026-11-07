class_name MerchItem
extends RefCounted
## Um lote fabricado de um produto oficial: estoque, preço e vendas.

const EXCLUSIVE_NONE := ""
const EXCLUSIVE_TOUR := "tour"
const EXCLUSIVE_PROJECT := "project"
const EXCLUSIVE_SHOW := "show"

var id: String = ""
var product_id: String = ""
var price: int = 0
var stock: int = 0
var made: int = 0
var sold: int = 0
var revenue: int = 0
var cost_total: int = 0
var exclusive_kind: String = EXCLUSIVE_NONE
var exclusive_id: String = ""
var limited: bool = false


func profit() -> int:
	return revenue - cost_total


func to_dict() -> Dictionary:
	return {
		"id": id, "product_id": product_id, "price": price, "stock": stock, "made": made, "sold": sold,
		"revenue": revenue, "cost_total": cost_total, "exclusive_kind": exclusive_kind,
		"exclusive_id": exclusive_id, "limited": limited,
	}


static func from_dict(data: Dictionary) -> MerchItem:
	var item := MerchItem.new()
	item.id = data.get("id", "")
	item.product_id = data.get("product_id", "")
	for key in ["price", "stock", "made", "sold", "revenue", "cost_total"]:
		item.set(key, int(data.get(key, 0)))
	item.exclusive_kind = data.get("exclusive_kind", EXCLUSIVE_NONE)
	item.exclusive_id = data.get("exclusive_id", "")
	item.limited = bool(data.get("limited", false))
	return item
