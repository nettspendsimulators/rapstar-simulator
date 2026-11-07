class_name VideoOptionDefinition
extends Resource
## Uma escolha de produção de videoclipe, como um conceito, uma locação ou um nível de edição.
## A lista fica em data/videos.tres.

@export var id: String
@export var display_name: String
## De 0 (caseiro) a 4 (superprodução). Escolhas muito acima da escala aumentam o risco.
@export_range(0, 4) var tier: int = 0
## Custo antes do multiplicador da escala.
@export var cost: int = 0
@export var weeks: int = 0

@export_group("Efeitos")
@export var technical: int = 0
@export var visual: int = 0
@export var creativity: int = 0
@export var identity: int = 0
@export var commercial: int = 0
@export var discovery: int = 0
@export var viral: int = 0
@export var risk: int = 0

@export_group("Escala")
## Multiplica o custo das demais escolhas. Só vale para as opções de escala.
@export var cost_multiplier: float = 1.0
@export var time_multiplier: float = 1.0
## Complexidade que a equipe aguenta sem aumentar o risco.
@export var crew_capacity: int = 0

@export_group("Conceito")
## Atributo da música que este conceito valoriza.
@export var song_attribute: String = ""
## Escolhas que combinam com este conceito.
@export var fits: PackedStringArray = []
## Escolhas que destoam deste conceito.
@export var clashes: PackedStringArray = []
