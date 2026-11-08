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
var _portrait := CharacterView.new()
var _kicker := Label.new()
var _numbers: Dictionary[String, Label] = {}
var _number_boxes: Dictionary[String, Control] = {}


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
	_build_banner()
	super()


## Banner do perfil: retrato, fase, nome, descrição e os números de público em destaque. O catálogo
## fica embaixo, e a edição do perfil (foto, descrição, visual) vai para a coluna da direita.
func _build_banner() -> void:
	var column: VBoxContainer = $Column
	column.add_theme_constant_override("separation", 14)
	var banner := PanelContainer.new()
	banner.name = "ProfileBanner"
	banner.theme_type_variation = &"HeroPanel"
	column.add_child(banner)
	column.move_child(banner, 1)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	banner.add_child(row)
	var frame := PanelContainer.new()
	frame.theme_type_variation = &"StagePanel"
	frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	frame.custom_minimum_size = Vector2(112, 112)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(frame)
	var holder := Control.new()
	frame.add_child(holder)
	var light := StageBackdrop.new()
	light.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	light.floor_ratio = 1.2
	holder.add_child(light)
	_portrait.focus = "head"
	_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait.offset_top = 8
	holder.add_child(_portrait)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 2)
	row.add_child(texts)
	_kicker.theme_type_variation = &"Kicker"
	texts.add_child(_kicker)
	%NameLabel.reparent(texts)
	%NameLabel.theme_type_variation = &"HeroTitle"
	%NameLabel.add_theme_font_size_override("font_size", 38)
	%NameLabel.clip_text = true
	%NameLabel.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	%BioLabel.reparent(texts)
	%BioLabel.theme_type_variation = &"MutedLabel"
	%BioLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	%BioLabel.max_lines_visible = 2
	var numbers := HBoxContainer.new()
	numbers.name = "ProfileNumbers"
	numbers.add_theme_constant_override("separation", 26)
	numbers.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(numbers)
	for spec: Array in [["listeners", "Ouvintes"], ["followers", "Seguidores"], ["subscribers", "Inscritos"], ["plays", "Reproduções"]]:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", -2)
		numbers.add_child(box)
		var value := Label.new()
		value.theme_type_variation = &"BigNumber"
		value.add_theme_font_size_override("font_size", 26)
		box.add_child(value)
		var caption := Label.new()
		caption.text = spec[1].to_upper()
		caption.theme_type_variation = &"SectionLabel"
		box.add_child(caption)
		_numbers[spec[0]] = value
		_number_boxes[spec[0]] = box
	%StatsLabel.visible = false
	# Catálogo primeiro; edição do perfil à direita, mais estreita.
	var body: HBoxContainer = $Column/Body
	body.move_child($Column/Body/Side, body.get_child_count() - 1)
	$Column/Body/Side.custom_minimum_size.x = 260
	# Capa compacta: prévia menor e os botões de imagem numa linha.
	var cover: Control = %CoverPicker
	cover.get_node("Preview").custom_minimum_size.y = 80
	cover.get_node("FileButton").reparent(cover.get_node("PasteRow"))
	cover.get_node("PasteRow").move_child(cover.get_node("PasteRow/FileButton"), 0)
	cover.get_node("PasteRow/FileButton").text = "Foto"
	cover.get_node("PasteRow/PasteButton").text = "Colar"
	# Filtro do catálogo e troca de perfil numa linha só; o nome da área já está na barra superior.
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 10)
	$Column/Body/Main.add_child(tools)
	$Column/Body/Main.move_child(tools, %FilterOption.get_index())
	%FilterOption.reparent(tools)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(spacer)
	%ArtistOption.reparent(tools)
	%ArtistOption.tooltip_text = "Ver o perfil de outro artista"
	$Column/HeaderRow.visible = false
	var catalog_title := Label.new()
	catalog_title.text = "CATÁLOGO"
	catalog_title.theme_type_variation = &"SectionLabel"
	$Column/Body/Main.add_child(catalog_title)
	$Column/Body/Main.move_child(catalog_title, 0)
	var edit_title := Label.new()
	edit_title.text = "EDITAR PERFIL"
	edit_title.theme_type_variation = &"SectionLabel"
	%OwnProfile.add_child(edit_title)
	%OwnProfile.move_child(edit_title, 0)


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
	_portrait.visible = true
	_portrait.appearance = career.appearance
	_kicker.text = "PERFIL PÚBLICO  •  %s" % GameManager.progression.stage_for(career.fame).display_name.to_upper()
	_set_number("listeners", streaming.total_listeners(career))
	_set_number("followers", streaming.total_followers(career) - youtube.followers)
	_set_number("subscribers", youtube.followers)
	_set_number("plays", streaming.total_plays(career))
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
	_portrait.visible = false
	_kicker.text = "ARTISTA  •  %s" % person.tier_label().to_upper()
	_set_number("listeners", listeners)
	_set_number("followers", followers)
	_set_number("subscribers", -1)
	_set_number("plays", -1)
	%BioLabel.text = "Artista convidado, com talento %d e consistência %d." % [person.skill, person.consistency]
	%StatsLabel.text = "Ouvintes: %s  |  Seguidores: %s  |  Parcerias com você: %d" % [
		Fmt.number(listeners), Fmt.number(followers), _collaboration_songs().size()
	]


## Valor negativo esconde o número (perfis de outros artistas não têm todos).
func _set_number(key: String, value: int) -> void:
	if not _numbers.has(key):
		return
	_number_boxes[key].visible = value >= 0
	_numbers[key].text = Fmt.number(maxi(value, 0))


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
