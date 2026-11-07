class_name SongQualitySystem
extends RefCounted
## Cálculo da nota de uma música, isolado para ser refinado sem afetar o resto.

class Result:
	var beat: int = 0
	var production: int = 0
	var feats: int = 0
	var base: int = 0


var _rules: SongQualityRules
var _catalog: CollaboratorCatalog


func _init(balance: GameBalance) -> void:
	_rules = balance.song_quality
	_catalog = balance.collaborators


## beat_roll e production_roll vão de -1 a 1 e definem para que lado a variação do time pende.
func calculate(credits: SongCredits, beat_roll: float, production_roll: float) -> Result:
	var result := Result.new()
	result.beat = _group_score(CollaboratorCatalog.resolve(_catalog.beatmakers, credits.beatmaker_ids), beat_roll)
	result.production = _group_score(CollaboratorCatalog.resolve(_catalog.producers, credits.producer_ids), production_roll)
	result.feats = _group_score(CollaboratorCatalog.resolve(_catalog.feats, credits.feat_ids), 0.0)
	var total := result.beat * _rules.beat_weight \
		+ result.production * _rules.production_weight \
		+ result.feats * _rules.feats_weight
	result.base = clampi(roundi(total), 0, 100)
	return result


## Maior nota que a música pode alcançar com melhorias.
func improvement_limit(base_quality: int) -> int:
	return mini(base_quality + _rules.max_improvement_points, 100)


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
