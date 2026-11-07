extends Screen


func _ready() -> void:
	%NewGameButton.pressed.connect(navigate.bind(Screen.NEW_CAREER))
	%LoadGameButton.pressed.connect(_on_load_pressed)
	%QuitButton.pressed.connect(func() -> void: get_tree().quit())
	super()


func refresh() -> void:
	%LoadGameButton.disabled = not GameManager.has_save()


func _on_load_pressed() -> void:
	var result := GameManager.load_game()
	if result.ok:
		navigate(Screen.HUB)
	else:
		%MessageLabel.text = result.message
