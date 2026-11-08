extends SceneTree
## Testes dos carros, dos novos rappers, dos feats com o sistema social e da Energia Infinita
## escolhida na criação. Para rodar:
##   godot --headless --path . --script res://tests/test_content.gd

const GameManagerScript := preload("res://scripts/core/game_manager.gd")
const TEST_SAVE_DIR := "user://test_saves_content"
const V9_FIXTURE := "res://tests/fixtures/save_v9.json"
const TABLE_CARS := {
	"Toyota Camry XSE": 35000, "BMW 330i": 50000, "Audi RS 7 Performance": 130000, "Porsche Panamera": 105000,
	"Cadillac Escalade": 90000, "GMC Yukon Denali": 80000, "Chevrolet Tahoe": 60000, "Range Rover Sport": 90000,
	"BMW X6 M Competition": 135000, "Land Rover Defender 110": 65000, "Ford F-150 Raptor": 80000, "Chevrolet Camaro ZL1": 75000,
	"Ford Mustang Dark Horse": 62000, "Chevrolet Corvette Z06": 110000, "Nissan GT-R NISMO": 220000, "Ferrari 296 GTB": 350000,
	"McLaren 750S": 350000, "Lamborghini Revuelto": 600000, "Rolls-Royce Spectre": 400000,
}
const FOLDER_ONLY := ["Bentley Bentayga", "BMW M4 Competition", "Dodge Challenger Widebody", "Dodge Charger R/T", "Ferrari 488 GTB",
	"Infiniti Q50 Red Sport 400", "Lamborghini Aventador SVJ", "Lamborghini Urus S", "McLaren 720S", "Mercedes-AMG G 63",
	"Mercedes-Maybach S 680", "Porsche 911 Turbo S", "Rolls-Royce Cullinan", "Rolls-Royce Ghost", "Mercedes-Benz E 450 All-Terrain"]
const US_RAPPERS := ["Ken Carson", "Destroy Lonely", "Homixide Beno", "Homixide Meechie", "BabyTron", "Rio Da Yung Og", "RMC Mike",
	"Doe Boy", "Sada Baby", "Babyface Ray", "Icewear Vezzo", "Veeze", "Rylo Rodriguez", "NoCap", "BabyDrill", "Hunxho",
	"Hurricane Wisdom", "BunnaB", "Zeddy Will", "S5", "Yhapojj", "xaviersobased", "Skeletrix", "Fakemink", "Rico Ace",
	"Loe Shimmy", "Samara Cyn", "Cash Cobain", "Chy Cartier", "Jawnino"]
const UK_RAPPERS := ["Central Cee", "Dave", "Little Simz", "Skepta", "J Hus", "Headie One", "Unknown T", "Knucks", "Pozer",
	"Mazza L20", "YT", "Feng", "TeeboFG", "SINN6R", "Ciel", "Len", "Caldo", "Reuben Aziz", "Ashbeck", "Namesbliss"]

var _failures := 0
var _checks := 0


func _init() -> void:
	_clean()
	_test_vehicle_catalog()
	_test_buying_and_garage()
	_test_artists()
	_test_feat_prices()
	_test_infinite_energy_from_creation()
	_test_v9_migration()
	_clean()
	print("%d verificações, %d falhas" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FALHOU: ", label)


func _game(money: int = 10000000, fame: int = 100) -> Node:
	var game: Node = GameManagerScript.new()
	game.rng.seed = 7
	game.saves.save_dir = TEST_SAVE_DIR
	game.new_career("MC Garagem")
	game.career.money = money
	game.career.fame = fame
	return game


func _vehicle_named(game: Node, name: String) -> VehicleDefinition:
	for vehicle: VehicleDefinition in game.vehicles.catalog():
		if vehicle.display_name() == name:
			return vehicle
	return null


func _artist_named(game: Node, name: String) -> CollaboratorDefinition:
	for person: CollaboratorDefinition in game.balance.collaborators.feats:
		if person.display_name == name:
			return person
	return null


# ---- carros

func _test_vehicle_catalog() -> void:
	var game := _game()
	var catalog: Array = game.vehicles.catalog()
	_check(catalog.size() == 34, "34 carros (os 20 da lista e os 14 que só estavam na pasta)")
	for name: String in TABLE_CARS:
		var vehicle := _vehicle_named(game, name)
		_check(vehicle != null, "carro da lista: %s" % name)
		if vehicle != null:
			_check(vehicle.price == TABLE_CARS[name], "preço de %s" % name)
	for name in FOLDER_ONLY:
		_check(_vehicle_named(game, name) != null, "carro da pasta: %s" % name)
	var ids := {}
	for vehicle: VehicleDefinition in catalog:
		_check(not ids.has(vehicle.id), "id único: %s" % vehicle.id)
		ids[vehicle.id] = true
		_check(vehicle.image != null and vehicle.image.get_width() > 100, "imagem carregada: %s" % vehicle.id)
		_check(VehicleRules.CATEGORIES.has(vehicle.category), "categoria válida: %s" % vehicle.id)
		_check(vehicle.price > 0 and vehicle.year >= 2019 and vehicle.year <= 2025, "preço e ano: %s" % vehicle.id)
	var categories := {}
	for vehicle: VehicleDefinition in catalog:
		categories[vehicle.category] = true
	_check(categories.size() == VehicleRules.CATEGORIES.size(), "todas as categorias têm carros")
	game.free()


func _test_buying_and_garage() -> void:
	_clean()
	var game := _game(100000)
	var vehicles: VehicleSystem = game.vehicles
	var camry := _vehicle_named(game, "Toyota Camry XSE")
	var revuelto := _vehicle_named(game, "Lamborghini Revuelto")
	var money: int = game.career.money
	_check(not game.buy_vehicle(revuelto.id).ok and game.career.money == money, "sem dinheiro não compra")
	_check(vehicles.purchase_block(game.career, revuelto.id).begins_with("Faltam"), "mostra quanto falta")
	var bought: ActionResult = game.buy_vehicle(camry.id)
	_check(bought.ok and game.career.money == money - camry.price, "compra paga o preço")
	_check(vehicles.is_owned(game.career, camry.id) and vehicles.garage(game.career)[0] == camry, "carro na garagem")
	_check(not game.buy_vehicle(camry.id).ok, "não compra o mesmo carro duas vezes")
	_check(game.career.finance_history[-1].category == FinanceEntry.CATEGORY_VEHICLE, "compra no histórico financeiro")
	game.career.money = 10000000
	game.buy_vehicle(revuelto.id)
	_check(vehicles.garage_value(game.career) == camry.price + revuelto.price, "valor da garagem")
	game.save_game()
	var other := _game()
	other.load_game()
	_check(other.career.vehicles.size() == 2 and other.vehicles.is_owned(other.career, revuelto.id), "garagem salva e carregada")
	other.free()
	game.free()


# ---- artistas e feats

func _test_artists() -> void:
	var game := _game()
	var feats: Array = game.balance.collaborators.feats
	var names := {}
	var ids := {}
	for person: CollaboratorDefinition in feats:
		_check(not names.has(person.display_name), "sem nome duplicado: %s" % person.display_name)
		_check(not ids.has(String(person.id)), "sem id duplicado: %s" % person.id)
		names[person.display_name] = true
		ids[String(person.id)] = true
		_check(not person.country.is_empty() and not person.tier_label().is_empty(), "país e nível: %s" % person.display_name)
	for name in US_RAPPERS + UK_RAPPERS:
		var person := _artist_named(game, name)
		_check(person != null, "rapper cadastrado: %s" % name)
	for name in UK_RAPPERS:
		_check(_artist_named(game, name).country == "Reino Unido", "%s do Reino Unido" % name)
	_check(_artist_named(game, "Ken Carson").country == "Estados Unidos", "rapper dos EUA")
	_check(_artist_named(game, "Drake").cost == 500000, "artista antigo mantém o cachê")
	var costs := {}
	for name in US_RAPPERS + UK_RAPPERS:
		costs[_artist_named(game, name).cost] = true
	_check(costs.size() >= 15, "cachês individuais, não um preço único")
	var ranges := {"underground": [5000, 25000], "emerging": [15000, 50000], "mid": [30000, 100000], "big": [75000, 200000], "superstar": [150000, 1000000]}
	var tiers := {}
	for name in US_RAPPERS + UK_RAPPERS:
		var person := _artist_named(game, name)
		tiers[person.tier] = true
		var bounds: Array = ranges[person.tier]
		_check(person.cost >= bounds[0] and person.cost <= bounds[1], "cachê de %s dentro da faixa %s" % [name, person.tier_label()])
	_check(tiers.size() == 5, "mistura de underground, emergentes, médios, grandes e superstars")
	_check(_artist_named(game, "Dave").cost > _artist_named(game, "Ashbeck").cost, "relevância define o cachê")
	var social: SocialSystem = game.social
	var newcomer := String(_artist_named(game, "Skeletrix").id)
	_check(social.person(newcomer) != null and newcomer in game.social.artists().map(func(item: CollaboratorDefinition) -> String: return String(item.id)), "novos artistas no sistema social")
	var pool: Array = game.festivals._artist_pool()
	_check(pool.any(func(item: CollaboratorDefinition) -> bool: return item.display_name == "Skeletrix"), "novos artistas nos line-ups de festivais")
	game.free()


func _test_feat_prices() -> void:
	var game := _game(2000000, 3000)
	var social: SocialSystem = game.social
	var person := _artist_named(game, "Babyface Ray")
	var artist_id := String(person.id)
	var credits := SongCredits.new()
	credits.feat_ids = [artist_id]
	_check(game.music.hiring_cost(credits, null, game.career) == person.cost, "desconhecido paga o cachê base")
	var relation: Relationship = social.relation(game.career, artist_id)
	relation.met = true
	var previous := person.cost + 1
	for value in [0, 15, 30, 50, 70]:
		relation.value = value
		var price: int = game.music.hiring_cost(credits, null, game.career)
		_check(price < previous, "amizade reduz o preço (%d): %s" % [value, Fmt.money(price)])
		previous = price
	relation.value = -5
	_check(game.music.hiring_cost(credits, null, game.career) == person.cost, "relação neutra paga o base")
	relation.value = -20
	_check(game.music.hiring_cost(credits, null, game.career) > person.cost, "tensão encarece")
	relation.value = -40
	_check(not game.create_song("Rival", credits).ok, "inimizade impede o feat")
	relation.value = 90
	_check(game.music.hiring_cost(credits, null, game.career) == 0, "melhor amigo do seu nível: feat grátis")
	var money: int = game.career.money
	var song: ActionResult = game.create_song("Grátis", credits)
	_check(song.ok and game.career.money == money - game.balance.song_production_cost, "contratação grátis cobra só a produção")
	_check(game.music.hiring_cost(credits, null, game.career) > 0, "grátis só de tempos em tempos")
	var poor := _game(500, 3000)
	var poor_credits := SongCredits.new()
	poor_credits.feat_ids = [String(_artist_named(poor, "Dave").id)]
	var refused: ActionResult = poor.create_song("Sem grana", poor_credits)
	_check(not refused.ok and refused.message.contains("Dinheiro insuficiente"), "dinheiro insuficiente para o feat")
	poor.free()
	game.save_game()
	var reloaded := _game()
	reloaded.load_game()
	_check(reloaded.career.social.relations.has(artist_id) and reloaded.career.find_song(song.value.id).credits.feat_ids == credits.feat_ids, "feat e relação salvos")
	reloaded.free()
	game.free()


# ---- energia

func _test_infinite_energy_from_creation() -> void:
	_clean()
	var game := _game()
	var on: ActionResult = game.create_career("Sem Cansaço", {"infinite_energy": true}, game.characters.default_appearance())
	var slot_on: String = game.current_slot
	_check(on.ok and game.career.infinite_energy, "criação com Energia Infinita ligada")
	var song: SongData = game.create_song("Demo").value
	var attribute: String = game.balance.song_quality.attributes[0].id
	var energy: int = game.career.energy
	game.improve_song(song.id, attribute)
	_check(game.career.energy == energy, "ligada: não consome energia")
	game.save_game()
	game.create_career("Normal", {"infinite_energy": false}, game.characters.default_appearance())
	var slot_off: String = game.current_slot
	_check(not game.career.infinite_energy, "criação com Energia Infinita desligada")
	var normal_song: SongData = game.create_song("Demo").value
	energy = game.career.energy
	game.improve_song(normal_song.id, attribute)
	_check(game.career.energy < energy, "desligada: consome normalmente")
	game.save_game()
	game.create_career("Padrão", {}, game.characters.default_appearance())
	_check(not game.career.infinite_energy, "sem escolher, fica desligada")
	game.load_game(slot_on)
	_check(game.career.infinite_energy, "configuração restaurada ao carregar")
	game.load_game(slot_off)
	_check(not game.career.infinite_energy, "cada carreira com a sua configuração")
	game.free()


func _test_v9_migration() -> void:
	_clean()
	DirAccess.make_dir_recursive_absolute(TEST_SAVE_DIR)
	var save_path := TEST_SAVE_DIR.path_join("career.json")
	var fixture_text := FileAccess.get_file_as_string(V9_FIXTURE)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(fixture_text)
	file.close()
	var payload: Dictionary = JSON.parse_string(fixture_text)
	var old: Dictionary = payload["career"]
	_check(int(payload["version"]) == 9, "fixture é v9")
	var game: Node = GameManagerScript.new()
	game.saves.save_dir = TEST_SAVE_DIR
	_check(game.load_game().ok, "carrega save v9 real")
	var career: CareerData = game.career
	_check(career.money == int(old["money"]) and career.fame == int(old["fame"]) and career.songs.size() == old["songs"].size(), "progresso preservado")
	_check(career.live_shows.size() == old["live_shows"].size() and career.social.relations.size() == old["social"]["relations"].size(), "shows e relações preservados")
	_check(career.infinite_energy == bool(old["infinite_energy"]), "Energia Infinita preservada")
	_check(career.vehicles.is_empty(), "garagem começa vazia")
	var legacy := old.duplicate(true)
	legacy.erase("infinite_energy")
	var legacy_payload := {"version": 7, "career": legacy}
	SaveMigration.migrate(legacy_payload, game.balance)
	_check(legacy_payload["career"]["infinite_energy"] == false, "save antigo sem o campo: Energia Infinita desligada")
	_check(game.save_game().ok and int(JSON.parse_string(FileAccess.get_file_as_string(save_path))["version"]) == SaveSystem.SAVE_VERSION, "salva no formato novo")
	game.free()


func _clean() -> void:
	if not DirAccess.dir_exists_absolute(TEST_SAVE_DIR):
		return
	for file_name in DirAccess.get_files_at(TEST_SAVE_DIR):
		DirAccess.remove_absolute(TEST_SAVE_DIR.path_join(file_name))
	DirAccess.remove_absolute(TEST_SAVE_DIR)
