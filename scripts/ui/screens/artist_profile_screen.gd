extends Screen
## Perfil público do artista. O próprio artista pode trocar a foto e a descrição e acompanha todo
## o catálogo. Colaboradores têm um perfil simples, com as músicas feitas em parceria.

const FILTER_POPULAR := "Populares"
const FILTER_SINGLES := "Singles"
const FILTER_ALBUMS := "Álbuns"
const FILTER_EPS := "EPs"
const FILTER_MIXTAPES := "Mixtapes"
const FILTER_SONGS := "Músicas"
const FORMAT_BY_FILTER := {FILTER_ALBUMS: "album", FILTER_EPS: "ep", FILTER_MIXTAPES: "mixtape"}

## Id do colaborador em exibição. Vazio para o próprio artista.
var _collaborator_id: String = ""


func _ready() -> void:
	%CatalogTable.set_headers(["Nome", "Tipo", "Status", "Reproduções", "Tendência"])
	%CatalogTable.item_mouse_selected.connect(func(_position: Vector2, _button: int) -> void: _open_selected())
	%CatalogTable.item_activated.connect(_open_selected)
	%ArtistOption.add_item(GameManager.career.artist_name)
	%ArtistOption.set_item_metadata(0, "")
	for person in GameManager.balance.collaborators.feats:
		%ArtistOption.add_item(person.display_name)
		%ArtistOption.set_item_metadata(%ArtistOption.item_count - 1, String(person.id))
	%ArtistOption.item_selected.connect(_on_artist_selected)
	for filter in [FILTER_POPULAR, FILTER_SINGLES, FILTER_ALBUMS, FILTER_EPS, FILTER_MIXTAPES, FILTER_SONGS]:
		%FilterOption.add_item(filter)
	%FilterOption.item_selected.connect(func(_index: int) -> void: _fill_catalog())
	%CoverPicker.set_cover(GameManager.career.artist_cover)
	%CoverPicker.cover_changed.connect(_on_cover_changed)
	%CoverPicker.message_requested.connect(%MessageLabel.set_text)
	%BioEdit.text = GameManager.career.artist_bio
	%BioButton.pressed.connect(_on_bio_pressed)
	%CustomizeButton.pressed.connect(navigate.bind(Screen.CHARACTER, {"back": Screen.ARTIST_PROFILE}))
	%BackButton.pressed.connect(navigate.bind(Screen.HUB))
	super()


func refresh() -> void:
	var is_own := _collaborator_id.is_empty()
	%OwnProfile.visible = is_own
	%CollaboratorCover.visible = not is_own
	%FilterOption.visible = is_own
	if is_own:
		_show_own_profile()
	else:
		_show_collaborator_profile()
	_fill_catalog()


func _show_own_profile() -> void:
	var career := GameManager.career
	var streaming := GameManager.streaming
	%NameLabel.text = career.artist_name
	%BioLabel.text = streaming.artist_bio(career)
	var youtube := career.platform_stats_for("youtube")
	%StatsLabel.text = "Ouvintes: %s  |  Seguidores: %s  |  Inscritos: %s  |  Reproduções: %s\nFama: %s  |  Catálogo: %s" % [
		Fmt.number(streaming.total_listeners(career)),
		Fmt.number(streaming.total_followers(career) - youtube.followers),
		Fmt.number(youtube.followers),
		Fmt.number(streaming.total_plays(career)),
		Fmt.number(career.fame),
		streaming.catalog_text(career),
	]


func _show_collaborator_profile() -> void:
	var person := _collaborator()
	var rules := GameManager.balance.streaming
	var listeners := person.cost * rules.collaborator_listeners_per_cost
	var followers := roundi(listeners * rules.collaborator_followers_rate)
	%CollaboratorCover.show_cover("")
	%NameLabel.text = person.display_name
	%BioLabel.text = "Artista convidado, com talento %d e consistência %d." % [person.skill, person.consistency]
	%StatsLabel.text = "Ouvintes: %s  |  Seguidores: %s  |  Parcerias com você: %d" % [
		Fmt.number(listeners), Fmt.number(followers), _collaboration_songs().size()
	]


func _collaborator() -> CollaboratorDefinition:
	var catalog := GameManager.balance.collaborators
	var ids: Array[String] = [_collaborator_id]
	return CollaboratorCatalog.resolve(catalog.feats, ids)[0]


func _collaboration_songs() -> Array[SongData]:
	var songs: Array[SongData] = []
	for song in GameManager.career.songs:
		if _collaborator_id in song.credits.feat_ids:
			songs.append(song)
	return songs


func _fill_catalog() -> void:
	%CatalogTable.clear_rows()
	if not _collaborator_id.is_empty():
		for song in _collaboration_songs():
			_add_song_row(song)
		return
	var career := GameManager.career
	var filter: String = %FilterOption.get_item_text(%FilterOption.selected)
	match filter:
		FILTER_POPULAR:
			for performance in GameManager.streaming.top_songs(career):
				_add_song_row(career.find_song(performance.song_id))
		FILTER_SONGS:
			for song in career.songs:
				_add_song_row(song)
		FILTER_SINGLES:
			for release in career.releases:
				if release.content_type == ReleaseData.TYPE_SONG:
					_add_song_row(career.find_song(release.content_id))
		_:
			for album in career.albums:
				if album.format_id == FORMAT_BY_FILTER[filter]:
					_add_project_row(album)


func _add_song_row(song: SongData) -> void:
	var streaming := GameManager.streaming
	var performance := GameManager.career.find_performance(song.id)
	%CatalogTable.add_row([
		song.title,
		streaming.release_label(GameManager.career, performance) if performance != null else "Música",
		song.display_status(),
		Fmt.number(performance.total_plays) if performance != null else "—",
		streaming.trend_label(performance) if performance != null else "—",
	], song.id, song.cover_file)


func _add_project_row(album: AlbumData) -> void:
	var release := GameManager.career.find_release(album.id)
	%CatalogTable.add_row([
		album.title,
		GameManager.releases.content_type_label(album),
		album.display_status(),
		Fmt.number(release.total_streams) if release != null else "—",
		"—",
	], null, album.cover_file)


## Adiado porque esta tela é trocada enquanto a tabela ainda trata o clique.
func _open_selected() -> void:
	var song_id: Variant = %CatalogTable.selected_value()
	if song_id != null:
		navigate.call_deferred(Screen.SONG_DETAIL, {"song_id": song_id})


func _on_artist_selected(index: int) -> void:
	_collaborator_id = %ArtistOption.get_item_metadata(index)
	refresh()


func _on_cover_changed() -> void:
	GameManager.set_artist_cover(%CoverPicker.cover_file)


func _on_bio_pressed() -> void:
	GameManager.set_artist_bio(%BioEdit.text)
	%MessageLabel.text = "Descrição salva. Deixe em branco para usar a descrição automática."
