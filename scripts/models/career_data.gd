class_name CareerData
extends RefCounted
## Estado completo de uma carreira: é a única fonte de dados e o que vai para o save.

var artist_name: String = ""
## Identidade pessoal. O nome artístico é a identidade pública; o nome real só aparece no perfil.
var real_name: String = ""
## Idade no início da carreira. A idade atual cresce com o calendário (CharacterSystem.current_age).
var age: int = 20
var country: String = ""
var city: String = ""
var appearance := CharacterAppearance.new()
## Configuração própria da carreira: atividades não gastam energia.
var infinite_energy: bool = false
## Relações com os artistas, beefs e convites desta carreira.
var social := SocialData.new()
## Carros comprados (garagem).
var vehicles: Array[OwnedVehicle] = []
## Peças de roupa e acessórios comprados (ids de data/character.tres). Básicas não entram aqui.
var wardrobe: Array[String] = []
## Gravadoras: contrato, propostas, gravadora própria e catálogo sob selo.
var label := LabelData.new()
## Foto do perfil público, gerenciada pelo CoverSystem.
var artist_cover: String = ""
## Texto próprio do perfil. Vazio usa a descrição automática, que muda com a carreira.
var artist_bio: String = ""
var money: int = 0
var fame: int = 0
var reputation: int = 0
var energy: int = 0
var current_week: int = 1
var songs: Array[SongData] = []
var albums: Array[AlbumData] = []
var releases: Array[ReleaseData] = []
var scheduled_releases: Array[ScheduledRelease] = []
var marketing_campaigns: Array[MarketingCampaign] = []
var song_performances: Array[SongPerformance] = []
var platform_stats: Dictionary[String, ArtistPlatformStats] = {}
var performance_snapshots: Array[PerformanceSnapshot] = []
var music_videos: Array[MusicVideo] = []
var live_shows: Array[LiveShow] = []
var live_tours: Array[LiveTour] = []
var merch_items: Array[MerchItem] = []
var festival_editions: Array[FestivalEdition] = []
var finance_history: Array[FinanceEntry] = []
var week_reports: Array[WeekReport] = []
var next_id: int = 1


static func create(name: String, balance: GameBalance) -> CareerData:
	var career := CareerData.new()
	career.artist_name = name
	career.money = balance.starting_money
	career.fame = balance.starting_fame
	career.reputation = balance.starting_reputation
	career.energy = balance.max_energy
	career.current_week = balance.starting_week
	return career


func new_id(prefix: String) -> String:
	var id := "%s_%d" % [prefix, next_id]
	next_id += 1
	return id


func find_song(id: String) -> SongData:
	for song in songs:
		if song.id == id:
			return song
	return null


func find_content(id: String) -> ReleasableContent:
	var song := find_song(id)
	if song != null:
		return song
	for album in albums:
		if album.id == id:
			return album
	return null


func find_release(content_id: String) -> ReleaseData:
	for release in releases:
		if release.content_id == content_id:
			return release
	return null


func find_active_schedule(content_id: String) -> ScheduledRelease:
	for schedule in scheduled_releases:
		if schedule.content_id == content_id and schedule.is_active():
			return schedule
	return null


func find_campaign(content_id: String) -> MarketingCampaign:
	for campaign in marketing_campaigns:
		if campaign.content_id == content_id:
			return campaign
	return null


func find_live_show(show_id: String) -> LiveShow:
	for show in live_shows:
		if show.id == show_id:
			return show
	return null


func find_tour(tour_id: String) -> LiveTour:
	for tour in live_tours:
		if tour.id == tour_id:
			return tour
	return null


func find_merch(item_id: String) -> MerchItem:
	for item in merch_items:
		if item.id == item_id:
			return item
	return null


func find_edition(edition_id: String) -> FestivalEdition:
	for edition in festival_editions:
		if edition.id == edition_id:
			return edition
	return null


func find_edition_for(festival_id: String, year: int) -> FestivalEdition:
	for edition in festival_editions:
		if edition.festival_id == festival_id and edition.year == year:
			return edition
	return null


func find_video(video_id: String) -> MusicVideo:
	for video in music_videos:
		if video.id == video_id:
			return video
	return null


func find_video_for_song(song_id: String) -> MusicVideo:
	for video in music_videos:
		if video.song_id == song_id:
			return video
	return null


func find_performance(song_id: String) -> SongPerformance:
	for performance in song_performances:
		if performance.song_id == song_id:
			return performance
	return null


## Perfil do artista em uma plataforma, criado na primeira vez em que é usado.
func platform_stats_for(platform_id: String) -> ArtistPlatformStats:
	if not platform_stats.has(platform_id):
		var stats := ArtistPlatformStats.new()
		stats.platform_id = platform_id
		platform_stats[platform_id] = stats
	return platform_stats[platform_id]


func find_album_of_song(song_id: String) -> AlbumData:
	for album in albums:
		if song_id in album.song_ids:
			return album
	return null


## A nota de um projeto é a média das notas das suas músicas.
func average_quality(song_ids: Array[String]) -> int:
	if song_ids.is_empty():
		return 0
	var total := 0
	for song_id in song_ids:
		total += find_song(song_id).quality
	return roundi(float(total) / song_ids.size())


## Mantém as notas dos projetos não lançados de acordo com as músicas deles.
func refresh_album_qualities() -> void:
	for album in albums:
		if not album.is_released():
			album.quality = average_quality(album.song_ids)


func last_report() -> WeekReport:
	return week_reports.back() if not week_reports.is_empty() else null


func to_dict() -> Dictionary:
	return {
		"artist_name": artist_name,
		"real_name": real_name,
		"age": age,
		"country": country,
		"city": city,
		"appearance": appearance.to_dict(),
		"infinite_energy": infinite_energy,
		"social": social.to_dict(),
		"vehicles": vehicles.map(func(item: OwnedVehicle) -> Dictionary: return item.to_dict()),
		"wardrobe": wardrobe.duplicate(),
		"label": label.to_dict(),
		"artist_cover": artist_cover,
		"artist_bio": artist_bio,
		"money": money,
		"fame": fame,
		"reputation": reputation,
		"energy": energy,
		"current_week": current_week,
		"next_id": next_id,
		"songs": songs.map(func(item: SongData) -> Dictionary: return item.to_dict()),
		"albums": albums.map(func(item: AlbumData) -> Dictionary: return item.to_dict()),
		"releases": releases.map(func(item: ReleaseData) -> Dictionary: return item.to_dict()),
		"scheduled_releases": scheduled_releases.map(func(item: ScheduledRelease) -> Dictionary: return item.to_dict()),
		"marketing_campaigns": marketing_campaigns.map(func(item: MarketingCampaign) -> Dictionary: return item.to_dict()),
		"song_performances": song_performances.map(func(item: SongPerformance) -> Dictionary: return item.to_dict()),
		"platform_stats": platform_stats.values().map(func(item: ArtistPlatformStats) -> Dictionary: return item.to_dict()),
		"performance_snapshots": performance_snapshots.map(func(item: PerformanceSnapshot) -> Dictionary: return item.to_dict()),
		"music_videos": music_videos.map(func(item: MusicVideo) -> Dictionary: return item.to_dict()),
		"live_shows": live_shows.map(func(item: LiveShow) -> Dictionary: return item.to_dict()),
		"live_tours": live_tours.map(func(item: LiveTour) -> Dictionary: return item.to_dict()),
		"merch_items": merch_items.map(func(item: MerchItem) -> Dictionary: return item.to_dict()),
		"festival_editions": festival_editions.map(func(item: FestivalEdition) -> Dictionary: return item.to_dict()),
		"finance_history": finance_history.map(func(item: FinanceEntry) -> Dictionary: return item.to_dict()),
		"week_reports": week_reports.map(func(item: WeekReport) -> Dictionary: return item.to_dict()),
	}


static func from_dict(data: Dictionary) -> CareerData:
	var career := CareerData.new()
	career.artist_name = data.get("artist_name", "")
	career.real_name = data.get("real_name", "")
	career.age = int(data.get("age", 20))
	career.country = data.get("country", "")
	career.city = data.get("city", "")
	career.appearance = CharacterAppearance.from_dict(data.get("appearance", {}))
	career.infinite_energy = bool(data.get("infinite_energy", false))
	career.social = SocialData.from_dict(data.get("social", {}))
	career.wardrobe.assign(data.get("wardrobe", []))
	career.label = LabelData.from_dict(data.get("label", {}))
	for item: Dictionary in data.get("vehicles", []):
		career.vehicles.append(OwnedVehicle.from_dict(item))
	career.artist_cover = data.get("artist_cover", "")
	career.artist_bio = data.get("artist_bio", "")
	career.money = int(data.get("money", 0))
	career.fame = int(data.get("fame", 0))
	career.reputation = int(data.get("reputation", 0))
	career.energy = int(data.get("energy", 0))
	career.current_week = int(data.get("current_week", 1))
	career.next_id = int(data.get("next_id", 1))
	for item: Dictionary in data.get("songs", []):
		career.songs.append(SongData.from_dict(item))
	for item: Dictionary in data.get("albums", []):
		career.albums.append(AlbumData.from_dict(item))
	for item: Dictionary in data.get("releases", []):
		career.releases.append(ReleaseData.from_dict(item))
	for item: Dictionary in data.get("scheduled_releases", []):
		career.scheduled_releases.append(ScheduledRelease.from_dict(item))
	for item: Dictionary in data.get("marketing_campaigns", []):
		career.marketing_campaigns.append(MarketingCampaign.from_dict(item))
	for item: Dictionary in data.get("song_performances", []):
		career.song_performances.append(SongPerformance.from_dict(item))
	for item: Dictionary in data.get("platform_stats", []):
		var stats := ArtistPlatformStats.from_dict(item)
		career.platform_stats[stats.platform_id] = stats
	for item: Dictionary in data.get("performance_snapshots", []):
		career.performance_snapshots.append(PerformanceSnapshot.from_dict(item))
	for item: Dictionary in data.get("music_videos", []):
		career.music_videos.append(MusicVideo.from_dict(item))
	for item: Dictionary in data.get("live_shows", []):
		career.live_shows.append(LiveShow.from_dict(item))
	for item: Dictionary in data.get("live_tours", []):
		career.live_tours.append(LiveTour.from_dict(item))
	for item: Dictionary in data.get("merch_items", []):
		career.merch_items.append(MerchItem.from_dict(item))
	for item: Dictionary in data.get("festival_editions", []):
		career.festival_editions.append(FestivalEdition.from_dict(item))
	for item: Dictionary in data.get("finance_history", []):
		career.finance_history.append(FinanceEntry.from_dict(item))
	for item: Dictionary in data.get("week_reports", []):
		career.week_reports.append(WeekReport.from_dict(item))
	return career
