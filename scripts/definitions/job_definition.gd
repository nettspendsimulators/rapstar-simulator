class_name JobDefinition
extends Resource
## Um trabalho disponível. Novos trabalhos são adicionados em data/game_balance.tres.

@export var id: StringName
@export var display_name: String
@export var pay: int = 0
## Opcional: substitui "Você trabalhou como <nome>." no relatório.
@export var report_text: String = ""
## Opcional: substitui "Trabalho como <nome>" no histórico financeiro.
@export var finance_text: String = ""


func get_report_text() -> String:
	return report_text if report_text != "" else "Você trabalhou como %s." % display_name


func get_finance_text() -> String:
	return finance_text if finance_text != "" else "Trabalho como %s" % display_name
