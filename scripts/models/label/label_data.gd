class_name LabelData
extends RefCounted
## Situação da carreira com gravadoras: independente, contratada ou dona da própria gravadora.
## Também guarda propostas, histórico e o catálogo lançado sob cada selo.

const MODE_INDEPENDENT := "independent"
const MODE_SIGNED := "signed"
const MODE_OWNER := "owner"

var contract: LabelContract
var own: OwnLabel
var offers: Array[LabelOffer] = []
## {week, text}
var history: Array[Dictionary] = []
## Faixas lançadas pelos artistas da gravadora do jogador: {artist_id, title, week, streams, revenue}.
## Os lançamentos do próprio jogador vêm de CareerData.releases, filtrados pelos períodos abaixo.
var catalog: Array[Dictionary] = []
## Períodos sob cada selo: {label, short, from, to (-1 = em aberto)}.
var periods: Array[Dictionary] = []
var next_offer: int = 1


func mode(week: int) -> String:
	if contract != null and contract.is_active(week):
		return MODE_SIGNED
	if own != null:
		return MODE_OWNER
	return MODE_INDEPENDENT


func active_contract(week: int) -> LabelContract:
	return contract if contract != null and contract.is_active(week) else null


func find_offer(offer_id: String) -> LabelOffer:
	for offer in offers:
		if offer.id == offer_id:
			return offer
	return null


func to_dict() -> Dictionary:
	return {
		"contract": contract.to_dict() if contract != null else null,
		"own": own.to_dict() if own != null else null,
		"offers": offers.map(func(item: LabelOffer) -> Dictionary: return item.to_dict()),
		"history": history.duplicate(true), "catalog": catalog.duplicate(true),
		"periods": periods.duplicate(true), "next_offer": next_offer,
	}


static func from_dict(data: Dictionary) -> LabelData:
	var label := LabelData.new()
	if data.get("contract") is Dictionary:
		label.contract = LabelContract.from_dict(data["contract"])
	if data.get("own") is Dictionary:
		label.own = OwnLabel.from_dict(data["own"])
	for item: Dictionary in data.get("offers", []):
		label.offers.append(LabelOffer.from_dict(item))
	# O JSON devolve números como decimais: semanas e valores voltam a ser inteiros.
	for item: Dictionary in data.get("history", []):
		label.history.append({"week": int(item.get("week", 0)), "text": String(item.get("text", ""))})
	for item: Dictionary in data.get("catalog", []):
		label.catalog.append({"artist_id": String(item.get("artist_id", "")), "title": String(item.get("title", "")),
			"week": int(item.get("week", 0)), "streams": int(item.get("streams", 0)), "revenue": int(item.get("revenue", 0))})
	for item: Dictionary in data.get("periods", []):
		label.periods.append({"label": String(item.get("label", "")), "short": String(item.get("short", "")),
			"from": int(item.get("from", 0)), "to": int(item.get("to", -1))})
	label.next_offer = int(data.get("next_offer", 1))
	return label
