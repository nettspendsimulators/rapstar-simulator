class_name ProgressionSystem
extends RefCounted
## Leitura da carreira para o jogador: fase atual (desconhecido → estrela), progresso até a
## próxima fase, agenda, próximos passos e o balanço de cada semana. Não altera o jogo:
## só organiza o que os outros sistemas já produzem.

var _balance: GameBalance
var _streaming: StreamingSystem
var _live: LiveSystem


func _init(balance: GameBalance, streaming: StreamingSystem, live: LiveSystem) -> void:
	_balance = balance
	_streaming = streaming
	_live = live


func stages() -> Array[CareerStageDefinition]:
	return _balance.career_stages


func stage_index(fame: int) -> int:
	var index := 0
	for i in stages().size():
		if fame >= stages()[i].min_fame:
			index = i
	return index


func stage_for(fame: int) -> CareerStageDefinition:
	return stages()[stage_index(fame)]


func next_stage(fame: int) -> CareerStageDefinition:
	var index := stage_index(fame) + 1
	return stages()[index] if index < stages().size() else null


## De 0 a 1 entre a fase atual e a próxima. Na última fase, 1.
func stage_progress(fame: int) -> float:
	var current := stage_for(fame)
	var following := next_stage(fame)
	if following == null:
		return 1.0
	return clampf(float(fame - current.min_fame) / maxf(following.min_fame - current.min_fame, 1.0), 0.0, 1.0)


## Valores usados para o balanço da semana.
func snapshot(career: CareerData) -> Dictionary:
	return {
		"money": career.money, "fame": career.fame, "fans": _streaming.total_followers(career),
		"plays": _streaming.total_plays(career),
	}


## Fecha o relatório com o que mudou na semana e avisa quando o artista sobe de fase.
func finish_week(career: CareerData, report: WeekReport, before: Dictionary) -> void:
	var after := snapshot(career)
	report.money_change = after["money"] - before["money"]
	report.fame_change = after["fame"] - before["fame"]
	report.fans_change = after["fans"] - before["fans"]
	report.plays = maxi(after["plays"] - before["plays"], 0)
	var old_stage := stage_index(before["fame"])
	var new_stage := stage_index(after["fame"])
	if new_stage != old_stage:
		var stage := stages()[new_stage]
		report.stage_reached = stage.id if new_stage > old_stage else ""
		var line := WeekReportEntry.new()
		line.title = ("Nova fase da carreira: %s" if new_stage > old_stage else "Sua fase caiu para %s") % stage.display_name
		line.note = stage.description
		report.entries.push_front(line)


## Compromissos e acontecimentos dos próximos tempos, em ordem de semana.
## Cada item: {"week", "kind", "text"}.
func agenda(career: CareerData) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for scheduled in career.scheduled_releases:
		if scheduled.is_active():
			var content := career.find_content(scheduled.content_id)
			if content != null:
				items.append({"week": scheduled.scheduled_week, "kind": "release", "text": "Lançamento de \"%s\"" % content.title})
	for show in _live.shows_with_status(career, LiveShow.STATUS_SCHEDULED):
		var label := show.event_name if not show.event_name.is_empty() else show.venue_name
		if show.kind == LiveShow.KIND_TOUR:
			var tour := career.find_tour(show.tour_id)
			label = "%s — %s" % [tour.name if tour != null else "Turnê", show.venue_name]
		items.append({"week": show.week(), "kind": "show", "text": "Show: %s" % label})
	for tour in career.live_tours:
		if tour.is_open():
			items.append({"week": career.current_week, "kind": "tour", "text": "Turnê \"%s\" em planejamento: confirme para marcar as datas" % tour.name})
	for video in career.music_videos:
		if video.status == MusicVideo.STATUS_PRODUCTION:
			var song := career.find_song(video.song_id)
			items.append({"week": video.ready_week, "kind": "video", "text": "Clipe de \"%s\" fica pronto" % (song.title if song != null else "?")})
	for campaign in career.marketing_campaigns:
		if campaign.is_active():
			var content := career.find_content(campaign.content_id)
			if content != null:
				items.append({"week": career.current_week, "kind": "marketing", "text": "Campanha ativa: \"%s\" (expectativa %d)" % [content.title, campaign.hype]})
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["week"] < b["week"])
	return items


## Sugestões do que fazer agora, a partir do estado da carreira. No máximo três.
func next_steps(career: CareerData) -> PackedStringArray:
	var texts := PackedStringArray()
	for item in actions(career):
		texts.append(item["text"])
	return texts


## As mesmas sugestões, com a área do jogo que resolve cada uma (action):
## "new_song", "releases", "offers", "marketing", "merch", "work" ou "" (só informação).
func actions(career: CareerData) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	var unreleased := career.songs.filter(func(song: SongData) -> bool: return not song.is_released())
	var scheduled := career.scheduled_releases.filter(func(item: ScheduledRelease) -> bool: return item.is_active())
	var offers := _live.shows_with_status(career, LiveShow.STATUS_OFFER).size()
	if career.songs.is_empty():
		steps.append({"text": "Grave sua primeira música em Músicas → Nova música.", "action": "new_song", "label": "Gravar música"})
	elif career.money < 200:
		steps.append({"text": "O dinheiro está curto: trabalhe uma semana para pagar as próximas produções.", "action": "work", "label": "Trabalhar"})
	if not unreleased.is_empty() and scheduled.is_empty():
		steps.append({"text": "Você tem %d música(s) inédita(s). Melhore com energia e lance em Lançamentos." % unreleased.size(), "action": "releases", "label": "Lançar música"})
	if offers > 0:
		steps.append({"text": "%d proposta(s) de show esperando resposta em Shows e ofertas." % offers, "action": "offers", "label": "Ver propostas"})
	if not career.releases.is_empty() and career.marketing_campaigns.is_empty():
		steps.append({"text": "Monte uma campanha de marketing antes do próximo lançamento para alcançar mais gente.", "action": "marketing", "label": "Criar campanha"})
	if career.merch_items.is_empty() and career.fame >= 150:
		steps.append({"text": "Seus fãs já compram produtos: fabrique merch para vender nos shows e na loja.", "action": "merch", "label": "Fazer merch"})
	if steps.is_empty():
		steps.append({"text": "Grave uma nova música para manter o público ouvindo.", "action": "new_song", "label": "Gravar música"})
	var following := next_stage(career.fame)
	if following != null:
		steps.append({"text": "Faltam %s de fama para virar %s." % [Fmt.number(following.min_fame - career.fame), following.display_name], "action": "", "label": ""})
	return steps.slice(0, 3)
