class_name CareerStageDefinition
extends Resource
## Uma fase da carreira, de artista desconhecido a estrela. A fase vem da fama.

@export var id: String = ""
@export var display_name: String = ""
@export var min_fame: int = 0
## O que essa fase significa para o artista, mostrado no hub e ao subir de fase.
@export_multiline var description: String = ""
