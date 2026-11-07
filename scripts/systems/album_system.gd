class_name AlbumSystem
extends RefCounted
## Projetos coletivos: EP, álbum e mixtape. Um projeto pode ser criado vazio e crescer
## ao longo da carreira. O mínimo de músicas só é exigido para lançar (ver ReleaseSystem).

var _balance: GameBalance
var _economy: EconomySystem


func _init(balance: GameBalance, economy: EconomySystem) -> void:
	_balance = balance
	_economy = economy


## Músicas que podem entrar no projeto. Cada música pertence a no máximo um projeto.
## Informe album_id para incluir as músicas do próprio projeto em edição.
func available_songs(career: CareerData, album_id: String = "") -> Array[SongData]:
	var available: Array[SongData] = []
	for song in career.songs:
		var album := career.find_album_of_song(song.id)
		if album == null or album.id == album_id:
			available.append(song)
	return available


func create_album(career: CareerData, title: String, format_id: StringName, song_ids: Array[String] = [], cover_file: String = "") -> ActionResult:
	var clean_title := title.strip_edges()
	if clean_title.is_empty():
		return ActionResult.failure("Dê um nome para o projeto.")
	var album_format := _balance.find_album_format(format_id)
	if album_format == null:
		return ActionResult.failure("Formato inválido.")
	var tracklist_error := _validate_tracklist(career, album_format, song_ids, "")
	if not tracklist_error.is_empty():
		return ActionResult.failure(tracklist_error)
	var cost := album_format.production_cost(song_ids.size())
	if not _economy.can_afford(career, cost):
		return _economy.insufficient_funds(cost)

	_economy.spend(career, cost, "Produção de %s: %s" % [album_format.display_name, clean_title], FinanceEntry.CATEGORY_PRODUCTION)
	var album := AlbumData.new()
	album.id = career.new_id("album")
	album.title = clean_title
	album.format_id = format_id
	album.song_ids = song_ids.duplicate()
	album.cover_file = cover_file
	album.production_cost = cost
	album.quality = career.average_quality(album.song_ids)
	career.albums.append(album)
	return ActionResult.success("\"%s\" criado. %s." % [album.title, album_format.progress_text(song_ids.size())], album)


## Só cobra o que passar do custo de produção já pago. Remover músicas não gera reembolso.
func update_album(career: CareerData, album_id: String, title: String, format_id: StringName, song_ids: Array[String], cover_file: String) -> ActionResult:
	var album := career.find_content(album_id) as AlbumData
	if album == null:
		return ActionResult.failure("Projeto não encontrado.")
	if album.is_released():
		return ActionResult.failure("\"%s\" já foi lançado e não pode mais ser editado." % album.title)
	var clean_title := title.strip_edges()
	if clean_title.is_empty():
		return ActionResult.failure("Dê um nome para o projeto.")
	var album_format := _balance.find_album_format(format_id)
	if album_format == null:
		return ActionResult.failure("Formato inválido.")
	var is_scheduled := career.find_active_schedule(album.id) != null
	if is_scheduled and album_format.id != StringName(album.format_id):
		return ActionResult.failure("Cancele o agendamento antes de mudar o formato.")
	# Um projeto agendado precisa continuar pronto para sair sozinho na semana marcada.
	if is_scheduled and song_ids.size() < album_format.min_songs:
		return ActionResult.failure("Projeto agendado precisa de pelo menos %d músicas. Cancele o agendamento para remover mais." % album_format.min_songs)
	var tracklist_error := _validate_tracklist(career, album_format, song_ids, album.id)
	if not tracklist_error.is_empty():
		return ActionResult.failure(tracklist_error)
	var extra_cost := maxi(album_format.production_cost(song_ids.size()) - album.production_cost, 0)
	if not _economy.can_afford(career, extra_cost):
		return _economy.insufficient_funds(extra_cost)

	if extra_cost > 0:
		_economy.spend(career, extra_cost, "Ampliação de projeto: %s" % clean_title, FinanceEntry.CATEGORY_PRODUCTION)
		album.production_cost += extra_cost
	album.title = clean_title
	album.format_id = format_id
	album.song_ids = song_ids.duplicate()
	album.cover_file = cover_file
	album.quality = career.average_quality(album.song_ids)
	return ActionResult.success("\"%s\" atualizado. %s." % [album.title, album_format.progress_text(song_ids.size())], album)


## Devolve a mensagem de erro, ou um texto vazio se a tracklist for válida.
func _validate_tracklist(career: CareerData, album_format: AlbumFormatDefinition, song_ids: Array[String], album_id: String) -> String:
	if song_ids.size() > album_format.max_songs:
		return "%s aceita no máximo %d músicas." % [album_format.display_name, album_format.max_songs]
	var available := available_songs(career, album_id)
	var seen: Array[String] = []
	for song_id in song_ids:
		var song := career.find_song(song_id)
		if song == null or song not in available or song_id in seen:
			return "Uma das músicas selecionadas não está disponível."
		seen.append(song_id)
	return ""
