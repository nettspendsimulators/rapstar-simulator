class_name LabelDefinition
extends Resource
## Uma gravadora do universo do jogo. Os termos aqui são a base das propostas que ela faz; os
## benefícios entram nos sistemas existentes (receitas, custos, descoberta, shows).

@export var id: String = ""
@export var display_name: String = ""
## Sigla mostrada no logo.
@export var short: String = ""
## underground, indie, medium, big, major.
@export var tier: String = "indie"
## Uma frase sobre o jeito da gravadora.
@export var profile: String = ""
## Logo: formato (circle, hex, diamond, square, shield) e cores.
@export var shape: String = "circle"
@export var color: Color = Color.WHITE
@export var color2: Color = Color.BLACK
## Caixa da gravadora (só informativo) e prestígio de 0 a 100.
@export var capital: int = 0
@export var prestige: int = 0
## Artistas do catálogo do jogo que já são da casa (ids de data/collaborators.tres).
@export var roster: Array[String] = []

@export_group("Proposta")
## Fama mínima para a gravadora se interessar.
@export var min_fame: int = 0
## Chance relativa de fazer proposta numa semana.
@export var offer_weight: float = 1.0
## Parte das receitas de música que fica com o artista (0 a 1).
@export var artist_share: float = 0.7
## Adiantamento base. É recuperado das receitas antes de o artista receber a parte dele por completo.
@export var base_advance: int = 0
@export var contract_weeks: int = 52

@export_group("Benefícios")
## Parte do custo de marketing, videoclipe e lançamento que a gravadora paga, até o orçamento.
@export var marketing_support: float = 0.0
@export var video_support: float = 0.0
@export var release_support: float = 0.0
## Orçamento total que a gravadora coloca nesses custos durante o contrato.
@export var budget: int = 0
## Bônus de descoberta nas plataformas (0.1 = +10%).
@export var discovery_bonus: float = 0.0
## Mais propostas de show (0.2 = +20%).
@export var show_bonus: float = 0.0


func tier_label() -> String:
	return LabelRules.TIER_LABELS.get(tier, tier)
