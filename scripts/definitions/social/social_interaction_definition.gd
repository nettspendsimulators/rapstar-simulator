class_name SocialInteractionDefinition
extends Resource
## Uma ação social com um artista. As regras de cada tipo ficam no SocialSystem/BeefSystem;
## aqui ficam os valores e as condições, para balancear em data/social.tres.

## meet, positive, provoke, respond, apology, reconcile, defend
@export var kind: String = "positive"
@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
## Mudança na relação quando a ação dá certo.
@export var delta: int = 0
## Faixa de relação em que a ação aparece.
@export var min_value: int = -100
@export var max_value: int = 100
@export var money_cost: int = 0
@export var energy_cost: int = 0
## Fama e seguidores ganhos por ações públicas.
@export var fame: int = 0
@export var followers: int = 0
