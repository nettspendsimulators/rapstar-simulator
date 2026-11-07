class_name MarketingCampaign
extends RefCounted
## Campanha de uma música ou projeto. Ações ficam planejadas até o agendamento, que as paga e inicia.

const STATUS_PLANNING := "planning"
const STATUS_ACTIVE := "active"
const STATUS_COMPLETED := "completed"

## Uma ação da campanha.
class Action:
	var action_id: String = ""
	## Zero enquanto a ação só está planejada.
	var paid_cost: int = 0
	## Semanas de promoção já realizadas por esta ação.
	var weeks_active: int = 0

	func is_paid() -> bool:
		return paid_cost > 0

	func to_dict() -> Dictionary:
		return {"action_id": action_id, "paid_cost": paid_cost, "weeks_active": weeks_active}

	static func from_dict(data: Dictionary) -> Action:
		var action := Action.new()
		action.action_id = data.get("action_id", "")
		action.paid_cost = int(data.get("paid_cost", 0))
		action.weeks_active = int(data.get("weeks_active", 0))
		return action


var content_id: String = ""
var status: String = STATUS_PLANNING
var actions: Array[Action] = []
## Expectativa acumulada até a semana atual.
var hype: int = 0
## Expectativa perdida com um vazamento.
var leak_penalty: int = 0
var result: MarketingResult


func is_active() -> bool:
	return status == STATUS_ACTIVE


func is_completed() -> bool:
	return status == STATUS_COMPLETED


func find_action(action_id: String) -> Action:
	for action in actions:
		if action.action_id == action_id:
			return action
	return null


func invested() -> int:
	var total := 0
	for action in actions:
		total += action.paid_cost
	return total


func status_label() -> String:
	match status:
		STATUS_ACTIVE:
			return "Em andamento"
		STATUS_COMPLETED:
			return "Concluída"
	return "Em planejamento"


func to_dict() -> Dictionary:
	var action_dicts: Array[Dictionary] = []
	for action in actions:
		action_dicts.append(action.to_dict())
	return {
		"content_id": content_id,
		"leak_penalty": leak_penalty,
		"status": status,
		"actions": action_dicts,
		"hype": hype,
		"result": result.to_dict() if result != null else null,
	}


static func from_dict(data: Dictionary) -> MarketingCampaign:
	var campaign := MarketingCampaign.new()
	campaign.content_id = data.get("content_id", "")
	campaign.leak_penalty = int(data.get("leak_penalty", 0))
	campaign.status = data.get("status", STATUS_PLANNING)
	campaign.hype = int(data.get("hype", 0))
	for item: Dictionary in data.get("actions", []):
		campaign.actions.append(Action.from_dict(item))
	var result_data: Variant = data.get("result")
	if result_data is Dictionary:
		campaign.result = MarketingResult.from_dict(result_data)
	return campaign
