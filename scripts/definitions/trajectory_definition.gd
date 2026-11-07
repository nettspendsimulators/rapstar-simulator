class_name TrajectoryDefinition
extends Resource
## Um comportamento possível de uma música ao longo das semanas, como hit imediato ou fracasso.

## Sorteia a plataforma que concentra o sucesso, entre as que mais combinam com a música.
const SPOTLIGHT_AUTO := "auto"

@export var id: String
@export var label: String

@export_group("Curva")
## Multiplicador de reproduções na primeira semana.
@export var debut: float = 1.0
## Semanas até chegar a ramp_peak. Zero quando não há crescimento gradual.
@export var ramp_weeks: int = 0
@export var ramp_peak: float = 1.0
## Parte das reproduções que permanece a cada semana depois do pico.
@export var weekly_decay: float = 0.9
@export var floor_value: float = 0.1

@export_group("Surto")
## Quanto as reproduções sobem de repente. Zero quando não há surto.
@export var surge_boost: float = 0.0
@export var surge_decay: float = 0.8
@export var surge_week_min: int = 2
@export var surge_week_max: int = 6

@export_group("Plataforma")
## Id da plataforma que concentra o sucesso, ou "auto". Vazio para distribuição normal.
@export var spotlight_platform: String = ""
@export var spotlight_boost: float = 1.0

@export_group("Chance")
## Peso no sorteio da trajetória, antes dos fatores abaixo.
@export var base_weight: float = 1.0
## Fatores somados ao peso. Positivo favorece esta trajetória, negativo a torna menos provável.
@export var quality_weight: float = 0.0
@export var hype_weight: float = 0.0
@export var fame_weight: float = 0.0
@export var attention_weight: float = 0.0


func multiplier(age_weeks: int, surge_week: int) -> float:
	var value: float
	if ramp_weeks > 0 and age_weeks < ramp_weeks:
		value = lerpf(debut, ramp_peak, float(age_weeks) / ramp_weeks)
	else:
		var start := ramp_peak if ramp_weeks > 0 else debut
		value = maxf(start * pow(weekly_decay, age_weeks - ramp_weeks), floor_value)
	if surge_boost > 0.0 and surge_week >= 0 and age_weeks >= surge_week:
		value += surge_boost * pow(surge_decay, age_weeks - surge_week)
	return value
