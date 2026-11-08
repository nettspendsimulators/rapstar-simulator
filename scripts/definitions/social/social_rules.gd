class_name SocialRules
extends Resource
## Valores do sistema social. A instância fica em data/social.tres.

const POSITIVE := [
	{"id": "known", "label": "Conhecido", "min": 0}, {"id": "colleague", "label": "Colega", "min": 15},
	{"id": "friend", "label": "Amigo", "min": 30}, {"id": "close", "label": "Amigo próximo", "min": 50},
	{"id": "great", "label": "Grande amigo", "min": 70}, {"id": "best", "label": "Melhor amigo", "min": 85},
]
const NEGATIVE := [
	{"id": "neutral", "label": "Neutro", "max": -1}, {"id": "tension", "label": "Tensão", "max": -15},
	{"id": "enmity", "label": "Inimizade", "max": -35}, {"id": "rival", "label": "Rival", "max": -55},
	{"id": "great_rival", "label": "Grande rival", "max": -75},
]

@export var interactions: Array[SocialInteractionDefinition] = []

@export_group("Confiança")
## Ganho positivo máximo com um mesmo artista por semana.
@export var weekly_gain_cap: int = 12
## Status -> desconto em feats e participações (0,25 = 25%).
@export var discounts := {"known": 0.05, "colleague": 0.12, "friend": 0.25, "close": 0.4, "great": 0.6, "best": 0.8}
## Tensão encarece; a partir de inimizade, o artista recusa trabalhar com o jogador.
@export var tension_surcharge: float = 0.2
## Artistas muito maiores que o jogador não fazem favores grandes: desconto máximo.
@export var star_discount_cap: float = 0.35
## Tamanho até o qual um artista é "do seu nível": base + fama do jogador × fator (em cachê).
@export var star_cost_base: int = 20000
@export var star_cost_per_fame: int = 40
## Semanas entre dois feats gratuitos do mesmo melhor amigo.
@export var free_feat_cooldown: int = 8

@export_group("Convites espontâneos")
## Status -> chance por semana de um artista convidar o jogador.
@export var invite_chances := {"friend": 0.04, "close": 0.07, "great": 0.1, "best": 0.14}
@export var invite_expiry_weeks: int = 3
## Cachê de uma participação na música de um amigo: parte do cachê de feat dele.
@export var feature_fee_share: float = 0.03
## Fama por participar da música de um amigo, por dólar do cachê de feat dele.
@export var feature_fame_per_cost: float = 0.00004

@export_group("Beefs")
## Queda na relação com o alvo de uma diss.
@export var diss_relation_hit: int = 25
## Chance por semana de um rival provocar o jogador.
@export var rival_provoke_chance: float = 0.08
## Chance por semana de surgir tensão entre dois artistas.
@export var npc_drama_chance: float = 0.05
## Semanas sem reação do jogador para um beef esfriar um nível.
@export var cooldown_weeks: int = 5
@export var diss_fame_base: int = 8
## Fama extra de uma diss bem recebida por mil dólares de cachê do alvo (alvos maiores repercutem mais).
@export var diss_fame_per_size: float = 0.05
@export var diss_followers_per_fame: int = 40
## Seguidores perdidos por uma diss mal recebida, por ponto de nota abaixo de 50.
@export var bad_diss_followers: int = 60


func find_interaction(id: String) -> SocialInteractionDefinition:
	for item in interactions:
		if item.id == id:
			return item
	return null
