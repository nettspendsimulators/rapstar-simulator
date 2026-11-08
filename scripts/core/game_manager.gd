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
var characters := CharacterSystem.new(balance)
var covers := CoverSystem.new(balance, saves)
var performance := PerformanceSystem.new(balance, rng)
var song_quality := SongQualitySystem.new(balance)
var work := WorkSystem.new(economy)
var social := SocialSystem.new(balance, economy, rng)
var music := MusicSystem.new(balance, economy, song_quality, rng)
var albums := AlbumSystem.new(balance, economy)
var marketing := MarketingSystem.new(balance, economy, rng)
var streaming := StreamingSystem.new(balance, economy, performance, time, marketing, rng)
var videos := VideoSystem.new(balance, economy, performance, streaming, marketing, time, rng)
var releases := ReleaseSystem.new(balance, economy, time, performance, marketing, streaming, videos, rng)
var merch := MerchSystem.new(balance, economy, rng)
var live := LiveSystem.new(balance, economy, streaming, merch, rng)
var tours := TourSystem.new(balance, economy, live, streaming, rng)
var festivals := FestivalSystem.new(balance, live, rng)
var progression := ProgressionSystem.new(balance, streaming, live)
var weeks := WeekSystem.new(balance, time, economy, work, releases, marketing, streaming, videos, live, tours, festivals, progression)


## Slot (arquivo) da carreira aberta. Salvar e carregar usam sempre este slot.
var current_slot: String = SaveSystem.DEFAULT_SLOT


var beefs := BeefSystem.new(balance, economy, social, streaming, rng)


func _init() -> void:
	rng.randomize()
	music.social = social
	releases.social = social
	live.social = social
	tours.social = social
	weeks.social = social
	weeks.beefs = beefs
	social.streaming = streaming
	social.live = live
	social.beefs = beefs


## Carreira com identidade e aparência padrão, ainda sem slot próprio.
func new_career(artist_name: String) -> ActionResult:
	var clean_name := artist_name.strip_edges()
	if clean_name.is_empty():
		return ActionResult.failure("Escolha um nome artístico.")
	career = CareerData.create(clean_name, balance)
	career.age = balance.character.default_age
	career.country = balance.character.default_country
	career.appearance = characters.default_appearance()
	festivals.ensure_editions(career)
	career_changed.emit()
	return ActionResult.success()


## Nova carreira independente: identidade, aparência e um slot próprio, salvo na hora.
## identity: real_name, age, country, city.
func create_career(artist_name: String, identity: Dictionary, appearance: CharacterAppearance) -> ActionResult:
	var previous := career
	var created := new_career(artist_name)
	if not created.ok:
		return created
	var applied := characters.apply_identity(career, identity)
	if not applied.ok:
		career = previous
		return applied
	career.appearance = characters.sanitize(appearance)
	current_slot = saves.new_slot_id()
	var saved := saves.save_career(career, current_slot)
	career_changed.emit()
	return ActionResult.success("Carreira criada." if saved.ok else saved.message, career)


## Há um save da carreira aberta.
func has_save() -> bool:
	return saves.has_save(current_slot)


func has_any_save() -> bool:
	return not saves.list_slots().is_empty()


func list_careers() -> Array[Dictionary]:
	return saves.list_slots()


func save_game() -> ActionResult:
	return saves.save_career(career, current_slot)


## Sem slot, recarrega a carreira aberta. Com slot, abre aquela carreira.
func load_game(slot: String = "") -> ActionResult:
	var target := current_slot if slot.is_empty() else slot
	var result := saves.load_career(target)
	if result.ok:
		current_slot = target
		career = result.value
		festivals.ensure_editions(career)
		career_changed.emit()
	return result


func delete_career(slot: String) -> ActionResult:
	return saves.delete_slot(slot)


## Troca a aparência sem tocar no resto da carreira e grava no slot da carreira.
func set_appearance(appearance: CharacterAppearance) -> ActionResult:
	career.appearance = characters.sanitize(appearance)
	var saved := save_game()
	career_changed.emit()
	return ActionResult.success("Aparência salva." if saved.ok else saved.message)


func set_infinite_energy(enabled: bool) -> ActionResult:
	career.infinite_energy = enabled
	var saved := save_game()
	career_changed.emit()
	if not saved.ok:
		return saved
	return ActionResult.success("Energia infinita %s nesta carreira." % ("ativada" if enabled else "desativada"))


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


func create_song(title: String, credits: SongCredits = null, cover_file: String = "", sample: SongSample = null, diss_target_id: String = "") -> ActionResult:
	return _notify_if_ok(music.create_song(career, title, credits, cover_file, sample, diss_target_id))


func edit_song(song_id: String, title: String, credits: SongCredits, cover_file: String, sample: SongSample = null, diss_target_id: Variant = null) -> ActionResult:
	return _notify_if_ok(music.edit_song(career, song_id, title, credits, cover_file, sample, diss_target_id))


func social_interact(artist_id: String, interaction_id: String) -> ActionResult:
	return _notify_if_ok(social.interact(career, artist_id, interaction_id))


func accept_social_invite(invite_id: String) -> ActionResult:
	return _notify_if_ok(social.accept_invite(career, invite_id))


func decline_social_invite(invite_id: String) -> ActionResult:
	return _notify_if_ok(social.decline_invite(career, invite_id))


func ignore_beef(artist_id: String) -> ActionResult:
	return _notify_if_ok(beefs.ignore(career, artist_id))


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


func add_marketing_action(content_id: String, action_id: String) -> ActionResult:
	return _notify_if_ok(marketing.add_action(career, content_id, action_id))


func remove_marketing_action(content_id: String, action_id: String) -> ActionResult:
	return _notify_if_ok(marketing.remove_action(career, content_id, action_id))


func create_video(song_id: String, choices: Dictionary, cover_file: String, release_mode: String, scheduled_week: int) -> ActionResult:
	return _notify_if_ok(videos.create_video(career, song_id, choices, cover_file, release_mode, scheduled_week))


func update_video(video_id: String, cover_file: String, release_mode: String, scheduled_week: int) -> ActionResult:
	return _notify_if_ok(videos.update_video(career, video_id, cover_file, release_mode, scheduled_week))


func schedule_show(show: LiveShow) -> ActionResult:
	return _notify_if_ok(live.schedule_independent(career, show))


func accept_offer(offer_id: String, choices: LiveShow) -> ActionResult:
	return _notify_if_ok(live.accept_offer(career, offer_id, choices))


func reject_offer(offer_id: String) -> ActionResult:
	return _notify_if_ok(live.reject_offer(career, offer_id))


func cancel_show(show_id: String) -> ActionResult:
	return _notify_if_ok(live.cancel_show(career, show_id))


func create_tour(tour_name: String, goal: String, project_id: String, types: Array[String], co_headliner_id: String) -> ActionResult:
	return _notify_if_ok(tours.create_tour(career, tour_name, goal, project_id, types, co_headliner_id))


func update_tour(tour_id: String, tour_name: String, goal: String, project_id: String, types: Array[String], co_headliner_id: String) -> ActionResult:
	return _notify_if_ok(tours.update_tour(career, tour_id, tour_name, goal, project_id, types, co_headliner_id))


func save_tour_date(tour_id: String, show: LiveShow) -> ActionResult:
	return _notify_if_ok(tours.save_date(career, tour_id, show))


func remove_tour_date(show_id: String) -> ActionResult:
	return _notify_if_ok(tours.remove_date(career, show_id))


func confirm_tour(tour_id: String) -> ActionResult:
	return _notify_if_ok(tours.confirm(career, tour_id))


func pause_tour(tour_id: String) -> ActionResult:
	return _notify_if_ok(tours.pause(career, tour_id))


func resume_tour(tour_id: String) -> ActionResult:
	return _notify_if_ok(tours.resume(career, tour_id))


func cancel_tour(tour_id: String) -> ActionResult:
	return _notify_if_ok(tours.cancel(career, tour_id))


func seek_sponsors(tour_id: String) -> ActionResult:
	return _notify_if_ok(tours.seek_sponsors(career, tour_id))


func accept_sponsor(tour_id: String, sponsor_id: String) -> ActionResult:
	return _notify_if_ok(tours.accept_sponsor(career, tour_id, sponsor_id))


func apply_to_festival(edition_id: String) -> ActionResult:
	return _notify_if_ok(festivals.apply(career, edition_id))


func manufacture_merch(product_id: String, quantity: int, price: int, exclusive_kind: String, exclusive_id: String, limited: bool) -> ActionResult:
	return _notify_if_ok(merch.manufacture(career, product_id, quantity, price, exclusive_kind, exclusive_id, limited))


func set_merch_price(item_id: String, price: int) -> ActionResult:
	return _notify_if_ok(merch.set_price(career, item_id, price))


func set_artist_cover(cover_file: String) -> void:
	career.artist_cover = cover_file
	career_changed.emit()


func set_artist_bio(bio: String) -> void:
	career.artist_bio = bio.strip_edges()
	career_changed.emit()


## Energia como o jogador vê: "infinita" quando a carreira tem essa opção ligada.
func energy_text() -> String:
	if career.infinite_energy:
		return "infinita"
	return "%d/%d" % [career.energy, balance.max_energy]


func _notify_if_ok(result: ActionResult) -> ActionResult:
	if result.ok:
		career_changed.emit()
	return result
