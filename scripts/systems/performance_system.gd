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

	var result := Result.new()
	var base_units := _rng.randi_range(rules.units_min, rules.units_max)
	var units_before_fame := base_units * quality_factor * age_factor
	result.units = roundi(units_before_fame * fame_factor(rules, artist_fame) * units_multiplier)
	result.money = roundi(result.units * rules.money_per_unit)
	# A fama ganha não considera a fama atual, para as duas não se multiplicarem sem limite.
	result.fame = floori(roundi(units_before_fame) / float(rules.units_per_fame) * fame_multiplier)
	return result


func fame_factor(rules: PerformanceRules, artist_fame: int) -> float:
	return minf(1.0 + artist_fame * rules.fame_bonus_per_point, rules.max_fame_factor)


## Tamanho do público de uma música, sorteado uma vez no lançamento.
func roll_base_units(rules: PerformanceRules) -> int:
	return _rng.randi_range(rules.units_min, rules.units_max)


## Reproduções de uma música em uma semana. Ao contrário de calculate_week, parte de um público
## fixo, então a evolução semanal depende dos fatores e não de um novo sorteio.
func stream_units(rules: PerformanceRules, base_units: int, quality: int, artist_fame: int, multiplier: float, noise: float) -> int:
	var quality_factor := float(quality) / rules.reference_quality
	return roundi(base_units * quality_factor * fame_factor(rules, artist_fame) * multiplier * _rng.randf_range(1.0 - noise, 1.0 + noise))


func reputation_change(quality: int, multiplier: float = 1.0) -> int:
	return roundi((quality - _balance.reputation_quality_pivot) * _balance.reputation_per_quality_point * multiplier)
