class_name CareerData
extends RefCounted
## Estado completo de uma carreira: é a única fonte de dados e o que vai para o save.

var artist_name: String = ""
var money: int = 0
var fame: int = 0
var reputation: int = 0
var energy: int = 0
var current_week: int = 1
var songs: Array[SongData] = []
var albums: Array[AlbumData] = []
var releases: Array[ReleaseData] = []
var scheduled_releases: Array[ScheduledRelease] = []
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
		"finance_history": finance_history.map(func(item: FinanceEntry) -> Dictionary: return item.to_dict()),
		"week_reports": week_reports.map(func(item: WeekReport) -> Dictionary: return item.to_dict()),
	}


static func from_dict(data: Dictionary) -> CareerData:
	var career := CareerData.new()
	career.artist_name = data.get("artist_name", "")
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
	for item: Dictionary in data.get("finance_history", []):
		career.finance_history.append(FinanceEntry.from_dict(item))
	for item: Dictionary in data.get("week_reports", []):
		career.week_reports.append(WeekReport.from_dict(item))
	return career
