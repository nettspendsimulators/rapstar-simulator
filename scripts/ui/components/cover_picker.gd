class_name CoverPicker
extends VBoxContainer
## Escolhe a capa por arquivo ou com Ctrl+V e mostra a prévia antes de confirmar.

signal cover_changed
## Texto para a tela mostrar ao jogador, como o motivo de uma colagem recusada.
signal message_requested(text: String)

var cover_file: String = ""


func _ready() -> void:
	%FileButton.pressed.connect(%FileDialog.popup_centered)
	%FileDialog.file_selected.connect(func(path: String) -> void: _apply(GameManager.covers.import_file(path)))
	%PasteButton.pressed.connect(_paste)
	%RemoveButton.pressed.connect(func() -> void: set_cover(""))


func set_cover(file_name: String) -> void:
	cover_file = file_name
	%Preview.show_cover(file_name)
	%RemoveButton.disabled = file_name.is_empty()
	message_requested.emit("")
	cover_changed.emit()


## Com uma imagem copiada, Ctrl+V sempre vira capa. Sem imagem, o atalho
## continua colando texto normalmente quando há um campo de texto em foco.
func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_paste"):
		return
	var has_image := GameManager.covers.clipboard_has_image()
	if has_image or not get_viewport().gui_get_focus_owner() is LineEdit:
		get_viewport().set_input_as_handled()
		_paste()


func _paste() -> void:
	_apply(GameManager.covers.import_clipboard())


func _apply(result: ActionResult) -> void:
	if result.ok:
		set_cover(result.value)
	else:
		message_requested.emit(result.message)
