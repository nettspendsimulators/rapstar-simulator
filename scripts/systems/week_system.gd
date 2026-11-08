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
var _live: LiveSystem
var _tours: TourSystem
var _festivals: FestivalSystem
var _progression: ProgressionSystem
var social: SocialSystem
var beefs: BeefSystem
var labels: LabelSystem


func _init(balance: GameBalance, time: TimeSystem, economy: EconomySystem, work: WorkSystem, release: ReleaseSystem, marketing: MarketingSystem, streaming: StreamingSystem, videos: VideoSystem, live: LiveSystem, tours: TourSystem, festivals: FestivalSystem, progression: ProgressionSystem) -> void:
	_balance = balance
	_time = time
	_economy = economy
	_work = work
	_release = release
	_marketing = marketing
	_streaming = streaming
	_videos = videos
	_live = live
	_tours = tours
	_festivals = festivals
	_progression = progression


func process_week(career: CareerData, job: JobDefinition = null) -> WeekReport:
	var before := _progression.snapshot(career)
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
	_live.process_week(career, report)
	_tours.process_week(career, report)
	_festivals.process_week(career, report)
	if social != null:
		social.process_week(career, report)
		beefs.process_week(career, report)
	_economy.restore_energy(career, _balance.energy_per_week, _balance.max_energy)
	_progression.finish_week(career, report, before)
	# Depois do fechamento: a gravadora própria usa os streams da semana e não mexe no saldo do artista.
	if labels != null:
		labels.process_week(career, report)
	career.week_reports.append(report)
	return report
