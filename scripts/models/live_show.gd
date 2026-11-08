class_name LiveShow
extends RefCounted
## Uma apresentação: oferta recebida, data de turnê em planejamento, show agendado ou já realizado.
## A data é um dia absoluto: o dia 1 é o primeiro dia da semana 1.

const KIND_CONTRACTED := "contracted"
const KIND_INDEPENDENT := "independent"
const KIND_TOUR := "tour"
const KIND_FESTIVAL := "festival"
const STATUS_OFFER := "offer"
const STATUS_DRAFT := "draft"
const STATUS_SCHEDULED := "scheduled"
const STATUS_DONE := "done"
const STATUS_CANCELLED := "cancelled"

var id: String = ""
var kind: String = KIND_INDEPENDENT
var status: String = STATUS_DRAFT
var event_name: String = ""
var event_type: String = ""
var city_id: String = ""
var venue_id: String = "bar"
var venue_name: String = ""
var capacity: int = 0
var day: int = 0
var ticket_price: float = 15.0
var vip_enabled: bool = false
var vip_price: float = 0.0
var model: String = LiveRules.MODEL_INDEPENDENT
var fee: int = 0
## Fração da bilheteria líquida, de 0 a 1.
var percentage: float = 0.0
var covers_travel: bool = false
var covers_lodging: bool = false
var production_id: String = "basic"
var addons: Array[String] = []
## Nível contratado de cada função da equipe.
var crew: Dictionary[String, int] = {}
var promotion: int = 0
## Convidados: {"artist_id": id do catálogo de feats, "role": abertura, convidado...}.
var guests: Array[Dictionary] = []
var merch_enabled: bool = true
var tour_id: String = ""
var festival_edition_id: String = ""
var lineup_position: String = ""
var stage_name: String = ""
var set_type: String = "full"
var fee_model: String = ""
var offer_expires_week: int = 0
## Despesas pagas ao confirmar o show.
var upfront_paid: int = 0
## Relatório depois do show.
var result: Dictionary = {}
## Artista que convidou o jogador para este show (participação no show ou na turnê dele).
var partner_id: String = ""


func week() -> int:
	return (day - 1) / 7 + 1


func weekday() -> int:
	return (day - 1) % 7 + 1


func is_active() -> bool:
	return status == STATUS_SCHEDULED or status == STATUS_OFFER or status == STATUS_DRAFT


func kind_label() -> String:
	match kind:
		KIND_CONTRACTED:
			return "Contratado"
		KIND_TOUR:
			return "Turnê"
		KIND_FESTIVAL:
			return "Festival"
	return "Independente"


func status_label() -> String:
	match status:
		STATUS_OFFER:
			return "Oferta"
		STATUS_DRAFT:
			return "Em planejamento"
		STATUS_SCHEDULED:
			return "Agendado"
		STATUS_DONE:
			return "Realizado"
	return "Cancelado"


func copy() -> LiveShow:
	return LiveShow.from_dict(to_dict())


func to_dict() -> Dictionary:
	return {
		"id": id, "kind": kind, "status": status, "event_name": event_name, "event_type": event_type,
		"city_id": city_id, "venue_id": venue_id, "venue_name": venue_name, "capacity": capacity, "day": day,
		"ticket_price": ticket_price, "vip_enabled": vip_enabled, "vip_price": vip_price, "model": model,
		"fee": fee, "percentage": percentage, "covers_travel": covers_travel, "covers_lodging": covers_lodging,
		"production_id": production_id, "addons": addons, "crew": crew, "promotion": promotion, "guests": guests,
		"merch_enabled": merch_enabled, "tour_id": tour_id, "festival_edition_id": festival_edition_id,
		"lineup_position": lineup_position, "stage_name": stage_name, "set_type": set_type, "fee_model": fee_model,
		"offer_expires_week": offer_expires_week, "upfront_paid": upfront_paid, "result": result, "partner_id": partner_id,
	}


static func from_dict(data: Dictionary) -> LiveShow:
	var show := LiveShow.new()
	for key in ["id", "kind", "status", "event_name", "event_type", "city_id", "venue_id", "venue_name", "model",
			"production_id", "tour_id", "festival_edition_id", "lineup_position", "stage_name", "set_type", "fee_model", "partner_id"]:
		show.set(key, data.get(key, show.get(key)))
	for key in ["capacity", "day", "fee", "promotion", "offer_expires_week", "upfront_paid"]:
		show.set(key, int(data.get(key, 0)))
	show.ticket_price = float(data.get("ticket_price", 15.0))
	show.vip_price = float(data.get("vip_price", 0.0))
	show.percentage = float(data.get("percentage", 0.0))
	show.vip_enabled = bool(data.get("vip_enabled", false))
	show.covers_travel = bool(data.get("covers_travel", false))
	show.covers_lodging = bool(data.get("covers_lodging", false))
	show.merch_enabled = bool(data.get("merch_enabled", true))
	show.addons.assign(data.get("addons", []))
	var saved_crew: Dictionary = data.get("crew", {})
	for role_id: String in saved_crew:
		show.crew[role_id] = int(saved_crew[role_id])
	for guest: Dictionary in data.get("guests", []):
		show.guests.append({"artist_id": guest.get("artist_id", ""), "role": guest.get("role", "guest")})
	show.result = LiveShow.whole_numbers(data.get("result", {}))
	return show


## O JSON lê todos os números como float. Valores inteiros voltam a ser int.
static func whole_numbers(source: Dictionary) -> Dictionary:
	var output := {}
	for key: Variant in source:
		var value: Variant = source[key]
		if value is float and value == floorf(value):
			output[key] = int(value)
		elif value is Dictionary:
			output[key] = LiveShow.whole_numbers(value)
		else:
			output[key] = value
	return output
