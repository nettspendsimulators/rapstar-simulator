class_name LabelLevelDefinition
extends Resource
## Um nível da gravadora do jogador. Subir de nível custa caixa da gravadora e pede reputação.

@export var display_name: String = ""
## Pago com o saldo da gravadora para chegar a este nível (o primeiro nível vem com a fundação).
@export var upgrade_cost: int = 0
@export var min_reputation: int = 0
@export var max_artists: int = 2
## Bônus de descoberta nos lançamentos do próprio jogador.
@export var reach_bonus: float = 0.0
## Mais propostas de show para o jogador.
@export var show_bonus: float = 0.0
## Multiplica o faturamento dos artistas contratados.
@export var artist_revenue_multiplier: float = 1.0
