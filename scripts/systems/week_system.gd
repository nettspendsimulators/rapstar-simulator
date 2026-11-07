class_name WeekSystem
extends RefCounted
## Processamento central da semana. Eventos, despesas, contratos e shows entram
## como novas etapas de process_week, cada uma escrevendo no mesmo relatório.

var _balance: GameBalance
var _time: TimeSystem
var _economy: EconomySystem
var _work: WorkSystem
var _release: ReleaseSystem
var _marketing: MarketingSystem
var _streaming: StreamingSystem
var _videos: VideoSystem


func _init(balance: GameBalance, time: TimeSystem, economy: EconomySystem, work: WorkSystem, release: ReleaseSystem, marketing: MarketingSystem, streaming: StreamingSystem, videos: VideoSystem) -> void:
	_balance = balance
	_time = time
	_economy = economy
	_work = work
	_release = release
	_marketing = marketing
	_streaming = streaming
	_videos = videos


func process_week(career: CareerData, job: JobDefinition = null) -> WeekReport:
	_time.advance(career)
	var report := WeekReport.new()
	report.week = career.current_week
	if job != null:
		_work.perform(career, job, report)
	_release.process_week(career, report)
	_videos.process_views(career, report)
	_streaming.finish_week(career, report)
	_marketing.process_week(career, report)
	_release.process_leaks(career, report)
	_release.publish_due(career, report)
	_videos.process_schedule(career, report)
	_economy.restore_energy(career, _balance.energy_per_week, _balance.max_energy)
	career.week_reports.append(report)
	return report
