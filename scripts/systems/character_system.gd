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


## Remove peças que não existem mais, completa categorias faltando com o padrão e troca peças
## que não combinam com o sexo escolhido (barba numa personagem feminina, saia num masculino).
func sanitize(appearance: CharacterAppearance) -> CharacterAppearance:
	var clean := default_appearance()
	if appearance == null:
		return clean
	if rules().find_option("sex", appearance.get_choice("sex")) != null:
		clean.choices["sex"] = appearance.get_choice("sex")
	var sex := clean.sex()
	for item: Dictionary in CharacterRules.CATEGORIES:
		var category: String = item["id"]
		if CharacterRules.is_multiple(category):
			continue
		var found := rules().find_option(category, appearance.get_choice(category))
		if found != null and found.allows_sex(sex):
			clean.choices[category] = found.id
	for option_id in appearance.accessories:
		var found := rules().find_option("accessory", option_id)
		if found != null and found.allows_sex(sex) and not clean.has_accessory(option_id):
			clean.accessories.append(option_id)
	return clean


## Só peças básicas: roupas e acessórios melhores são comprados durante a carreira.
func starter_only(appearance: CharacterAppearance) -> CharacterAppearance:
	var clean := sanitize(appearance)
	for category: String in CharacterRules.WEAR_CATEGORIES:
		if CharacterRules.is_multiple(category):
			continue
		var found := rules().find_option(category, clean.get_choice(category))
		if found != null and found.tier != "basic":
			clean.choices[category] = rules().defaults.get(category, "")
	clean.accessories.assign(clean.accessories.filter(func(option_id: String) -> bool:
		return rules().find_option("accessory", option_id).tier == "basic"))
	return clean


## Opções de uma categoria que combinam com o sexo (e, se pedido, só as básicas).
func options_for(category: String, sex: String, starter: bool = false) -> Array[CharacterOptionDefinition]:
	var result: Array[CharacterOptionDefinition] = []
	for candidate in rules().options_for(category):
		if candidate.allows_sex(sex) and (not starter or candidate.tier == "basic" or not CharacterRules.is_wear(category)):
			result.append(candidate)
	return result


## Peça escolhida numa categoria, já resolvida para a definição (cai no padrão se faltar).
func option(appearance: CharacterAppearance, category: String) -> CharacterOptionDefinition:
	var found := rules().find_option(category, appearance.get_choice(category) if appearance != null else "")
	if found == null:
		found = rules().find_option(category, rules().defaults.get(category, ""))
	return found


## Visual sorteado. "starter" limita roupas e acessórios às peças básicas (criação da carreira).
## Personagens femininas não sorteiam barba; masculinos raramente usam maquiagem.
func random_appearance(rng: RandomNumberGenerator, starter: bool = false) -> CharacterAppearance:
	var appearance := CharacterAppearance.new()
	appearance.choices["sex"] = "sex_female" if rng.randf() < 0.5 else "sex_male"
	var sex := appearance.sex()
	for item: Dictionary in CharacterRules.CATEGORIES:
		var category: String = item["id"]
		if category == "sex":
			continue
		var options := options_for(category, sex, starter)
		if options.is_empty():
			continue
		if CharacterRules.is_multiple(category):
			for candidate in options:
				if rng.randf() < 0.2:
					appearance.accessories.append(candidate.id)
		elif category == "makeup" and sex == "male" and rng.randf() < 0.85:
			appearance.choices[category] = "makeup_none"
		elif category == "beard" and rng.randf() < 0.3:
			appearance.choices[category] = "beard_none"
		else:
			appearance.choices[category] = options[rng.randi() % options.size()].id
	return sanitize(appearance)


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
