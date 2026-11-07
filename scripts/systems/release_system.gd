class_name ReleaseSystem
extends RefCounted
## Lançamentos imediatos e agendados, e o resultado semanal de tudo que já saiu.

var _balance: GameBalance
var _economy: EconomySystem
var _time: TimeSystem
var _performance: PerformanceSystem


func _init(balance: GameBalance, economy: EconomySystem, time: TimeSystem, performance: PerformanceSystem) -> void:
	_balance = balance
	_economy = economy
	_time = time
	_performance = performance


## Conteúdo que pode ser lançado ou agendado agora.
func unreleased_content(career: CareerData) -> Array[ReleasableContent]:
	var pending: Array[ReleasableContent] = []
	for song in career.songs:
		if not song.is_released() and career.find_active_schedule(song.id) == null:
			pending.append(song)
	for album in career.albums:
		if not album.is_released() and career.find_active_schedule(album.id) == null:
			pending.append(album)
	return pending


func release_cost(content: ReleasableContent) -> int:
	if content is AlbumData:
		return _balance.find_album_format(content.format_id).release_cost
	return _balance.song_release_cost


func content_type_label(content: ReleasableContent) -> String:
	if content is AlbumData:
		return _balance.find_album_format(content.format_id).display_name
	return "Single"


func release(career: CareerData, content_id: String) -> ActionResult:
	var content := career.find_content(content_id)
	var error := release_error(career, content)
	if not error.is_empty():
		return ActionResult.failure(error)
	var cost := release_cost(content)
	if not _economy.can_afford(career, cost):
		return _economy.insufficient_funds(cost)

	_economy.spend(career, cost, "Lançamento: %s" % content.title, FinanceEntry.CATEGORY_RELEASE)
	var reputation := _publish(career, content)
	var message := "\"%s\" lançado! Reputação %s." % [content.title, Fmt.signed_number(reputation)]
	return ActionResult.success(message, career.find_release(content.id))


## O custo do lançamento é pago ao agendar, para o lançamento nunca falhar na semana marcada.
func schedule(career: CareerData, content_id: String, week: int) -> ActionResult:
	var content := career.find_content(content_id)
	var error := release_error(career, content)
	if error.is_empty():
		error = _week_error(career, week)
	if not error.is_empty():
		return ActionResult.failure(error)
	var cost := release_cost(content)
	if not _economy.can_afford(career, cost):
		return _economy.insufficient_funds(cost)

	_economy.spend(career, cost, "Agendamento: %s" % content.title, FinanceEntry.CATEGORY_RELEASE)
	var entry := ScheduledRelease.new()
	entry.content_id = content.id
	entry.scheduled_week = week
	entry.paid_cost = cost
	career.scheduled_releases.append(entry)
	return ActionResult.success("\"%s\" agendado para a semana %s." % [content.title, Fmt.number(week)], entry)


func reschedule(career: CareerData, content_id: String, week: int) -> ActionResult:
	var entry := career.find_active_schedule(content_id)
	if entry == null:
		return ActionResult.failure("Este lançamento não está agendado.")
	var error := _week_error(career, week)
	if not error.is_empty():
		return ActionResult.failure(error)
	entry.scheduled_week = week
	var title := career.find_content(content_id).title
	return ActionResult.success("\"%s\" remarcado para a semana %s." % [title, Fmt.number(week)], entry)


func cancel_schedule(career: CareerData, content_id: String) -> ActionResult:
	var entry := career.find_active_schedule(content_id)
	if entry == null:
		return ActionResult.failure("Este lançamento não está agendado.")
	_cancel_and_refund(career, entry)
	var title := career.find_content(content_id).title
	return ActionResult.success("Agendamento de \"%s\" cancelado. %s devolvidos." % [title, Fmt.money(entry.paid_cost)], entry)


## Etapa da semana: publica o que estava marcado para a semana atual ou antes dela.
## Roda depois de process_week, para o lançamento render a partir da semana seguinte,
## como acontece em um lançamento imediato.
func publish_due(career: CareerData, report: WeekReport) -> void:
	for entry in career.scheduled_releases:
		if not entry.is_active() or entry.scheduled_week > career.current_week:
			continue
		var content := career.find_content(entry.content_id)
		entry.status = ScheduledRelease.STATUS_RELEASED
		var reputation := _publish(career, content, report)
		var line := WeekReportEntry.new()
		line.title = content.title
		line.cover_file = content.cover_file
		line.note = "%s lançado como agendado. Reputação %s." % [content_type_label(content), Fmt.signed_number(reputation)]
		report.entries.append(line)


## Calcula o resultado de cada lançamento ativo e o registra no relatório.
func process_week(career: CareerData, report: WeekReport) -> void:
	for release_entry in career.releases:
		var content := career.find_content(release_entry.content_id)
		var is_album := release_entry.content_type == ReleaseData.TYPE_ALBUM
		var rules := _balance.album_performance if is_album else _balance.song_performance
		var age_weeks := maxi(_time.weeks_since(career, release_entry.release_week) - 1, 0)
		var units_multiplier := 1.0
		var fame_multiplier := 1.0
		if is_album:
			var album_format := _balance.find_album_format(content.format_id)
			units_multiplier = album_format.units_multiplier
			fame_multiplier = album_format.fame_multiplier
		var result := _performance.calculate_week(rules, content.quality, age_weeks, career.fame, units_multiplier, fame_multiplier)

		var entry := WeekReportEntry.new()
		entry.title = content.title
		entry.cover_file = content.cover_file
		entry.money = result.money
		entry.fame = result.fame
		if is_album:
			entry.sales = result.units
			release_entry.total_sales += result.units
			var description := "Vendas de %s: %s" % [content_type_label(content), content.title]
			_economy.earn(career, result.money, description, FinanceEntry.CATEGORY_SALES)
		else:
			entry.streams = result.units
			release_entry.total_streams += result.units
			_economy.earn(career, result.money, "Streams: %s" % content.title, FinanceEntry.CATEGORY_STREAMS)
		_economy.add_fame(career, result.fame)
		release_entry.total_money += result.money
		release_entry.total_fame += result.fame
		report.entries.append(entry)


## Devolve a mensagem de erro, ou um texto vazio se o conteúdo puder ser lançado ou agendado.
func release_error(career: CareerData, content: ReleasableContent) -> String:
	if content == null:
		return "Conteúdo não encontrado."
	if content.is_released():
		return "\"%s\" já foi lançado." % content.title
	if career.find_active_schedule(content.id) != null:
		return "\"%s\" já está agendado. Cancele ou remarque na agenda." % content.title
	if content is AlbumData:
		var album_format := _balance.find_album_format(content.format_id)
		if not album_format.accepts_song_count(content.song_ids.size()):
			return "%s precisa ter de %d a %d músicas para ser lançado." % [album_format.display_name, album_format.min_songs, album_format.max_songs]
	return ""


func _week_error(career: CareerData, week: int) -> String:
	var last_week := career.current_week + _balance.max_schedule_weeks_ahead
	if week <= career.current_week or week > last_week:
		return "Escolha uma semana entre %s e %s." % [Fmt.number(career.current_week + 1), Fmt.number(last_week)]
	return ""


func _publish(career: CareerData, content: ReleasableContent, report: WeekReport = null) -> int:
	content.mark_released(career.current_week)
	if content is AlbumData:
		_release_tracks(career, content, report)

	var release_entry := ReleaseData.new()
	release_entry.content_type = ReleaseData.TYPE_ALBUM if content is AlbumData else ReleaseData.TYPE_SONG
	release_entry.content_id = content.id
	release_entry.release_week = career.current_week
	career.releases.append(release_entry)

	var multiplier := 1.0
	if content is AlbumData:
		multiplier = _balance.find_album_format(content.format_id).reputation_multiplier
	var reputation := _performance.reputation_change(content.quality, multiplier)
	_economy.add_reputation(career, reputation)
	return reputation


## Faixas inéditas saem junto com o projeto e rendem como parte dele, sem streams próprios.
## Um single agendado de uma dessas faixas é cancelado e reembolsado.
func _release_tracks(career: CareerData, album: AlbumData, report: WeekReport) -> void:
	for song_id in album.song_ids:
		var song := career.find_song(song_id)
		if song.is_released():
			continue
		song.mark_released(career.current_week)
		var entry := career.find_active_schedule(song_id)
		if entry == null:
			continue
		_cancel_and_refund(career, entry)
		if report != null:
			var line := WeekReportEntry.new()
			line.title = song.title
			line.cover_file = song.cover_file
			line.money = entry.paid_cost
			line.note = "Single cancelado: a faixa saiu com \"%s\". Custo devolvido." % album.title
			report.entries.append(line)


func _cancel_and_refund(career: CareerData, entry: ScheduledRelease) -> void:
	entry.status = ScheduledRelease.STATUS_CANCELLED
	var title := career.find_content(entry.content_id).title
	_economy.earn(career, entry.paid_cost, "Reembolso de agendamento: %s" % title, FinanceEntry.CATEGORY_RELEASE)
