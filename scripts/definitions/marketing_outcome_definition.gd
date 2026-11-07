class_name MarketingOutcomeDefinition
extends Resource
## Um possível resultado de campanha, sorteado na data de lançamento.
## Novos eventos, como viralização, podem ser novas entradas deste tipo.

@export var id: String
@export var label: String
## Chance relativa de este resultado ser sorteado.
@export var weight: float = 1.0
## Multiplica alcance, expectativa, pré-saves e novos fãs da campanha.
@export var multiplier: float = 1.0
