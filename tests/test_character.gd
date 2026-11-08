extends SceneTree
## Testes de personagem, aparência, múltiplas carreiras e energia infinita, sem interface. Para rodar:
##   godot --headless --path . --script res://tests/test_character.gd

const GameManagerScript := preload("res://scripts/core/game_manager.gd")
const TEST_SAVE_DIR := "user://test_saves_character"
const V7_FIXTURE := "res://tests/fixtures/save_v7.json"
const V10_FIXTURE := "res://tests/fixtures/save_v10.json"

var _failures := 0
var _checks := 0


func _init() -> void:
	_clean_saves()
	_test_catalog()
	_test_create_career()
	_test_identity_validation()
	_test_appearance_rules()
	_test_customize_keeps_progress()
	_test_multiple_careers()
	_test_delete_career()
	_test_infinite_energy()
	_test_age_progression()
	_test_legacy_single_save_listed()
	_test_v7_migration()
	_test_editor_coverage()
	_test_tiers_and_prices()
	_test_sex_and_build()
	_test_creation_is_basic()
	_test_shop_and_wardrobe()
	_test_wardrobe_per_career()
	_test_v10_migration()
	_clean_saves()
	print("%d verificações, %d falhas" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FALHOU: ", label)


func _game() -> Node:
	var game: Node = GameManagerScript.new()
	game.rng.seed = 61
	game.saves.save_dir = TEST_SAVE_DIR
	return game


func _appearance(game: Node, choices: Dictionary, accessories: Array = []) -> CharacterAppearance:
	var appearance: CharacterAppearance = game.characters.default_appearance()
	for category: String in choices:
		appearance.set_choice(category, choices[category])
	for option_id: String in accessories:
		appearance.set_accessory(option_id, true)
	return appearance


func _create(game: Node, artist: String, identity: Dictionary, appearance: CharacterAppearance = null) -> ActionResult:
	return game.create_career(artist, identity, appearance if appearance != null else game.characters.default_appearance())


# ---- testes

func _test_catalog() -> void:
	var game := _game()
	var rules: CharacterRules = game.characters.rules()
	for item: Dictionary in CharacterRules.CATEGORIES:
		var category: String = item["id"]
		_check(rules.options_for(category).size() >= 2, "opções em %s" % category)
		if not CharacterRules.is_multiple(category):
			_check(rules.find_option(category, rules.defaults.get(category, "")) != null, "padrão válido em %s" % category)
	_check(rules.find_option("beard", "beard_none") != null, "opção sem barba")
	_check(rules.options_for("top").size() >= 8, "várias roupas")
	_check(rules.countries.has(rules.default_country), "país padrão na lista")
	game.free()


func _test_create_career() -> void:
	_clean_saves()
	var game := _game()
	var look := _appearance(game, {"skin": "skin_7", "hair": "hair_dreads", "hair_color": "hc_blond", "brows": "brows_thick",
		"eye_color": "eyes_green", "beard": "beard_full", "top": "top_hoodie_black", "jacket": "jacket_none",
		"bottom": "bottom_sweat_gray", "shoes": "shoes_black", "headwear": "head_beanie", "build": "build_athletic"}, ["acc_studs", "acc_watch_basic"])
	var result := _create(game, "MC Nova", {"real_name": "Ana Souza", "age": 22, "country": "Brasil", "city": "São Paulo"}, look)
	_check(result.ok, "cria carreira")
	var career: CareerData = game.career
	_check(career.artist_name == "MC Nova" and career.real_name == "Ana Souza", "nomes")
	_check(career.age == 22 and career.country == "Brasil" and career.city == "São Paulo", "idade, país e cidade")
	_check(JSON.stringify(career.appearance.to_dict()) == JSON.stringify(look.to_dict()), "aparência completa")
	_check(game.current_slot != SaveSystem.DEFAULT_SLOT and game.has_save(), "slot próprio salvo na criação")
	_check(career.money == game.balance.starting_money and career.energy == game.balance.max_energy, "progresso inicial normal")
	var reopened := _game()
	_check(reopened.load_game(game.current_slot).ok, "reabre a carreira")
	_check(JSON.stringify(reopened.career.to_dict()) == JSON.stringify(career.to_dict()), "carreira idêntica ao reabrir")
	reopened.free()
	game.free()


func _test_identity_validation() -> void:
	_clean_saves()
	var game := _game()
	_check(not _create(game, "  ", {}).ok, "nome artístico obrigatório")
	_check(not _create(game, "Novo", {"age": 5}).ok, "idade mínima")
	_check(not _create(game, "Novo", {"age": 99}).ok, "idade máxima")
	_check(game.list_careers().is_empty(), "carreira inválida não é salva")
	_check(_create(game, "Sem Detalhes", {}).ok, "identidade opcional usa padrões")
	_check(game.career.country == game.characters.rules().default_country and game.career.age == game.characters.rules().default_age, "padrões de país e idade")
	game.free()


func _test_appearance_rules() -> void:
	var game := _game()
	var characters: CharacterSystem = game.characters
	var broken := CharacterAppearance.new()
	broken.set_choice("hair", "corte_que_nao_existe")
	broken.set_accessory("acc_inexistente", true)
	broken.set_accessory("acc_glasses", true)
	var clean := characters.sanitize(broken)
	_check(clean.get_choice("hair") == characters.rules().defaults["hair"], "peça inexistente volta ao padrão")
	_check(clean.accessories.size() == 1 and clean.accessories[0] == "acc_glasses", "acessório inexistente sai")
	_check(clean.get_choice("skin") == characters.rules().defaults["skin"], "categoria faltando ganha o padrão")
	var look := characters.default_appearance()
	look.set_choice("beard", "beard_goatee")
	_check(look.get_choice("hair") == characters.rules().defaults["hair"], "barba independente do cabelo")
	var copy := look.copy()
	copy.set_choice("top", "top_tank_black")
	_check(look.get_choice("top") != "top_tank_black", "cópia independente")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var random := characters.random_appearance(rng)
	_check(JSON.stringify(characters.sanitize(random).to_dict()) == JSON.stringify(random.to_dict()) or random.accessories.size() >= 0, "aparência aleatória válida")
	for item: Dictionary in CharacterRules.CATEGORIES:
		if not CharacterRules.is_multiple(item["id"]):
			_check(characters.option(random, item["id"]) != null, "aleatória resolve %s" % item["id"])
	game.free()


func _test_customize_keeps_progress() -> void:
	_clean_saves()
	var game := _game()
	_create(game, "MC Nova", {"age": 22})
	game.career.money = 500000
	game.career.fame = 80
	var song: SongData = game.create_song("Hit").value
	game.release_content(song.id)
	game.manufacture_merch("tshirt", 50, 30, "", "", false)
	for i in 3:
		game.next_week()
	game.save_game()
	var before: Dictionary = game.career.to_dict()
	before.erase("appearance")
	before.erase("wardrobe")
	# Peças da loja entram no guarda-roupa antes (a compra é testada à parte).
	for option in game.characters.rules().options:
		if CharacterRules.is_wear(option.category) and option.price > 0:
			game.career.wardrobe.append(option.id)
	for category in ["skin", "hair", "hair_color", "brows", "eye_color", "beard", "top", "jacket", "bottom", "shoes", "headwear", "build", "makeup"]:
		var look: CharacterAppearance = game.career.appearance.copy()
		var options: Array = game.characters.options_for(category, "male")
		look.set_choice(category, options[-1].id)
		_check(game.set_appearance(look).ok and game.career.appearance.get_choice(category) == options[-1].id, "altera %s sozinho" % category)
	var look: CharacterAppearance = game.career.appearance.copy()
	look.set_accessory("acc_sunglasses", true)
	game.set_appearance(look)
	var after: Dictionary = game.career.to_dict()
	after.erase("appearance")
	after.erase("wardrobe")
	_check(JSON.stringify(after) == JSON.stringify(before), "progresso intacto ao personalizar")
	var reopened := _game()
	reopened.load_game(game.current_slot)
	_check(JSON.stringify(reopened.career.appearance.to_dict()) == JSON.stringify(game.career.appearance.to_dict()), "aparência gravada no save")
	_check(reopened.career.money == game.career.money and reopened.career.songs.size() == 1, "progresso no save")
	reopened.free()
	game.free()


func _test_multiple_careers() -> void:
	_clean_saves()
	var game := _game()
	_create(game, "MC Nova", {"age": 22, "country": "Brasil"}, _appearance(game, {"hair": "hair_afro"}))
	var slot_a: String = game.current_slot
	for i in 2:
		game.create_song("Faixa %d" % i)
	game.career.money = 500000
	game.career.fame = 80
	game.save_game()
	var a_saved := JSON.stringify(game.career.to_dict())
	_create(game, "Young Mike", {"age": 19, "country": "Estados Unidos"}, _appearance(game, {"hair": "hair_buzz"}))
	var slot_b: String = game.current_slot
	_check(slot_a != slot_b, "cada carreira tem seu slot")
	game.career.money = 5000
	game.career.fame = 12
	game.save_game()
	var b_saved := JSON.stringify(game.career.to_dict())
	var careers: Array[Dictionary] = game.list_careers()
	_check(careers.size() == 2, "duas carreiras na lista")
	var names := careers.map(func(item: Dictionary) -> String: return item["artist_name"])
	_check("MC Nova" in names and "Young Mike" in names, "cartões com o nome artístico")
	for info in careers:
		if info["artist_name"] == "MC Nova":
			_check(info["fame"] == 80 and info["money"] == 500000 and info["age"] == 22 and info["country"] == "Brasil", "cartão com fama, dinheiro e identidade")
			_check(info["appearance"]["choices"]["hair"] == "hair_afro" and info["saved_at"] > 0, "cartão com aparência e data")
	_check(game.load_game(slot_a).ok and JSON.stringify(game.career.to_dict()) == a_saved, "carregar A restaura A")
	_check(game.load_game(slot_b).ok and JSON.stringify(game.career.to_dict()) == b_saved, "carregar B restaura B")
	game.load_game(slot_a)
	game.career.money = 1
	game.save_game()
	game.load_game(slot_b)
	_check(game.career.money == 5000, "salvar A não altera B")
	game.free()


func _test_delete_career() -> void:
	_clean_saves()
	var game := _game()
	_create(game, "Fica", {})
	var keep: String = game.current_slot
	var keep_saved := JSON.stringify(game.career.to_dict())
	_create(game, "Sai", {})
	var gone: String = game.current_slot
	_check(not game.delete_career("nao_existe").ok, "slot inexistente")
	_check(game.delete_career(gone).ok, "exclui carreira")
	_check(game.list_careers().size() == 1 and not game.saves.has_save(gone), "carreira excluída some")
	_check(game.load_game(keep).ok and JSON.stringify(game.career.to_dict()) == keep_saved, "outra carreira intacta")
	game.free()


func _test_infinite_energy() -> void:
	_clean_saves()
	var game := _game()
	_create(game, "Normal", {})
	var normal: String = game.current_slot
	var song: SongData = game.create_song("Demo").value
	var cost: int = game.balance.song_quality.attributes[0].energy_cost
	var energy: int = game.career.energy
	game.improve_song(song.id, game.balance.song_quality.attributes[0].id)
	_check(game.career.energy == energy - cost, "energia normal é consumida")
	game.save_game()
	_create(game, "Infinita", {})
	var infinite: String = game.current_slot
	_check(game.set_infinite_energy(true).ok and game.career.infinite_energy, "ativa energia infinita")
	game.career.energy = 0
	var demo: SongData = game.create_song("Demo").value
	var improved: ActionResult = game.improve_song(demo.id, game.balance.song_quality.attributes[0].id)
	_check(improved.ok and game.career.energy == 0, "sem consumo com energia infinita")
	for i in 5:
		var again: ActionResult = game.improve_song(demo.id, game.balance.song_quality.attributes[i % game.balance.song_quality.attributes.size()].id)
		_check(again.ok or not "Energia" in again.message, "nunca falta energia")
	game.load_game(infinite)
	_check(game.career.infinite_energy, "configuração salva")
	game.load_game(normal)
	_check(not game.career.infinite_energy, "outra carreira mantém a própria configuração")
	game.career.energy = 0
	var blocked: ActionResult = game.improve_song(song.id, game.balance.song_quality.attributes[1].id)
	_check(not blocked.ok, "carreira normal continua limitada")
	game.free()


func _test_age_progression() -> void:
	var game := _game()
	game.new_career("Tempo")
	game.career.age = 20
	var characters: CharacterSystem = game.characters
	_check(characters.current_age(game.career) == 20, "idade inicial")
	game.career.current_week = game.balance.starting_week + characters.rules().weeks_per_year
	_check(characters.current_age(game.career) == 21, "um ano depois")
	_check(characters.age_at(20, game.balance.starting_week + characters.rules().weeks_per_year * 3 - 1) == 22, "idade pelo calendário")
	game.free()


## O save único das versões anteriores (career.json) vira uma carreira da lista.
func _test_legacy_single_save_listed() -> void:
	_clean_saves()
	var game := _game()
	game.new_career("Antiga")
	game.save_game()
	_check(game.current_slot == SaveSystem.DEFAULT_SLOT, "save antigo no slot padrão")
	_create(game, "Nova", {})
	var careers: Array[Dictionary] = game.list_careers()
	var slots := careers.map(func(item: Dictionary) -> String: return item["slot"])
	_check(careers.size() == 2 and SaveSystem.DEFAULT_SLOT in slots, "save antigo aparece entre as carreiras")
	_check(game.load_game(SaveSystem.DEFAULT_SLOT).ok and game.career.artist_name == "Antiga", "save antigo carrega")
	game.free()


func _test_v7_migration() -> void:
	_clean_saves()
	DirAccess.make_dir_recursive_absolute(TEST_SAVE_DIR)
	var save_path := TEST_SAVE_DIR.path_join("career.json")
	var fixture_text := FileAccess.get_file_as_string(V7_FIXTURE)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(fixture_text)
	file.close()
	var old_payload: Dictionary = JSON.parse_string(fixture_text)
	var old: Dictionary = old_payload["career"]
	_check(int(old_payload["version"]) == 7, "fixture é v7")
	var game := _game()
	var listed: Array[Dictionary] = game.list_careers()
	_check(listed.size() == 1 and listed[0]["artist_name"] == old["artist_name"], "save v7 aparece na lista antes de migrar")
	_check(game.load_game(SaveSystem.DEFAULT_SLOT).ok, "carrega save v7 real")
	var career: CareerData = game.career
	_check(FileAccess.get_file_as_string(save_path + ".v7.bak") == fixture_text, "cópia do save v7 guardada")
	_check(career.artist_name == old["artist_name"] and career.money == int(old["money"]) and career.fame == int(old["fame"]), "nome, dinheiro e fama")
	_check(career.reputation == int(old["reputation"]) and career.energy == int(old["energy"]) and career.current_week == int(old["current_week"]), "reputação, energia e semana")
	_check(career.songs.size() == old["songs"].size() and career.albums.size() == old["albums"].size(), "músicas e projetos")
	_check(career.releases.size() == old["releases"].size() and career.platform_stats.size() == old["platform_stats"].size(), "lançamentos e plataformas")
	_check(career.live_shows.size() == old["live_shows"].size() and career.live_tours.size() == old["live_tours"].size(), "shows e turnês")
	_check(career.merch_items.size() == old["merch_items"].size() and career.finance_history.size() == old["finance_history"].size(), "merch e histórico")
	_check(career.next_id == int(old["next_id"]), "contador de ids")
	_check(JSON.stringify(career.appearance.to_dict()) == JSON.stringify(game.characters.default_appearance().to_dict()), "aparência padrão")
	_check(career.age == game.characters.rules().default_age and career.country == game.characters.rules().default_country, "identidade padrão")
	_check(career.real_name == "" and not career.infinite_energy, "nome real vazio e energia normal")
	_check(game.save_game().ok and int(JSON.parse_string(FileAccess.get_file_as_string(save_path))["version"]) == SaveSystem.SAVE_VERSION, "salva no formato novo")
	game.free()


## O editor por miniaturas e o desenho cobrem todo o catálogo: cada categoria está em uma aba,
## cada miniatura recorta uma região que existe e cada estilo tem desenho.
func _test_editor_coverage() -> void:
	var game := _game()
	var rules: CharacterRules = game.characters.rules()
	var regions := CharacterLayout.FOCUS_RECTS
	var view_source: String = FileAccess.get_file_as_string("res://scripts/ui/components/character_view.gd")
	for item: Dictionary in CharacterRules.CATEGORIES:
		var category: String = item["id"]
		var tabs := 0
		for group: Dictionary in CharacterLayout.GROUPS:
			tabs += 1 if category in group["categories"] else 0
		_check(tabs == 1, "categoria %s em exatamente uma aba do editor" % category)
		if category in CharacterRules.COLOR_CATEGORIES:
			continue
		for option in rules.options_for(category):
			var focus: String = CharacterLayout.ACCESSORY_FOCUS.get(option.style, "") if category == "accessory" else CharacterLayout.FOCUS.get(category, "")
			_check(regions.has(focus), "miniatura de %s recorta uma região conhecida (%s)" % [option.id, focus])
			# none, bald, normal e sneakers são o desenho padrão de cada camada.
			_check(option.style in ["none", "bald", "normal", "sneakers", "male"] or ('"%s"' % option.style) in view_source, "estilo %s tem desenho" % option.style)
	game.free()



## Níveis e preços: básicas de graça, as outras pagas, e o preço médio cresce a cada nível.
func _test_tiers_and_prices() -> void:
	var game := _game()
	var rules: CharacterRules = game.characters.rules()
	var totals := {}
	var counts := {}
	for option in rules.options:
		_check(CharacterRules.TIERS.has(option.tier), "nível conhecido em %s" % option.id)
		if not CharacterRules.is_wear(option.category):
			_check(option.price == 0 and option.tier == "basic", "%s é do corpo: grátis" % option.id)
			continue
		_check((option.tier == "basic") == (option.price == 0), "%s: só básicas são grátis" % option.id)
		totals[option.tier] = int(totals.get(option.tier, 0)) + option.price
		counts[option.tier] = int(counts.get(option.tier, 0)) + 1
	var previous := -1.0
	for tier in ["basic", "common", "premium", "luxury", "exclusive"]:
		_check(counts.get(tier, 0) > 0, "há peças %s" % tier)
		var average := float(totals.get(tier, 0)) / maxi(int(counts.get(tier, 1)), 1)
		_check(average > previous, "preço médio de %s maior que o nível anterior" % tier)
		previous = average
	for category in ["top", "bottom", "shoes", "headwear", "accessory"]:
		var basics := rules.options_for(category).filter(func(o: CharacterOptionDefinition) -> bool: return o.tier == "basic")
		_check(basics.size() >= 2, "%s tem peças básicas para a criação" % category)
	_check(rules.options_for("hair").size() >= 20, "pelo menos 20 cabelos")
	_check(rules.options_for("beard").size() >= 10 and rules.options_for("top").size() >= 20, "barbas e roupas de cima variadas")
	_check(rules.options_for("accessory").size() >= 14, "acessórios variados")
	game.free()


## Sexo e corpo: peças que não combinam saem do visual; o sorteio respeita isso.
func _test_sex_and_build() -> void:
	var game := _game()
	var characters: CharacterSystem = game.characters
	var female := characters.sanitize(_appearance(game, {"sex": "sex_female", "beard": "beard_full", "bottom": "bottom_skirt_black", "build": "build_athletic"}))
	_check(female.sex() == "female" and female.get_choice("beard") == "beard_none", "personagem feminina não tem barba")
	_check(female.get_choice("bottom") == "bottom_skirt_black" and female.get_choice("build") == "build_athletic", "saia e corpo mantidos")
	var male := characters.sanitize(_appearance(game, {"sex": "sex_male", "bottom": "bottom_skirt_black", "top": "top_crop_white", "beard": "beard_anchor"}))
	_check(male.get_choice("bottom") == characters.rules().defaults["bottom"] and male.get_choice("top") == characters.rules().defaults["top"], "peças só femininas saem do masculino")
	_check(male.get_choice("beard") == "beard_anchor", "barba do masculino mantida")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var sexes := {}
	for i in 60:
		var look := characters.random_appearance(rng, true)
		sexes[look.sex()] = true
		var clean := true
		for option_id in look.worn_ids():
			var option: CharacterOptionDefinition = game.wardrobe.find_item(option_id)
			if option == null or not option.allows_sex(look.sex()) or (CharacterRules.is_wear(option.category) and option.tier != "basic"):
				clean = false
		_check(clean, "sorteio inicial %d só com peças básicas e compatíveis" % i)
	_check(sexes.size() == 2, "sorteio gera os dois sexos")
	game.free()


## A criação só aceita peças básicas: o resto é comprado durante a carreira.
func _test_creation_is_basic() -> void:
	_clean_saves()
	var game := _game()
	var fancy := _appearance(game, {"sex": "sex_female", "jacket": "jacket_fur", "top": "top_crop_white", "shoes": "shoes_designer", "hair": "hair_ponytail"}, ["acc_cuban", "acc_studs"])
	_check(_create(game, "Nova Estrela", {"age": 21}, fancy).ok, "cria carreira feminina")
	var look: CharacterAppearance = game.career.appearance
	_check(look.sex() == "female" and look.get_choice("hair") == "hair_ponytail" and look.get_choice("top") == "top_crop_white", "sexo, cabelo e peça básica guardados")
	_check(look.get_choice("jacket") == "jacket_none" and look.get_choice("shoes") == game.characters.rules().defaults["shoes"], "peças caras trocadas pelo padrão")
	_check(not look.has_accessory("acc_cuban") and look.has_accessory("acc_studs"), "só acessórios básicos")
	_check(game.career.wardrobe.is_empty(), "guarda-roupa começa vazio (básicas não contam)")
	game.free()


## Loja: comprar desconta o dinheiro e guarda a peça; sem dinheiro, nada muda; vestir exige a peça.
func _test_shop_and_wardrobe() -> void:
	_clean_saves()
	var game := _game()
	_create(game, "Comprador", {})
	var career: CareerData = game.career
	career.money = 1000
	var leather: CharacterOptionDefinition = game.wardrobe.find_item("jacket_leather")
	var denied: ActionResult = game.buy_wardrobe_item("jacket_leather")
	_check(not denied.ok and "Faltam" in denied.message and career.money == 1000 and career.wardrobe.is_empty(), "sem dinheiro a compra é bloqueada: " + denied.message)
	var look := career.appearance.copy()
	look.set_choice("jacket", "jacket_leather")
	var blocked: ActionResult = game.set_appearance(look)
	_check(not blocked.ok and career.appearance.get_choice("jacket") == "jacket_none", "não veste peça que não comprou: " + blocked.message)
	career.money = 10000
	var bought: ActionResult = game.buy_wardrobe_item("jacket_leather")
	_check(bought.ok and career.money == 10000 - leather.price and career.wardrobe.has("jacket_leather"), "compra desconta e guarda a peça")
	_check(career.finance_history[-1].category == FinanceEntry.CATEGORY_STYLE and career.finance_history[-1].amount == -leather.price, "compra entra nas finanças como roupas")
	_check(not game.buy_wardrobe_item("jacket_leather").ok, "não compra a mesma peça duas vezes")
	_check(game.set_appearance(look).ok and career.appearance.get_choice("jacket") == "jacket_leather", "veste a peça comprada")
	var undressed := career.appearance.copy()
	undressed.set_choice("jacket", "jacket_none")
	_check(game.set_appearance(undressed).ok and career.wardrobe.has("jacket_leather"), "tirar a peça mantém no guarda-roupa")
	# Comprar e vestir de uma vez: tudo ou nada.
	var outfit := career.appearance.copy()
	outfit.set_choice("shoes", "shoes_retro")
	outfit.set_accessory("acc_rings", true)
	var cost: int = game.wardrobe.missing_cost(career, outfit)
	career.money = cost - 1
	_check(not game.buy_and_wear(outfit).ok and career.money == cost - 1 and not career.wardrobe.has("shoes_retro"), "visual caro demais não compra nada")
	career.money = cost + 50
	_check(game.buy_and_wear(outfit).ok and career.money == 50 and career.appearance.has_accessory("acc_rings"), "compra o que falta e veste")
	_check(game.wardrobe.missing(career, outfit).is_empty() and game.wardrobe.wardrobe_value(career) == leather.price + cost, "guarda-roupa soma as peças")
	game.free()


## Cada carreira tem o próprio guarda-roupa, e ele sobrevive a salvar e carregar.
func _test_wardrobe_per_career() -> void:
	_clean_saves()
	var game := _game()
	_create(game, "Primeira", {})
	game.career.money = 50000
	game.buy_wardrobe_item("acc_chain_gold")
	var first: String = game.current_slot
	game.save_game()
	_create(game, "Segunda", {})
	_check(game.career.wardrobe.is_empty(), "carreira nova não herda roupas")
	var second: String = game.current_slot
	game.load_game(first)
	_check(game.career.wardrobe.has("acc_chain_gold"), "guarda-roupa salvo com a carreira")
	game.load_game(second)
	_check(game.career.wardrobe.is_empty(), "inventários não se misturam")
	game.free()


## Save v10 real: sexo, corpo e maquiagem entram no padrão e as peças vestidas viram do jogador.
func _test_v10_migration() -> void:
	_clean_saves()
	DirAccess.make_dir_recursive_absolute(TEST_SAVE_DIR)
	var save_path := TEST_SAVE_DIR.path_join("career.json")
	var fixture_text := FileAccess.get_file_as_string(V10_FIXTURE)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(fixture_text)
	file.close()
	var old_payload: Dictionary = JSON.parse_string(fixture_text)
	var old: Dictionary = old_payload["career"]
	_check(int(old_payload["version"]) == 10, "fixture é v10")
	var game := _game()
	_check(game.load_game(SaveSystem.DEFAULT_SLOT).ok, "carrega save v10 real")
	var career: CareerData = game.career
	_check(FileAccess.get_file_as_string(save_path + ".v10.bak") == fixture_text, "cópia do save v10 guardada")
	_check(career.money == int(old["money"]) and career.fame == int(old["fame"]) and career.songs.size() == old["songs"].size(), "progresso mantido")
	_check(career.vehicles.size() == old["vehicles"].size() and career.infinite_energy == bool(old["infinite_energy"]), "carros e energia mantidos")
	_check(career.appearance.sex() == "male" and career.appearance.get_choice("build") == "build_regular", "sexo e corpo padrão")
	_check(career.appearance.get_choice("jacket") == "jacket_bomber" and career.appearance.has_accessory("acc_chain_gold"), "visual antigo mantido")
	_check(career.wardrobe.has("jacket_bomber") and career.wardrobe.has("acc_chain_gold"), "peças vestidas entram no guarda-roupa")
	_check(game.wardrobe.missing(career, career.appearance).is_empty(), "nada do visual atual precisa ser comprado")
	_check(game.save_game().ok and int(JSON.parse_string(FileAccess.get_file_as_string(save_path))["version"]) == SaveSystem.SAVE_VERSION, "salva no formato novo")
	game.free()


func _clean_saves() -> void:
	if not DirAccess.dir_exists_absolute(TEST_SAVE_DIR):
		return
	for file_name in DirAccess.get_files_at(TEST_SAVE_DIR):
		DirAccess.remove_absolute(TEST_SAVE_DIR.path_join(file_name))
	DirAccess.remove_absolute(TEST_SAVE_DIR)
