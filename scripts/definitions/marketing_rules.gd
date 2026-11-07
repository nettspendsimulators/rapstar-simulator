class_name MarketingRules
extends Resource
## Ações, resultados e parâmetros do marketing. A instância fica em data/marketing.tres.

@export var actions: Array[MarketingActionDefinition] = []
@export var outcomes: Array[MarketingOutcomeDefinition] = []

@export_group("Tempo de campanha")
## Eficiência de uma ação sem nenhuma semana antes do lançamento.
@export_range(0.0, 1.0) var min_timing_efficiency: float = 0.35
## Eficiência perdida a cada semana além da duração ideal da ação.
@export_range(0.0, 1.0) var overrun_efficiency_loss: float = 0.05
## Menor eficiência de uma ação que começou cedo demais.
@export_range(0.0, 1.0) var overrun_efficiency_floor: float = 0.6

@export_group("Expectativa")
## Multiplicador para qualidade 0 e para qualidade 100.
@export var quality_factor_min: float = 0.6
@export var quality_factor_max: float = 1.4
@export var hype_per_fame_point: float = 0.002
@export var max_fame_hype_factor: float = 1.5
## Bônus por ação além da primeira, por elas se reforçarem.
@export var synergy_per_extra_action: float = 0.05
## Pontos de expectativa por ordem de grandeza do alcance.
@export var hype_per_reach_magnitude: float = 1.0

@export_group("Alcance")
@export var reach_per_fame_point: float = 0.005

@export_group("Resultados")
@export var new_fan_rate: float = 0.01
## Pontos de exposição por ordem de grandeza do alcance, de 0 a 100.
@export var exposure_per_reach_magnitude: float = 15.0
@export var new_fans_per_popularity_point: int = 100

@export_group("Desempenho")
## Maior bônus de streams na primeira semana, com expectativa e qualidade máximas.
@export var max_initial_bonus: float = 0.5
## Parte do bônus de streams que permanece a cada semana.
@export_range(0.0, 1.0) var initial_bonus_decay: float = 0.7


func find_action(action_id: String) -> MarketingActionDefinition:
	for action in actions:
		if action.id == action_id:
			return action
	return null
