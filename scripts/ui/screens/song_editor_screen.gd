extends Screen
## Cria uma música nova ou edita uma não lançada (quando context tem song_id).

var _song: SongData


func _ready() -> void:
	var balance := GameManager.balance
	var catalog := balance.collaborators
	var rules := balance.song_quality
	%ProducerPicker.setup("Produtores", catalog.producers, rules.max_producers)
	%BeatmakerPicker.setup("Beatmakers", catalog.beatmakers, rules.max_beatmakers)
	%FeatPicker.setup("Feats", catalog.feats, rules.max_feats)
	for picker: CollaboratorPicker in [%ProducerPicker, %BeatmakerPicker, %FeatPicker]:
		picker.selection_changed.connect(_update_preview)

	_song = GameManager.career.find_song(context.get("song_id", ""))
	if _song != null:
		%Title.text = "Editar música"
		%TitleEdit.text = _song.title
		%CoverPicker.set_cover(_song.cover_file)
		%ProducerPicker.set_selected_ids(_song.credits.producer_ids)
		%BeatmakerPicker.set_selected_ids(_song.credits.beatmaker_ids)
		%FeatPicker.set_selected_ids(_song.credits.feat_ids)

	%CoverPicker.message_requested.connect(%MessageLabel.set_text)
	%ConfirmButton.pressed.connect(_on_confirm_pressed)
	%BackButton.pressed.connect(_go_back)
	_update_preview()
	super()


func refresh() -> void:
	_update_preview()


func _credits() -> SongCredits:
	var credits := SongCredits.new()
	credits.producer_ids = %ProducerPicker.selected_ids()
	credits.beatmaker_ids = %BeatmakerPicker.selected_ids()
	credits.feat_ids = %FeatPicker.selected_ids()
	return credits


func _update_preview() -> void:
	var credits := _credits()
	var preview := GameManager.music.preview_quality(credits, _song)
	var parts := PackedStringArray()
	for attribute in GameManager.balance.song_quality.attributes:
		parts.append("%s: %d" % [attribute.display_name, preview.attribute_values[attribute.id]])
	parts.append("Feats: %d" % preview.feat_value)
	var note_label := "Nota" if _song != null else "Nota estimada"
	%PreviewLabel.text = "%s  |  %s: %d" % ["  |  ".join(parts), note_label, preview.quality]

	var hiring := GameManager.music.hiring_cost(credits, _song)
	var total := hiring
	var cost_text := "Contratações novas: %s" % Fmt.money(hiring)
	if _song == null:
		var production := GameManager.balance.song_production_cost
		total += production
		cost_text = "Produção: %s  +  Contratações: %s  =  Total: %s" % [Fmt.money(production), Fmt.money(hiring), Fmt.money(total)]
	var money := GameManager.career.money
	%CostLabel.text = "%s  |  Seu dinheiro: %s" % [cost_text, Fmt.money(money)]
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
		result = GameManager.edit_song(_song.id, %TitleEdit.text, _credits(), %CoverPicker.cover_file)
	else:
		result = GameManager.create_song(%TitleEdit.text, _credits(), %CoverPicker.cover_file)
	if result.ok:
		navigate(Screen.SONG_DETAIL, {"song_id": result.value.id})
	else:
		%MessageLabel.text = result.message


func _go_back() -> void:
	if _song != null:
		navigate(Screen.SONG_DETAIL, {"song_id": _song.id})
	else:
		navigate(Screen.SONGS)
