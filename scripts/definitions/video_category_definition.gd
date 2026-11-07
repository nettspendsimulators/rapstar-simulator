class_name VideoCategoryDefinition
extends Resource
## Uma etapa da montagem do videoclipe, como Conceito ou Locações.

@export var id: String
@export var label: String
## Locações aceitam várias escolhas; as demais etapas, uma só.
@export var multiple: bool = false
@export var max_choices: int = 1
@export var options: Array[VideoOptionDefinition] = []


func find_option(option_id: String) -> VideoOptionDefinition:
	for option in options:
		if option.id == option_id:
			return option
	return null
