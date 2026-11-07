class_name GameBalance
extends Resource
## Todos os valores configuráveis do jogo. A instância fica em data/game_balance.tres.

@export_group("Início de carreira")
@export var starting_money: int = 500
@export var starting_fame: int = 0
@export var starting_reputation: int = 0
@export var starting_week: int = 1

@export_group("Energia")
@export var max_energy: int = 100
## Energia recuperada a cada semana.
@export var energy_per_week: int = 100

@export_group("Trabalhos")
@export var jobs: Array[JobDefinition] = []

@export_group("Músicas")
@export var song_production_cost: int = 100
@export var song_release_cost: int = 50
@export var song_quality: SongQualityRules
@export var collaborators: CollaboratorCatalog

@export_group("Capas")
## As capas são recortadas em quadrado e salvas neste tamanho, em pixels.
@export var cover_size: int = 512

@export_group("Projetos")
@export var album_formats: Array[AlbumFormatDefinition] = []

@export_group("Agendamento")
@export var max_schedule_weeks_ahead: int = 52

@export_group("Desempenho")
@export var song_performance: PerformanceRules
@export var album_performance: PerformanceRules

@export_group("Reputação")
## Lançamentos acima desta qualidade dão reputação; abaixo, tiram.
@export var reputation_quality_pivot: int = 50
@export var reputation_per_quality_point: float = 0.1


func find_job(job_id: StringName) -> JobDefinition:
	for job in jobs:
		if job.id == job_id:
			return job
	return null


func find_album_format(format_id: StringName) -> AlbumFormatDefinition:
	for album_format in album_formats:
		if album_format.id == format_id:
			return album_format
	return null
