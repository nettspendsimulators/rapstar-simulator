class_name SocialSystem
extends RefCounted
## Relações do jogador com os artistas do catálogo (data/collaborators.tres) e dos artistas entre si.
## Único lugar que altera relações, calcula status, preço de feats/participações e convites.
## Beefs e diss tracks ficam no BeefSystem, que usa estas regras.

var _balance: GameBalance
var _economy: EconomySystem
var _rng: RandomNumberGenerator
var streaming: StreamingSystem
var live: LiveSystem
var beefs: BeefSystem


func _init(balance: GameBalance, economy: EconomySystem, rng: RandomNumberGenerator) -> void:
	_balance = balance
	_economy = economy
	_rng = rng


func rules() -> SocialRules:
	return _balance.social


# ---- artistas

## Artistas com quem o jogador se relaciona: as participações (feats) do catálogo.
func artists() -> Array[CollaboratorDefinition]:
	return _balance.collaborators.feats


func person(artist_id: String) -> CollaboratorDefinition:
	var catalog := _balance.collaborators
	for pool in [catalog.feats, catalog.producers, catalog.beatmakers]:
		for item: CollaboratorDefinition in pool:
			if String(item.id) == artist_id:
				return item
	return null


func display_name(artist_id: String) -> String:
	var found := person(artist_id)
	return found.display_name if found != null else "?"


## Personalidade mínima, estável para cada artista: facilidade para amizade, pavio curto e perdão.
func personality(artist_id: String) -> Dictionary:
	var seed_value := absi(hash(artist_id + "|personalidade"))
	return {
		"friendliness": float(seed_value % 100) / 100.0,
		"temper": float((seed_value / 100) % 100) / 100.0,
		"forgiveness": float((seed_value / 10000) % 100) / 100.0,
	}


func personality_text(artist_id: String) -> String:
	var traits := personality(artist_id)
	var parts := PackedStringArray()
	parts.append("receptivo" if traits["friendliness"] > 0.6 else ("reservado" if traits["friendliness"] < 0.35 else "tranquilo"))
	parts.append("pavio curto" if traits["temper"] > 0.65 else ("difícil de provocar" if traits["temper"] < 0.3 else "responde quando provocado"))
	parts.append("perdoa fácil" if traits["forgiveness"] > 0.6 else ("guarda rancor" if traits["forgiveness"] < 0.3 else ""))
	var kept := PackedStringArray()
	for part in parts:
		if not part.is_empty():
			kept.append(part)
	return ", ".join(kept)


## Tamanho do artista na indústria, pelo cachê de feat do catálogo.
func size_of(artist_id: String) -> int:
	var found := person(artist_id)
	return found.cost if found != null else 0


## Até que cachê um artista é "do seu nível": acima disso, não faz grandes favores.
func star_limit(career: CareerData) -> int:
	return rules().star_cost_base + career.fame * rules().star_cost_per_fame


# ---- relação

func relation(career: CareerData, artist_id: String) -> Relationship:
	if not career.social.relations.has(artist_id):
		var created := Relationship.new()
		created.artist_id = artist_id
		career.social.relations[artist_id] = created
	return career.social.relations[artist_id]


func peek(career: CareerData, artist_id: String) -> Relationship:
	return career.social.relations.get(artist_id)


## Status {"id", "label"} de uma relação.
func status_of(relation_value: int, met: bool) -> Dictionary:
	if not met:
		return {"id": "unknown", "label": "Desconhecido"}
	if relation_value >= 0:
		var found: Dictionary = SocialRules.POSITIVE[0]
		for item: Dictionary in SocialRules.POSITIVE:
			if relation_value >= item["min"]:
				found = item
		return found
	var negative: Dictionary = SocialRules.NEGATIVE[0]
	for item: Dictionary in SocialRules.NEGATIVE:
		if relation_value <= item["max"]:
			negative = item
	return negative


func status(career: CareerData, artist_id: String) -> Dictionary:
	var current := peek(career, artist_id)
	return status_of(current.value, current.met) if current != null else status_of(0, false)


func is_hostile(career: CareerData, artist_id: String) -> bool:
	var current := peek(career, artist_id)
	return current != null and current.value <= -35


## Muda a relação. Ganhos positivos têm teto por semana (a confiança cresce aos poucos);
## perdas não. Registra no histórico e avisa quando o status muda.
func change(career: CareerData, artist_id: String, delta: int, text: String = "", report: WeekReport = null) -> int:
	var current := relation(career, artist_id)
	var before := status_of(current.value, current.met)
	var applied := delta
	if delta > 0:
		if current.gain_week != career.current_week:
			current.gain_week = career.current_week
			current.week_gain = 0
		applied = mini(delta, maxi(rules().weekly_gain_cap - current.week_gain, 0))
		current.week_gain += applied
	current.value = clampi(current.value + applied, -100, 100)
	if not current.met:
		current.met = true
		current.add_history(career.current_week, "Você conheceu %s." % display_name(artist_id))
	if not text.is_empty():
		current.add_history(career.current_week, text)
	var after := status_of(current.value, current.met)
	if after["id"] != before["id"] and before["id"] != "unknown":
		var line := _status_change_text(artist_id, before, after)
		current.add_history(career.current_week, line)
		if report != null:
			_note(report, "Relações: %s" % display_name(artist_id), line)
	return applied


func _status_change_text(artist_id: String, before: Dictionary, after: Dictionary) -> String:
	var name := display_name(artist_id)
	var order := ["great_rival", "rival", "enmity", "tension", "neutral", "known", "colleague", "friend", "close", "great", "best"]
	var improved := order.find(after["id"]) > order.find(before["id"])
	if improved:
		return "Vocês agora são: %s (%s)." % [after["label"].to_lower(), name]
	return "A relação com %s piorou: %s." % [name, after["label"].to_lower()]


# ---- preço e disposição para trabalhar junto

## Por que o artista recusa trabalhar com o jogador, ou texto vazio.
func refusal(career: CareerData, artist_id: String) -> String:
	if is_hostile(career, artist_id):
		return "%s não quer trabalhar com você (%s)." % [display_name(artist_id), status(career, artist_id)["label"].to_lower()]
	var beef := career.social.active_beef_with(artist_id)
	if beef != null:
		return "%s está em beef com você e recusa a parceria." % display_name(artist_id)
	return ""


## Fator sobre o cachê do catálogo: amizade dá desconto, tensão encarece. Melhor amigo do seu
## nível faz de graça de tempos em tempos; estrelas muito maiores que você limitam o desconto.
func price_multiplier(career: CareerData, artist_id: String) -> float:
	var current := peek(career, artist_id)
	if current == null or not current.met:
		return 1.0
	var state: Dictionary = status_of(current.value, current.met)
	if state["id"] == "tension" or state["id"] == "neutral":
		return 1.0 + (rules().tension_surcharge if state["id"] == "tension" else 0.0)
	var discount: float = rules().discounts.get(state["id"], 0.0)
	var is_star := size_of(artist_id) > star_limit(career)
	if is_star:
		discount = minf(discount, rules().star_discount_cap)
	elif free_feat_available(career, artist_id):
		discount = 1.0
	return 1.0 - discount


func free_feat_available(career: CareerData, artist_id: String) -> bool:
	var current := peek(career, artist_id)
	if current == null or status_of(current.value, current.met)["id"] != "best":
		return false
	if size_of(artist_id) > star_limit(career):
		return false
	return career.current_week - current.last_free_feat_week >= rules().free_feat_cooldown


## Cachê de feat cobrado do jogador: o do catálogo com o fator da relação.
func feat_price(career: CareerData, collaborator: CollaboratorDefinition) -> int:
	if career == null:
		return collaborator.cost
	return roundi(collaborator.cost * price_multiplier(career, String(collaborator.id)))


func price_text(career: CareerData, artist_id: String) -> String:
	var found := person(artist_id)
	if found == null:
		return ""
	var reason := refusal(career, artist_id)
	if not reason.is_empty():
		return "Não aceita feat"
	var price := feat_price(career, found)
	if price == 0:
		return "Feat grátis (amizade)"
	if price < found.cost:
		return "%s (era %s)" % [Fmt.money(price), Fmt.money(found.cost)]
	if price > found.cost:
		return "%s (tensão encarece)" % Fmt.money(price)
	return Fmt.money(price)


## Chamado quando uma música contrata participações: aproxima e registra.
func record_feats(career: CareerData, artist_ids: Array[String], song_title: String) -> void:
	for artist_id in artist_ids:
		var current := relation(career, artist_id)
		var was_free := free_feat_available(career, artist_id)
		current.feats += 1
		if was_free:
			current.last_free_feat_week = career.current_week
			change(career, artist_id, 5, "%s fez um feat de graça em \"%s\"." % [display_name(artist_id), song_title])
		else:
			change(career, artist_id, 5, "%s participou de \"%s\"." % [display_name(artist_id), song_title])


# ---- interações

## Ações com o artista: [{"definition", "available", "reason"}], só as que fazem sentido agora.
func interactions(career: CareerData, artist_id: String) -> Array[Dictionary]:
	var current := peek(career, artist_id)
	var met := current != null and current.met
	var value := current.value if current != null else 0
	var beef := career.social.active_beef_with(artist_id)
	var result: Array[Dictionary] = []
	for definition in rules().interactions:
		if definition.kind == "meet":
			if met:
				continue
		elif not met:
			continue
		if definition.kind == "respond" and (beef == null or beef.awaiting != Beef.TURN_PLAYER):
			continue
		if definition.kind == "reconcile" and beef == null:
			continue
		if definition.kind == "defend" and rivals_of(career, artist_id).is_empty():
			continue
		if definition.kind in ["positive", "defend", "apology"] and (value < definition.min_value or value > definition.max_value):
			continue
		var reason := _blocked_reason(career, artist_id, definition)
		result.append({"definition": definition, "available": reason.is_empty(), "reason": reason})
	return result


func _blocked_reason(career: CareerData, artist_id: String, definition: SocialInteractionDefinition) -> String:
	var current := peek(career, artist_id)
	if current != null and int(current.used.get(definition.id, -99)) == career.current_week:
		return "Já feito nesta semana."
	if definition.money_cost > 0 and not _economy.can_afford(career, definition.money_cost):
		return "Custa %s." % Fmt.money(definition.money_cost)
	if definition.energy_cost > 0 and not _economy.can_spend_energy(career, definition.energy_cost):
		return "Precisa de %d de energia." % definition.energy_cost
	return ""


func interact(career: CareerData, artist_id: String, interaction_id: String) -> ActionResult:
	var definition := rules().find_interaction(interaction_id)
	var options := interactions(career, artist_id)
	var option: Dictionary = {}
	for item in options:
		if item["definition"] == definition:
			option = item
	if definition == null or option.is_empty():
		return ActionResult.failure("Essa ação não está disponível com %s agora." % display_name(artist_id))
	if not option["available"]:
		return ActionResult.failure(option["reason"])
	if definition.money_cost > 0:
		_economy.spend(career, definition.money_cost, "%s com %s" % [definition.display_name, display_name(artist_id)], FinanceEntry.CATEGORY_SOCIAL)
	if definition.energy_cost > 0:
		_economy.spend_energy(career, definition.energy_cost)
	relation(career, artist_id).used[definition.id] = career.current_week
	_public_effects(career, definition)
	match definition.kind:
		"meet":
			return _meet(career, artist_id, definition)
		"provoke", "respond", "reconcile":
			return beefs.player_action(career, artist_id, definition)
		"apology":
			return _apologize(career, artist_id, definition)
		"defend":
			return _defend(career, artist_id, definition)
	var traits := personality(artist_id)
	var delta := roundi(definition.delta * (0.7 + 0.6 * traits["friendliness"]))
	# Ações de rotina não entram no histórico; só o que marca a relação (e as mudanças de status).
	var gained := change(career, artist_id, delta)
	if gained <= 0:
		return ActionResult.success("%s com %s. A confiança já cresceu o que podia nesta semana." % [definition.display_name, display_name(artist_id)])
	return ActionResult.success("%s com %s. A relação melhorou." % [definition.display_name, display_name(artist_id)])


func _public_effects(career: CareerData, definition: SocialInteractionDefinition) -> void:
	if definition.fame > 0:
		_economy.add_fame(career, definition.fame)
	if definition.followers > 0 and streaming != null:
		streaming.add_followers(career, definition.followers)


## Artistas bem maiores que o jogador nem sempre dão atenção.
func meet_chance(career: CareerData, artist_id: String) -> float:
	var traits := personality(artist_id)
	var size := size_of(artist_id) / 1000.0
	return clampf((career.fame + 50.0) / (size * 4.0 + 50.0) * (0.6 + 0.8 * traits["friendliness"]), 0.08, 0.95)


func _meet(career: CareerData, artist_id: String, definition: SocialInteractionDefinition) -> ActionResult:
	if _rng.randf() > meet_chance(career, artist_id):
		return ActionResult.success("%s não deu muita atenção. Tente de novo outra semana, ou cresça na cena." % display_name(artist_id))
	change(career, artist_id, definition.delta, "Vocês trocaram uma ideia pela primeira vez.")
	return ActionResult.success("Você conheceu %s." % display_name(artist_id))


func _apologize(career: CareerData, artist_id: String, definition: SocialInteractionDefinition) -> ActionResult:
	var traits := personality(artist_id)
	if _rng.randf() > 0.35 + 0.6 * traits["forgiveness"]:
		change(career, artist_id, 0, "Você pediu desculpas a %s, que não aceitou." % display_name(artist_id))
		return ActionResult.success("%s não aceitou as desculpas. Talvez com o tempo." % display_name(artist_id))
	change(career, artist_id, definition.delta, "Você pediu desculpas a %s." % display_name(artist_id))
	var beef := career.social.active_beef_with(artist_id)
	if beef != null:
		beefs.cool_down(career, beef, "Você pediu desculpas.")
	return ActionResult.success("%s aceitou suas desculpas." % display_name(artist_id))


func _defend(career: CareerData, artist_id: String, definition: SocialInteractionDefinition) -> ActionResult:
	var rival_id: String = rivals_of(career, artist_id)[0]
	change(career, artist_id, definition.delta, "Você defendeu %s publicamente contra %s." % [display_name(artist_id), display_name(rival_id)])
	if relation(career, rival_id).met:
		change(career, rival_id, -8, "Você tomou o lado de %s contra %s." % [display_name(artist_id), display_name(rival_id)])
	return ActionResult.success("Você defendeu %s. %s não gostou." % [display_name(artist_id), display_name(rival_id)])


# ---- relações entre artistas

func _pair_key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]


## Relação entre dois artistas: o que mudou nesta carreira, ou um valor estável do mundo do jogo.
func npc_relation(career: CareerData, a: String, b: String) -> int:
	if a == b:
		return 100
	var key := _pair_key(a, b)
	if career.social.npc_relations.has(key):
		return career.social.npc_relations[key]
	var roll := absi(hash(key + "|cena")) % 100
	if roll < 6:
		return -55
	if roll < 22:
		return 45
	return 0


func set_npc_relation(career: CareerData, a: String, b: String, value: int) -> void:
	career.social.npc_relations[_pair_key(a, b)] = clampi(value, -100, 100)


func friends_of(career: CareerData, artist_id: String) -> Array[String]:
	return _related(career, artist_id, func(value: int) -> bool: return value >= 30)


func rivals_of(career: CareerData, artist_id: String) -> Array[String]:
	return _related(career, artist_id, func(value: int) -> bool: return value <= -35)


func _related(career: CareerData, artist_id: String, test: Callable) -> Array[String]:
	var result: Array[String] = []
	for item in artists():
		var other := String(item.id)
		if other != artist_id and test.call(npc_relation(career, artist_id, other)):
			result.append(other)
	return result


# ---- convites

func pending_invites(career: CareerData) -> Array[SocialInvite]:
	var result: Array[SocialInvite] = []
	for invite in career.social.invites:
		if invite.expires_week >= career.current_week:
			result.append(invite)
	return result


func invite_text(invite: SocialInvite) -> String:
	var name := display_name(invite.artist_id)
	match invite.kind:
		SocialInvite.KIND_FEATURE:
			return "%s: \"Estou fechando meu próximo projeto. Quer participar de uma faixa?\" (cachê %s)" % [name, Fmt.money(invite.fee)]
		SocialInvite.KIND_PROMOTE:
			return "%s: \"Vi sua música nova. Posso divulgar pros meus fãs?\"" % name
		SocialInvite.KIND_PEACE:
			return "%s: \"Vamos encerrar essa história? Não vale a pena.\"" % name
	return name


func accept_invite(career: CareerData, invite_id: String, report: WeekReport = null) -> ActionResult:
	var invite := career.social.find_invite(invite_id)
	if invite == null or invite.expires_week < career.current_week:
		return ActionResult.failure("Esse convite não está mais disponível.")
	career.social.invites.erase(invite)
	var name := display_name(invite.artist_id)
	match invite.kind:
		SocialInvite.KIND_FEATURE:
			if invite.fee > 0:
				_economy.earn(career, invite.fee, "Participação na música de %s" % name, FinanceEntry.CATEGORY_SOCIAL)
			var fame := maxi(roundi(size_of(invite.artist_id) * rules().feature_fame_per_cost), 1)
			_economy.add_fame(career, fame)
			if streaming != null:
				streaming.add_followers(career, fame * 25)
			change(career, invite.artist_id, 6, "Você participou de uma música de %s." % name)
			return ActionResult.success("Você gravou na música de %s: %s e +%d de fama." % [name, Fmt.money(invite.fee), fame])
		SocialInvite.KIND_PROMOTE:
			var followers := 200 + size_of(invite.artist_id) / 1000
			if streaming != null:
				streaming.add_followers(career, followers)
			_economy.add_fame(career, 2)
			change(career, invite.artist_id, 3, "%s divulgou seu lançamento." % name)
			return ActionResult.success("%s divulgou sua música: +%s seguidores." % [name, Fmt.number(followers)])
		SocialInvite.KIND_PEACE:
			var beef := career.social.active_beef_with(invite.artist_id)
			if beef != null:
				beefs.end_beef(career, beef, "Vocês encerraram o beef em paz.", report)
			return ActionResult.success("Beef com %s encerrado." % name)
	return ActionResult.failure("Convite inválido.")


func decline_invite(career: CareerData, invite_id: String) -> ActionResult:
	var invite := career.social.find_invite(invite_id)
	if invite == null:
		return ActionResult.failure("Convite não encontrado.")
	career.social.invites.erase(invite)
	if invite.kind == SocialInvite.KIND_PEACE:
		change(career, invite.artist_id, -5, "Você recusou a proposta de paz de %s." % display_name(invite.artist_id))
	else:
		relation(career, invite.artist_id).add_history(career.current_week, "Você recusou um convite de %s." % display_name(invite.artist_id))
	return ActionResult.success("Convite recusado.")


func add_invite(career: CareerData, artist_id: String, kind: String, fee: int = 0) -> SocialInvite:
	var invite := SocialInvite.new()
	invite.id = career.new_id("invite")
	invite.artist_id = artist_id
	invite.kind = kind
	invite.week = career.current_week
	invite.expires_week = career.current_week + rules().invite_expiry_weeks
	invite.fee = fee
	career.social.invites.append(invite)
	return invite


# ---- integrações com shows, turnês, festivais e lançamentos

## Convidados, parceiros e colegas de festival depois de um show realizado.
func on_show_performed(career: CareerData, show: LiveShow, report: WeekReport) -> void:
	for guest in show.guests:
		var artist_id: String = guest.get("artist_id", "")
		if person(artist_id) != null:
			relation(career, artist_id).shows += 1
			change(career, artist_id, 4, "%s participou do seu show em %s." % [display_name(artist_id), live.city_label(show.city_id)], report)
	if not show.partner_id.is_empty():
		relation(career, show.partner_id).shows += 1
		change(career, show.partner_id, 6, "Você subiu no palco de %s em %s." % [display_name(show.partner_id), live.city_label(show.city_id)], report)
	if show.kind == LiveShow.KIND_FESTIVAL:
		var edition := career.find_edition(show.festival_edition_id)
		if edition != null:
			_festival_encounters(career, edition, report)


func _festival_encounters(career: CareerData, edition: FestivalEdition, report: WeekReport) -> void:
	var met_friends := PackedStringArray()
	var tense := PackedStringArray()
	for slot in edition.lineup:
		var artist_id: String = slot.get("artist_id", "")
		var current := peek(career, artist_id)
		if current == null or not current.met:
			continue
		if current.value >= 30:
			change(career, artist_id, 3, "Vocês dividiram o line-up de um festival.")
			met_friends.append(display_name(artist_id))
		elif current.value <= -35:
			change(career, artist_id, -3, "Clima tenso nos bastidores de um festival.")
			_economy.add_fame(career, 2)
			tense.append(display_name(artist_id))
	if not met_friends.is_empty():
		_note(report, "Relações: festival", "Você reencontrou amigos no festival: %s." % ", ".join(met_friends))
	if not tense.is_empty():
		_note(report, "Relações: festival", "Clima tenso com %s nos bastidores. A imprensa reparou." % ", ".join(tense))


## Turnê conjunta concluída aproxima o jogador do co-headliner.
func on_tour_completed(career: CareerData, tour: LiveTour, report: WeekReport) -> void:
	if not tour.co_headliner_id.is_empty() and person(tour.co_headliner_id) != null:
		change(career, tour.co_headliner_id, 10, "Vocês fizeram a turnê \"%s\" juntos." % tour.name, report)


## Lançamento: amigos próximos podem divulgar. Diss tracks vão para o BeefSystem.
func on_content_released(career: CareerData, content: ReleasableContent, report: WeekReport) -> void:
	if content is SongData and not (content as SongData).diss_target_id.is_empty():
		beefs.on_diss_released(career, content, report)
		return
	for artist_id in career.social.relations:
		var current := career.social.relations[artist_id]
		if current.met and current.value >= 50 and _rng.randf() < 0.35:
			add_invite(career, artist_id, SocialInvite.KIND_PROMOTE)


# ---- semana

func process_week(career: CareerData, report: WeekReport) -> void:
	career.social.invites = career.social.invites.filter(func(invite: SocialInvite) -> bool: return invite.expires_week >= career.current_week)
	for artist_id in career.social.relations.keys():
		var current := career.social.relations[artist_id]
		var state: Dictionary = status_of(current.value, current.met)
		var chance: float = rules().invite_chances.get(state["id"], 0.0)
		if chance > 0.0 and _rng.randf() < chance:
			_spontaneous_invite(career, artist_id, report)


func _spontaneous_invite(career: CareerData, artist_id: String, report: WeekReport) -> void:
	var name := display_name(artist_id)
	var roll := _rng.randf()
	if roll < 0.45:
		var fee := roundi(size_of(artist_id) * rules().feature_fee_share)
		add_invite(career, artist_id, SocialInvite.KIND_FEATURE, fee)
		_note(report, "Convite de %s" % name, "%s quer você numa faixa do próximo projeto. Responda em Relações." % name)
	elif roll < 0.8 and live != null:
		live.partner_offers(career, artist_id, name, 1)
		_note(report, "Convite de %s" % name, "%s chamou você para subir no palco do show dele. Veja em Shows e ofertas." % name)
	elif live != null:
		live.partner_offers(career, artist_id, name, 3)
		_note(report, "Convite de %s" % name, "%s quer você em algumas datas da turnê dele. Veja em Shows e ofertas." % name)


func _note(report: WeekReport, title: String, text: String) -> void:
	if report == null:
		return
	var line := WeekReportEntry.new()
	line.title = title
	line.note = text
	report.entries.append(line)
