extends Screen
## Desempenho musical: totais, evolução, músicas, plataformas e histórico.


func _ready() -> void:
	%SongsTable.set_headers(["Música", "Reproduções", "Última semana", "Melhor semana", "Tendência", "Trajetória", "Receita"])
	%SongsTable.set_column_expand_ratio(5, 3)
	%PlatformsTable.set_headers(["Plataforma", "Reproduções", "Ouvintes", "Seguidores", "Receita"])
	%HistoryTable.set_headers(["Semana", "Reproduções", "Ouvintes", "Seguidores", "Receita"])
	%HistoryTable.set_column_expand_ratio(0, 1)
	%BackButton.pressed.connect(navigate.bind(Screen.HUB))
	super()


func refresh() -> void:
	_fill_summary()
	_fill_songs()
	_fill_platforms()
	_fill_history()


func _fill_summary() -> void:
	var career := GameManager.career
	var streaming := GameManager.streaming
	var youtube := career.platform_stats_for("youtube")
	var revenue := 0
	for stats: ArtistPlatformStats in career.platform_stats.values():
		revenue += stats.revenue
	%TotalsLabel.text = "Reproduções totais: %s  |  Ouvintes: %s  |  Seguidores: %s  |  Inscritos: %s  |  Receita: %s" % [
		Fmt.number(streaming.total_plays(career)),
		Fmt.number(streaming.total_listeners(career)),
		Fmt.number(streaming.total_followers(career) - youtube.followers),
		Fmt.number(youtube.followers),
		Fmt.money(revenue),
	]
	var top := streaming.top_songs(career)
	var best := streaming.best_release(career)
	%RecordsLabel.text = "Recordes: maior público %s ouvintes  |  melhor semana %s reproduções  |  música mais popular: %s  |  melhor lançamento: %s" % [
		Fmt.number(streaming.peak_listeners(career)),
		Fmt.number(streaming.peak_week_plays(career)),
		career.find_song(top[0].song_id).title if not top.is_empty() else "—",
		career.find_content(best.content_id).title if best != null else "—",
	]
	%RecentLabel.text = "Lançamentos recentes: %s" % _recent_releases()
	var plays: Array[int] = []
	var followers: Array[int] = []
	for snapshot in career.performance_snapshots:
		plays.append(snapshot.plays)
		followers.append(snapshot.followers)
	%PlaysChart.show_values("Reproduções por semana", plays)
	%FollowersChart.show_values("Seguidores", followers)


func _recent_releases() -> String:
	var career := GameManager.career
	var names := PackedStringArray()
	for index in range(career.releases.size() - 1, maxi(career.releases.size() - 4, 0) - 1, -1):
		var release := career.releases[index]
		names.append("%s (semana %s)" % [career.find_content(release.content_id).title, Fmt.number(release.release_week)])
	return "—" if names.is_empty() else ", ".join(names)


func _fill_songs() -> void:
	var career := GameManager.career
	var streaming := GameManager.streaming
	%SongsTable.clear_rows()
	for performance in streaming.top_songs(career):
		var song := career.find_song(performance.song_id)
		%SongsTable.add_row([
			song.title,
			Fmt.number(performance.total_plays),
			Fmt.number(performance.weekly_plays.back()) if not performance.weekly_plays.is_empty() else "—",
			Fmt.number(performance.peak_week_plays),
			streaming.trend_label(performance),
			streaming.trajectory_label(performance),
			Fmt.money(performance.revenue),
		], song.id, song.cover_file)


func _fill_platforms() -> void:
	var career := GameManager.career
	%PlatformsTable.clear_rows()
	for platform in GameManager.balance.streaming.platforms:
		var stats := career.platform_stats_for(platform.id)
		%PlatformsTable.add_row([
			platform.display_name,
			Fmt.number(stats.total_plays),
			Fmt.number(stats.listeners) if not platform.listeners_label.is_empty() else "—",
			Fmt.number(stats.followers) if not platform.followers_label.is_empty() else "—",
			Fmt.money(stats.revenue),
		])


func _fill_history() -> void:
	var snapshots := GameManager.career.performance_snapshots
	%HistoryTable.clear_rows()
	for index in range(snapshots.size() - 1, -1, -1):
		var snapshot := snapshots[index]
		%HistoryTable.add_row([
			Fmt.number(snapshot.week),
			Fmt.number(snapshot.plays),
			Fmt.number(snapshot.listeners),
			Fmt.number(snapshot.followers),
			Fmt.money(snapshot.revenue),
		])
