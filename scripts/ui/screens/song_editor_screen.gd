extends Screen
## Cria uma música nova ou edita uma não lançada (quando context tem song_id).
## Layout: à esquerda a identidade da faixa (nome, capa, diss, sample); no centro a equipe, uma
## função por aba; embaixo, a barra de resumo com a nota estimada, os atributos e o custo, ao
## lado do botão de produzir. Assim o jogador vê o efeito de cada escolha antes de pagar.

const TEAM := [["producers", "Produtores", "ProducerPicker"], ["beatmakers", "Beatmakers", "BeatmakerPicker"], ["feats", "Feats", "FeatPicker"]]

var _song: SongData
var _diss := OptionButton.new()
var _team_tabs: Dictionary[String, Button] = {}
var _grade := Label.new()
var _grade_caption := Label.new()
var _bars: Dictionary[String, ProgressBar] = {}
var _bar_values: Dictionary[String, Label] = {}


func _ready() -> void:
	var balance := GameManager.balance
	var catalog := balance.collaborators
	var rules := balance.song_quality
	%ProducerPicker.setup("Produtores", catalog.producers, rules.max_producers)
	%BeatmakerPicker.setup("Beatmakers", catalog.beatmakers, rules.max_beatmakers)
	# Do cachê mais acessível ao mais caro: o jogador acha logo quem cabe no orçamento.
	var feats: Array[CollaboratorDefinition] = catalog.feats.duplicate()
	feats.sort_custom(func(a: CollaboratorDefinition, b: CollaboratorDefinition) -> bool: return a.cost < b.cost)
	%FeatPicker.setup("Feats", feats, rules.max_feats)
	for picker: CollaboratorPicker in [%ProducerPicker, %BeatmakerPicker, %FeatPicker]:
		picker.selection_changed.connect(_update_preview)
	_build_layout()

	_song = GameManager.career.find_song(context.get("song_id", ""))
	_show_social_prices()
	_build_diss_option()
	_fill_sample_options()
	if _song != null:
		%Title.text = "Editar música"
		%TitleEdit.text = _song.title
		%CoverPicker.set_cover(_song.cover_file)
		%ProducerPicker.set_selected_ids(_song.credits.producer_ids)
		%BeatmakerPicker.set_selected_ids(_song.credits.beatmaker_ids)
		%FeatPicker.set_selected_ids(_song.credits.feat_ids)

	%SampleOption.item_selected.connect(func(_index: int) -> void: _on_sample_changed())
	%OwnSongOption.item_selected.connect(func(_index: int) -> void: _update_preview())
	_on_sample_changed()
	%CoverPicker.message_requested.connect(%MessageLabel.set_text)
	%ConfirmButton.pressed.connect(_on_confirm_pressed)
	%BackButton.pressed.connect(_go_back)
	_update_preview()
	super()


func refresh() -> void:
	_update_preview()


## O primeiro item da lista de músicas próprias não é uma música: a escolha é sempre do jogador.
func _fill_sample_options() -> void:
	%SampleOption.add_item("Sem sample")
	%SampleOption.set_item_metadata(0, "")
	for definition in GameManager.balance.samples.samples:
		%SampleOption.add_item("[%s] %s" % [definition.type_label, definition.display_name])
		%SampleOption.set_item_metadata(%SampleOption.item_count - 1, definition.id)
	%OwnSongOption.add_item("Selecione a música")
	%OwnSongOption.set_item_metadata(0, "")
	for song in GameManager.career.songs:
		if _song == null or song.id != _song.id:
			%OwnSongOption.add_item(song.title)
			%OwnSongOption.set_item_metadata(%OwnSongOption.item_count - 1, song.id)
	if _song != null:
		_select_by_metadata(%SampleOption, _song.sample.sample_id)
		_select_by_metadata(%OwnSongOption, _song.sample.song_id)


func _select_by_metadata(option: OptionButton, value: String) -> void:
	for index in option.item_count:
		if option.get_item_metadata(index) == value:
			option.select(index)
			return


func _selected_definition() -> SampleDefinition:
	return GameManager.balance.samples.find_sample(%SampleOption.get_selected_metadata())


func _sample() -> SongSample:
	var sample := SongSample.new()
	var definition := _selected_definition()
	if definition != null:
		sample.sample_id = definition.id
		if definition.is_own():
			sample.song_id = %OwnSongOption.get_selected_metadata()
	return sample


func _on_sample_changed() -> void:
	var definition := _selected_definition()
	%OwnSongOption.visible = definition != null and definition.is_own()
	%SampleInfo.text = definition.info_text() if definition != null else ""
	%SampleInfo.tooltip_text = %SampleInfo.text
	_update_preview()


func _credits() -> SongCredits:
	var credits := SongCredits.new()
	credits.producer_ids = %ProducerPicker.selected_ids()
	credits.beatmaker_ids = %BeatmakerPicker.selected_ids()
	credits.feat_ids = %FeatPicker.selected_ids()
	return credits


func _update_preview() -> void:
	var credits := _credits()
	var sample := _sample()
	var preview := GameManager.music.preview_quality(credits, _song, sample)
	var parts := PackedStringArray()
	for attribute in GameManager.balance.song_quality.attributes:
		parts.append("%s: %d" % [attribute.display_name, preview.attribute_values[attribute.id]])
	parts.append("Feats: %d" % preview.feat_value)
	var note_label := "Nota" if _song != null else "Nota estimada"
	%PreviewLabel.text = "%s  |  %s: %d" % ["  |  ".join(parts), note_label, preview.quality]
	_grade.text = str(preview.quality)
	_grade.add_theme_color_override("font_color", Color("#46d483") if preview.quality >= 70 else (Color("#f5b82e") if preview.quality >= 45 else Color("#ff8a94")))
	_grade_caption.text = note_label.to_upper()
	for attribute in GameManager.balance.song_quality.attributes:
		_set_bar(attribute.id, preview.attribute_values[attribute.id])
	_set_bar("feats", preview.feat_value)
	for item: Array in TEAM:
		var picker: CollaboratorPicker = get_node("%" + item[2])
		_team_tabs[item[0]].text = "%s  %s" % [item[1], picker.count_text()]

	var hiring := GameManager.music.hiring_cost(credits, _song, GameManager.career)
	if _song == null or not sample.equals(_song.sample):
		hiring += GameManager.music.sample_cost(sample)
	var total := hiring
	var cost_text := "Contratações novas: %s" % Fmt.money(hiring)
	if _song == null:
		var production := GameManager.balance.song_production_cost
		total += production
		cost_text = "Produção: %s  +  Contratações: %s  =  Total: %s" % [Fmt.money(production), Fmt.money(hiring), Fmt.money(total)]
	var money := GameManager.career.money
	%CostLabel.text = "%s  |  Seu dinheiro: %s  →  depois: %s" % [cost_text, Fmt.money(money), Fmt.money(money - total)]
	%ConfirmButton.disabled = total > money
	if total > money:
		%ConfirmButton.text = "Dinheiro insuficiente"
	elif _song != null:
		%ConfirmButton.text = "Salvar alterações (%s)" % Fmt.money(total)
	else:
		%ConfirmButton.text = "Produzir (%s)" % Fmt.money(total)


func _set_bar(id: String, value: int) -> void:
	if not _bars.has(id):
		return
	var bar := _bars[id]
	bar.create_tween().tween_property(bar, "value", float(value), 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_bar_values[id].text = str(value)


# ---- montagem

func _build_layout() -> void:
	var column: VBoxContainer = $Column
	column.add_theme_constant_override("separation", 10)
	# Cabeçalho: área, título, frase de apoio e Voltar discreto à direita.
	var header := HBoxContainer.new()
	column.add_child(header)
	column.move_child(header, 0)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	var kicker := Label.new()
	kicker.text = "ESTÚDIO"
	kicker.theme_type_variation = &"Kicker"
	titles.add_child(kicker)
	%Title.reparent(titles)
	%Title.tooltip_text = "Monte a equipe: talento sobe a nota, consistência reduz a variação e o cachê é pago uma vez."
	%Title.mouse_filter = Control.MOUSE_FILTER_PASS
	%BackButton.reparent(header)
	%BackButton.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	# Identidade à esquerda: nome, capa, diss e sample juntos.
	var form: VBoxContainer = $Column/Body/Form/FormColumn
	form.add_theme_constant_override("separation", 10)
	$Column/Body/Form.custom_minimum_size.x = 300
	# Capa compacta: a prévia menor e os botões de imagem numa linha só.
	var cover: Control = %CoverPicker
	cover.get_node("Preview").custom_minimum_size.y = 72
	cover.get_node("FileButton").reparent(cover.get_node("PasteRow"))
	cover.get_node("PasteRow").move_child(cover.get_node("PasteRow/FileButton"), 0)
	cover.get_node("PasteRow/FileButton").text = "Imagem"
	_section_label(form, "SAMPLE", form.get_child_count())
	for node: Control in [%SampleOption, %OwnSongOption, %SampleInfo]:
		node.reparent(form)
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	%SampleInfo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	%SampleInfo.theme_type_variation = &"MutedLabel"
	$Column/SampleRow.visible = false
	# Equipe no centro, uma função por aba.
	var team := PanelContainer.new()
	team.name = "TeamCard"
	team.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	$Column/Body.add_child(team)
	var team_column := VBoxContainer.new()
	team_column.add_theme_constant_override("separation", 10)
	team.add_child(team_column)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	team_column.add_child(tabs)
	var team_label := Label.new()
	team_label.text = "EQUIPE"
	team_label.tooltip_text = "Talento sobe a nota, consistência reduz a variação e o cachê é pago uma vez."
	team_label.mouse_filter = Control.MOUSE_FILTER_PASS
	team_label.theme_type_variation = &"SectionLabel"
	team_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	team_label.custom_minimum_size.x = 64
	tabs.add_child(team_label)
	var group := ButtonGroup.new()
	for item: Array in TEAM:
		var tab := Button.new()
		tab.name = "Team_%s" % item[0]
		tab.theme_type_variation = &"ChipButton"
		tab.toggle_mode = true
		tab.button_group = group
		tab.focus_mode = Control.FOCUS_NONE
		tab.pressed.connect(_show_team.bind(item[0]))
		tabs.add_child(tab)
		_team_tabs[item[0]] = tab
		var picker: CollaboratorPicker = get_node("%" + item[2])
		picker.reparent(team_column)
		picker.show_header(false)
		picker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_show_team("feats" if context.has("diss_target") else "producers")
	# Barra de resumo: nota, atributos e custo, com a ação principal.
	var summary := PanelContainer.new()
	summary.name = "SummaryBar"
	summary.theme_type_variation = &"HeroPanel"
	column.add_child(summary)
	column.move_child(summary, $Column/ButtonRow.get_index())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	summary.add_child(row)
	var grade_box := VBoxContainer.new()
	grade_box.add_theme_constant_override("separation", -4)
	grade_box.custom_minimum_size.x = 110
	row.add_child(grade_box)
	_grade_caption.theme_type_variation = &"Kicker"
	grade_box.add_child(_grade_caption)
	_grade.name = "GradeValue"
	_grade.theme_type_variation = &"HeroTitle"
	_grade.add_theme_font_size_override("font_size", 40)
	grade_box.add_child(_grade)
	var bars := GridContainer.new()
	bars.columns = 6
	bars.add_theme_constant_override("h_separation", 10)
	bars.add_theme_constant_override("v_separation", 4)
	bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bars)
	var specs: Array = []
	for attribute in GameManager.balance.song_quality.attributes:
		specs.append([attribute.id, attribute.display_name])
	specs.append(["feats", "Feats"])
	for spec: Array in specs:
		var name_label := Label.new()
		name_label.text = spec[1]
		name_label.theme_type_variation = &"StatCaption"
		name_label.custom_minimum_size.x = 70
		bars.add_child(name_label)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = 100
		bar.custom_minimum_size = Vector2(70, 6)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bars.add_child(bar)
		_bars[spec[0]] = bar
		var value := Label.new()
		value.theme_type_variation = &"ChipLabel"
		value.custom_minimum_size.x = 28
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		bars.add_child(value)
		_bar_values[spec[0]] = value
	var money := VBoxContainer.new()
	money.add_theme_constant_override("separation", 8)
	money.custom_minimum_size.x = 360
	money.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(money)
	%CostLabel.reparent(money)
	%CostLabel.theme_type_variation = &"StatCaption"
	%CostLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	%ConfirmButton.reparent(money)
	%MessageLabel.reparent(money)
	%MessageLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	%ConfirmButton.theme_type_variation = &"PrimaryButton"
	%ConfirmButton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	%PreviewLabel.visible = false
	$Column/ButtonRow.visible = false


func _section_label(parent: Container, text: String, index: int) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"SectionLabel"
	parent.add_child(label)
	parent.move_child(label, index)


func _show_team(team_id: String) -> void:
	for item: Array in TEAM:
		var picker: CollaboratorPicker = get_node("%" + item[2])
		picker.visible = item[0] == team_id
		_team_tabs[item[0]].set_pressed_no_signal(item[0] == team_id)


## Quem automatiza cliques chega a um colaborador abrindo a aba da função dele.
func reveal(control: Control) -> void:
	for item: Array in TEAM:
		if get_node("%" + item[2]).is_ancestor_of(control):
			_show_team(item[0])


func _on_confirm_pressed() -> void:
	var result: ActionResult
	if _song != null:
		result = GameManager.edit_song(_song.id, %TitleEdit.text, _credits(), %CoverPicker.cover_file, _sample(), _diss.get_selected_metadata())
	else:
		result = GameManager.create_song(%TitleEdit.text, _credits(), %CoverPicker.cover_file, _sample(), _diss.get_selected_metadata())
	if result.ok:
		navigate(Screen.SONG_DETAIL, {"song_id": result.value.id})
	else:
		%MessageLabel.text = result.message


## Artistas conhecidos mostram o cachê com o efeito da relação (ou que recusam o feat).
func _show_social_prices() -> void:
	var social := GameManager.social
	var career := GameManager.career
	for person in GameManager.balance.collaborators.feats:
		var artist_id := String(person.id)
		var current := social.peek(career, artist_id)
		var label := "%s (%d)  %s  •  %s" % [person.display_name, person.skill, Fmt.money(person.cost), person.tier_label()]
		if current != null and current.met:
			label = "%s (%d)  %s  •  %s" % [person.display_name, person.skill, social.price_text(career, artist_id), social.status(career, artist_id)["label"]]
		%FeatPicker.set_label(artist_id, label)


## Diss: a música pode ter um artista conhecido como alvo. Continua sendo uma música normal.
func _build_diss_option() -> void:
	var social := GameManager.social
	var career := GameManager.career
	_diss.name = "DissOption"
	_diss.add_item("Música normal")
	_diss.set_item_metadata(0, "")
	for artist_id in GameManager.beefs.diss_targets(career):
		_diss.add_item("Diss contra %s (%s)" % [social.display_name(artist_id), social.status(career, artist_id)["label"].to_lower()])
		_diss.set_item_metadata(_diss.item_count - 1, artist_id)
	var target: String = _song.diss_target_id if _song != null else String(context.get("diss_target", ""))
	for index in _diss.item_count:
		if _diss.get_item_metadata(index) == target:
			_diss.select(index)
	_diss.tooltip_text = "Uma diss é uma música normal com um alvo: ao ser lançada, começa ou esquenta um beef."
	_diss.disabled = _diss.item_count == 1
	%CoverPicker.get_parent().add_child(_diss)
	%CoverPicker.get_parent().move_child(_diss, %CoverPicker.get_index() + 1)


func _go_back() -> void:
	if _song != null:
		navigate(Screen.SONG_DETAIL, {"song_id": _song.id})
	else:
		navigate(Screen.SONGS)
