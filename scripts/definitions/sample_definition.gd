class_name SampleDefinition
extends Resource
## Um sample disponível na criação de músicas. A lista fica em data/samples.tres.

const TYPE_ICONIC := "iconic"
const TYPE_RECOGNIZABLE := "recognizable"
const TYPE_OBSCURE := "obscure"
const TYPE_OWN := "own"

@export var id: String
@export var display_name: String
@export var type: String = TYPE_OBSCURE
@export var type_label: String = ""
## De 0 (comum) a 100 (raríssimo).
@export_range(0, 100) var rarity: int = 0
## De 0 (ninguém conhece) a 100 (todo mundo conhece).
@export_range(0, 100) var recognition: int = 0
## Pontos somados à nota geral da música. Pode ser negativo.
@export var quality_impact: int = 0
## Interesse do público no lançamento, em porcentagem de reproduções iniciais.
@export var interest_impact: int = 0
## De 0 a 100. Aumenta a chance de a música chamar atenção de repente.
@export_range(0, 100) var attention: int = 0
@export var cost: int = 0


func is_own() -> bool:
	return type == TYPE_OWN


func info_text() -> String:
	return "%s  |  Raridade %d  |  Reconhecimento %d  |  Qualidade %s  |  Interesse +%d%%  |  Custo %s" % [
		type_label,
		rarity,
		recognition,
		Fmt.signed_number(quality_impact),
		interest_impact,
		Fmt.money(cost),
	]
