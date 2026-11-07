extends Screen
## Perfil do artista em cada plataforma e o desempenho do catálogo nela.

var _platform: PlatformDefinition


func _ready() -> void:
	%PlatformsTable.set_headers(["Plataforma", "Público", "Reproduções", "Receita"])
	%PlatformsTable.item_selected.connect(_on_platform_selected)
	%CatalogTable.set_headers(["Conteúdo", "Tipo", "Reproduções", "Tendência"])
	%BackButton.pressed.connect(navigate.bind(Screen.HUB))
	_platform = GameManager.balance.streaming.platforms[0]
	super()


func refresh() -> void:
	var career := GameManager.career
	var selected := _platform.id
	%PlatformsTable.clear_rows()
	for platform in GameManager.balance.streaming.platforms:
		var stats := career.platform_stats_for(platform.id)
		%PlatformsTable.add_row([
			platform.display_name,
			Fmt.number(stats.followers),
			Fmt.number(stats.total_plays),
			Fmt.money(stats.revenue),
		], platform.id)
	%PlatformsTable.select_value(selected)
	_show_platform()


func _on_platform_selected() -> void:
	_platform = GameManager.balance.streaming.find_platform(%PlatformsTable.selected_value())
	_show_platform()


func _show_platform() -> void:
	var career := GameManager.career
	var stats := career.platform_stats_for(_platform.id)
	%PlatformTitle.text = _platform.display_name
	%Description.text = _platform.description
	%ArtistCover.show_cover(career.artist_cover)
	%ArtistLabel.text = "%s\n%s" % [career.artist_name, GameManager.streaming.artist_bio(career)]
	var parts := PackedStringArray()
	if not _platform.listeners_label.is_empty():
		parts.append("%s: %s" % [_platform.listeners_label, Fmt.number(stats.listeners)])
	if not _platform.followers_label.is_empty():
		parts.append("%s: %s" % [_platform.followers_label, Fmt.number(stats.followers)])
	parts.append("%s: %s" % [_platform.plays_label, Fmt.number(stats.total_plays)])
	if not _platform.extra_label.is_empty():
		parts.append("%s: %s" % [_platform.extra_label, Fmt.number(roundi(stats.total_plays * _platform.likes_per_play))])
	parts.append("Receita: %s" % Fmt.money(stats.revenue))
	%StatsLabel.text = "  |  ".join(parts)
	%CatalogHeader.text = "%s  (%s)" % [_platform.catalog_label, GameManager.streaming.catalog_text(career)]
	_fill_catalog()


func _fill_catalog() -> void:
	var career := GameManager.career
	%CatalogTable.clear_rows()
	if _platform.kind == PlatformDefinition.KIND_STORE:
		for release in career.releases:
			var content := career.find_content(release.content_id)
			%CatalogTable.add_row([
				content.title,
				GameManager.releases.content_type_label(content),
				Fmt.number(release.total_sales),
				"—",
			], content.id, content.cover_file)
		return
	for performance in GameManager.streaming.top_songs(career, _platform.id):
		var plays := GameManager.streaming.plays_on(performance, _platform.id)
		if _platform.kind == PlatformDefinition.KIND_RADIO and plays == 0:
			continue
		var song := career.find_song(performance.song_id)
		%CatalogTable.add_row([
			song.title,
			GameManager.streaming.release_label(career, performance),
			Fmt.number(plays),
			GameManager.streaming.trend_label(performance),
		], song.id, song.cover_file)
