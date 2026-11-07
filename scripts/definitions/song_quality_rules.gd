class_name SongQualityRules
extends Resource
## Parâmetros da nota das músicas e das melhorias.

@export_group("Limites de colaboradores")
@export var max_producers: int = 3
@export var max_beatmakers: int = 3
@export var max_feats: int = 5

@export_group("Peso de cada parte na nota")
@export var beat_weight: float = 0.45
@export var production_weight: float = 0.35
@export var feats_weight: float = 0.20

@export_group("Sem colaboradores")
## Nota de cada parte quando o próprio artista cuida dela.
@export var solo_skill: int = 50
@export var solo_consistency: int = 50

@export_group("Cálculo")
## Bônus por colaborador além do primeiro, na mesma função.
@export var team_bonus_per_extra: int = 2
## Variação máxima, para cima ou para baixo, de um time com consistência 0.
@export var max_variance: float = 15.0

@export_group("Melhorias")
@export var improvement_energy_cost: int = 20
@export var improvement_gain_min: int = 2
@export var improvement_gain_max: int = 4
## Quantos pontos as melhorias podem somar acima da nota base da música.
@export var max_improvement_points: int = 15
