class_name MarketingActionDefinition
extends Resource
## Uma ação de promoção disponível. A lista fica em data/marketing.tres.

@export var id: String
@export var display_name: String
@export var cost: int = 0
## Pessoas que a ação pode alcançar quando roda pelo tempo ideal.
@export var reach: int = 0
## Semanas antes do lançamento em que a ação rende o máximo.
@export var duration_weeks: int = 2
## Pontos de expectativa que a ação pode gerar.
@export var hype_impact: float = 0.0
## Multiplica fãs e potencial de desempenho que a campanha gera.
@export var return_potential: float = 1.0
## Parte do alcance que vira pré-save. Zero para ações que não geram pré-saves.
@export var pre_save_rate: float = 0.0

@export_group("Requisitos")
@export var required_fame: int = 0
@export var required_reputation: int = 0


func meets_requirements(career: CareerData) -> bool:
	return career.fame >= required_fame and career.reputation >= required_reputation


func requirements_text() -> String:
	var parts := PackedStringArray()
	if required_fame > 0:
		parts.append("Fama %s" % Fmt.number(required_fame))
	if required_reputation > 0:
		parts.append("Rep. %s" % Fmt.number(required_reputation))
	return ", ".join(parts) if not parts.is_empty() else "—"
