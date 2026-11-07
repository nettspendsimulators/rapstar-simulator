class_name PerformanceRules
extends Resource
## Parâmetros do desempenho semanal de um tipo de lançamento.
## "Unidade" é um stream para músicas e uma venda para álbuns.

@export var units_min: int = 1000
@export var units_max: int = 10000
@export var money_per_unit: float = 0.01
@export var units_per_fame: int = 1500
## Qualidade em que o multiplicador de qualidade vale 1.
@export var reference_quality: int = 50
## Quanto do desempenho permanece a cada semana após o lançamento.
@export_range(0.0, 1.0) var weekly_decay: float = 0.9
## Piso do multiplicador de idade, para catálogos antigos renderem um pouco.
@export_range(0.0, 1.0) var min_age_factor: float = 0.1
## Bônus de unidades por ponto de fama do artista.
@export var fame_bonus_per_point: float = 0.005
