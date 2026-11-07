class_name SongQualityRules
extends Resource
## Parâmetros da nota das músicas e das melhorias.

@export_group("Limites de colaboradores")
@export var max_producers: int = 3
@export var max_beatmakers: int = 3
@export var max_feats: int = 5

@export_group("Atributos")
@export var attributes: Array[SongAttributeDefinition] = []
## Peso das participações na nota geral. Somado aos pesos dos atributos, deve dar 1.
@export var feats_weight: float = 0.10

@export_group("Sem colaboradores")
## Nota de uma parte quando o próprio artista cuida dela.
@export var solo_skill: int = 50
@export var solo_consistency: int = 50

@export_group("Cálculo")
## Bônus por colaborador além do primeiro, na mesma função.
@export var team_bonus_per_extra: int = 2
## Variação máxima, para cima ou para baixo, de um time com consistência 0.
@export var max_variance: float = 15.0

@export_group("Melhorias")
@export var improvement_gain_min: int = 2
@export var improvement_gain_max: int = 4
## Quantos pontos as melhorias podem somar acima da nota base de cada atributo.
@export var max_improvement_points: int = 15


func find_attribute(attribute_id: String) -> SongAttributeDefinition:
	for attribute in attributes:
		if attribute.id == attribute_id:
			return attribute
	return null
