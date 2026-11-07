class_name ProductionLevelDefinition
extends Resource
## Nível de produção de um show.

@export var id: String = ""
@export var display_name: String = ""
## Custo por show para um local de 3.000 pessoas. Escala com o tamanho do local.
@export var cost: int = 0
@export var quality: int = 0
@export var tier: int = 0
