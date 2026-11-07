extends Node
## Autoload que guarda a carreira atual, liga os sistemas e é a porta de entrada da UI.
## A UI chama estes métodos e reage a career_changed; as regras ficam nos sistemas.

signal career_changed

const BALANCE: GameBalance = preload("res://data/game_balance.tres")

var balance: GameBalance = BALANCE
var career: CareerData
var rng := RandomNumberGenerator.new()

var time := TimeSystem.new()
var economy := EconomySystem.new()
var saves := SaveSystem.new(balance)
var covers := CoverSystem.new(balance, saves)
var performance := PerformanceSystem.new(balance, rng)
var song_quality := SongQualitySystem.new(balance)
var work := WorkSystem.new(economy)
var music := MusicSystem.new(balance, economy, song_quality, rng)
var albums := AlbumSystem.new(balance, economy)
var releases := ReleaseSystem.new(balance, economy, time, performance)
var weeks := WeekSystem.new(balance, time, economy, work, releases)


func _init() -> void:
	rng.randomize()


func new_career(artist_name: String) -> ActionResult:
	var clean_name := artist_name.strip_edges()
	if clean_name.is_empty():
		return ActionResult.failure("Escolha um nome artístico.")
	career = CareerData.create(clean_name, balance)
	career_changed.emit()
	return ActionResult.success()


func has_save() -> bool:
	return saves.has_save()


func save_game() -> ActionResult:
	return saves.save_career(career)


func load_game() -> ActionResult:
	var result := saves.load_career()
	if result.ok:
		career = result.value
		career_changed.emit()
	return result


func next_week() -> WeekReport:
	var report := weeks.process_week(career)
	career_changed.emit()
	return report


func work_job(job_id: StringName) -> ActionResult:
	var job := balance.find_job(job_id)
	if job == null:
		return ActionResult.failure("Trabalho inválido.")
	var report := weeks.process_week(career, job)
	career_changed.emit()
	return ActionResult.success(job.get_report_text(), report)


func create_song(title: String, credits: SongCredits = null, cover_file: String = "") -> ActionResult:
	return _notify_if_ok(music.create_song(career, title, credits, cover_file))


func edit_song(song_id: String, title: String, credits: SongCredits, cover_file: String) -> ActionResult:
	return _notify_if_ok(music.edit_song(career, song_id, title, credits, cover_file))


func improve_song(content_id: String, attribute_id: String) -> ActionResult:
	return _notify_if_ok(music.improve_song(career, content_id, attribute_id))


func create_album(title: String, format_id: StringName, song_ids: Array[String] = [], cover_file: String = "") -> ActionResult:
	return _notify_if_ok(albums.create_album(career, title, format_id, song_ids, cover_file))


func update_album(album_id: String, title: String, format_id: StringName, song_ids: Array[String], cover_file: String) -> ActionResult:
	return _notify_if_ok(albums.update_album(career, album_id, title, format_id, song_ids, cover_file))


func release_content(content_id: String) -> ActionResult:
	return _notify_if_ok(releases.release(career, content_id))


func schedule_release(content_id: String, week: int) -> ActionResult:
	return _notify_if_ok(releases.schedule(career, content_id, week))


func reschedule_release(content_id: String, week: int) -> ActionResult:
	return _notify_if_ok(releases.reschedule(career, content_id, week))


func cancel_schedule(content_id: String) -> ActionResult:
	return _notify_if_ok(releases.cancel_schedule(career, content_id))


func _notify_if_ok(result: ActionResult) -> ActionResult:
	if result.ok:
		career_changed.emit()
	return result
