class_name BeefSystem
extends RefCounted
## Beefs: provocações, diss tracks (músicas normais com um alvo), respostas, escalada, aliados
## tomando partido e encerramento. Toda mudança de relação passa pelo SocialSystem.

var _balance: GameBalance
var _economy: EconomySystem
var _social: SocialSystem
var _streaming: StreamingSystem
var _rng: RandomNumberGenerator


func _init(balance: GameBalance, economy: EconomySystem, social: SocialSystem, streaming: StreamingSystem, rng: RandomNumberGenerator) -> void:
	_balance = balance
	_economy = economy
	_social = social
	_streaming = streaming
	_rng = rng


func _rules() -> SocialRules:
	return _balance.social


## Artistas que podem ser alvo de uma diss: os que o jogador já conhece.
func diss_targets(career: CareerData) -> Array[String]:
	var result: Array[String] = []
	for artist_id in career.social.relations:
		if career.social.relations[artist_id].met and _social.person(artist_id) != null:
			result.append(artist_id)
	return result


func beef_with(career: CareerData, artist_id: String) -> Beef:
	return career.social.active_beef_with(artist_id)


# ---- ações do jogador

func player_action(career: CareerData, artist_id: String, definition: SocialInteractionDefinition) -> ActionResult:
	var name := _social.display_name(artist_id)
	match definition.kind:
		"provoke":
			_social.change(career, artist_id, definition.delta, "Você provocou %s em público." % name)
			var beef := _escalate(career, artist_id, "player", "provoke", "Você provocou %s." % name)
			_take_sides(career, artist_id, 1, null)
			return ActionResult.success("Você provocou %s. O clima esquentou (%s)." % [name, beef.intensity_label().to_lower()])
		"respond":
			_social.change(career, artist_id, definition.delta, "Você respondeu à provocação de %s." % name)
			_escalate(career, artist_id, "player", "response", "Você respondeu %s nas redes." % name)
			return ActionResult.success("Você respondeu %s. A bola está com ele." % name)
		"reconcile":
			return propose_end(career, artist_id)
	return ActionResult.failure("Ação inválida.")


## Ignorar a vez do jogador num beef: o conflito perde força.
func ignore(career: CareerData, artist_id: String) -> ActionResult:
	var beef := beef_with(career, artist_id)
	if beef == null or beef.awaiting != Beef.TURN_PLAYER:
		return ActionResult.failure("Não há provocação para ignorar.")
	_economy.add_reputation(career, 1)
	beef.awaiting = ""
	cool_down(career, beef, "Você ignorou a provocação.")
	return ActionResult.success("Você ignorou %s. O beef perdeu força." % _social.display_name(artist_id))


## Tentar encerrar: depende do perdão do artista, da intensidade e da relação.
func propose_end(career: CareerData, artist_id: String) -> ActionResult:
	var beef := beef_with(career, artist_id)
	var name := _social.display_name(artist_id)
	if beef == null:
		return ActionResult.failure("Não há beef com %s." % name)
	var traits := _social.personality(artist_id)
	var chance: float = clampf(0.25 + traits["forgiveness"] * 0.6 - (beef.intensity - 1) * 0.12, 0.08, 0.9)
	if _rng.randf() > chance:
		_log(beef, career, "player", "peace_refused", "Você propôs encerrar e %s recusou." % name)
		_social.relation(career, artist_id).add_history(career.current_week, "Você propôs encerrar o beef; %s recusou." % name)
		return ActionResult.success("%s recusou encerrar o beef por enquanto." % name)
	end_beef(career, beef, "Você e %s encerraram o beef publicamente." % name)
	return ActionResult.success("Beef com %s encerrado. A confiança vai precisar ser reconstruída." % name)


# ---- diss track

## Lançamento de uma diss: repercussão pela nota, queda na relação, escalada do beef,
## aliados tomando partido e a vez do alvo responder.
func on_diss_released(career: CareerData, song: SongData, report: WeekReport) -> void:
	var artist_id := song.diss_target_id
	var name := _social.display_name(artist_id)
	var r := _rules()
	var reception: float = clampf((song.quality - 55) / 35.0 + _rng.randf_range(-0.15, 0.15), -1.0, 1.0)
	var size := _social.size_of(artist_id)
	var friend_hit := _social.peek(career, artist_id) != null and _social.peek(career, artist_id).value >= 30
	_social.change(career, artist_id, -r.diss_relation_hit, "Você lançou a diss \"%s\" contra %s." % [song.title, name])
	var beef := _escalate(career, artist_id, "player", "diss", "Você lançou a diss \"%s\"." % song.title, song.id)
	song.beef_id = beef.id
	var line := WeekReportEntry.new()
	line.title = "Diss: \"%s\" contra %s" % [song.title, name]
	if reception > 0.0:
		var fame := roundi((r.diss_fame_base + size / 1000.0 * r.diss_fame_per_size) * reception * (1.0 + beef.intensity * 0.25))
		_economy.add_fame(career, fame)
		_streaming.add_followers(career, fame * r.diss_followers_per_fame)
		line.fame = fame
		line.note = "A diss foi bem recebida e todo mundo está falando disso. %s precisa responder." % name
	else:
		var lost := roundi(-reception * r.bad_diss_followers * 10)
		_streaming.remove_followers(career, lost)
		_economy.add_reputation(career, -2)
		_economy.add_fame(career, 1)
		line.note = "A diss foi mal recebida: %s seguidores a menos e a reputação caiu." % Fmt.number(lost)
	if friend_hit:
		_economy.add_reputation(career, -1)
		line.note += " Atacar um amigo pegou mal."
	report.entries.append(line)
	_take_sides(career, artist_id, beef.intensity, report)


# ---- vez do artista

func process_week(career: CareerData, report: WeekReport) -> void:
	for beef in career.social.beefs:
		if not beef.is_active():
			continue
		if beef.awaiting == Beef.TURN_ARTIST and career.current_week >= beef.response_week:
			_artist_turn(career, beef, report)
		elif beef.awaiting == Beef.TURN_PLAYER and career.current_week - beef.last_week >= _rules().cooldown_weeks:
			cool_down(career, beef, "Sem resposta, o beef esfriou.", report)
	_rival_provocations(career, report)
	_npc_drama(career, report)


## O artista decide entre ignorar, responder nas redes, lançar uma diss ou propor paz,
## pela personalidade, pela relação, pelo tamanho dele e pela intensidade.
func _artist_turn(career: CareerData, beef: Beef, report: WeekReport) -> void:
	var artist_id := beef.artist_id
	var name := _social.display_name(artist_id)
	var traits := _social.personality(artist_id)
	var current := _social.relation(career, artist_id)
	var size_gap: float = clampf(float(_social.size_of(artist_id)) / maxf(_social.star_limit(career), 1.0), 0.0, 4.0)
	var fight: float = traits["temper"] * 0.6 + beef.intensity * 0.12 - traits["forgiveness"] * 0.25 + (0.15 if current.value <= -55 else 0.0)
	# Estrelas muito maiores costumam ignorar provocações de artistas pequenos.
	var ignore_chance: float = clampf(0.15 + (size_gap - 1.0) * 0.2, 0.05, 0.7)
	var roll := _rng.randf()
	if roll < ignore_chance:
		_log(beef, career, "artist", "ignore", "%s ignorou." % name)
		_note(report, "Beef com %s" % name, "%s ignorou você. Sem resposta, o assunto morre aos poucos." % name)
		beef.awaiting = ""
		cool_down(career, beef, "%s ignorou." % name)
		return
	if roll < ignore_chance + clampf(0.35 - fight * 0.3, 0.05, 0.4):
		_social.add_invite(career, artist_id, SocialInvite.KIND_PEACE)
		_log(beef, career, "artist", "peace", "%s propôs encerrar o beef." % name)
		_note(report, "Beef com %s" % name, "%s quer encerrar o conflito. Responda em Relações." % name)
		beef.awaiting = Beef.TURN_PLAYER
		beef.last_week = career.current_week
		return
	if fight > 0.45 or beef.intensity >= 2:
		var hit := 15 + beef.intensity * 4
		_social.change(career, artist_id, -8, "%s lançou uma diss contra você." % name)
		_escalate(career, artist_id, "artist", "diss", "%s lançou uma diss contra você." % name)
		_streaming.remove_followers(career, hit * 20)
		_economy.add_fame(career, 2 + beef.intensity)
		_note(report, "Beef com %s" % name, "%s lançou uma diss respondendo você. Sua vez: responda com outra diss, ignore ou tente encerrar." % name)
		_take_sides(career, artist_id, beef.intensity, report, true)
	else:
		_social.change(career, artist_id, -5, "%s respondeu nas redes." % name)
		_escalate(career, artist_id, "artist", "response", "%s respondeu nas redes." % name)
		_economy.add_fame(career, 1)
		_note(report, "Beef com %s" % name, "%s respondeu nas redes. Você pode rebater, ignorar ou tentar encerrar." % name)


func _rival_provocations(career: CareerData, report: WeekReport) -> void:
	for artist_id in career.social.relations.keys():
		var current := career.social.relations[artist_id]
		if not current.met or current.value > -55 or beef_with(career, artist_id) != null:
			continue
		if _rng.randf() < _rules().rival_provoke_chance:
			var name := _social.display_name(artist_id)
			_social.change(career, artist_id, -4, "%s provocou você." % name)
			_escalate(career, artist_id, "artist", "provoke", "%s provocou você." % name)
			_note(report, "Provocação de %s" % name, "%s soltou uma indireta para você. Responda, ignore ou proponha encerrar em Relações." % name)


## Tensão espontânea entre dois artistas que o jogador conhece; aliados mudam com isso.
func _npc_drama(career: CareerData, report: WeekReport) -> void:
	if _rng.randf() > _rules().npc_drama_chance:
		return
	var known := diss_targets(career)
	if known.size() < 2:
		return
	var a: String = known[_rng.randi() % known.size()]
	var b: String = known[_rng.randi() % known.size()]
	if a == b or _social.npc_relation(career, a, b) <= -35:
		return
	_social.set_npc_relation(career, a, b, -40)
	_note(report, "Clima na cena", "%s e %s trocaram indiretas. Quem for amigo de um pode se afastar do outro." % [_social.display_name(a), _social.display_name(b)])


# ---- regras internas

func _escalate(career: CareerData, artist_id: String, actor: String, kind: String, text: String, song_id: String = "") -> Beef:
	var beef := beef_with(career, artist_id)
	if beef == null:
		beef = Beef.new()
		beef.id = career.new_id("beef")
		beef.artist_id = artist_id
		beef.intensity = 1
		beef.started_week = career.current_week
		career.social.beefs.append(beef)
	elif kind == "diss" or (kind == "response" and beef.intensity < 2):
		beef.intensity = mini(beef.intensity + 1, 4)
	_log(beef, career, actor, kind, text, song_id)
	beef.last_week = career.current_week
	if actor == "player":
		beef.awaiting = Beef.TURN_ARTIST
		beef.response_week = career.current_week + 1
	else:
		beef.awaiting = Beef.TURN_PLAYER
	_sync_relation_floor(career, beef)
	return beef


## A relação acompanha a intensidade do beef (rivalidade não convive com amizade).
func _sync_relation_floor(career: CareerData, beef: Beef) -> void:
	var ceiling: int = [-1, -15, -35, -55, -75][clampi(beef.intensity, 0, 4)]
	var current := _social.relation(career, beef.artist_id)
	if current.value > ceiling:
		current.value = ceiling


func cool_down(career: CareerData, beef: Beef, text: String, report: WeekReport = null) -> void:
	beef.intensity -= 1
	_log(beef, career, "", "cool", text)
	beef.last_week = career.current_week
	if beef.intensity <= 0:
		end_beef(career, beef, "O beef com %s acabou." % _social.display_name(beef.artist_id), report)


## Encerra o beef. A relação volta a neutro (nunca restaura uma amizade antiga).
func end_beef(career: CareerData, beef: Beef, text: String, report: WeekReport = null) -> void:
	beef.status = Beef.STATUS_ENDED
	beef.awaiting = ""
	_log(beef, career, "", "end", text)
	var current := _social.relation(career, beef.artist_id)
	current.value = maxi(current.value, -5)
	current.add_history(career.current_week, text)
	career.social.invites = career.social.invites.filter(func(invite: SocialInvite) -> bool:
		return not (invite.artist_id == beef.artist_id and invite.kind == SocialInvite.KIND_PEACE))
	if report != null:
		_note(report, "Beef encerrado", text)


## Aliados reagem: amigos do alvo se afastam do jogador (e podem criticar); amigos do jogador
## que não são próximos do alvo saem em defesa. Quanto maior a intensidade, maior o efeito.
func _take_sides(career: CareerData, artist_id: String, intensity: int, report: WeekReport, artist_attacked_player: bool = false) -> void:
	var critics := PackedStringArray()
	var defenders := PackedStringArray()
	for ally in _social.friends_of(career, artist_id):
		var current := _social.peek(career, ally)
		if current == null or not current.met:
			continue
		if current.value >= 50 and not artist_attacked_player:
			continue
		_social.change(career, ally, -(3 + intensity * 2), "%s ficou do lado de %s no beef." % [_social.display_name(ally), _social.display_name(artist_id)])
		critics.append(_social.display_name(ally))
	for friend_id in career.social.relations.keys():
		var current := career.social.relations[friend_id]
		if friend_id == artist_id or not current.met or current.value < 30:
			continue
		if _social.npc_relation(career, friend_id, artist_id) >= 30:
			continue
		_social.set_npc_relation(career, friend_id, artist_id, _social.npc_relation(career, friend_id, artist_id) - 10 * intensity)
		_social.change(career, friend_id, 2, "%s defendeu você no beef com %s." % [_social.display_name(friend_id), _social.display_name(artist_id)])
		defenders.append(_social.display_name(friend_id))
	if report == null:
		return
	if not critics.is_empty():
		_note(report, "Aliados de %s" % _social.display_name(artist_id), "Ficaram do lado dele: %s." % ", ".join(critics.slice(0, 4)))
	if not defenders.is_empty():
		_note(report, "Seus aliados", "Defenderam você: %s." % ", ".join(defenders.slice(0, 4)))


func _log(beef: Beef, career: CareerData, actor: String, kind: String, text: String, song_id: String = "") -> void:
	beef.events.append({"week": career.current_week, "actor": actor, "kind": kind, "text": text, "song_id": song_id})


func _note(report: WeekReport, title: String, text: String) -> void:
	if report == null:
		return
	var line := WeekReportEntry.new()
	line.title = title
	line.note = text
	report.entries.append(line)
