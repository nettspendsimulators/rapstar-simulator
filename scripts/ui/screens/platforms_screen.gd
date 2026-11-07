extends Screen
## Vitrine das plataformas. Cada bloco abre a tela própria daquela plataforma.

const TILE_COLORS := {
	"spotify": [Color("#1db954"), Color.BLACK],
	"apple_music": [Color("#fa2d48"), Color.WHITE],
	"deezer": [Color("#a238ff"), Color.WHITE],
	"soundcloud": [Color("#ff5500"), Color.WHITE],
	"youtube": [Color("#ff0000"), Color.WHITE],
	"digital_store": [Color("#f2c14e"), Color.BLACK],
	"radio": [Color("#ffb000"), Color.BLACK],
}


func _ready() -> void:
	%BackButton.pressed.connect(navigate.bind(Screen.HUB))
	super()


func refresh() -> void:
	var career := GameManager.career
	var streaming := GameManager.streaming
	%SummaryLabel.text = "Ouvintes: %s  |  Seguidores: %s  |  Reproduções: %s  |  %s" % [
		Fmt.number(streaming.total_listeners(career)),
		Fmt.number(streaming.total_followers(career)),
		Fmt.number(streaming.total_plays(career)),
		streaming.catalog_text(career),
	]
	for child in %Tiles.get_children():
		%Tiles.remove_child(child)
		child.queue_free()
	for platform in GameManager.balance.streaming.platforms:
		%Tiles.add_child(_tile(platform, career.platform_stats_for(platform.id)))


func _tile(platform: PlatformDefinition, stats: ArtistPlatformStats) -> Button:
	var colors: Array = TILE_COLORS.get(platform.id, [Color("#2b2f3a"), Color.WHITE])
	var button := Button.new()
	button.name = "Tile_%s" % platform.id
	button.custom_minimum_size = Vector2(0, 150)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = "%s\n%s\n%s: %s" % [platform.display_name, _main_metric(platform, stats), platform.plays_label, Fmt.number(stats.total_plays)]
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = colors[0].lightened(0.12) if state == "hover" else colors[0]
		box.set_corner_radius_all(14)
		box.set_content_margin_all(20)
		button.add_theme_stylebox_override(state, box)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, colors[1])
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(navigate.bind(Screen.PLATFORM_PAGE, {"platform_id": platform.id}))
	return button


func _main_metric(platform: PlatformDefinition, stats: ArtistPlatformStats) -> String:
	if not platform.listeners_label.is_empty():
		return "%s: %s" % [platform.listeners_label, Fmt.number(stats.listeners)]
	if not platform.followers_label.is_empty():
		return "%s: %s" % [platform.followers_label, Fmt.number(stats.followers)]
	return "Receita: %s" % Fmt.money(stats.revenue)
