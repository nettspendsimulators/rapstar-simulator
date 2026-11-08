class_name GameShell
extends VBoxContainer
## Moldura das telas da carreira: barra superior com o artista, a fase da carreira e os
## indicadores (semana, dinheiro, fama, fãs, energia), e o menu lateral com todas as áreas.
## A tela aberta fica no centro; trocar de área não passa mais pelo hub.

signal navigate_requested(screen_id: StringName, context: Dictionary)

## [rótulo, ícone, tela, contexto] por seção do menu lateral.
const NAV := [
	["ARTISTA", [
		["Início", "home", Screen.HUB, {}, "HomeButton"],
		["Perfil público", "profile", Screen.ARTIST_PROFILE, {}, "ProfileButton"],
		["Personagem", "character", Screen.CHARACTER, {}, "CharacterButton"],
		["Relações", "social", Screen.SOCIAL, {}, "SocialButton"],
	]],
	["MÚSICA", [
		["Músicas", "music", Screen.SONGS, {}, "SongsButton"],
		["Projetos", "album", Screen.ALBUMS, {}, "AlbumsButton"],
		["Lançamentos", "release", Screen.RELEASES, {}, "ReleasesButton"],
		["Videoclipes", "video", Screen.VIDEOS, {}, "VideosButton"],
	]],
	["DIVULGAÇÃO", [
		["Marketing", "marketing", Screen.MARKETING_HUB, {}, "MarketingButton"],
		["Plataformas", "platforms", Screen.PLATFORMS, {}, "PlatformsButton"],
		["Desempenho", "chart", Screen.PERFORMANCE, {}, "PerformanceButton"],
	]],
	["AO VIVO", [
		["Shows e ofertas", "mic", Screen.LIVE, {"tab": 0}, "LiveButton"],
		["Turnês", "tour", Screen.LIVE, {"tab": 2}, "ToursButton"],
		["Festivais", "festival", Screen.LIVE, {"tab": 3}, "FestivalsButton"],
		["Merchandising", "merch", Screen.LIVE, {"tab": 4}, "MerchButton"],
	]],
	["NEGÓCIOS", [
		["Trabalhar", "work", Screen.WORK, {}, "WorkButton"],
		["Carreira e finanças", "career", Screen.CAREER, {}, "CareerButton"],
	]],
]
## Telas internas acendem o item da área a que pertencem.
const PARENT := {
	Screen.WEEK_REPORT: Screen.HUB, Screen.SONG_DETAIL: Screen.SONGS, Screen.SONG_EDITOR: Screen.SONGS,
	Screen.PROJECT_EDITOR: Screen.ALBUMS, Screen.MARKETING: Screen.MARKETING_HUB, Screen.PLATFORM_PAGE: Screen.PLATFORMS,
	Screen.VIDEO_EDITOR: Screen.VIDEOS, Screen.SHOW_EDITOR: Screen.LIVE, Screen.SHOW_REPORT: Screen.LIVE,
	Screen.TOUR_EDITOR: Screen.LIVE, Screen.FESTIVAL: Screen.LIVE, Screen.ARTIST_RELATION: Screen.SOCIAL,
}
const LIVE_TAB_FOR := {Screen.TOUR_EDITOR: 2, Screen.FESTIVAL: 3}

## Área da tela aberta. A rolagem horizontal só aparece se uma tela não couber na janela.
var content := ScrollContainer.new()
var _avatar := CharacterView.new()
var _name := Label.new()
var _stage := Label.new()
var _week := Label.new()
var _chips: Dictionary[String, Label] = {}
var _energy_bar := ProgressBar.new()
var _nav: Dictionary[String, Button] = {}
var _toast := PanelContainer.new()
var _toast_label := Label.new()
var _menu_confirm := ConfirmationDialog.new()
var _last: Dictionary = {}
var _last_career: CareerData
var _toast_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_constant_override("separation", 0)
	_build_top_bar()
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	add_child(body)
	_build_sidebar(body)
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body.add_child(content)
	_build_toast()
	_menu_confirm.name = "MenuConfirm"
	_menu_confirm.title = "Menu principal"
	_menu_confirm.ok_button_text = "Sair para o menu"
	_menu_confirm.cancel_button_text = "Cancelar"
	_menu_confirm.dialog_text = "Voltar ao menu principal? O jogo é salvo a cada semana; o que você fez nesta semana sem salvar será perdido."
	_menu_confirm.confirmed.connect(func() -> void: navigate_requested.emit(Screen.MAIN_MENU, {}))
	add_child(_menu_confirm)
	GameManager.career_changed.connect(refresh)
	refresh()


## Coloca a tela no centro e acende o item do menu correspondente.
func set_screen(screen: Screen, screen_id: StringName, screen_context: Dictionary) -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	screen.add_theme_constant_override("margin_left", 28)
	screen.add_theme_constant_override("margin_right", 28)
	screen.add_theme_constant_override("margin_top", 20)
	screen.add_theme_constant_override("margin_bottom", 20)
	screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(screen)
	Main._enter(screen)
	var area: StringName = PARENT.get(screen_id, screen_id)
	var tab := int(screen_context.get("tab", LIVE_TAB_FOR.get(screen_id, 0)))
	if area == Screen.LIVE and tab == 1:
		tab = 0
	if area == Screen.LIVE and tab == 5:
		tab = 0
	for key in _nav:
		var button := _nav[key]
		var item: Array = button.get_meta("item")
		var matches: bool = item[2] == area
		if matches and area == Screen.LIVE:
			matches = int(item[3].get("tab", 0)) == tab
		button.set_pressed_no_signal(matches)


func refresh() -> void:
	var career := GameManager.career
	if career == null:
		return
	var progression := GameManager.progression
	_avatar.appearance = career.appearance
	_name.text = career.artist_name
	_stage.text = progression.stage_for(career.fame).display_name
	_week.text = "Semana %s" % Fmt.number(career.current_week)
	var values := {
		"money": career.money, "fame": career.fame, "fans": GameManager.streaming.total_followers(career),
	}
	for key: String in values:
		_count_to(key, values[key], _last_career == career)
	_chips["energy"].text = "∞" if career.infinite_energy else GameManager.energy_text()
	_energy_bar.max_value = GameManager.balance.max_energy
	_energy_bar.value = GameManager.balance.max_energy if career.infinite_energy else career.energy
	# Mudanças desde a última atualização aparecem como números flutuando sobre o indicador.
	if _last_career == career:
		for key: String in values:
			var change: int = values[key] - int(_last.get(key, values[key]))
			if change != 0:
				_float_delta(_chips[key], key, change)
	_last_career = career
	_last = values
	var offers := GameManager.live.shows_with_status(career, LiveShow.STATUS_OFFER).size()
	_nav["LiveButton"].text = "Shows e ofertas" + ("  (%d)" % offers if offers > 0 else "")
	var pending := GameManager.social.pending_invites(career).size()
	for beef in career.social.beefs:
		pending += 1 if beef.is_active() and beef.awaiting == Beef.TURN_PLAYER else 0
	_nav["SocialButton"].text = "Relações" + ("  (%d)" % pending if pending > 0 else "")


## Números da barra contam até o novo valor, para a mudança ser percebida.
func _count_to(key: String, target: int, animate: bool) -> void:
	var label := _chips[key]
	var start := int(_last.get(key, target)) if animate else target
	var show := func(value: float) -> void:
		label.text = Fmt.money(roundi(value)) if key == "money" else Fmt.number(roundi(value))
	if start == target:
		show.call(target)
		return
	var tween := label.create_tween()
	tween.tween_method(show, float(start), float(target), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func show_toast(text: String) -> void:
	if text.is_empty():
		return
	_toast_label.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(func() -> void: _toast.visible = false)


# ---- montagem

func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.name = "TopBar"
	bar.theme_type_variation = &"TopBar"
	add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bar.add_child(row)
	var logo := Label.new()
	logo.text = "RAPSTAR"
	logo.theme_type_variation = &"Logo"
	logo.custom_minimum_size = Vector2(178, 0)
	row.add_child(logo)
	_avatar.custom_minimum_size = Vector2(26, 52)
	row.add_child(_avatar)
	var identity := VBoxContainer.new()
	identity.add_theme_constant_override("separation", 2)
	identity.custom_minimum_size = Vector2(150, 0)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(identity)
	_name.name = "ArtistName"
	_name.theme_type_variation = &"ChipLabel"
	_name.clip_text = true
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	identity.add_child(_name)
	var stage_row := HBoxContainer.new()
	stage_row.add_theme_constant_override("separation", 8)
	identity.add_child(stage_row)
	_stage.name = "StageBadge"
	_stage.theme_type_variation = &"StageLabel"
	stage_row.add_child(_stage)
	_week.name = "WeekLabel"
	_week.theme_type_variation = &"MutedLabel"
	stage_row.add_child(_week)
	_chip(row, "money", "money", "Dinheiro")
	_chip(row, "fame", "fame", "Fama: a sua popularidade. Abre portas para shows, festivais e marcas")
	_chip(row, "fans", "fans", "Fãs: seguidores e inscritos em todas as plataformas")
	var energy := _chip(row, "energy", "energy", "Energia: usada para melhorar músicas. Volta toda semana")
	_energy_bar.theme_type_variation = &"EnergyBar"
	_energy_bar.show_percentage = false
	_energy_bar.custom_minimum_size = Vector2(54, 8)
	_energy_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	energy.get_child(0).add_child(_energy_bar)
	var save := _icon_button("SaveButton", "save", "Salvar o jogo")
	save.pressed.connect(func() -> void: show_toast(GameManager.save_game().message))
	row.add_child(save)
	var menu := _icon_button("MenuButton", "exit", "Menu principal")
	menu.pressed.connect(_menu_confirm.popup_centered)
	row.add_child(menu)
	var next := Button.new()
	next.name = "NextWeekButton"
	next.text = "PRÓXIMA SEMANA"
	next.icon = load("res://assets/icons/next.svg")
	next.theme_type_variation = &"PrimaryButton"
	next.tooltip_text = "Avança o calendário: lançamentos saem, shows acontecem, plataformas pagam e a energia volta."
	next.pressed.connect(_on_next_week)
	row.add_child(next)


func _chip(row: HBoxContainer, key: String, icon_name: String, tooltip: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.name = "Chip_" + key
	chip.theme_type_variation = &"StatChip"
	chip.tooltip_text = tooltip
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(chip)
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	chip.add_child(inner)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/icons/%s.svg" % icon_name)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(18, 18)
	icon.modulate = {"money": Color("#46d483"), "fame": Color("#f5b82e"), "fans": Color("#a25cff"), "energy": Color("#46d483")}[key]
	inner.add_child(icon)
	var label := Label.new()
	label.name = "Value"
	label.theme_type_variation = &"ChipLabel"
	inner.add_child(label)
	_chips[key] = label
	return chip


func _icon_button(node_name: String, icon_name: String, tooltip: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.icon = load("res://assets/icons/%s.svg" % icon_name)
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(42, 42)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return button


func _build_sidebar(body: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.name = "Sidebar"
	panel.theme_type_variation = &"Sidebar"
	panel.custom_minimum_size = Vector2(210, 0)
	body.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 1)
	scroll.add_child(column)
	for section: Array in NAV:
		var header := Label.new()
		header.text = section[0]
		header.theme_type_variation = &"SectionLabel"
		if column.get_child_count() > 0:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 4)
			column.add_child(gap)
		column.add_child(header)
		for item: Array in section[1]:
			var button := Button.new()
			button.name = item[4]
			button.text = item[0]
			button.icon = load("res://assets/icons/%s.svg" % item[1])
			button.theme_type_variation = &"NavButton"
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.toggle_mode = true
			button.focus_mode = Control.FOCUS_NONE
			button.set_meta("item", item)
			button.pressed.connect(func() -> void: navigate_requested.emit(item[2], item[3].duplicate()))
			column.add_child(button)
			_nav[item[4]] = button


func _build_toast() -> void:
	_toast.name = "Toast"
	_toast.theme_type_variation = &"HeroPanel"
	_toast.visible = false
	_toast.top_level = true
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label.name = "ToastLabel"
	_toast.add_child(_toast_label)
	add_child(_toast)
	_toast_label.resized.connect(_place_toast)


func _place_toast() -> void:
	var viewport := get_viewport_rect().size
	_toast.size = _toast.get_combined_minimum_size()
	_toast.position = Vector2(viewport.x - _toast.size.x - 16, 76)


func _float_delta(target: Label, key: String, change: int) -> void:
	var label := Label.new()
	label.theme_type_variation = &"DeltaLabel"
	label.text = (Fmt.signed_money(change) if key == "money" else Fmt.signed_number(change))
	label.add_theme_color_override("font_color", Color("#46d483") if change > 0 else Color("#ff5f6d"))
	label.top_level = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.global_position = target.global_position + Vector2(0, 26)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y + 18, 1.6)
	tween.tween_property(label, "modulate:a", 0.0, 1.6).set_delay(0.6)
	tween.chain().tween_callback(label.queue_free)


## Avança a semana e salva a carreira, para nunca perder semanas jogadas.
func _on_next_week() -> void:
	var report := GameManager.next_week()
	var saved := GameManager.save_game()
	navigate_requested.emit(Screen.WEEK_REPORT, {})
	show_toast("Semana %s  •  %s" % [Fmt.number(report.week), "jogo salvo automaticamente" if saved.ok else saved.message])
