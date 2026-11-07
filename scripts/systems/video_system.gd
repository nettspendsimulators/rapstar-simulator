class_name VideoSystem
extends RefCounted
## Videoclipes: montagem e orçamento, produção, lançamento, vazamento e desempenho no YouTube.
## Usa a economia, o tempo, as plataformas, as trajetórias e o marketing que já existem.

## Resultado das escolhas de produção, antes de produzir.
class Evaluation:
	var cost: int = 0
	var weeks: int = 0
	var technical: int = 0
	var visual: int = 0
	var creativity: int = 0
	var identity: int = 0
	var coherence: int = 0
	var commercial: int = 0
	var discovery: int = 0
	var viral: int = 0
	var risk: int = 0
	var score: int = 0
	var problem_chance: float = 0.0


var _balance: GameBalance
var _economy: EconomySystem
var _performance: PerformanceSystem
var _streaming: StreamingSystem
var _marketing: MarketingSystem
var _time: TimeSystem
var _rng: RandomNumberGenerator


func _init(balance: GameBalance, economy: EconomySystem, performance: PerformanceSystem, streaming: StreamingSystem, marketing: MarketingSystem, time: TimeSystem, rng: RandomNumberGenerator) -> void:
	_balance = balance
	_economy = economy
	_performance = performance
	_streaming = streaming
	_marketing = marketing
	_time = time
	_rng = rng


## Qualquer música sem videoclipe, lançada ou não, de single ou de projeto.
func eligible_songs(career: CareerData) -> Array[SongData]:
	var songs: Array[SongData] = []
	for song in career.songs:
		if career.find_video_for_song(song.id) == null:
			songs.append(song)
	return songs


## A primeira opção de cada etapa: a produção mais simples possível.
func default_choices() -> Dictionary[String, Array]:
	var choices: Dictionary[String, Array] = {}
	for category in _rules().categories:
		var ids: Array[String] = [category.options[0].id]
		choices[category.id] = ids
	return choices


func evaluate(song: SongData, choices: Dictionary) -> Evaluation:
	var rules := _rules()
	var result := Evaluation.new()
	var scale := _chosen(choices, "scale")[0]
	var complexity := _chosen(choices, "complexity")[0]
	var crew := _chosen(choices, "crew")[0]
	var concept := _chosen(choices, "concept")[0]
	var stats := {
		"technical": rules.base_stat, "visual": rules.base_stat, "creativity": rules.base_stat, "identity": rules.base_stat,
		"commercial": rules.base_stat, "discovery": rules.base_stat, "viral": rules.base_stat, "risk": rules.base_risk,
	}
	var option_cost := 0
	var weeks := float(scale.weeks)
	var chosen_ids := PackedStringArray()
	for category in rules.categories:
		for option in _chosen(choices, category.id):
			chosen_ids.append(option.id)
			for stat: String in stats:
				stats[stat] += option.get(stat)
			if category.id != "scale":
				option_cost += option.cost
				weeks += option.weeks
			# Uma escolha muito acima da escala vira improviso e aumenta o risco.
			if option.tier > scale.tier + 1:
				stats["risk"] += rules.tier_mismatch_risk
	var extra_locations := maxi(_chosen(choices, "locations").size() - 1, 0)
	weeks += extra_locations * rules.extra_location_weeks
	stats["visual"] += extra_locations * rules.extra_location_visual
	stats["risk"] += extra_locations * rules.extra_location_risk
	stats["risk"] += maxi(complexity.tier - (crew.crew_capacity - 1), 0) * rules.crew_overload_risk

	var coherence := float(rules.base_coherence)
	for option_id in chosen_ids:
		if option_id in concept.fits:
			coherence += rules.fit_bonus
		if option_id in concept.clashes:
			coherence -= rules.clash_penalty
	if not concept.song_attribute.is_empty():
		coherence += (song.attribute_value(concept.song_attribute) - song.quality) * rules.song_fit_weight
	if "presence_guests" in chosen_ids and not song.credits.feat_ids.is_empty():
		coherence += rules.feats_with_guests_bonus

	result.cost = roundi(scale.cost + option_cost * scale.cost_multiplier)
	result.weeks = maxi(ceili(weeks * complexity.time_multiplier), 1)
	result.technical = clampi(stats["technical"], 0, 100)
	result.visual = clampi(stats["visual"], 0, 100)
	result.creativity = clampi(stats["creativity"], 0, 100)
	result.identity = clampi(stats["identity"], 0, 100)
	result.commercial = clampi(stats["commercial"], 0, 100)
	result.discovery = clampi(stats["discovery"], 0, 100)
	result.viral = clampi(stats["viral"], 0, 100)
	result.risk = clampi(stats["risk"], 0, 100)
	result.coherence = clampi(roundi(coherence), 0, 100)
	result.score = _score(result.technical, result.visual, result.creativity, result.identity, result.coherence)
	result.problem_chance = minf(result.risk * rules.problem_chance_per_risk, 0.9)
	return result


## Devolve a mensagem de erro, ou um texto vazio se as escolhas forem válidas.
func validate_choices(choices: Dictionary) -> String:
	for category in _rules().categories:
		var ids: Array = choices.get(category.id, [])
		if ids.is_empty():
			return "Escolha uma opção em %s." % category.label
		if ids.size() > category.max_choices:
			return "Escolha no máximo %d em %s." % [category.max_choices, category.label]
		var unique := {}
		for option_id: String in ids:
			if category.find_option(option_id) == null:
				return "Opção inválida em %s." % category.label
			unique[option_id] = true
		if unique.size() != ids.size():
			return "Há opções repetidas em %s." % category.label
	return ""


func create_video(career: CareerData, song_id: String, choices: Dictionary, cover_file: String, release_mode: String, scheduled_week: int) -> ActionResult:
	var song := career.find_song(song_id)
	if song == null:
		return ActionResult.failure("Escolha uma música.")
	if career.find_video_for_song(song_id) != null:
		return ActionResult.failure("\"%s\" já tem um videoclipe." % song.title)
	var error := validate_choices(choices)
	if error.is_empty():
		error = _release_settings_error(career, release_mode, scheduled_week)
	if not error.is_empty():
		return ActionResult.failure(error)
	var evaluation := evaluate(song, choices)
	if not _economy.can_afford(career, evaluation.cost):
		return _economy.insufficient_funds(evaluation.cost)

	if evaluation.cost > 0:
		_economy.spend(career, evaluation.cost, "Videoclipe: %s" % song.title, FinanceEntry.CATEGORY_VIDEO)
	var video := MusicVideo.new()
	video.id = career.new_id("video")
	video.song_id = song_id
	for category_id: String in choices:
		var ids: Array[String] = []
		ids.assign(choices[category_id])
		video.choices[category_id] = ids
	video.cover_file = cover_file
	video.cost = evaluation.cost
	video.production_weeks = evaluation.weeks
	video.start_week = career.current_week
	video.ready_week = career.current_week + evaluation.weeks
	video.release_mode = release_mode
	video.scheduled_week = scheduled_week if release_mode == VideoRules.MODE_DATE else MusicVideo.NO_WEEK
	for stat in ["technical", "visual", "creativity", "identity", "coherence", "commercial", "discovery", "viral", "risk", "score"]:
		video.set(stat, evaluation.get(stat))
	career.music_videos.append(video)
	return ActionResult.success("Produção de \"%s\" começou. Pronto na semana %s." % [song.title, Fmt.number(video.ready_week)], video)


## Capa e lançamento podem mudar até o lançamento oficial. A capa não tem custo.
func update_video(career: CareerData, video_id: String, cover_file: String, release_mode: String, scheduled_week: int) -> ActionResult:
	var video := career.find_video(video_id)
	if video == null:
		return ActionResult.failure("Videoclipe não encontrado.")
	video.cover_file = cover_file
	if video.is_released():
		return ActionResult.success("Capa atualizada.", video)
	var error := _release_settings_error(career, release_mode, scheduled_week)
	if not error.is_empty():
		return ActionResult.failure(error)
	video.release_mode = release_mode
	video.scheduled_week = scheduled_week if release_mode == VideoRules.MODE_DATE else MusicVideo.NO_WEEK
	return ActionResult.success("Videoclipe atualizado.", video)


func status_label(career: CareerData, video: MusicVideo) -> String:
	var label: String
	match video.status:
		MusicVideo.STATUS_RELEASED:
			label = "Lançado na semana %s" % Fmt.number(video.release_week)
		MusicVideo.STATUS_READY:
			label = "Pronto"
		_:
			label = "Em produção até a semana %s" % Fmt.number(video.ready_week)
	if video.is_leaked() and not video.is_released():
		label += " (vazou)"
	return label


func release_label(career: CareerData, video: MusicVideo) -> String:
	if video.is_released():
		return "Semana %s" % Fmt.number(video.release_week)
	var song := career.find_song(video.song_id)
	var waiting := "" if song.is_released() else ", depois da música"
	if video.release_mode == VideoRules.MODE_WITH_SONG:
		return "Junto com a música" if not song.is_released() else "Assim que ficar pronto"
	return "Semana %s%s" % [Fmt.number(video.scheduled_week), waiting]


## Chamado quando músicas saem oficialmente: videoclipes prontos no modo automático saem juntos.
func on_content_released(career: CareerData, content: ReleasableContent, report: WeekReport) -> void:
	var song_ids: Array[String] = []
	if content is SongData:
		song_ids.append(content.id)
	else:
		song_ids.assign(content.song_ids)
	for song_id in song_ids:
		var video := career.find_video_for_song(song_id)
		if video != null and video.status == MusicVideo.STATUS_READY and video.release_mode == VideoRules.MODE_WITH_SONG:
			_release(career, video, report)


## Etapa da semana, antes de as plataformas fecharem a semana: visualizações dos videoclipes.
func process_views(career: CareerData, report: WeekReport) -> void:
	for video in career.music_videos:
		if video.is_released():
			_process_official_views(career, video, report)
		elif video.is_leaked() and video.leak_weekly_views > 0:
			video.leak_weekly_views = roundi(video.leak_weekly_views * _rules().leak_views_decay)
			video.leak_views += video.leak_weekly_views


## Etapa da semana, depois dos lançamentos agendados: produção, vazamentos e lançamentos.
func process_schedule(career: CareerData, report: WeekReport) -> void:
	for video in career.music_videos:
		if video.is_released():
			continue
		if video.status == MusicVideo.STATUS_PRODUCTION and career.current_week >= video.ready_week:
			_finish_production(career, video, report)
		if video.is_released():
			continue
		if not video.is_leaked():
			_maybe_leak(career, video, report)
		if video.status == MusicVideo.STATUS_READY and _release_is_due(career, video):
			_release(career, video, report)


func _release_is_due(career: CareerData, video: MusicVideo) -> bool:
	if not career.find_song(video.song_id).is_released():
		return false
	if video.release_mode == VideoRules.MODE_WITH_SONG:
		return true
	return career.current_week >= video.scheduled_week


func _finish_production(career: CareerData, video: MusicVideo, report: WeekReport) -> void:
	var rules := _rules()
	var song := career.find_song(video.song_id)
	if not video.problem_checked:
		video.problem_checked = true
		if _rng.randf() < minf(video.risk * rules.problem_chance_per_risk, 0.9):
			var delay := _rng.randi_range(rules.problem_delay_min, rules.problem_delay_max)
			video.ready_week += delay
			video.technical = maxi(video.technical - rules.problem_quality_loss, 0)
			video.score = _score(video.technical, video.visual, video.creativity, video.identity, video.coherence)
			video.problem_note = "Problemas na filmagem atrasaram %d semana(s) e prejudicaram a parte técnica." % delay
			_add_line(report, video, song, "Videoclipe: %s" % song.title, video.problem_note)
			return
	video.status = MusicVideo.STATUS_READY
	_add_line(report, video, song, "Videoclipe: %s" % song.title, "Produção concluída. Nota do videoclipe: %d." % video.score)


func _maybe_leak(career: CareerData, video: MusicVideo, report: WeekReport) -> void:
	var rules := _rules()
	if _rng.randf() >= rules.leak_chance_per_week:
		return
	var song := career.find_song(video.song_id)
	video.leak_week = career.current_week
	video.leak_weekly_views = _rng.randi_range(rules.leak_views_min, rules.leak_views_max)
	video.leak_views += video.leak_weekly_views
	# Um bom videoclipe vazado pode virar burburinho; um fraco perde a força da estreia.
	var buzz_chance := rules.leak_buzz_base_chance + video.score / 100.0 * rules.leak_buzz_score_chance
	video.leak_effect = rules.leak_buzz_factor if _rng.randf() < buzz_chance else rules.leak_harm_factor
	_streaming.add_followers(career, roundi(video.leak_weekly_views * rules.leak_followers_rate))
	var effect := "virou burburinho e aumentou a curiosidade" if video.leak_effect > 1.0 else "tirou parte do impacto da estreia"
	_add_line(report, video, song, "Vazamento do videoclipe: %s" % song.title, "%s visualizações não oficiais, sem receita. O vazamento %s." % [Fmt.number(video.leak_weekly_views), effect])


func _release(career: CareerData, video: MusicVideo, report: WeekReport) -> void:
	var song := career.find_song(video.song_id)
	var song_performance := career.find_performance(song.id)
	video.status = MusicVideo.STATUS_RELEASED
	video.release_week = career.current_week
	var song_units := song_performance.base_units if song_performance != null else _rules().min_base_units
	video.base_units = roundi(maxi(song_units, _rules().min_base_units) * _rules().audience_share)
	var campaign := _campaign_for(career, song)
	var hype := campaign.result.expectation if campaign != null and campaign.result != null else 0
	var trajectory := _streaming.roll_trajectory(career, _effective_quality(song, video), hype, video.viral / 100.0)
	video.trajectory_id = trajectory.id
	if trajectory.surge_boost > 0.0:
		video.surge_week = _rng.randi_range(trajectory.surge_week_min, trajectory.surge_week_max)
	if report != null:
		_add_line(report, video, song, "Videoclipe lançado: %s" % song.title, "Disponível no YouTube.")


func _process_official_views(career: CareerData, video: MusicVideo, report: WeekReport) -> void:
	var rules := _rules()
	var song := career.find_song(video.song_id)
	var song_performance := career.find_performance(song.id)
	var age := maxi(_time.weeks_since(career, video.release_week) - 1, 0)
	var trajectory := _balance.streaming.find_trajectory(video.trajectory_id)
	var curve := trajectory.multiplier(age, video.surge_week)
	var commercial := 1.0 + (video.commercial - 50) / 100.0 * rules.commercial_bonus
	var discovery := 1.0 + (video.discovery / 100.0 + _marketing_exposure(career, song) / 100.0) * rules.discovery_bonus
	var song_plays := song_performance.total_plays if song_performance != null else 0
	var popularity := 1.0 + log(song_plays + 1.0) / log(10.0) * rules.song_popularity_bonus_per_magnitude
	var leak := 1.0 + (video.leak_effect - 1.0) * pow(rules.leak_effect_decay, age)
	var marketing := _marketing_multiplier(career, song, age)
	var views := _performance.stream_units(
		_balance.song_performance, video.base_units, _effective_quality(song, video), career.fame,
		curve * commercial * discovery * popularity * leak * marketing, _balance.streaming.weekly_noise
	)
	var youtube := _balance.streaming.find_platform(rules.youtube_platform_id)
	var money := roundi(views * youtube.money_per_play)
	video.total_views += views
	video.weekly_views.append(views)
	video.peak_week_views = maxi(video.peak_week_views, views)
	video.revenue += money
	video.likes += roundi(views * (rules.engagement_base + video.creativity * rules.engagement_per_creativity))
	_streaming.record_platform_plays(career, rules.youtube_platform_id, views, money)
	if money > 0:
		_economy.earn(career, money, "YouTube (videoclipe): %s" % song.title, FinanceEntry.CATEGORY_STREAMS)
	var units_per_fame := _balance.song_performance.units_per_fame
	var fame := floori(views / _performance.fame_factor(_balance.song_performance, career.fame) / units_per_fame * rules.fame_multiplier)
	_economy.add_fame(career, fame)
	# Um videoclipe forte leva gente para a música nas outras plataformas.
	if song_performance != null:
		var song_week: int = song_performance.weekly_plays.back() if not song_performance.weekly_plays.is_empty() else 0
		var ratio := float(views) / maxf(song_week, 1.0)
		song_performance.video_boost = 1.0 + minf(ratio * rules.song_boost_per_ratio, rules.max_song_boost)
	var line := WeekReportEntry.new()
	line.title = "Videoclipe: %s" % song.title
	line.cover_file = video.cover_file if not video.cover_file.is_empty() else song.cover_file
	line.streams = views
	line.money = money
	line.fame = fame
	report.entries.append(line)


## Nota usada no desempenho: metade da música, metade do videoclipe. Uma música fraca não
## vira sucesso só porque o videoclipe é caro.
func _effective_quality(song: SongData, video: MusicVideo) -> int:
	var weight := _rules().song_quality_weight
	return roundi(song.quality * weight + video.score * (1.0 - weight))


func _campaign_for(career: CareerData, song: SongData) -> MarketingCampaign:
	var campaign := career.find_campaign(song.id)
	if campaign == null:
		var album := career.find_album_of_song(song.id)
		if album != null:
			campaign = career.find_campaign(album.id)
	return campaign


func _marketing_exposure(career: CareerData, song: SongData) -> int:
	var campaign := _campaign_for(career, song)
	return campaign.result.exposure if campaign != null and campaign.result != null else 0


func _marketing_multiplier(career: CareerData, song: SongData, age: int) -> float:
	var performance := career.find_performance(song.id)
	if performance == null:
		return 1.0
	var release := career.find_release(performance.release_id)
	return _marketing.units_multiplier(release, age) if release != null else 1.0


func _release_settings_error(career: CareerData, release_mode: String, scheduled_week: int) -> String:
	if release_mode == VideoRules.MODE_WITH_SONG:
		return ""
	if release_mode != VideoRules.MODE_DATE:
		return "Forma de lançamento inválida."
	if scheduled_week <= career.current_week:
		return "Escolha uma semana depois da semana %s." % Fmt.number(career.current_week)
	return ""


func _score(technical: int, visual: int, creativity: int, identity: int, coherence: int) -> int:
	var rules := _rules()
	return clampi(roundi(
		technical * rules.technical_weight + visual * rules.visual_weight + creativity * rules.creativity_weight
		+ identity * rules.identity_weight + coherence * rules.coherence_weight
	), 0, 100)


func _chosen(choices: Dictionary, category_id: String) -> Array[VideoOptionDefinition]:
	var category := _rules().find_category(category_id)
	var options: Array[VideoOptionDefinition] = []
	for option_id: String in choices.get(category_id, []):
		var option := category.find_option(option_id)
		if option != null:
			options.append(option)
	if options.is_empty():
		options.append(category.options[0])
	return options


func _add_line(report: WeekReport, video: MusicVideo, song: SongData, title: String, note: String) -> void:
	if report == null:
		return
	var line := WeekReportEntry.new()
	line.title = title
	line.cover_file = video.cover_file if not video.cover_file.is_empty() else song.cover_file
	line.note = note
	report.entries.append(line)


func _rules() -> VideoRules:
	return _balance.videos
