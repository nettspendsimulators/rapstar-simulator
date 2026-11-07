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
const ALBUMS := &"albums"
const PROJECT_EDITOR := &"project_editor"
const RELEASES := &"releases"
const CAREER := &"career"
const WEEK_REPORT := &"week_report"

## Dados passados pela tela anterior, como o id do item a editar. Disponível em _ready.
var context: Dictionary = {}


func _ready() -> void:
	GameManager.career_changed.connect(refresh)
	refresh()


## Sobrescreva para mostrar os dados atuais da carreira.
func refresh() -> void:
	pass


func navigate(screen_id: StringName, next_context: Dictionary = {}) -> void:
	navigate_requested.emit(screen_id, next_context)
