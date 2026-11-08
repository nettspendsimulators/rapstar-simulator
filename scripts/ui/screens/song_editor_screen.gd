extends Screen
## Cria uma música nova ou edita uma não lançada (quando context tem song_id).

var _song: SongData
var _diss := OptionButton.new()


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


func _go_back() -> void:
	if _song != null:
		navigate(Screen.SONG_DETAIL, {"song_id": _song.id})
	else:
		navigate(Screen.SONGS)
