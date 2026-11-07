class_name CollaboratorCatalog
extends Resource

@export var producers: Array[CollaboratorDefinition] = []
@export var beatmakers: Array[CollaboratorDefinition] = []
@export var feats: Array[CollaboratorDefinition] = []


## Devolve os colaboradores conhecidos de uma função, na ordem dos ids.
## Ids que saíram do catálogo são ignorados, para saves antigos continuarem abrindo.
static func resolve(pool: Array[CollaboratorDefinition], ids: Array[String]) -> Array[CollaboratorDefinition]:
	var resolved: Array[CollaboratorDefinition] = []
	for id in ids:
		for person in pool:
			if String(person.id) == id:
				resolved.append(person)
				break
	return resolved


static func names(pool: Array[CollaboratorDefinition], ids: Array[String]) -> PackedStringArray:
	var result := PackedStringArray()
	for person in resolve(pool, ids):
		result.append(person.display_name)
	return result
