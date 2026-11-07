class_name CrewRoleDefinition
extends Resource
## Função da equipe de shows. Cada nível multiplica o custo pelos fatores das regras.

@export var id: String = ""
@export var display_name: String = ""
## Custo por show no primeiro nível.
@export var base_cost: int = 0
## Pessoas por nível, para transporte, hospedagem e alimentação.
@export var people: int = 1
## Qualidade por nível.
@export var quality: int = 0
## Organização por nível.
@export var organization: int = 0
## Vendas de merch extras por nível.
@export var merch_bonus: float = 0.0
## Repercussão por nível.
@export var buzz: int = 0
