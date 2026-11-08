class_name PlatformPage
extends Screen
## Tela de uma plataforma. Cada plataforma tem sua própria visualização (scripts/ui/platforms),
## que monta a interface com os blocos daqui e os dados reais da carreira.
## context precisa ter platform_id.

const VIEWS := {
	"spotify": preload("res://scripts/ui/platforms/spotify_view.gd"),
	"apple_music": preload("res://scripts/ui/platforms/apple_music_view.gd"),
	"deezer": preload("res://scripts/ui/platforms/deezer_view.gd"),
	"soundcloud": preload("res://scripts/ui/platforms/soundcloud_view.gd"),
	"youtube": preload("res://scripts/ui/platforms/youtube_view.gd"),
	"digital_store": preload("res://scripts/ui/platforms/store_view.gd"),
	"radio": preload("res://scripts/ui/platforms/radio_view.gd"),
}

## Barras de forma de onda, desenhadas a partir do id da música para cada faixa ter a sua.
class Waveform:
	extends Control
	var seed_text: String = ""
	var progress: float = 0.0
	var played_color := Color("#ff5500")
	var idle_color := Color("#cccccc")

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(seed_text)
		var bars := int(size.x / 4.0)
		for index in bars:
			var height := size.y * rng.randf_range(0.2, 1.0)
			var color := played_color if float(index) / bars < progress else idle_color
			draw_rect(Rect2(index * 4.0, (size.y - height) / 2.0, 2.0, height), color)


var platform: PlatformDefinition
var _background := ColorRect.new()
var _content := Control.new()


func _ready() -> void:
	platform = GameManager.balance.streaming.find_platform(context.get("platform_id", "spotify"))
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_background)
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_content)
	super()


func refresh() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	VIEWS[platform.id].new().build(self)


# ---- dados

func career() -> CareerData:
	return GameManager.career


func stats() -> ArtistPlatformStats:
	return career().platform_stats_for(platform.id)


## Músicas presentes nesta plataforma, das mais tocadas para as menos tocadas.
func songs_here() -> Array[SongPerformance]:
	var result: Array[SongPerformance] = []
	for performance in GameManager.streaming.top_songs(career(), platform.id):
		if platform.kind != PlatformDefinition.KIND_RADIO or plays(performance) > 0:
			result.append(performance)
	return result


func plays(performance: SongPerformance) -> int:
	return GameManager.streaming.plays_on(performance, platform.id)


func song_of(performance: SongPerformance) -> SongData:
	return career().find_song(performance.song_id)


## Lançamentos oficiais, do mais recente para o mais antigo.
func releases_newest_first() -> Array[ReleaseData]:
	var result: Array[ReleaseData] = career().releases.duplicate()
	result.reverse()
	return result


func content_of(release: ReleaseData) -> ReleasableContent:
	return career().find_content(release.content_id)


func type_of(content: ReleasableContent) -> String:
	return GameManager.releases.content_type_label(content)


func released_videos() -> Array[MusicVideo]:
	var result: Array[MusicVideo] = []
	for video in career().music_videos:
		if video.is_released():
			result.append(video)
	result.sort_custom(func(a: MusicVideo, b: MusicVideo) -> bool: return a.total_views > b.total_views)
	return result


func weeks_ago(week: int) -> String:
	var weeks := career().current_week - week
	if weeks <= 0:
		return "nesta semana"
	return "há %d semana%s" % [weeks, "" if weeks == 1 else "s"]


# ---- blocos visuais

func set_background(color: Color) -> void:
	_background.color = color


func content_root() -> Control:
	return _content


## Coluna rolável que ocupa a tela, com margens.
func scroll_column(margin: int = 32, separation: int = 16) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	var margins := MarginContainer.new()
	margins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, margin)
	scroll.add_child(margins)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", separation)
	margins.add_child(column)
	return column


func label(text: String, font_size: int, color: Color, bold: bool = false, node_name: String = "") -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	if bold:
		result.add_theme_font_override("font", bold_font())
	if not node_name.is_empty():
		result.name = node_name
	if font_size >= 28:
		# Nomes grandes de artista ou música não podem alargar a página.
		result.clip_text = true
		result.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return result


func bold_font() -> Font:
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = 0.9
	return font


func panel(color: Color, radius: int = 8, padding: int = 16) -> PanelContainer:
	var result := PanelContainer.new()
	result.add_theme_stylebox_override("panel", style(color, radius, padding))
	return result


func style(color: Color, radius: int = 8, padding: int = 12) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(padding)
	return box


func pill(text: String, background: Color, foreground: Color, font_size: int = 16) -> PanelContainer:
	var result := panel(background, 999, 8)
	result.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	result.add_child(label(text, font_size, foreground, true))
	return result


func cover(file_name: String, side: float, seed_text: String = "") -> CoverPreview:
	var result := CoverPreview.new()
	result.custom_minimum_size = Vector2(side, side)
	result.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	result.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	result.ready.connect(func() -> void: result.show_cover(file_name, seed_text))
	return result


## Foto do artista; sem foto escolhida, o próprio personagem sobre um fundo de estúdio.
func artist_avatar(career: CareerData, side: float) -> Control:
	if not career.artist_cover.is_empty():
		return cover(career.artist_cover, side)
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(side, side)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.clip_contents = true
	var backdrop := TextureRect.new()
	backdrop.texture = CoverArt.generated(career.artist_name + " perfil")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.modulate = Color(0.55, 0.55, 0.6)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(backdrop)
	var person := CharacterView.new()
	person.appearance = career.appearance
	person.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	person.offset_top = side * 0.05
	person.offset_bottom = side * 0.9
	frame.add_child(person)
	return frame


func hbox(separation: int = 12) -> HBoxContainer:
	var result := HBoxContainer.new()
	result.add_theme_constant_override("separation", separation)
	return result


func vbox(separation: int = 4) -> VBoxContainer:
	var result := VBoxContainer.new()
	result.add_theme_constant_override("separation", separation)
	return result


func spacer() -> Control:
	var result := Control.new()
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return result


## Botão de volta para a lista de plataformas, no estilo de cada uma.
func back_button(background: Color, foreground: Color) -> Button:
	var button := Button.new()
	button.name = "BackButton"
	button.text = "‹  Plataformas"
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, style(background.lightened(0.1) if state == "hover" else background, 999, 10))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, foreground)
	button.pressed.connect(navigate.bind(Screen.PLATFORMS))
	return button


func empty_message(text: String, color: Color) -> Label:
	var result := label(text, 18, color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.custom_minimum_size = Vector2(600, 0)
	return result
