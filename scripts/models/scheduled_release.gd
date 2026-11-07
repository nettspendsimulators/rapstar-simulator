class_name ScheduledRelease
extends RefCounted
## Um lançamento programado. O custo é pago ao agendar e devolvido se for cancelado.

const STATUS_SCHEDULED := "scheduled"
const STATUS_RELEASED := "released"
const STATUS_CANCELLED := "cancelled"

var content_id: String = ""
var scheduled_week: int = 0
var status: String = STATUS_SCHEDULED
var paid_cost: int = 0


func is_active() -> bool:
	return status == STATUS_SCHEDULED


func status_label() -> String:
	match status:
		STATUS_RELEASED:
			return "Lançado"
		STATUS_CANCELLED:
			return "Cancelado"
	return "Agendado"


func to_dict() -> Dictionary:
	return {
		"content_id": content_id,
		"scheduled_week": scheduled_week,
		"status": status,
		"paid_cost": paid_cost,
	}


static func from_dict(data: Dictionary) -> ScheduledRelease:
	var schedule := ScheduledRelease.new()
	schedule.content_id = data.get("content_id", "")
	schedule.scheduled_week = int(data.get("scheduled_week", 0))
	schedule.status = data.get("status", STATUS_SCHEDULED)
	schedule.paid_cost = int(data.get("paid_cost", 0))
	return schedule
