class_name Beef
extends RefCounted
## Conflito público entre o jogador e um artista. A intensidade vai de 1 (tensão) a 4 (grande
## rivalidade); "awaiting" diz de quem é a vez de reagir.

const STATUS_ACTIVE := "active"
const STATUS_ENDED := "ended"
const TURN_PLAYER := "player"
const TURN_ARTIST := "artist"
const INTENSITY_LABELS := ["", "Tensão", "Inimizade", "Rivalidade", "Grande rivalidade"]

var id: String = ""
var artist_id: String = ""
var intensity: int = 1
var status: String = STATUS_ACTIVE
var awaiting: String = ""
## Semana em que o artista vai reagir, quando é a vez dele.
var response_week: int = 0
var started_week: int = 0
var last_week: int = 0
## Entradas {"week", "actor" ("player"/"artist"), "kind", "text", "song_id"}.
var events: Array[Dictionary] = []


func is_active() -> bool:
	return status == STATUS_ACTIVE


func intensity_label() -> String:
	return INTENSITY_LABELS[clampi(intensity, 1, 4)]


func to_dict() -> Dictionary:
	return {
		"id": id, "artist_id": artist_id, "intensity": intensity, "status": status, "awaiting": awaiting,
		"response_week": response_week, "started_week": started_week, "last_week": last_week, "events": events,
	}


static func from_dict(data: Dictionary) -> Beef:
	var beef := Beef.new()
	for key in ["id", "artist_id", "status", "awaiting"]:
		beef.set(key, String(data.get(key, beef.get(key))))
	for key in ["intensity", "response_week", "started_week", "last_week"]:
		beef.set(key, int(data.get(key, beef.get(key))))
	for item: Dictionary in data.get("events", []):
		beef.events.append({"week": int(item.get("week", 0)), "actor": String(item.get("actor", "")), "kind": String(item.get("kind", "")),
			"text": String(item.get("text", "")), "song_id": String(item.get("song_id", ""))})
	return beef
