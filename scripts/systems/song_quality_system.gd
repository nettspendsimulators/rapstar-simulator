class_name SongQualitySystem
extends RefCounted
## Cálculo da nota de uma música, isolado para ser refinado sem afetar o resto.

var _rules: SongQualityRules
var _catalog: CollaboratorCatalog


func _init(balance: GameBalance) -> void:
	_rules = balance.song_quality
	_catalog = balance.collaborators


## roll vai de -1 a 1 e define para que lado a variação do time pende.
func beat_score(credits: SongCredits, roll: float) -> int:
	return _group_score(CollaboratorCatalog.resolve(_catalog.beatmakers, credits.beatmaker_ids), roll)


func production_score(credits: SongCredits, roll: float) -> int:
	return _group_score(CollaboratorCatalog.resolve(_catalog.producers, credits.producer_ids), roll)


func feats_score(credits: SongCredits) -> int:
	return _group_score(CollaboratorCatalog.resolve(_catalog.feats, credits.feat_ids), 0.0)


## Nota de um atributo que depende só do próprio artista, como Vocal e Letra.
func solo_score(roll: float) -> int:
	return _group_score([], roll)


## Nota geral: média dos atributos e das participações, pelos pesos configurados.
func overall(attribute_values: Dictionary, feat_value: int) -> int:
	var total: float = feat_value * _rules.feats_weight
	for attribute in _rules.attributes:
		total += attribute_values.get(attribute.id, 0) * attribute.weight
	return clampi(roundi(total), 0, 100)


## Maior nota que um atributo pode alcançar com melhorias.
func attribute_limit(base_value: int) -> int:
	return mini(base_value + _rules.max_improvement_points, 100)


func _group_score(people: Array[CollaboratorDefinition], roll: float) -> int:
	var skill := float(_rules.solo_skill)
	var consistency := float(_rules.solo_consistency)
	if not people.is_empty():
		skill = 0.0
		consistency = 0.0
		for person in people:
			skill += person.skill
			consistency += person.consistency
		skill /= people.size()
		consistency /= people.size()
		skill += _rules.team_bonus_per_extra * (people.size() - 1)
	var variance := roll * _rules.max_variance * (100.0 - consistency) / 100.0
	return clampi(roundi(skill + variance), 0, 100)
