class_name FestivalDefinition
extends Resource
## Um festival que volta todo ano, com edições próprias.

@export var id: String = ""
@export var display_name: String = ""
@export var country: String = ""
@export var city_id: String = ""
@export var genres: String = ""
## Quanto o festival valoriza rap, de 0 a 1.
@export var rap_affinity: float = 1.0
@export var prestige: int = 50
## Público por dia.
@export var capacity: int = 10000
@export var stages: Array[String] = []
@export var week_of_year: int = 1
@export var days: int = 1
@export var merch_allowed: bool = true
## Fama mínima para a inscrição ser considerada.
@export var min_fame: int = 0
## Cachê do headliner. As outras posições recebem uma fração.
@export var headliner_fee: int = 0
## fixed, variable (conforme o público) ou covered (sem cachê, despesas pagas).
@export var fee_model: String = "fixed"
@export var covers_expenses: bool = true
