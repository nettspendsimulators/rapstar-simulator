extends Screen


func _ready() -> void:
	%NewGameButton.pressed.connect(navigate.bind(Screen.NEW_CAREER))
	%LoadGameButton.pressed.connect(navigate.bind(Screen.CAREERS))
	%QuitButton.pressed.connect(func() -> void: get_tree().quit())
	super()


func refresh() -> void:
	%LoadGameButton.disabled = not GameManager.has_any_save()
