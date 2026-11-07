class_name StreamingRules
extends Resource
## Plataformas, trajetórias e parâmetros de desempenho. A instância fica em data/streaming.tres.

@export var platforms: Array[PlatformDefinition] = []
@export var trajectories: Array[TrajectoryDefinition] = []
## Trajetória das músicas lançadas antes deste sistema.
@export var legacy_trajectory_id: String = "legacy"

@export_group("Reproduções")
## Variação semanal das reproduções, para cima ou para baixo.
@export var weekly_noise: float = 0.1
## Parte das reproduções de um single que cada faixa de um projeto recebe.
@export var project_track_share: float = 0.3
## Bônus por ordem de grandeza dos seguidores do artista.
@export var audience_bonus_per_magnitude: float = 0.05

@export_group("Momento do lançamento")
## Semanas sem lançar para o público estar com vontade de novidade.
@export var launch_gap_weeks: int = 4
@export var launch_gap_factor: float = 1.1
## Lançamentos colados um no outro dividem a atenção do público.
@export var launch_crowded_factor: float = 0.85
## Parte do efeito do momento do lançamento que permanece a cada semana.
@export var launch_effect_decay: float = 0.75
## Parte do interesse de um sample que vira reproduções iniciais.
@export var sample_interest_weight: float = 1.0

@export_group("Descoberta")
## Maior bônus semanal de descoberta.
@export var discovery_max_bonus: float = 0.4
## Pesos do que faz o público encontrar a música. A soma deve dar 1.
@export var discovery_marketing_weight: float = 0.3
@export var discovery_fame_weight: float = 0.2
@export var discovery_growth_weight: float = 0.2
@export var discovery_catalog_weight: float = 0.15
@export var discovery_listeners_weight: float = 0.15
## Fama, reproduções do catálogo e ouvintes que contam como desempenho máximo.
@export var discovery_fame_reference: int = 200
@export var discovery_catalog_reference: int = 1000000
@export var discovery_listeners_reference: int = 100000
## Chance semanal de a música ser recomendada, somada à descoberta.
@export var recommendation_base_chance: float = 0.01
@export var recommendation_score_chance: float = 0.05
@export var recommendation_boost: float = 1.5
@export var recommendation_weeks: int = 2

@export_group("Trajetória")
## Fama que conta como popularidade máxima no sorteio da trajetória.
@export var trajectory_fame_reference: int = 200
## Menor peso de uma trajetória, para nenhuma ser totalmente impossível.
@export var trajectory_min_factor: float = 0.05

@export_group("Crescimento do artista")
## Novos seguidores necessários para cada ponto de fama.
@export var followers_per_fame: int = 500
## Semanas usadas para calcular os ouvintes atuais.
@export var listeners_window_weeks: int = 4
@export var trend_threshold: float = 0.05

@export_group("Loja digital")
## Vendas de single por reprodução.
@export var single_sale_rate: float = 0.002
@export var single_sale_price: float = 1.0

@export_group("Vazamentos")
## Chance semanal de um lançamento agendado vazar.
@export var leak_chance_per_week: float = 0.02
## Chance extra com a expectativa máxima: mais expectativa, mais olhos no lançamento.
@export var leak_hype_chance: float = 0.03
## Pontos de expectativa perdidos com o vazamento.
@export var leak_hype_penalty: int = 15
## Efeito no lançamento oficial: perde parte da novidade, mas ganha atenção.
@export var leak_launch_factor: float = 0.92
@export var leak_attention_min: int = 500
@export var leak_attention_max: int = 5000
## Parte da atenção do vazamento que vira seguidores.
@export var leak_followers_rate: float = 0.02

@export_group("Outros artistas")
## Ouvintes mensais de um colaborador por dólar do custo dele.
@export var collaborator_listeners_per_cost: int = 100
@export var collaborator_followers_rate: float = 0.4


func find_platform(platform_id: String) -> PlatformDefinition:
	for platform in platforms:
		if platform.id == platform_id:
			return platform
	return null


func find_trajectory(trajectory_id: String) -> TrajectoryDefinition:
	for trajectory in trajectories:
		if trajectory.id == trajectory_id:
			return trajectory
	return null
