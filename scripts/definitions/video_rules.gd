class_name VideoRules
extends Resource
## Produção e desempenho de videoclipes. A instância fica em data/videos.tres.

const MODE_WITH_SONG := "with_song"
const MODE_DATE := "date"

@export var categories: Array[VideoCategoryDefinition] = []

@export_group("Notas de produção")
## Valor inicial de cada nota antes das escolhas.
@export var base_stat: int = 20
@export var base_risk: int = 5
## Pesos da nota do videoclipe. A soma deve dar 1.
@export var technical_weight: float = 0.2
@export var visual_weight: float = 0.25
@export var creativity_weight: float = 0.2
@export var identity_weight: float = 0.1
@export var coherence_weight: float = 0.25

@export_group("Coerência")
@export var base_coherence: int = 50
@export var fit_bonus: int = 6
@export var clash_penalty: int = 8
## Quanto o atributo favorito do conceito, acima da média da música, aumenta a coerência.
@export var song_fit_weight: float = 0.5
@export var feats_with_guests_bonus: int = 8

@export_group("Prazo e risco")
## Semanas extras por locação além da primeira.
@export var extra_location_weeks: float = 0.5
@export var extra_location_visual: int = 3
@export var extra_location_risk: int = 2
## Risco de cada escolha muito acima da escala da produção.
@export var tier_mismatch_risk: int = 8
## Risco de cada nível de complexidade acima do que a equipe aguenta.
@export var crew_overload_risk: int = 10
## Chance de problema na produção por ponto de risco.
@export var problem_chance_per_risk: float = 0.006
@export var problem_delay_min: int = 1
@export var problem_delay_max: int = 2
@export var problem_quality_loss: int = 10

@export_group("Desempenho")
## Parte do público da música que assiste ao videoclipe.
@export var audience_share: float = 0.6
## Público mínimo, para músicas sem dados nas plataformas.
@export var min_base_units: int = 1500
## Peso da música na nota usada para o desempenho; o resto vem do videoclipe.
@export var song_quality_weight: float = 0.5
## Quanto apelo comercial e descoberta aumentam as visualizações.
@export var commercial_bonus: float = 0.3
@export var discovery_bonus: float = 0.3
@export var song_popularity_bonus_per_magnitude: float = 0.05
## Visualizações em relação às reproduções da música que viram bônus para a música.
@export var song_boost_per_ratio: float = 0.2
@export var max_song_boost: float = 0.5
@export var fame_multiplier: float = 0.5
@export var engagement_base: float = 0.02
@export var engagement_per_creativity: float = 0.0004
@export var youtube_platform_id: String = "youtube"

@export_group("Vazamentos")
@export var leak_chance_per_week: float = 0.03
@export var leak_views_min: int = 1000
@export var leak_views_max: int = 20000
## Parte das visualizações do vazamento que continua a cada semana.
@export var leak_views_decay: float = 0.6
@export var leak_followers_rate: float = 0.01
## Chance de o vazamento virar burburinho, somada à nota do videoclipe.
@export var leak_buzz_base_chance: float = 0.25
@export var leak_buzz_score_chance: float = 0.3
@export var leak_harm_factor: float = 0.75
@export var leak_buzz_factor: float = 1.25
## Parte do efeito do vazamento que permanece a cada semana depois do lançamento oficial.
@export var leak_effect_decay: float = 0.7


func find_category(category_id: String) -> VideoCategoryDefinition:
	for category in categories:
		if category.id == category_id:
			return category
	return null


func find_option(option_id: String) -> VideoOptionDefinition:
	for category in categories:
		var option := category.find_option(option_id)
		if option != null:
			return option
	return null
