class_name StreamingSystem
extends RefCounted
## Plataformas de música: leva lançamentos às plataformas, calcula o desempenho semanal de cada
## música e faz o público do artista crescer. É chamado pelo ReleaseSystem e pelo WeekSystem.

## Resultado semanal de um lançamento nas plataformas.
class WeekResult:
	var plays: int = 0
	var money: int = 0
	var sales: int = 0
	var sales_money: int = 0
	var fame: int = 0
	var note: String = ""


var _balance: GameBalance
var _economy: EconomySystem
var _performance: PerformanceSystem
var _time: TimeSystem
var _marketing: MarketingSystem
var _rng: RandomNumberGenerator


func _init(balance: GameBalance, economy: EconomySystem, performance: PerformanceSystem, time: TimeSystem, marketing: MarketingSystem, rng: RandomNumberGenerator) -> void:
	_balance = balance
	_economy = economy
	_performance = performance
	_time = time
	_marketing = marketing
	_rng = rng


## Coloca nas plataformas as músicas de um lançamento oficial que ainda não estão lá.
func start_release(career: CareerData, content: ReleasableContent) -> void:
	var campaign := career.find_campaign(content.id)
	var hype := 0
	if campaign != null and campaign.result != null:
		hype = campaign.result.expectation
		add_followers(career, campaign.result.new_fans)
	var launch := _launch_factor(career, content)
	for song in _songs_going_live(career, content):
		var performance := SongPerformance.new()
		performance.song_id = song.id
		performance.release_id = content.id
		performance.base_units = _performance.roll_base_units(_balance.song_performance)
		performance.launch_factor = launch * _sample_launch_factor(career, song)
		var definition := _balance.samples.find_sample(song.sample.sample_id)
		var attention := definition.attention / 100.0 if definition != null else 0.0
		var trajectory := roll_trajectory(career, song.quality, hype + content.leak_attention_score(), attention)
		performance.trajectory_id = trajectory.id
		performance.spotlight_platform = _pick_spotlight(trajectory, song)
		if trajectory.surge_boost > 0.0:
			performance.surge_week = _rng.randi_range(trajectory.surge_week_min, trajectory.surge_week_max)
		career.song_performances.append(performance)


## Calcula uma semana de todas as músicas de um lançamento.
func process_release(career: CareerData, release_entry: ReleaseData, content: ReleasableContent) -> WeekResult:
	var result := WeekResult.new()
	var age_weeks := maxi(_time.weeks_since(career, release_entry.release_week) - 1, 0)
	var track_share := 1.0
	var fame_multiplier := 1.0
	if content is AlbumData:
		var album_format := _balance.find_album_format(content.format_id)
		track_share = _rules().project_track_share * album_format.units_multiplier
		fame_multiplier = album_format.fame_multiplier
	var catalog_plays := total_plays(career)
	var marketing_factor := _marketing.units_multiplier(release_entry, age_weeks)
	var exposure := _marketing_exposure(career, content)
	for performance in career.song_performances:
		if performance.release_id == content.id:
			_process_song(career, performance, release_entry, age_weeks, track_share * marketing_factor, exposure, catalog_plays, result)
	# A fama ganha não considera a fama atual, para as duas não se multiplicarem sem limite.
	var rules := _balance.song_performance
	var plays_before_fame := result.plays / _performance.fame_factor(rules, career.fame)
	result.fame = floori(plays_before_fame / rules.units_per_fame * fame_multiplier)
	return result


## Registra reproduções calculadas por outro sistema, como as visualizações de videoclipes.
func record_platform_plays(career: CareerData, platform_id: String, plays: int, money: int) -> void:
	var stats := career.platform_stats_for(platform_id)
	stats.week_plays += plays
	stats.total_plays += plays
	stats.revenue += money


## Registra na Loja digital uma venda calculada por outro sistema.
func record_store_sales(career: CareerData, sales: int, money: int) -> void:
	var stats := career.platform_stats_for(_store().id)
	stats.week_plays += sales
	stats.total_plays += sales
	stats.revenue += money


## Etapa da semana: reproduções viram ouvintes, seguidores e popularidade.
func finish_week(career: CareerData, report: WeekReport) -> void:
	var followers_before := total_followers(career)
	var week_plays := 0
	var week_revenue := 0
	for platform in _rules().platforms:
		var stats := career.platform_stats_for(platform.id)
		week_plays += stats.week_plays if platform.kind != PlatformDefinition.KIND_STORE else 0
		stats.recent_plays.append(stats.week_plays)
		while stats.recent_plays.size() > _rules().listeners_window_weeks:
			stats.recent_plays.pop_front()
		var recent_total := 0
		for plays in stats.recent_plays:
			recent_total += plays
		stats.listeners = roundi(recent_total * platform.listeners_per_play)
		stats.peak_listeners = maxi(stats.peak_listeners, stats.listeners)
		stats.followers += roundi(stats.week_plays * platform.followers_per_play)
		stats.week_plays = 0
	var followers_after := total_followers(career)
	var per_fame := _rules().followers_per_fame
	var fame_gain := followers_after / per_fame - followers_before / per_fame
	if fame_gain > 0:
		_economy.add_fame(career, fame_gain)
		var line := WeekReportEntry.new()
		line.title = "Crescimento nas plataformas"
		line.note = "%s seguidores no total." % Fmt.number(followers_after)
		line.fame = fame_gain
		report.entries.append(line)
	for entry in report.entries:
		week_revenue += entry.money if entry.streams > 0 or entry.sales > 0 else 0
	if week_plays > 0 or followers_after > 0:
		var snapshot := PerformanceSnapshot.new()
		snapshot.week = career.current_week
		snapshot.plays = week_plays
		snapshot.listeners = total_listeners(career)
		snapshot.followers = followers_after
		snapshot.revenue = week_revenue
		career.performance_snapshots.append(snapshot)


## Novos seguidores vindos de fora das reproduções, como marketing e vazamentos.
func add_followers(career: CareerData, amount: int) -> void:
	if amount <= 0:
		return
	var streaming := _rules().platforms.filter(func(item: PlatformDefinition) -> bool: return item.kind == PlatformDefinition.KIND_STREAMING)
	var share_total := 0.0
	for platform: PlatformDefinition in streaming:
		share_total += platform.audience_share
	for platform: PlatformDefinition in streaming:
		career.platform_stats_for(platform.id).followers += roundi(amount * platform.audience_share / share_total)


## Fãs perdidos (por exemplo, numa diss mal recebida), proporcionalmente em cada plataforma.
func remove_followers(career: CareerData, amount: int) -> void:
	var total := total_followers(career)
	if amount <= 0 or total <= 0:
		return
	var share := minf(float(amount) / total, 1.0)
	for stats: ArtistPlatformStats in career.platform_stats.values():
		stats.followers = maxi(stats.followers - roundi(stats.followers * share), 0)


func total_plays(career: CareerData) -> int:
	var total := 0
	for performance in career.song_performances:
		total += performance.total_plays
	return total


func total_listeners(career: CareerData) -> int:
	var total := 0
	for stats: ArtistPlatformStats in career.platform_stats.values():
		total += stats.listeners
	return total


func total_followers(career: CareerData) -> int:
	var total := 0
	for stats: ArtistPlatformStats in career.platform_stats.values():
		total += stats.followers
	return total


func peak_listeners(career: CareerData) -> int:
	var peak := 0
	for snapshot in career.performance_snapshots:
		peak = maxi(peak, snapshot.listeners)
	return peak


func peak_week_plays(career: CareerData) -> int:
	var peak := 0
	for snapshot in career.performance_snapshots:
		peak = maxi(peak, snapshot.plays)
	return peak


## Músicas ordenadas pelas mais reproduzidas, nesta plataforma ou em todas.
func top_songs(career: CareerData, platform_id: String = "") -> Array[SongPerformance]:
	var sorted: Array[SongPerformance] = career.song_performances.duplicate()
	sorted.sort_custom(func(a: SongPerformance, b: SongPerformance) -> bool:
		return plays_on(a, platform_id) > plays_on(b, platform_id)
	)
	return sorted


func plays_on(performance: SongPerformance, platform_id: String) -> int:
	if platform_id.is_empty():
		return performance.total_plays
	return performance.platform_plays.get(platform_id, 0)


func best_release(career: CareerData) -> ReleaseData:
	var best: ReleaseData = null
	for release in career.releases:
		if best == null or release.total_money > best.total_money:
			best = release
	return best


## Crescendo, estável ou caindo, comparando as duas últimas semanas com as duas anteriores.
func trend_label(performance: SongPerformance) -> String:
	var weeks := performance.weekly_plays
	if weeks.size() < 2:
		return "Estreia"
	var window := mini(2, weeks.size() / 2)
	var recent := 0
	var previous := 0
	for index in window:
		recent += weeks[weeks.size() - 1 - index]
		previous += weeks[weeks.size() - 1 - window - index]
	if previous == 0:
		return "Crescendo" if recent > 0 else "Estável"
	var change := float(recent - previous) / previous
	if change > _rules().trend_threshold:
		return "Crescendo"
	if change < -_rules().trend_threshold:
		return "Caindo"
	return "Estável"


## Tipo do lançamento que levou a música às plataformas, como "Single" ou "EP".
func release_label(career: CareerData, performance: SongPerformance) -> String:
	var content := career.find_content(performance.release_id)
	if content is AlbumData:
		return _balance.find_album_format(content.format_id).display_name
	return "Single"


## Resumo do catálogo lançado, como "2 singles, 1 EP".
func catalog_text(career: CareerData) -> String:
	var singles := 0
	var by_format := {}
	for release in career.releases:
		if release.content_type == ReleaseData.TYPE_SONG:
			singles += 1
		else:
			var label: String = release_label_by_content(career, release.content_id)
			by_format[label] = by_format.get(label, 0) + 1
	var parts := PackedStringArray()
	if singles > 0:
		parts.append("%d single(s)" % singles)
	for label: String in by_format:
		parts.append("%d %s" % [by_format[label], label])
	return "nenhum lançamento" if parts.is_empty() else ", ".join(parts)


func release_label_by_content(career: CareerData, content_id: String) -> String:
	var content := career.find_content(content_id)
	return _balance.find_album_format(content.format_id).display_name


## A descrição própria do artista ou, sem ela, uma que acompanha a carreira.
func artist_bio(career: CareerData) -> String:
	if not career.artist_bio.is_empty():
		return career.artist_bio
	var stage := "em início de carreira"
	if career.fame >= 500:
		stage = "consagrado"
	elif career.fame >= 100:
		stage = "consolidado"
	elif career.fame >= 20:
		stage = "em ascensão"
	return "Artista %s, com %s." % [stage, catalog_text(career)]


func trajectory_label(performance: SongPerformance) -> String:
	var trajectory := _rules().find_trajectory(performance.trajectory_id)
	return trajectory.label if trajectory != null else "—"


## Rádio exige fama ou uma ação de Rádio na campanha.
func has_platform_access(career: CareerData, platform: PlatformDefinition, song_id: String, release_id: String) -> bool:
	if platform.unlock_action.is_empty():
		return true
	if career.fame >= platform.required_fame:
		return true
	for content_id in [song_id, release_id]:
		var campaign := career.find_campaign(content_id)
		if campaign != null:
			var action := campaign.find_action(platform.unlock_action)
			if action != null and action.is_paid():
				return true
	return false


func _process_song(career: CareerData, performance: SongPerformance, release_entry: ReleaseData, age_weeks: int, multiplier: float, exposure: int, catalog_plays: int, result: WeekResult) -> void:
	var song := career.find_song(performance.song_id)
	var rules := _rules()
	var trajectory := rules.find_trajectory(performance.trajectory_id)
	var curve := trajectory.multiplier(age_weeks, performance.surge_week)
	var audience := 1.0 + _magnitude(total_followers(career)) * rules.audience_bonus_per_magnitude
	var launch := 1.0 + (performance.launch_factor - 1.0) * pow(rules.launch_effect_decay, age_weeks)
	var score := _discovery_score(career, performance, exposure, catalog_plays)
	var discovery := 1.0 + score * rules.discovery_max_bonus
	if performance.recommendation_weeks_left > 0:
		performance.recommendation_weeks_left -= 1
		discovery *= rules.recommendation_boost
	elif _rng.randf() < rules.recommendation_base_chance + score * rules.recommendation_score_chance:
		performance.recommendation_weeks_left = rules.recommendation_weeks
		performance.recommendations += 1
		result.note = "As plataformas começaram a recomendar \"%s\"." % song.title

	var units := _performance.stream_units(
		_balance.song_performance, performance.base_units, song.quality, career.fame,
		curve * audience * launch * discovery * multiplier * performance.video_boost, rules.weekly_noise
	)
	var week_plays := 0
	var money := 0.0
	var shares := _platform_shares(song, performance)
	for platform_id in shares:
		var platform := rules.find_platform(platform_id)
		var plays := roundi(units * shares[platform_id])
		week_plays += plays
		money += plays * platform.money_per_play
		_add_plays(career, performance, platform, plays)
	var radio := _radio_platform()
	if radio != null and has_platform_access(career, radio, song.id, performance.release_id):
		var radio_plays := roundi(units * radio.audience_share)
		week_plays += radio_plays
		money += radio_plays * radio.money_per_play
		_add_plays(career, performance, radio, radio_plays)

	var earned := roundi(money)
	performance.total_plays += week_plays
	performance.revenue += earned
	performance.weekly_plays.append(week_plays)
	performance.peak_week_plays = maxi(performance.peak_week_plays, week_plays)
	result.plays += week_plays
	result.money += earned
	if release_entry.content_type == ReleaseData.TYPE_SONG:
		_sell_single(career, week_plays, result)


func _sell_single(career: CareerData, plays: int, result: WeekResult) -> void:
	var sales := roundi(plays * _rules().single_sale_rate)
	if sales <= 0:
		return
	var money := roundi(sales * _rules().single_sale_price)
	result.sales += sales
	result.sales_money += money
	record_store_sales(career, sales, money)


func _add_plays(career: CareerData, performance: SongPerformance, platform: PlatformDefinition, plays: int) -> void:
	performance.platform_plays[platform.id] = performance.platform_plays.get(platform.id, 0) + plays
	var stats := career.platform_stats_for(platform.id)
	stats.week_plays += plays
	stats.total_plays += plays
	stats.revenue += roundi(plays * platform.money_per_play)


## Parte de cada plataforma de streaming nas reproduções da música. A soma dá 1.
func _platform_shares(song: SongData, performance: SongPerformance) -> Dictionary:
	var rules := _rules()
	var trajectory := rules.find_trajectory(performance.trajectory_id)
	var weights := {}
	var total := 0.0
	for platform in rules.platforms:
		if platform.kind != PlatformDefinition.KIND_STREAMING:
			continue
		var weight := platform.audience_share * _affinity(platform, song)
		if platform.id == performance.spotlight_platform:
			weight *= trajectory.spotlight_boost
		weights[platform.id] = weight
		total += weight
	for platform_id: String in weights:
		weights[platform_id] /= total
	return weights


## Uma música acima da própria média no atributo favorito rende mais nessa plataforma.
func _affinity(platform: PlatformDefinition, song: SongData) -> float:
	if platform.affinity_attribute.is_empty():
		return 1.0
	var difference := (song.attribute_value(platform.affinity_attribute) - song.quality) / 100.0
	return maxf(1.0 + difference * platform.affinity_strength * 2.0, 0.2)


## De 0 a 1: o quanto marketing, popularidade, crescimento, catálogo e ouvintes ajudam o público
## a encontrar a música nesta semana.
func _discovery_score(career: CareerData, performance: SongPerformance, exposure: int, catalog_plays: int) -> float:
	var rules := _rules()
	var growth := 0.0
	var weeks := performance.weekly_plays
	if weeks.size() >= 2 and weeks[-2] > 0:
		growth = clampf(float(weeks[-1] - weeks[-2]) / weeks[-2], 0.0, 1.0)
	var other_plays := catalog_plays - performance.total_plays
	return clampf(
		exposure / 100.0 * rules.discovery_marketing_weight
		+ minf(float(career.fame) / rules.discovery_fame_reference, 1.0) * rules.discovery_fame_weight
		+ growth * rules.discovery_growth_weight
		+ minf(float(other_plays) / rules.discovery_catalog_reference, 1.0) * rules.discovery_catalog_weight
		+ minf(float(total_listeners(career)) / rules.discovery_listeners_reference, 1.0) * rules.discovery_listeners_weight,
		0.0, 1.0
	)


## O público responde melhor depois de um tempo sem novidades, e pior a lançamentos colados.
func _launch_factor(career: CareerData, content: ReleasableContent) -> float:
	var rules := _rules()
	var factor := rules.launch_gap_factor
	for release in career.releases:
		if release.content_id == content.id:
			continue
		var gap := career.current_week - release.release_week
		if gap <= 1:
			factor = rules.launch_crowded_factor
			break
		if gap < rules.launch_gap_weeks:
			factor = 1.0
	if content.is_leaked():
		factor *= rules.leak_launch_factor
	return factor


func _sample_launch_factor(career: CareerData, song: SongData) -> float:
	var definition := _balance.samples.find_sample(song.sample.sample_id)
	if definition == null:
		return 1.0
	var interest := float(definition.interest_impact)
	if definition.is_own():
		var sampled := career.find_performance(song.sample.song_id)
		if sampled != null:
			interest += _magnitude(sampled.total_plays)
	return 1.0 + interest / 100.0 * _rules().sample_interest_weight


## Sorteia a trajetória de uma música ou de um videoclipe. attention_level vai de 0 a 1.
func roll_trajectory(career: CareerData, quality: int, hype: int, attention_level: float) -> TrajectoryDefinition:
	var rules := _rules()
	var fame_level := minf(float(career.fame) / rules.trajectory_fame_reference, 1.0)
	var quality_level := (quality - 50.0) / 50.0
	var hype_level := minf(hype / 100.0, 1.0)
	var weights: Array[float] = []
	var total := 0.0
	for trajectory in rules.trajectories:
		var factor := 1.0 \
			+ trajectory.quality_weight * quality_level \
			+ trajectory.hype_weight * hype_level \
			+ trajectory.fame_weight * fame_level \
			+ trajectory.attention_weight * attention_level
		var weight := trajectory.base_weight * maxf(factor, rules.trajectory_min_factor)
		weights.append(weight)
		total += weight
	var roll := _rng.randf() * total
	for index in weights.size():
		roll -= weights[index]
		if roll <= 0.0 and weights[index] > 0.0:
			return rules.trajectories[index]
	return rules.find_trajectory("steady")


func _pick_spotlight(trajectory: TrajectoryDefinition, song: SongData) -> String:
	if trajectory.spotlight_platform != TrajectoryDefinition.SPOTLIGHT_AUTO:
		return trajectory.spotlight_platform
	var streaming := _rules().platforms.filter(func(item: PlatformDefinition) -> bool: return item.kind == PlatformDefinition.KIND_STREAMING)
	var total := 0.0
	for platform: PlatformDefinition in streaming:
		total += platform.audience_share * _affinity(platform, song)
	var roll := _rng.randf() * total
	for platform: PlatformDefinition in streaming:
		roll -= platform.audience_share * _affinity(platform, song)
		if roll <= 0.0:
			return platform.id
	return streaming.back().id


func _songs_going_live(career: CareerData, content: ReleasableContent) -> Array[SongData]:
	var songs: Array[SongData] = []
	if content is SongData:
		songs.append(content)
		return songs
	for song_id: String in content.song_ids:
		if career.find_performance(song_id) == null:
			songs.append(career.find_song(song_id))
	return songs


func _marketing_exposure(career: CareerData, content: ReleasableContent) -> int:
	var campaign := career.find_campaign(content.id)
	return campaign.result.exposure if campaign != null and campaign.result != null else 0


func _magnitude(value: float) -> float:
	return log(value + 1.0) / log(10.0)


func _store() -> PlatformDefinition:
	for platform in _rules().platforms:
		if platform.kind == PlatformDefinition.KIND_STORE:
			return platform
	return null


func _radio_platform() -> PlatformDefinition:
	for platform in _rules().platforms:
		if platform.kind == PlatformDefinition.KIND_RADIO:
			return platform
	return null


func _rules() -> StreamingRules:
	return _balance.streaming
