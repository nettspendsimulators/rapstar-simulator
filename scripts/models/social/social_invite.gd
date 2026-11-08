class_name SocialInvite
extends RefCounted
## Convite de um artista que não é um show (shows e turnês viram propostas do LiveSystem):
## participar de uma música dele, divulgação de um lançamento ou proposta de paz.

const KIND_FEATURE := "feature"
const KIND_PROMOTE := "promote"
const KIND_PEACE := "peace"

var id: String = ""
var artist_id: String = ""
var kind: String = KIND_FEATURE
var week: int = 0
var expires_week: int = 0
## Cachê recebido pelo jogador (participações em músicas de outros artistas).
var fee: int = 0


func to_dict() -> Dictionary:
	return {"id": id, "artist_id": artist_id, "kind": kind, "week": week, "expires_week": expires_week, "fee": fee}


static func from_dict(data: Dictionary) -> SocialInvite:
	var invite := SocialInvite.new()
	invite.id = data.get("id", "")
	invite.artist_id = data.get("artist_id", "")
	invite.kind = data.get("kind", KIND_FEATURE)
	invite.week = int(data.get("week", 0))
	invite.expires_week = int(data.get("expires_week", 0))
	invite.fee = int(data.get("fee", 0))
	return invite
