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
		%ConfirmButton.text = "Salvar alterações"
	else:
		%ConfirmButton.text = "Produzir (%s)" % Fmt.money(balance.song_production_cost)

	%CoverPicker.message_requested.connect(%MessageLabel.set_text)
	%ConfirmButton.pressed.connect(_on_confirm_pressed)
	%BackButton.pressed.connect(navigate.bind(Screen.SONGS))
	_update_preview()
	super()


func _credits() -> SongCredits:
	var credits := SongCredits.new()
	credits.producer_ids = %ProducerPicker.selected_ids()
	credits.beatmaker_ids = %BeatmakerPicker.selected_ids()
	credits.feat_ids = %FeatPicker.selected_ids()
	return credits


func _update_preview() -> void:
	var result := GameManager.music.preview_quality(_credits(), _song)
	var text := "Beat: %d  |  Produção: %d  |  Feats: %d  |  " % [result.beat, result.production, result.feats]
	if _song != null:
		var final_quality := mini(result.base + _song.improvement_points, GameManager.song_quality.improvement_limit(result.base))
		%PreviewLabel.text = text + "Nota: %d" % final_quality
	else:
		%PreviewLabel.text = text + "Nota estimada: %d (varia com a consistência do time)" % result.base


func _on_confirm_pressed() -> void:
	var result: ActionResult
	if _song != null:
		result = GameManager.edit_song(_song.id, %TitleEdit.text, _credits(), %CoverPicker.cover_file)
	else:
		result = GameManager.create_song(%TitleEdit.text, _credits(), %CoverPicker.cover_file)
	if result.ok:
		navigate(Screen.SONGS)
	else:
		%MessageLabel.text = result.message
