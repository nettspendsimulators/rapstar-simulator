class_name CollaboratorDefinition
extends Resource
## Um produtor, beatmaker ou participação disponível. A lista fica em data/collaborators.tres.

@export var id: StringName
@export var display_name: String
## Quanto a pessoa eleva a nota da música.
@export_range(0, 100) var skill: int = 70
## Quanto menor, mais a nota do resultado pode variar para cima ou para baixo.
@export_range(0, 100) var consistency: int = 70
## Valor-base pago ao adicionar a pessoa a uma música (cachê de feat). Para artistas, o preço final
## passa pelo SocialSystem (amizade dá desconto, tensão encarece). Valores internos do jogo.
@export var cost: int = 0
## País do artista (vazio para produtores e beatmakers).
@export var country: String = ""
## Nível na indústria: underground, emerging, mid, big ou superstar.
@export var tier: String = ""

const TIER_LABELS := {"underground": "Underground", "emerging": "Emergente", "mid": "Médio", "big": "Grande", "superstar": "Superstar"}


func tier_label() -> String:
	return TIER_LABELS.get(tier, "")
