class_name LabelRules
extends Resource
## Gravadoras, propostas e a gravadora do jogador. A instância fica em data/labels.tres; todos os
## números de balanceamento do sistema ficam aqui.

const TIER_LABELS := {"underground": "Underground", "indie": "Independente", "medium": "Média", "big": "Grande", "major": "Major"}
## Receitas divididas com a gravadora e custos que ela ajuda a pagar.
const SHARED_CATEGORIES := ["streams", "sales"]
const SUPPORTED_COSTS := {"marketing": "marketing_support", "video": "video_support", "release": "release_support"}

@export var labels: Array[LabelDefinition] = []

@export_group("Propostas")
## Chance base por gravadora e por semana, antes do peso dela e do momento da carreira.
@export var offer_chance: float = 0.035
@export var max_pending_offers: int = 3
@export var offer_weeks_valid: int = 3
## O adiantamento cresce com a fama até este múltiplo do valor base.
@export var max_advance_multiplier: float = 1.8
## Na renovação, a gravadora melhora a parte do artista neste tanto (se o contrato deu lucro).
@export var renewal_share_bonus: float = 0.05
## Rescindir custa o que falta recuperar do adiantamento mais esta fração dele.
@export var termination_fee_rate: float = 0.25

@export_group("Gravadora própria")
@export var creation_cost: int = 120000
@export var creation_min_fame: int = 400
@export var levels: Array[LabelLevelDefinition] = []
## Contratar um artista custa o cachê-base de feat dele vezes este fator.
@export var signing_fee_factor: float = 0.6
## Desconto na contratação para amigos (relação >= friend_value). Rivais recusam.
@export var friend_value: int = 30
@export var friend_discount: float = 0.25
@export var rival_value: int = -15
## Salário semanal de um contratado e faturamento semanal médio, ambos sobre o cachê-base.
@export var artist_weekly_cost_rate: float = 0.005
@export var artist_weekly_revenue_rate: float = 0.035
## Parte do faturamento dos contratados que fica com a gravadora.
@export var label_share_of_artists: float = 0.5
@export var signed_contract_weeks: int = 52
## A cada quantas semanas, em média, um contratado lança uma faixa.
@export var artist_release_interval: int = 6
## Reputação ganha por mil dólares faturados e por mil streams do dono.
@export var reputation_per_k_revenue: float = 0.2
@export var reputation_per_k_owner_plays: float = 0.05


func find_label(id: String) -> LabelDefinition:
	for label in labels:
		if label.id == id:
			return label
	return null
