class_name Screen
extends Control
## Base das telas: navegação pelo Main e atualização quando a carreira muda.

signal navigate_requested(screen_id: StringName, next_context: Dictionary)

const MAIN_MENU := &"main_menu"
const NEW_CAREER := &"new_career"
const HUB := &"hub"
const WORK := &"work"
const SONGS := &"songs"
const SONG_DETAIL := &"song_detail"
const SONG_EDITOR := &"song_editor"
const MARKETING := &"marketing"
const MARKETING_HUB := &"marketing_hub"
const PLATFORMS := &"platforms"
const ARTIST_PROFILE := &"artist_profile"
const PERFORMANCE := &"performance"
const VIDEOS := &"videos"
const VIDEO_EDITOR := &"video_editor"
const PLATFORM_PAGE := &"platform_page"
const ALBUMS := &"albums"
const PROJECT_EDITOR := &"project_editor"
const RELEASES := &"releases"
const CAREER := &"career"
const WEEK_REPORT := &"week_report"
const LIVE := &"live"
const CHARACTER := &"character"
const CAREERS := &"careers"
const SOCIAL := &"social"
const ARTIST_RELATION := &"artist_relation"
const GARAGE := &"garage"
const SHOW_EDITOR := &"show_editor"
const TOUR_EDITOR := &"tour_editor"
const FESTIVAL := &"festival"
const SHOW_REPORT := &"show_report"

const BACK_ICON := preload("res://assets/icons/back.svg")

## Dados passados pela tela anterior, como o id do item a editar. Disponível em _ready.
var context: Dictionary = {}


func _ready() -> void:
	GameManager.career_changed.connect(refresh)
	refresh()
	fit_long_texts(self)


## Nomes longos (músicas, artistas, projetos) não podem alargar a tela: listas de opções cortam o
## texto e títulos terminam em reticências. Vale para todas as telas.
static func fit_long_texts(node: Node) -> void:
	for child in node.get_children():
		# Voltar é ação terciária em todo o jogo: discreta, com seta, sem disputar com a principal.
		if child is Button and String(child.name) in ["BackButton", "CancelButton"] and child.theme_type_variation == &"":
			child.theme_type_variation = &"GhostButton"
			if child.name == &"BackButton" and child.icon == null:
				child.icon = BACK_ICON
		if child is OptionButton:
			child.fit_to_longest_item = false
			child.clip_text = true
			child.custom_minimum_size.x = maxf(child.custom_minimum_size.x, 150.0)
		elif child is Label and child.autowrap_mode == TextServer.AUTOWRAP_OFF:
			if child.theme_type_variation in [&"TitleLabel", &"HeaderLabel"]:
				child.clip_text = true
				child.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			elif child.text.length() > 70 and not child.clip_text:
				# Frases longas quebram linha em vez de alargar a tela.
				child.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fit_long_texts(child)


## Sobrescreva para mostrar os dados atuais da carreira.
func refresh() -> void:
	pass


func navigate(screen_id: StringName, next_context: Dictionary = {}) -> void:
	navigate_requested.emit(screen_id, next_context)
