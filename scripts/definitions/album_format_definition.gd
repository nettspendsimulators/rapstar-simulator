class_name AlbumFormatDefinition
extends Resource
## Formato de projeto coletivo (EP, álbum, mixtape). Novos formatos são novas entradas deste tipo.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String = ""
@export var min_songs: int = 3
@export var max_songs: int = 20
@export var base_cost: int = 200
@export var cost_per_song: int = 25
@export var release_cost: int = 150
@export var units_multiplier: float = 1.0
@export var fame_multiplier: float = 1.0
@export var reputation_multiplier: float = 1.0


func production_cost(song_count: int) -> int:
	return base_cost + cost_per_song * song_count


func accepts_song_count(song_count: int) -> bool:
	return song_count >= min_songs and song_count <= max_songs


## Progresso até o mínimo para lançar, como "Álbum — 4/7 músicas".
func progress_text(song_count: int) -> String:
	return "%s — %d/%d músicas" % [display_name, song_count, min_songs]


## Texto mostrado ao jogador para explicar o formato, sempre coerente com os valores configurados.
func summary() -> String:
	return "%s: lança com %d a %d músicas e pode ser criado vazio. %s\nProdução: %s + %s por música. Lançamento: %s. Vendas x%s, fama x%s, reputação x%s." % [
		display_name,
		min_songs,
		max_songs,
		description,
		Fmt.money(base_cost),
		Fmt.money(cost_per_song),
		Fmt.money(release_cost),
		_multiplier_text(units_multiplier),
		_multiplier_text(fame_multiplier),
		_multiplier_text(reputation_multiplier),
	]


func _multiplier_text(value: float) -> String:
	return str(snappedf(value, 0.01)).replace(".", ",")
