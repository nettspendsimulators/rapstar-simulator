class_name FestivalEdition
extends RefCounted
## Uma edição anual de um festival, com lineup completo.

const APPLICATION_NONE := ""
const APPLICATION_PENDING := "pending"
const APPLICATION_ACCEPTED := "accepted"
const APPLICATION_REJECTED := "rejected"
const PLAYER_ID := "player"

var id: String = ""
var festival_id: String = ""
var year: int = 1
## Semana do primeiro dia do festival.
var week: int = 1
## Apresentações: {"artist_id", "name", "day", "stage", "start", "minutes", "position"}.
## day vai de 1 até a duração do festival; start é o horário em minutos desde a meia-noite.
var lineup: Array[Dictionary] = []
var application_status: String = APPLICATION_NONE
var application_week: int = 0


func has_player() -> bool:
	for slot in lineup:
		if slot.get("artist_id", "") == PLAYER_ID:
			return true
	return false


## Coloca o artista no lugar de uma apresentação da mesma posição, ou adiciona uma nova.
func place_player(artist_name: String, position: String, festival_day: int, minutes: int) -> Dictionary:
	for slot in lineup:
		if slot.get("position", "") == position and int(slot.get("day", 0)) == festival_day:
			slot["artist_id"] = PLAYER_ID
			slot["name"] = artist_name
			slot["minutes"] = minutes
			return slot
	var slot := {"artist_id": PLAYER_ID, "name": artist_name, "day": festival_day, "stage": "", "start": 14 * 60, "minutes": minutes, "position": position}
	lineup.append(slot)
	return slot


func to_dict() -> Dictionary:
	return {
		"id": id, "festival_id": festival_id, "year": year, "week": week, "lineup": lineup,
		"application_status": application_status, "application_week": application_week,
	}


static func from_dict(data: Dictionary) -> FestivalEdition:
	var edition := FestivalEdition.new()
	edition.id = data.get("id", "")
	edition.festival_id = data.get("festival_id", "")
	edition.year = int(data.get("year", 1))
	edition.week = int(data.get("week", 1))
	edition.application_status = data.get("application_status", APPLICATION_NONE)
	edition.application_week = int(data.get("application_week", 0))
	for slot: Dictionary in data.get("lineup", []):
		edition.lineup.append(LiveShow.whole_numbers(slot))
	return edition
