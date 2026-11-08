class_name CharacterSystem
extends RefCounted
## Identidade e aparência do personagem. A mesma lógica serve à criação e à personalização
## durante a carreira; a aparência é só mais um dado da CareerData.

var _balance: GameBalance


func _init(balance: GameBalance) -> void:
	_balance = balance


func rules() -> CharacterRules:
	return _balance.character


func default_appearance() -> CharacterAppearance:
	var appearance := CharacterAppearance.new()
	for category: String in rules().defaults:
		appearance.choices[category] = rules().defaults[category]
	return appearance


## Remove peças que não existem mais e completa categorias faltando com o padrão.
func sanitize(appearance: CharacterAppearance) -> CharacterAppearance:
	var clean := default_appearance()
	if appearance == null:
		return clean
	for item: Dictionary in CharacterRules.CATEGORIES:
		var category: String = item["id"]
		if CharacterRules.is_multiple(category):
			continue
		if rules().find_option(category, appearance.get_choice(category)) != null:
			clean.choices[category] = appearance.get_choice(category)
	for option_id in appearance.accessories:
		if rules().find_option("accessory", option_id) != null and not clean.has_accessory(option_id):
			clean.accessories.append(option_id)
	return clean


## Peça escolhida numa categoria, já resolvida para a definição (cai no padrão se faltar).
func option(appearance: CharacterAppearance, category: String) -> CharacterOptionDefinition:
	var found := rules().find_option(category, appearance.get_choice(category) if appearance != null else "")
	if found == null:
		found = rules().find_option(category, rules().defaults.get(category, ""))
	return found


func random_appearance(rng: RandomNumberGenerator) -> CharacterAppearance:
	var appearance := CharacterAppearance.new()
	for item: Dictionary in CharacterRules.CATEGORIES:
		var category: String = item["id"]
		var options := rules().options_for(category)
		if options.is_empty():
			continue
		if CharacterRules.is_multiple(category):
			for candidate in options:
				if rng.randf() < 0.25:
					appearance.accessories.append(candidate.id)
		else:
			appearance.choices[category] = options[rng.randi() % options.size()].id
	return appearance


## Idade atual: a idade do início da carreira mais os anos que passaram no calendário do jogo.
func current_age(career: CareerData) -> int:
	return career.age + maxi(career.current_week - _balance.starting_week, 0) / rules().weeks_per_year


func age_at(start_age: int, week: int) -> int:
	return start_age + maxi(week - _balance.starting_week, 0) / rules().weeks_per_year


## Valida e aplica nome real, idade, país e cidade.
func apply_identity(career: CareerData, identity: Dictionary) -> ActionResult:
	var age := int(identity.get("age", rules().default_age))
	if age < rules().min_age or age > rules().max_age:
		return ActionResult.failure("A idade precisa ficar entre %d e %d anos." % [rules().min_age, rules().max_age])
	career.real_name = String(identity.get("real_name", "")).strip_edges()
	career.age = age
	career.country = String(identity.get("country", rules().default_country)).strip_edges()
	if career.country.is_empty():
		career.country = rules().default_country
	career.city = String(identity.get("city", "")).strip_edges()
	return ActionResult.success()


func location_label(country: String, city: String) -> String:
	return country if city.is_empty() else "%s, %s" % [city, country]
