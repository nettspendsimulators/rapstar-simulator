class_name CharacterAppearance
extends RefCounted
## Aparência do personagem: uma peça por categoria e uma lista de acessórios.
## Categorias novas em data/character.tres funcionam sem mudar este modelo.

## Categoria -> id da peça escolhida.
var choices: Dictionary[String, String] = {}
var accessories: Array[String] = []


## "male" ou "female", lido da peça escolhida em "sex" (ids sex_male / sex_female).
func sex() -> String:
	return "female" if get_choice("sex") == "sex_female" else "male"


## Todas as peças usadas (uma por categoria e os acessórios).
func worn_ids() -> Array[String]:
	var ids: Array[String] = []
	for category in choices:
		ids.append(choices[category])
	ids.append_array(accessories)
	return ids


func get_choice(category: String) -> String:
	return choices.get(category, "")


func set_choice(category: String, option_id: String) -> void:
	choices[category] = option_id


func has_accessory(option_id: String) -> bool:
	return option_id in accessories


func set_accessory(option_id: String, enabled: bool) -> void:
	if enabled and not has_accessory(option_id):
		accessories.append(option_id)
	elif not enabled:
		accessories.erase(option_id)


func copy() -> CharacterAppearance:
	return CharacterAppearance.from_dict(to_dict())


func to_dict() -> Dictionary:
	return {"choices": choices.duplicate(), "accessories": accessories.duplicate()}


static func from_dict(data: Dictionary) -> CharacterAppearance:
	var appearance := CharacterAppearance.new()
	var saved: Dictionary = data.get("choices", {})
	for category: String in saved:
		appearance.choices[category] = String(saved[category])
	appearance.accessories.assign(data.get("accessories", []))
	return appearance
