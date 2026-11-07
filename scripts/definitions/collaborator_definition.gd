class_name CollaboratorDefinition
extends Resource
## Um produtor, beatmaker ou participação disponível. A lista fica em data/collaborators.tres.

@export var id: StringName
@export var display_name: String
## Quanto a pessoa eleva a nota da música.
@export_range(0, 100) var skill: int = 70
## Quanto menor, mais a nota do resultado pode variar para cima ou para baixo.
@export_range(0, 100) var consistency: int = 70
