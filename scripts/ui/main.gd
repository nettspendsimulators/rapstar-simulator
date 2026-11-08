extends Control
## Cena raiz: troca a tela visível. Cada tela é recriada ao ser aberta.

const SCREENS := {
	Screen.MAIN_MENU: preload("res://scenes/screens/main_menu_screen.tscn"),
	Screen.NEW_CAREER: preload("res://scenes/screens/new_career_screen.tscn"),
	Screen.HUB: preload("res://scenes/screens/hub_screen.tscn"),
	Screen.WORK: preload("res://scenes/screens/work_screen.tscn"),
	Screen.SONGS: preload("res://scenes/screens/songs_screen.tscn"),
	Screen.SONG_DETAIL: preload("res://scenes/screens/song_detail_screen.tscn"),
	Screen.SONG_EDITOR: preload("res://scenes/screens/song_editor_screen.tscn"),
	Screen.MARKETING: preload("res://scenes/screens/marketing_screen.tscn"),
	Screen.MARKETING_HUB: preload("res://scenes/screens/marketing_hub_screen.tscn"),
	Screen.PLATFORMS: preload("res://scenes/screens/platforms_screen.tscn"),
	Screen.ARTIST_PROFILE: preload("res://scenes/screens/artist_profile_screen.tscn"),
	Screen.PERFORMANCE: preload("res://scenes/screens/performance_screen.tscn"),
	Screen.VIDEOS: preload("res://scenes/screens/videos_screen.tscn"),
	Screen.VIDEO_EDITOR: preload("res://scenes/screens/video_editor_screen.tscn"),
	Screen.PLATFORM_PAGE: preload("res://scenes/platforms/platform_page.tscn"),
	Screen.ALBUMS: preload("res://scenes/screens/albums_screen.tscn"),
	Screen.PROJECT_EDITOR: preload("res://scenes/screens/project_editor_screen.tscn"),
	Screen.RELEASES: preload("res://scenes/screens/releases_screen.tscn"),
	Screen.CAREER: preload("res://scenes/screens/career_screen.tscn"),
	Screen.WEEK_REPORT: preload("res://scenes/screens/week_report_screen.tscn"),
	Screen.LIVE: preload("res://scenes/screens/live_screen.tscn"),
	Screen.CHARACTER: preload("res://scenes/screens/character_screen.tscn"),
	Screen.CAREERS: preload("res://scenes/screens/careers_screen.tscn"),
	Screen.SHOW_EDITOR: preload("res://scenes/screens/show_editor_screen.tscn"),
	Screen.TOUR_EDITOR: preload("res://scenes/screens/tour_editor_screen.tscn"),
	Screen.FESTIVAL: preload("res://scenes/screens/festival_screen.tscn"),
	Screen.SHOW_REPORT: preload("res://scenes/screens/show_report_screen.tscn"),
}

var _current: Screen


func _ready() -> void:
	show_screen(Screen.MAIN_MENU)


func show_screen(screen_id: StringName, screen_context: Dictionary = {}) -> void:
	if _current != null:
		remove_child(_current)
		_current.queue_free()
	_current = SCREENS[screen_id].instantiate()
	_current.context = screen_context
	_current.navigate_requested.connect(show_screen)
	add_child(_current)
