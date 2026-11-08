extends SceneTree
## Testes do sistema social: relações, amizades, feats, rivalidades, beefs, diss tracks, rede entre
## artistas, integrações e saves. Para rodar:
##   godot --headless --path . --script res://tests/test_social.gd

const GameManagerScript := preload("res://scripts/core/game_manager.gd")
const TEST_SAVE_DIR := "user://test_saves_social"
const V8_FIXTURE := "res://tests/fixtures/save_v8.json"

var _failures := 0
var _checks := 0


func _init() -> void:
	_clean()
	_test_creation_and_meeting()
	_test_gradual_positive_evolution()
	_test_negative_evolution_and_beef_start()
	_test_statuses()
	_test_progressive_discounts()
	_test_feats_integration()
	_test_invites()
	_test_diss_track()
	_test_artist_response_and_escalation()
	_test_ignore_cooldown_and_resolution()
	_test_reconciliation_rebuilds_trust()
	_test_npc_network_and_sides()
	_test_shows_tours_festivals()
	_test_persistence_and_careers()
	_test_v8_migration()
	_clean()
	print("%d verificações, %d falhas" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FALHOU: ", label)


func _game(fame: int = 100, money: int = 10000000, seed_value: int = 91) -> Node:
	var game: Node = GameManagerScript.new()
	game.rng.seed = seed_value
	game.saves.save_dir = TEST_SAVE_DIR
	game.new_career("MC Social")
	game.career.fame = fame
	game.career.money = money
	game.balance.streaming.leak_chance_per_week = 0.0
	game.balance.videos.leak_chance_per_week = 0.0
	return game


func _restore(game: Node) -> void:
	game.balance.streaming.leak_chance_per_week = 0.02
	game.balance.videos.leak_chance_per_week = 0.03
	game.free()


## Artistas do catálogo do mais barato ao mais caro.
func _artists(game: Node) -> Array[String]:
	var people: Array = game.balance.collaborators.feats.duplicate()
	people.sort_custom(func(a: CollaboratorDefinition, b: CollaboratorDefinition) -> bool: return a.cost < b.cost)
	var ids: Array[String] = []
	for person: CollaboratorDefinition in people:
		ids.append(String(person.id))
	return ids


## Prepara uma relação diretamente (só para montar cenários de teste).
func _relate(game: Node, artist_id: String, value: int) -> Relationship:
	var relation: Relationship = game.social.relation(game.career, artist_id)
	relation.met = true
	relation.value = value
	return relation


func _weeks(game: Node, count: int) -> void:
	for i in count:
		game.next_week()


# ---- relações

func _test_creation_and_meeting() -> void:
	var game := _game(5000)
	var social: SocialSystem = game.social
	var artist: String = _artists(game)[0]
	_check(social.peek(game.career, artist) == null and social.status(game.career, artist)["label"] == "Desconhecido", "começa desconhecido, sem dados salvos")
	_check(social.interactions(game.career, artist).size() == 1 and social.interactions(game.career, artist)[0]["definition"].id == "meet", "desconhecido: só dá para puxar conversa")
	for i in 10:
		game.social_interact(artist, "meet")
		if social.peek(game.career, artist).met:
			break
		game.next_week()
	var relation: Relationship = social.peek(game.career, artist)
	_check(relation.met and social.status(game.career, artist)["label"] == "Conhecido", "conhece o artista")
	_check(relation.history[0]["text"].contains("conheceu"), "histórico registra o encontro")
	var star: String = _artists(game)[-1]
	var small: String = _artists(game)[0]
	game.career.fame = 0
	_check(social.meet_chance(game.career, star) < social.meet_chance(game.career, small), "estrelas dão menos atenção a quem está começando")
	_restore(game)


func _test_gradual_positive_evolution() -> void:
	var game := _game()
	var social: SocialSystem = game.social
	var artist: String = _artists(game)[3]
	_relate(game, artist, 0)
	for action in ["talk", "social", "support"]:
		game.social_interact(artist, action)
	var after_week: int = social.peek(game.career, artist).value
	_check(after_week > 0 and after_week <= game.balance.social.weekly_gain_cap, "ganho por semana tem teto")
	_check(not game.social_interact(artist, "talk").ok, "mesma ação só uma vez por semana")
	var statuses := []
	for week in 40:
		game.next_week()
		for action in ["talk", "social", "support", "hangout", "studio", "appearance"]:
			game.social_interact(artist, action)
		var label: String = social.status(game.career, artist)["label"]
		if statuses.is_empty() or statuses[-1] != label:
			statuses.append(label)
	_check(statuses.size() >= 4, "passa por vários status: %s" % str(statuses))
	_check(statuses[-1] == "Melhor amigo", "chega a melhor amigo com o tempo")
	var order := ["Conhecido", "Colega", "Amigo", "Amigo próximo", "Grande amigo", "Melhor amigo"]
	for i in range(1, statuses.size()):
		_check(order.find(statuses[i]) == order.find(statuses[i - 1]) + 1, "nunca pula etapas: %s -> %s" % [statuses[i - 1], statuses[i]])
	var friendship_history := social.peek(game.career, artist).history.filter(func(item: Dictionary) -> bool: return String(item["text"]).contains("agora são"))
	_check(friendship_history.size() >= 4, "histórico marca cada nova etapa")
	_restore(game)


func _test_negative_evolution_and_beef_start() -> void:
	var game := _game()
	var social: SocialSystem = game.social
	var artist: String = _artists(game)[4]
	_relate(game, artist, 5)
	var result: ActionResult = game.social_interact(artist, "provoke")
	_check(result.ok and social.peek(game.career, artist).value < 0, "provocação deixa a relação negativa")
	var beef: Beef = game.career.social.active_beef_with(artist)
	_check(beef != null and beef.intensity == 1 and beef.awaiting == Beef.TURN_ARTIST, "provocação abre um beef e a vez é do artista")
	_check(social.status(game.career, artist)["label"] in ["Neutro", "Tensão"], "status de tensão")
	_restore(game)


func _test_statuses() -> void:
	var game := _game()
	var social: SocialSystem = game.social
	var expected := {0: "Conhecido", 15: "Colega", 30: "Amigo", 50: "Amigo próximo", 70: "Grande amigo", 85: "Melhor amigo",
		-1: "Neutro", -15: "Tensão", -35: "Inimizade", -55: "Rival", -75: "Grande rival"}
	for value: int in expected:
		_check(social.status_of(value, true)["label"] == expected[value], "status em %d: %s" % [value, expected[value]])
	_check(social.status_of(90, false)["label"] == "Desconhecido", "sem conhecer, desconhecido")
	_restore(game)


# ---- amizades e feats

func _test_progressive_discounts() -> void:
	var game := _game(20000)
	var social: SocialSystem = game.social
	var small: String = _artists(game)[2]
	var star: String = _artists(game)[-1]
	var previous := 2.0
	for value in [0, 15, 30, 50, 70]:
		_relate(game, small, value)
		var multiplier := social.price_multiplier(game.career, small)
		_check(multiplier < previous, "desconto cresce com a amizade (%d)" % value)
		previous = multiplier
	_relate(game, small, 90)
	_check(social.price_multiplier(game.career, small) == 0.0, "melhor amigo do seu nível faz de graça")
	game.career.fame = 500
	_relate(game, star, 90)
	_check(social.size_of(star) > social.star_limit(game.career), "estrela muito maior que o jogador")
	_check(social.price_multiplier(game.career, star) >= 1.0 - game.balance.social.star_discount_cap, "estrela tem desconto limitado mesmo sendo melhor amiga")
	_relate(game, small, -20)
	_check(social.price_multiplier(game.career, small) > 1.0, "tensão encarece")
	_relate(game, small, -40)
	_check(not social.refusal(game.career, small).is_empty(), "inimizade recusa feat")
	_restore(game)


func _test_feats_integration() -> void:
	var game := _game(20000, 2000000)
	var social: SocialSystem = game.social
	var friend: String = _artists(game)[5]
	var person := social.person(friend)
	_relate(game, friend, 55)
	var credits := SongCredits.new()
	credits.feat_ids = [friend]
	var expected := roundi(person.cost * social.price_multiplier(game.career, friend))
	_check(game.music.hiring_cost(credits, null, game.career) == expected and expected < person.cost, "preço do feat com desconto antes de confirmar")
	_check(game.music.hiring_cost(credits) == person.cost, "sem carreira, preço do catálogo")
	var money: int = game.career.money
	var song: SongData = game.create_song("Com amigo", credits).value
	_check(game.career.money == money - game.balance.song_production_cost - expected, "cobra o preço com desconto")
	_check(social.peek(game.career, friend).feats == 1 and social.peek(game.career, friend).history[-1]["text"].contains("participou"), "feat aproxima e entra no histórico")
	_relate(game, friend, 90)
	var before: int = game.career.money
	var free_song: ActionResult = game.create_song("De graça", credits)
	_check(free_song.ok and game.career.money == before - game.balance.song_production_cost, "melhor amigo: feat gratuito")
	_check(social.peek(game.career, friend).history[-1]["text"].contains("de graça") or social.peek(game.career, friend).history.any(func(item: Dictionary) -> bool: return String(item["text"]).contains("de graça")), "feat gratuito no histórico")
	_check(not social.free_feat_available(game.career, friend), "feat gratuito tem intervalo")
	_check(game.music.hiring_cost(credits, null, game.career) > 0, "logo depois volta a ter cachê (com desconto)")
	var rival: String = _artists(game)[6]
	_relate(game, rival, -60)
	var rival_credits := SongCredits.new()
	rival_credits.feat_ids = [rival]
	var refused: ActionResult = game.create_song("Sem chance", rival_credits)
	_check(not refused.ok and refused.message.contains("não quer"), "rival recusa o feat")
	_check(song.credits.feat_ids == credits.feat_ids, "música continua normal")
	_restore(game)


func _test_invites() -> void:
	var game := _game(500)
	var social: SocialSystem = game.social
	var best: String = _artists(game)[1]
	var stranger: String = _artists(game)[2]
	_relate(game, best, 90)
	_relate(game, stranger, 5)
	var invites_from := {}
	var offers_before: int = game.live.shows_with_status(game.career, LiveShow.STATUS_OFFER).size()
	var partner_offers := 0
	for week in 40:
		game.next_week()
		for invite in social.pending_invites(game.career):
			invites_from[invite.artist_id] = true
		for show in game.career.live_shows:
			if show.partner_id == best:
				partner_offers += 1
	_check(invites_from.has(best) or partner_offers > 0, "melhor amigo convida espontaneamente")
	_check(not invites_from.has(stranger), "conhecido distante não convida")
	var invite := social.add_invite(game.career, best, SocialInvite.KIND_FEATURE, 5000)
	var money: int = game.career.money
	var fame: int = game.career.fame
	var accepted: ActionResult = game.accept_social_invite(invite.id)
	_check(accepted.ok and game.career.money == money + 5000 and game.career.fame > fame, "participar da música do amigo rende cachê e fama")
	_check(social.peek(game.career, best).history[-1]["text"].contains("participou de uma música"), "participação no histórico")
	var other := social.add_invite(game.career, best, SocialInvite.KIND_PROMOTE)
	_check(game.decline_social_invite(other.id).ok and game.career.social.find_invite(other.id) == null, "recusar remove o convite")
	_restore(game)


# ---- beefs

func _diss(game: Node, target: String, quality: int) -> SongData:
	var song: SongData = game.create_song("Diss %d" % quality, null, "", null, target).value
	song.quality = quality
	game.release_content(song.id)
	return song


func _test_diss_track() -> void:
	var game := _game(800)
	var social: SocialSystem = game.social
	var target: String = _artists(game)[8]
	var unknown_target: String = _artists(game)[9]
	var refused: ActionResult = game.create_song("Sem alvo", null, "", null, unknown_target)
	_check(not refused.ok, "diss só contra artista conhecido")
	_relate(game, target, 10)
	var self_feat := SongCredits.new()
	self_feat.feat_ids = [target]
	_check(not game.create_song("Contra e com", self_feat, "", null, target).ok, "alvo não participa da própria diss")
	var fame: int = game.career.fame
	var fans: int = game.streaming.total_followers(game.career)
	var song := _diss(game, target, 90)
	_check(song.diss_target_id == target and song.is_released(), "diss é uma música normal lançada")
	var beef: Beef = game.career.social.active_beef_with(target)
	_check(beef != null and song.beef_id == beef.id, "diss abre beef com o alvo")
	_check(beef.events.any(func(item: Dictionary) -> bool: return item["kind"] == "diss" and item["song_id"] == song.id), "beef registra a diss")
	_check(social.peek(game.career, target).value <= -15, "relação cai com a diss")
	_check(game.career.fame > fame and game.streaming.total_followers(game.career) > fans, "diss bem recebida dá fama e fãs")
	var bad_game := _game(800)
	var bad_target: String = _artists(bad_game)[8]
	_relate(bad_game, bad_target, 10)
	var reputation: int = bad_game.career.reputation
	var bad_song: SongData = bad_game.create_song("Fraca", null, "", null, bad_target).value
	bad_game.streaming.add_followers(bad_game.career, 5000)
	var bad_fans: int = bad_game.streaming.total_followers(bad_game.career)
	bad_song.quality = 20
	bad_game.release_content(bad_song.id)
	_check(bad_game.career.reputation < reputation + 1 and bad_game.streaming.total_followers(bad_game.career) < bad_fans, "diss ruim custa fãs e reputação")
	_restore(bad_game)
	_restore(game)


func _test_artist_response_and_escalation() -> void:
	var game := _game(800, 10000000, 17)
	var target: String = _artists(game)[7]
	_relate(game, target, 0)
	_diss(game, target, 85)
	var beef: Beef = game.career.social.active_beef_with(target)
	var responded := false
	for i in 4:
		game.next_week()
		if beef.events.any(func(item: Dictionary) -> bool: return item["actor"] == "artist"):
			responded = true
			break
	_check(responded, "o alvo reage (ignora, responde, diss ou paz)")
	var kinds := beef.events.map(func(item: Dictionary) -> String: return item["kind"])
	_check("ignore" in kinds or "response" in kinds or "diss" in kinds or "peace" in kinds, "reação registrada: %s" % str(kinds))
	var escalation := _game(800, 10000000, 23)
	var rival: String = _artists(escalation)[7]
	_relate(escalation, rival, -20)
	for round in 5:
		var current: Beef = escalation.career.social.active_beef_with(rival)
		if current != null:
			current.awaiting = Beef.TURN_PLAYER
		_diss(escalation, rival, 80)
	var hot: Beef = escalation.career.social.active_beef_with(rival)
	_check(hot != null and hot.intensity == 4 and hot.intensity_label() == "Grande rivalidade", "contra-respostas escalam até grande rivalidade")
	_check(escalation.social.status(escalation.career, rival)["label"] == "Grande rival", "relação acompanha a intensidade")
	_restore(escalation)
	_restore(game)


func _test_ignore_cooldown_and_resolution() -> void:
	var game := _game(800)
	var target: String = _artists(game)[10]
	_relate(game, target, -20)
	game.social_interact(target, "provoke")
	var beef: Beef = game.career.social.active_beef_with(target)
	beef.awaiting = Beef.TURN_PLAYER
	beef.intensity = 2
	_check(game.ignore_beef(target).ok and beef.intensity == 1, "ignorar diminui a intensidade")
	_check(beef.awaiting == "", "depois de ignorar, não é mais a vez do jogador")
	beef.awaiting = Beef.TURN_PLAYER
	game.ignore_beef(target)
	_check(not beef.is_active() and game.career.social.active_beef_with(target) == null, "ignorar até o fim encerra o beef")
	var cooling := _game(800)
	var other: String = _artists(cooling)[11]
	_relate(cooling, other, -10)
	cooling.social_interact(other, "provoke")
	var open: Beef = cooling.career.social.active_beef_with(other)
	open.awaiting = Beef.TURN_PLAYER
	open.last_week = cooling.career.current_week
	_weeks(cooling, cooling.balance.social.cooldown_weeks + 1)
	_check(not open.is_active(), "beef sem reação esfria e termina")
	_restore(cooling)
	_restore(game)


func _test_reconciliation_rebuilds_trust() -> void:
	var game := _game(800)
	var social: SocialSystem = game.social
	var target: String = _artists(game)[12]
	_relate(game, target, 60)
	game.social_interact(target, "provoke")
	_diss(game, target, 80)
	var beef: Beef = game.career.social.active_beef_with(target)
	_check(social.peek(game.career, target).value < -15, "amizade virou conflito")
	var ended := false
	for i in 30:
		if game.social_interact(target, "reconcile").message.contains("encerrado"):
			ended = true
			break
		social.peek(game.career, target).used.clear()
	_check(ended and not beef.is_active(), "reconciliação encerra o beef")
	_check(social.status(game.career, target)["label"] == "Neutro", "volta a neutro, sem restaurar a amizade antiga")
	game.next_week()
	game.social_interact(target, "talk")
	game.social_interact(target, "support")
	_check(social.status(game.career, target)["label"] in ["Neutro", "Conhecido"], "uma semana depois ainda não é amizade")
	for week in 5:
		game.next_week()
		game.social_interact(target, "talk")
		game.social_interact(target, "support")
	_check(social.peek(game.career, target).value >= 0, "confiança reconstruída aos poucos")
	_restore(game)


# ---- rede entre artistas

func _test_npc_network_and_sides() -> void:
	var game := _game(800)
	var social: SocialSystem = game.social
	var ids := _artists(game)
	var target: String = ids[13]
	var ally: String = ids[14]
	var my_friend: String = ids[15]
	_check(social.npc_relation(game.career, target, ally) == social.npc_relation(game.career, ally, target), "relação entre artistas é simétrica")
	social.set_npc_relation(game.career, target, ally, 60)
	social.set_npc_relation(game.career, my_friend, target, 0)
	_check(ally in social.friends_of(game.career, target), "aliados vêm da rede entre artistas")
	_relate(game, target, 5)
	_relate(game, ally, 20)
	_relate(game, my_friend, 40)
	var ally_before: int = social.peek(game.career, ally).value
	_diss(game, target, 80)
	_check(social.peek(game.career, ally).value < ally_before, "aliado do alvo se afasta do jogador")
	_check(social.npc_relation(game.career, my_friend, target) < 0, "amigo do jogador toma partido contra o alvo")
	_check(social.peek(game.career, my_friend).history.any(func(item: Dictionary) -> bool: return String(item["text"]).contains("defendeu você")), "defesa registrada")
	var rival: String = ids[16]
	social.set_npc_relation(game.career, ally, rival, -60)
	_check(rival in social.rivals_of(game.career, ally), "rivais entre artistas")
	_relate(game, ally, 30)
	_check(social.interactions(game.career, ally).any(func(item: Dictionary) -> bool: return item["definition"].id == "defend"), "dá para defender um amigo que tem rival")
	_restore(game)


# ---- shows, turnês e festivais

func _test_shows_tours_festivals() -> void:
	var game := _game(1500)
	var social: SocialSystem = game.social
	var live: LiveSystem = game.live
	var ids := _artists(game)
	var friend: String = ids[17]
	var rival: String = ids[18]
	_relate(game, friend, 55)
	_relate(game, rival, -60)
	var show := live.new_show(game.career, LiveShow.KIND_INDEPENDENT)
	show.guests = [{"artist_id": rival, "role": "guest"}]
	_check(not game.schedule_show(show).ok, "rival recusa subir no palco")
	show.guests = [{"artist_id": friend, "role": "guest"}]
	var guest_cost: int = live.costs(game.career, show, {})["guests"]
	var person := social.person(friend)
	_check(guest_cost < roundi(person.cost * game.balance.live.guest_fee["guest"]), "amigo cobra menos para participar do show")
	_check(game.schedule_show(show).ok, "amigo aceita participar do show")
	var before: int = social.peek(game.career, friend).value
	_weeks(game, 3)
	_check(show.status == LiveShow.STATUS_DONE and social.peek(game.career, friend).shows == 1 and social.peek(game.career, friend).value > before, "show juntos aproxima")
	var types: Array[String] = ["national"]
	_check(not game.create_tour("Sem rival", "", "", types, rival).ok, "rival recusa turnê conjunta")
	_check(game.create_tour("Com amigo", "", "", types, friend).ok, "amigo aceita turnê conjunta")
	live.partner_offers(game.career, friend, social.display_name(friend), 3)
	var partner: Array = game.career.live_shows.filter(func(item: LiveShow) -> bool: return item.partner_id == friend and item.status == LiveShow.STATUS_OFFER)
	_check(partner.size() == 3 and partner[0].event_name.contains("Turnê de"), "convite para datas da turnê do amigo vira proposta")
	var edition: FestivalEdition = game.festivals.upcoming_editions(game.career)[0]
	var slot_artist: String = String(edition.lineup[0]["artist_id"])
	_relate(game, slot_artist, 40)
	var line_before: int = social.peek(game.career, slot_artist).value
	var report := WeekReport.new()
	social._festival_encounters(game.career, edition, report)
	_check(social.peek(game.career, slot_artist).value > line_before and not report.entries.is_empty(), "festival com amigo no line-up aproxima e aparece no relatório")
	_restore(game)


# ---- saves

func _test_persistence_and_careers() -> void:
	_clean()
	var game := _game(800)
	var ids := _artists(game)
	game.create_career("Carreira A", {}, game.characters.default_appearance())
	var slot_a: String = game.current_slot
	game.career.money = 1000000
	game.career.fame = 800
	_relate(game, ids[0], 40).add_history(game.career.current_week, "Teste A")
	game.social_interact(ids[1], "meet")
	_relate(game, ids[2], -10)
	game.social_interact(ids[2], "provoke")
	game.social.add_invite(game.career, ids[0], SocialInvite.KIND_FEATURE, 100)
	game.social.set_npc_relation(game.career, ids[3], ids[4], -80)
	var song: SongData = game.create_song("Diss salva", null, "", null, ids[2]).value
	game.save_game()
	var saved := JSON.stringify(game.career.social.to_dict())
	var value_a: int = game.career.social.relations[ids[0]].value
	game.create_career("Carreira B", {}, game.characters.default_appearance())
	_check(game.career.social.relations.is_empty(), "carreira nova começa sem relações")
	_relate(game, ids[0], -50)
	game.save_game()
	var reopened := _game()
	_check(reopened.load_game(slot_a).ok, "reabre a carreira A")
	_check(JSON.stringify(reopened.career.social.to_dict()) == saved, "rede social restaurada exatamente")
	_check(reopened.career.social.relations[ids[0]].value == value_a, "carreira B não altera a A")
	_check(reopened.career.find_song(song.id).diss_target_id == ids[2], "alvo da diss salvo na música")
	reopened.free()
	_restore(game)


func _test_v8_migration() -> void:
	_clean()
	DirAccess.make_dir_recursive_absolute(TEST_SAVE_DIR)
	var save_path := TEST_SAVE_DIR.path_join("career.json")
	var fixture_text := FileAccess.get_file_as_string(V8_FIXTURE)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(fixture_text)
	file.close()
	var old: Dictionary = JSON.parse_string(fixture_text)["career"]
	_check(int(JSON.parse_string(fixture_text)["version"]) == 8, "fixture é v8")
	var game: Node = GameManagerScript.new()
	game.saves.save_dir = TEST_SAVE_DIR
	_check(game.load_game().ok, "carrega save v8 real")
	var career: CareerData = game.career
	_check(FileAccess.get_file_as_string(save_path + ".v8.bak") == fixture_text, "cópia do save v8 guardada")
	_check(career.money == int(old["money"]) and career.fame == int(old["fame"]) and career.reputation == int(old["reputation"]), "dinheiro, fama e reputação")
	_check(career.songs.size() == old["songs"].size() and career.albums.size() == old["albums"].size() and career.releases.size() == old["releases"].size(), "músicas, projetos e lançamentos")
	_check(career.live_shows.size() == old["live_shows"].size() and career.live_tours.size() == old["live_tours"].size() and career.merch_items.size() == old["merch_items"].size(), "shows, turnês e merch")
	# A aparência antiga fica igual; a v11 só acrescenta sexo, corpo e maquiagem no padrão.
	var old_look := CharacterAppearance.from_dict(old["appearance"])
	var kept := old_look.accessories == career.appearance.accessories
	for category in old_look.choices:
		kept = kept and career.appearance.get_choice(category) == old_look.get_choice(category)
	_check(career.platform_stats.size() == old["platform_stats"].size() and kept, "plataformas e aparência")
	_check(career.social.relations.is_empty() and career.social.beefs.is_empty() and career.social.invites.is_empty(), "rede social começa vazia")
	_check(career.songs.all(func(song: SongData) -> bool: return song.diss_target_id.is_empty()), "músicas antigas não viram diss")
	game.next_week()
	_check(game.save_game().ok and int(JSON.parse_string(FileAccess.get_file_as_string(save_path))["version"]) == SaveSystem.SAVE_VERSION, "salva no formato novo")
	game.free()


func _clean() -> void:
	if not DirAccess.dir_exists_absolute(TEST_SAVE_DIR):
		return
	for file_name in DirAccess.get_files_at(TEST_SAVE_DIR):
		DirAccess.remove_absolute(TEST_SAVE_DIR.path_join(file_name))
	DirAccess.remove_absolute(TEST_SAVE_DIR)
