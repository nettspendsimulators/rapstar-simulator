class_name GameShell
extends HBoxContainer
## Moldura das telas da carreira.
## - Trilho à esquerda com as 6 áreas do jogo (Início, Música, Carreira, Palco, Social, Estilo),
##   o mini retrato do artista, salvar e menu.
## - Barra superior com o nome da área, as subabas dela, os indicadores (dinheiro, fama, fãs,
##   energia) e "Próxima semana".
## - A tela aberta fica abaixo. Cada área agrupa só o que é dela, então o jogador sempre sabe
##   onde está e onde procurar.

signal navigate_requested(screen_id: StringName, context: Dictionary)

## Áreas do jogo: id, rótulo, ícone, frase de apoio e itens [rótulo, ícone, tela, contexto, nome].
const SECTIONS := [
	{"id": "home", "accent": Color("#f5b82e"), "label": "Início", "icon": "home", "hint": "Sua carreira em um olhar", "items": [
		["Início", "home", Screen.HUB, {}, "HomeButton"],
	]},
	{"id": "music", "accent": Color("#b07cff"), "label": "Música", "icon": "music", "hint": "Criar, gravar e lançar", "items": [
		["Músicas", "music", Screen.SONGS, {}, "SongsButton"],
		["Projetos", "album", Screen.ALBUMS, {}, "AlbumsButton"],
		["Lançamentos", "release", Screen.RELEASES, {}, "ReleasesButton"],
		["Videoclipes", "video", Screen.VIDEOS, {}, "VideosButton"],
		["Marketing", "marketing", Screen.MARKETING_HUB, {}, "MarketingButton"],
	]},
	{"id": "career", "accent": Color("#3ec7e0"), "label": "Carreira", "icon": "chart", "hint": "Números, público e dinheiro", "items": [
		["Desempenho", "chart", Screen.PERFORMANCE, {}, "PerformanceButton"],
		["Plataformas", "platforms", Screen.PLATFORMS, {}, "PlatformsButton"],
		["Perfil público", "profile", Screen.ARTIST_PROFILE, {}, "ProfileButton"],
		["Gravadora", "label", Screen.LABEL, {}, "LabelButton"],
		["Finanças", "career", Screen.CAREER, {}, "CareerButton"],
		["Trabalhar", "work", Screen.WORK, {}, "WorkButton"],
	]},
	{"id": "stage", "accent": Color("#ff5ea8"), "label": "Palco", "icon": "mic", "hint": "Shows, turnês, festivais e merch", "items": [
		["Shows", "mic", Screen.LIVE, {"tab": 0}, "LiveButton"],
		["Ofertas", "mic", Screen.LIVE, {"tab": 1}, "OffersButton"],
		["Turnês", "tour", Screen.LIVE, {"tab": 2}, "ToursButton"],
		["Festivais", "festival", Screen.LIVE, {"tab": 3}, "FestivalsButton"],
		["Merch", "merch", Screen.LIVE, {"tab": 4}, "MerchButton"],
		["Histórico", "calendar", Screen.LIVE, {"tab": 5}, "LiveHistoryButton"],
	]},
	{"id": "social", "accent": Color("#ff8a5c"), "label": "Social", "icon": "social", "hint": "Amizades, rivalidades e beefs", "items": [
		["Relações", "social", Screen.SOCIAL, {}, "SocialButton"],
	]},
	{"id": "style", "accent": Color("#5b9dff"), "label": "Estilo", "icon": "character", "hint": "Visual e garagem", "items": [
		["Personagem", "character", Screen.CHARACTER, {}, "CharacterButton"],
		["Carros", "car", Screen.GARAGE, {}, "GarageButton"],
	]},
]
## Telas internas pertencem à área do item que as abre.
const PARENT := {
	Screen.WEEK_REPORT: Screen.HUB, Screen.SONG_DETAIL: Screen.SONGS, Screen.SONG_EDITOR: Screen.SONGS,
	Screen.PROJECT_EDITOR: Screen.ALBUMS, Screen.MARKETING: Screen.MARKETING_HUB, Screen.PLATFORM_PAGE: Screen.PLATFORMS,
	Screen.VIDEO_EDITOR: Screen.VIDEOS, Screen.SHOW_EDITOR: Screen.LIVE, Screen.SHOW_REPORT: Screen.LIVE,
	Screen.TOUR_EDITOR: Screen.LIVE, Screen.FESTIVAL: Screen.LIVE, Screen.ARTIST_RELATION: Screen.SOCIAL,
}
const LIVE_TAB_FOR := {Screen.TOUR_EDITOR: 2, Screen.FESTIVAL: 3}
const CHIP_COLORS := {"money": Color("#46d483"), "fame": Color("#f5b82e"), "fans": Color("#b07cff"), "energy": Color("#46d483")}

## Área da tela aberta. A rolagem horizontal só aparece se uma tela não couber na janela.
var content := ScrollContainer.new()
var _section_icon := TextureRect.new()
var _section_title := Label.new()
var _section_hint := Label.new()
var _tabs := HBoxContainer.new()
var _rail: Dictionary[String, Button] = {}
var _badges: Dictionary[String, Label] = {}
var _nav: Dictionary[String, Button] = {}
var _avatar := CharacterView.new()
var _chips: Dictionary[String, Label] = {}
var _energy_bar := ProgressBar.new()
var _toast := PanelContainer.new()
var _toast_label := Label.new()
var _menu_confirm := ConfirmationDialog.new()
var _current_section := ""
var _top_line: StyleBoxFlat
var _last: Dictionary = {}
var _last_career: CareerData
var _toast_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_constant_override("separation", 0)
	_build_rail()
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 0)
	add_child(column)
	_build_top_bar(column)
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	column.add_child(content)
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


## Coloca a tela no centro, acende a área no trilho e mostra as subabas dela.
func set_screen(screen: Screen, screen_id: StringName, screen_context: Dictionary) -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	screen.add_theme_constant_override("margin_left", 32)
	screen.add_theme_constant_override("margin_right", 32)
	screen.add_theme_constant_override("margin_top", 22)
	screen.add_theme_constant_override("margin_bottom", 22)
	screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(screen)
	Main._enter(screen)
	var area: StringName = PARENT.get(screen_id, screen_id)
	var tab := int(screen_context.get("tab", LIVE_TAB_FOR.get(screen_id, 0)))
	_highlight(area, tab)
	# Telas com abas próprias (Ao vivo) mantêm a subaba do topo em dia quando trocam de aba.
	var inner_tabs := screen.find_child("LiveTabs", true, false) as TabContainer
	if inner_tabs != null:
		inner_tabs.tab_changed.connect(func(index: int) -> void: _highlight(area, index))


func _highlight(area: StringName, tab: int) -> void:
	var section := ""
	for key in _nav:
		var button := _nav[key]
		var item: Array = button.get_meta("item")
		var matches: bool = item[2] == area
		if matches and area == Screen.LIVE:
			matches = int(item[3].get("tab", 0)) == tab
		button.set_pressed_no_signal(matches)
		if matches:
			section = button.get_meta("section")
	if not section.is_empty():
		_show_section(section)


## Botões que levam até um item do menu, na ordem de clique (área e, se preciso, a subaba).
## Usado por quem automatiza a navegação, como os testes de interface.
func nav_path(button_name: String) -> Array[Control]:
	var path: Array[Control] = []
	var button: Button = _nav.get(button_name)
	if button == null:
		return path
	var section: String = button.get_meta("section")
	var first: bool = button.get_meta("first")
	if section != _current_section or first:
		path.append(_rail[section])
	if not first:
		path.append(button)
	return path


func refresh() -> void:
	var career := GameManager.career
	if career == null:
		return
	_avatar.appearance = career.appearance
	_avatar.tooltip_text = "%s  •  %s  •  Semana %s" % [career.artist_name, GameManager.progression.stage_for(career.fame).display_name, Fmt.number(career.current_week)]
	var values := {"money": career.money, "fame": career.fame, "fans": GameManager.streaming.total_followers(career)}
	for key: String in values:
		_count_to(key, values[key], _last_career == career)
	_chips["energy"].text = "∞" if career.infinite_energy else GameManager.energy_text()
	_energy_bar.max_value = GameManager.balance.max_energy
	_energy_bar.value = GameManager.balance.max_energy if career.infinite_energy else career.energy
	# Mudanças desde a última atualização aparecem como números flutuando sob o indicador.
	if _last_career == career:
		for key: String in values:
			var change: int = values[key] - int(_last.get(key, values[key]))
			if change != 0:
				_float_delta(_chips[key], key, change)
	_last_career = career
	_last = values
	var offers := GameManager.live.shows_with_status(career, LiveShow.STATUS_OFFER).size()
	_nav["OffersButton"].text = "Ofertas" + ("  %d" % offers if offers > 0 else "")
	var pending := GameManager.social.pending_invites(career).size()
	for beef in career.social.beefs:
		pending += 1 if beef.is_active() and beef.awaiting == Beef.TURN_PLAYER else 0
	_set_badge("stage", offers)
	_set_badge("social", pending)


func _set_badge(section: String, count: int) -> void:
	_badges[section].text = str(count)
	_badges[section].visible = count > 0


func _show_section(section_id: String) -> void:
	_current_section = section_id
	for id in _rail:
		_rail[id].set_pressed_no_signal(id == section_id)
	for section: Dictionary in SECTIONS:
		if section["id"] == section_id:
			_section_title.text = section["label"]
			_section_hint.text = section["hint"]
			_apply_accent(section)
	var multiple := false
	for key in _nav:
		var button := _nav[key]
		var mine: bool = button.get_meta("section") == section_id
		button.visible = mine
		if mine and not button.get_meta("first"):
			multiple = true
	# Uma área com um item só não precisa de abas: o nome dela já diz onde você está.
	_tabs.visible = multiple


## Cada área tem uma cor: ícone ao lado do nome, linha da barra superior e luz do fundo.
func _apply_accent(section: Dictionary) -> void:
	var accent: Color = section["accent"]
	_section_icon.texture = load("res://assets/icons/%s.svg" % section["icon"])
	_section_icon.modulate = accent
	_top_line.border_color = Color(accent, 0.45)
	var background := get_parent().get_node_or_null("AppBackground") as AppBackground
	if background != null:
		background.set_accent(accent)


## Estilos de uma cor de área para o botão do trilho e as subabas dela.
static func _accent_styles(button: Button, accent: Color, rail: bool) -> void:
	var pressed := StyleBoxFlat.new()
	if rail:
		pressed.bg_color = Color(accent, 0.14)
		pressed.border_color = Color(accent, 0.6)
		pressed.set_border_width_all(1)
		pressed.set_corner_radius_all(14)
		pressed.shadow_color = Color(accent, 0.18)
		pressed.shadow_size = 12
		pressed.content_margin_left = 4
		pressed.content_margin_right = 4
		pressed.content_margin_top = 8
		pressed.content_margin_bottom = 6
	else:
		pressed.bg_color = Color(accent, 0.0)
		pressed.border_color = accent
		pressed.border_width_bottom = 3
		pressed.content_margin_left = 12
		pressed.content_margin_right = 12
		pressed.content_margin_top = 10
		pressed.content_margin_bottom = 10
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	if rail:
		for key in ["font_pressed_color", "font_hover_pressed_color", "icon_pressed_color", "icon_hover_pressed_color"]:
			button.add_theme_color_override(key, accent.lightened(0.15))


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
	_toast.modulate.a = 0.0
	_place_toast()
	var rest := _toast.position
	_toast.position = rest + Vector2(0, -10)
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.set_parallel(true)
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.18)
	_toast_tween.tween_property(_toast, "position", rest, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.chain().tween_interval(2.2)
	_toast_tween.chain().tween_property(_toast, "modulate:a", 0.0, 0.4)
	_toast_tween.chain().tween_callback(func() -> void: _toast.visible = false)


# ---- montagem

func _build_rail() -> void:
	var panel := PanelContainer.new()
	panel.name = "Rail"
	panel.theme_type_variation = &"Rail"
	panel.custom_minimum_size = Vector2(88, 0)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	var logo := Label.new()
	logo.name = "LogoMark"
	logo.text = "R"
	logo.theme_type_variation = &"LogoMark"
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	logo.custom_minimum_size = Vector2(46, 46)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	logo.tooltip_text = "Rapstar"
	logo.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(logo)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	column.add_child(gap)
	for section: Dictionary in SECTIONS:
		var section_id: String = section["id"]
		var button := Button.new()
		button.name = "Section_%s" % section_id
		button.text = section["label"]
		button.icon = load("res://assets/icons/%s.svg" % section["icon"])
		button.theme_type_variation = &"RailButton"
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(72, 52)
		button.tooltip_text = "%s — %s" % [section["label"], section["hint"]]
		var first: Array = section["items"][0]
		button.pressed.connect(func() -> void: navigate_requested.emit(first[2], first[3].duplicate()))
		column.add_child(button)
		_rail[section_id] = button
		_accent_styles(button, section["accent"], true)
		var badge := Label.new()
		badge.theme_type_variation = &"CountBadge"
		badge.visible = false
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.position = Vector2(46, 4)
		badge.custom_minimum_size = Vector2(20, 18)
		button.add_child(badge)
		_badges[section_id] = badge
		for index in section["items"].size():
			var item: Array = section["items"][index]
			var tab := Button.new()
			tab.name = item[4]
			tab.text = item[0]
			tab.theme_type_variation = &"SubTab"
			tab.toggle_mode = true
			tab.focus_mode = Control.FOCUS_NONE
			tab.visible = false
			tab.set_meta("item", item)
			tab.set_meta("section", section_id)
			tab.set_meta("first", index == 0)
			tab.pressed.connect(func() -> void: navigate_requested.emit(item[2], item[3].duplicate()))
			_accent_styles(tab, section["accent"], false)
			_tabs.add_child(tab)
			_nav[item[4]] = tab
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	_avatar.name = "RailAvatar"
	_avatar.focus = "head"
	_avatar.custom_minimum_size = Vector2(44, 44)
	_avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_avatar.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(_avatar)
	var save := _icon_button("SaveButton", "save", "Salvar o jogo")
	save.pressed.connect(func() -> void: show_toast(GameManager.save_game().message))
	column.add_child(save)
	var menu := _icon_button("MenuButton", "exit", "Menu principal")
	menu.pressed.connect(_menu_confirm.popup_centered)
	column.add_child(menu)


func _build_top_bar(parent: Container) -> void:
	var bar := PanelContainer.new()
	bar.name = "TopBar"
	bar.theme_type_variation = &"TopBar"
	_top_line = StyleBoxFlat.new()
	_top_line.bg_color = Color("#100e18b8")
	_top_line.border_width_bottom = 1
	_top_line.border_color = Color("#241f33")
	_top_line.content_margin_left = 28
	_top_line.content_margin_right = 20
	_top_line.content_margin_top = 10
	_top_line.content_margin_bottom = 4
	bar.add_theme_stylebox_override("panel", _top_line)
	parent.add_child(bar)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	bar.add_child(rows)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	rows.add_child(row)
	var where := HBoxContainer.new()
	where.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	where.clip_contents = true
	row.add_child(where)
	_section_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_section_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_section_icon.custom_minimum_size = Vector2(26, 26)
	_section_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	where.add_child(_section_icon)
	where.add_theme_constant_override("separation", 12)
	_section_title.name = "SectionTitle"
	_section_title.theme_type_variation = &"SectionTitle"
	_section_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	where.add_child(_section_title)
	_section_hint.name = "SectionHint"
	_section_hint.theme_type_variation = &"MutedLabel"
	_section_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	where.add_child(_section_hint)
	_tabs.name = "SubTabs"
	_tabs.add_theme_constant_override("separation", 4)
	rows.add_child(_tabs)
	var stats := HBoxContainer.new()
	stats.name = "Stats"
	stats.add_theme_constant_override("separation", 18)
	row.add_child(stats)
	_chip(stats, "money", "money", "Dinheiro")
	_chip(stats, "fame", "fame", "Fama: a sua popularidade. Abre portas para shows, festivais e marcas")
	_chip(stats, "fans", "fans", "Fãs: seguidores e inscritos em todas as plataformas")
	var energy := _chip(stats, "energy", "energy", "Energia: usada para melhorar músicas. Volta toda semana")
	_energy_bar.theme_type_variation = &"EnergyBar"
	_energy_bar.show_percentage = false
	_energy_bar.custom_minimum_size = Vector2(44, 6)
	_energy_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	energy.get_child(0).add_child(_energy_bar)
	var next := Button.new()
	next.name = "NextWeekButton"
	next.text = "Próxima semana"
	next.icon = load("res://assets/icons/next.svg")
	next.theme_type_variation = &"PrimaryButton"
	next.tooltip_text = "Avança o calendário: lançamentos saem, shows acontecem, plataformas pagam e a energia volta. O jogo é salvo."
	next.pressed.connect(_on_next_week)
	row.add_child(next)


func _chip(row: HBoxContainer, key: String, icon_name: String, tooltip: String) -> Control:
	var chip := MarginContainer.new()
	chip.name = "Chip_" + key
	chip.tooltip_text = tooltip
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	for side in ["left", "right", "top", "bottom"]:
		chip.add_theme_constant_override("margin_" + side, 0)
	row.add_child(chip)
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	chip.add_child(inner)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/icons/%s.svg" % icon_name)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(18, 18)
	icon.modulate = CHIP_COLORS[key]
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(icon)
	var label := Label.new()
	label.name = "Value"
	label.theme_type_variation = &"ChipLabel"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(label)
	_chips[key] = label
	return chip


func _icon_button(node_name: String, icon_name: String, tooltip: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.icon = load("res://assets/icons/%s.svg" % icon_name)
	button.tooltip_text = tooltip
	button.theme_type_variation = &"RailButton"
	button.custom_minimum_size = Vector2(72, 36)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.focus_mode = Control.FOCUS_NONE
	return button


func _build_toast() -> void:
	_toast.name = "Toast"
	_toast.theme_type_variation = &"Toast"
	_toast.visible = false
	_toast.top_level = true
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_toast.add_child(row)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/icons/checkbox_on.svg")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(18, 18)
	row.add_child(icon)
	_toast_label.name = "ToastLabel"
	row.add_child(_toast_label)
	add_child(_toast)
	_toast_label.resized.connect(_place_toast)


func _place_toast() -> void:
	var viewport := get_viewport_rect().size
	_toast.size = _toast.get_combined_minimum_size()
	_toast.position = Vector2(viewport.x - _toast.size.x - 20, viewport.y - _toast.size.y - 20)


func _float_delta(target: Label, key: String, change: int) -> void:
	var label := Label.new()
	label.theme_type_variation = &"DeltaLabel"
	label.text = (Fmt.signed_money(change) if key == "money" else Fmt.signed_number(change))
	label.add_theme_color_override("font_color", Color("#46d483") if change > 0 else Color("#ff5f6d"))
	label.top_level = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.global_position = target.global_position + Vector2(0, 24)
	var tween := label.create_tween()
	tween.set_parallel(true)
	# Aparece logo abaixo do número e some, sem cobrir o valor nem as subabas.
	tween.tween_property(label, "global_position:y", label.global_position.y + 4, 1.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.6).set_delay(0.6)
	tween.chain().tween_callback(label.queue_free)


## Avança a semana e salva a carreira, para nunca perder semanas jogadas.
func _on_next_week() -> void:
	var report := GameManager.next_week()
	var saved := GameManager.save_game()
	navigate_requested.emit(Screen.WEEK_REPORT, {})
	show_toast("Semana %s  •  %s" % [Fmt.number(report.week), "jogo salvo automaticamente" if saved.ok else saved.message])
