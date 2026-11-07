extends Screen


func _ready() -> void:
	%StartButton.pressed.connect(_start)
	%NameEdit.text_submitted.connect(func(_text: String) -> void: _start())
	%BackButton.pressed.connect(navigate.bind(Screen.MAIN_MENU))
	if GameManager.has_save():
		%MessageLabel.text = "Já existe um jogo salvo. Ao salvar esta nova carreira, ele será substituído."
	%NameEdit.grab_focus()
	super()


func _start() -> void:
	var result := GameManager.new_career(%NameEdit.text)
	if result.ok:
		navigate(Screen.HUB)
	else:
		%MessageLabel.text = result.message
