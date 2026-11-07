class_name PlatformDefinition
extends Resource
## Uma plataforma de música. A lista fica em data/streaming.tres.

const KIND_STREAMING := "streaming"
const KIND_STORE := "store"
const KIND_RADIO := "radio"

@export var id: String
@export var display_name: String
@export_multiline var description: String = ""
@export var kind: String = KIND_STREAMING

@export_group("Audiência")
## Parte das reproduções da música que acontece nesta plataforma.
@export var audience_share: float = 0.0
## Atributo da música que esta plataforma mais valoriza.
@export var affinity_attribute: String = ""
## Quanto o atributo preferido muda a parte da plataforma.
@export var affinity_strength: float = 0.0

@export_group("Economia")
@export var money_per_play: float = 0.0

@export_group("Crescimento")
## Ouvintes por reprodução, considerando as últimas semanas.
@export var listeners_per_play: float = 0.0
## Novos seguidores por reprodução.
@export var followers_per_play: float = 0.0
## Curtidas por reprodução. Zero quando a plataforma não mostra curtidas.
@export var likes_per_play: float = 0.0

@export_group("Textos")
## Vazio quando a plataforma não mostra esta informação.
@export var listeners_label: String = ""
@export var followers_label: String = ""
@export var plays_label: String = "Plays"
@export var catalog_label: String = "Catálogo"
@export var extra_label: String = ""

@export_group("Acesso")
## Fama que dá acesso à plataforma sem nenhuma ação de marketing.
@export var required_fame: int = 0
## Ação de marketing que também dá acesso à plataforma.
@export var unlock_action: String = ""
