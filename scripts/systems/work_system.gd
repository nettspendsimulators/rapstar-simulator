class_name WorkSystem
extends RefCounted
## Paga um trabalho durante o processamento da semana. Só é chamado pelo WeekSystem,
## então cada trabalho consome uma semana e não é possível repeti-lo na mesma semana.

var _economy: EconomySystem


func _init(economy: EconomySystem) -> void:
	_economy = economy


func perform(career: CareerData, job: JobDefinition, report: WeekReport) -> void:
	_economy.earn(career, job.pay, job.get_finance_text(), FinanceEntry.CATEGORY_WORK)
	var entry := WeekReportEntry.new()
	entry.title = job.get_report_text()
	entry.money = job.pay
	report.entries.append(entry)
