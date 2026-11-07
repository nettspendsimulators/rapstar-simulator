class_name MarketingResult
extends RefCounted
## Resultado de uma campanha, gerado no lançamento e disponível para o sistema de desempenho.

var outcome_id: String = ""
var outcome_label: String = ""
var reach: int = 0
var expectation: int = 0
var pre_saves: int = 0
var new_fans: int = 0
## De 0 a 100, conforme o alcance.
var exposure: int = 0
var popularity: int = 0
## Multiplicador de streams na primeira semana. 1 significa sem bônus.
var initial_potential: float = 1.0


func to_dict() -> Dictionary:
	return {
		"outcome_id": outcome_id,
		"outcome_label": outcome_label,
		"reach": reach,
		"expectation": expectation,
		"pre_saves": pre_saves,
		"new_fans": new_fans,
		"exposure": exposure,
		"popularity": popularity,
		"initial_potential": initial_potential,
	}


static func from_dict(data: Dictionary) -> MarketingResult:
	var result := MarketingResult.new()
	result.outcome_id = data.get("outcome_id", "")
	result.outcome_label = data.get("outcome_label", "")
	result.reach = int(data.get("reach", 0))
	result.expectation = int(data.get("expectation", 0))
	result.pre_saves = int(data.get("pre_saves", 0))
	result.new_fans = int(data.get("new_fans", 0))
	result.exposure = int(data.get("exposure", 0))
	result.popularity = int(data.get("popularity", 0))
	result.initial_potential = float(data.get("initial_potential", 1.0))
	return result
