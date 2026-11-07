class_name PerformanceSystem
extends RefCounted
## Algoritmo de desempenho dos lançamentos, isolado para ser refinado sem afetar o resto.

class Result:
	var units: int = 0
	var money: int = 0
	var fame: int = 0


var _balance: GameBalance
var _rng: RandomNumberGenerator


func _init(balance: GameBalance, rng: RandomNumberGenerator) -> void:
	_balance = balance
	_rng = rng


## age_weeks é 0 na primeira semana de resultados do lançamento.
## Os multiplicadores permitem que cada formato de projeto renda de um jeito.
func calculate_week(rules: PerformanceRules, quality: int, age_weeks: int, artist_fame: int, units_multiplier: float = 1.0, fame_multiplier: float = 1.0) -> Result:
	var quality_factor := float(quality) / rules.reference_quality
	var age_factor := maxf(pow(rules.weekly_decay, age_weeks), rules.min_age_factor)
	var fame_factor := 1.0 + artist_fame * rules.fame_bonus_per_point

	var result := Result.new()
	var base_units := _rng.randi_range(rules.units_min, rules.units_max)
	var units_before_format := base_units * quality_factor * age_factor * fame_factor
	result.units = roundi(units_before_format * units_multiplier)
	result.money = roundi(result.units * rules.money_per_unit)
	result.fame = floori(roundi(units_before_format) / float(rules.units_per_fame) * fame_multiplier)
	return result


func reputation_change(quality: int, multiplier: float = 1.0) -> int:
	return roundi((quality - _balance.reputation_quality_pivot) * _balance.reputation_per_quality_point * multiplier)
