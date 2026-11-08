class_name SocialData
extends RefCounted
## Rede social de uma carreira: relações do jogador, mudanças nas relações entre artistas,
## beefs e convites. Cada carreira tem a sua.

var relations: Dictionary[String, Relationship] = {}
## Só as relações entre artistas que mudaram na carreira ("idA|idB" em ordem alfabética -> valor).
## As demais vêm de um valor estável calculado pelo SocialSystem.
var npc_relations: Dictionary[String, int] = {}
var beefs: Array[Beef] = []
var invites: Array[SocialInvite] = []


func find_beef(beef_id: String) -> Beef:
	for beef in beefs:
		if beef.id == beef_id:
			return beef
	return null


func active_beef_with(artist_id: String) -> Beef:
	for beef in beefs:
		if beef.artist_id == artist_id and beef.is_active():
			return beef
	return null


func find_invite(invite_id: String) -> SocialInvite:
	for invite in invites:
		if invite.id == invite_id:
			return invite
	return null


func to_dict() -> Dictionary:
	var relation_dicts := {}
	for artist_id in relations:
		relation_dicts[artist_id] = relations[artist_id].to_dict()
	return {
		"relations": relation_dicts, "npc_relations": npc_relations,
		"beefs": beefs.map(func(item: Beef) -> Dictionary: return item.to_dict()),
		"invites": invites.map(func(item: SocialInvite) -> Dictionary: return item.to_dict()),
	}


static func from_dict(data: Dictionary) -> SocialData:
	var social := SocialData.new()
	var relation_data: Dictionary = data.get("relations", {})
	for artist_id: String in relation_data:
		social.relations[artist_id] = Relationship.from_dict(relation_data[artist_id])
	var npc: Dictionary = data.get("npc_relations", {})
	for key: String in npc:
		social.npc_relations[key] = int(npc[key])
	for item: Dictionary in data.get("beefs", []):
		social.beefs.append(Beef.from_dict(item))
	for item: Dictionary in data.get("invites", []):
		social.invites.append(SocialInvite.from_dict(item))
	return social
