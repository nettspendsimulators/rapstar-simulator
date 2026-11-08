extends Screen


func _ready() -> void:
	%WorkButton.pressed.connect(navigate.bind(Screen.WORK))
	%SongsButton.pressed.connect(navigate.bind(Screen.SONGS))
	%AlbumsButton.pressed.connect(navigate.bind(Screen.ALBUMS))
	%ReleasesButton.pressed.connect(navigate.bind(Screen.RELEASES))
	%CareerButton.pressed.connect(navigate.bind(Screen.CAREER))
	%MarketingButton.pressed.connect(navigate.bind(Screen.MARKETING_HUB))
	%PlatformsButton.pressed.connect(navigate.bind(Screen.PLATFORMS))
	%ProfileButton.pressed.connect(navigate.bind(Screen.ARTIST_PROFILE))
	%PerformanceButton.pressed.connect(navigate.bind(Screen.PERFORMANCE))
	%VideosButton.pressed.connect(navigate.bind(Screen.VIDEOS))
	%LiveButton.pressed.connect(navigate.bind(Screen.LIVE))
	%CharacterButton.pressed.connect(navigate.bind(Screen.CHARACTER))
	%NextWeekButton.pressed.connect(_on_next_week_pressed)
	%SaveButton.pressed.connect(_on_save_pressed)
	%LoadButton.pressed.connect(%LoadConfirm.popup_centered)
	%LoadConfirm.confirmed.connect(_on_load_confirmed)
	%MenuButton.pressed.connect(%MenuConfirm.popup_centered)
	%MenuConfirm.confirmed.connect(navigate.bind(Screen.MAIN_MENU))
	super()


func refresh() -> void:
	var career := GameManager.career
	%ArtistLabel.text = "Artista: %s" % career.artist_name
	%IdentityLabel.text = "%d anos  •  %s" % [GameManager.characters.current_age(career), GameManager.characters.location_label(career.country, career.city)]
	%HubCharacter.appearance = career.appearance
	%WeekLabel.text = "Semana: %s" % Fmt.number(career.current_week)
	%MoneyLabel.text = "Dinheiro: %s" % Fmt.money(career.money)
	%FameLabel.text = "Fama: %s" % Fmt.number(career.fame)
	%ReputationLabel.text = "Reputação: %s" % Fmt.number(career.reputation)
	%EnergyLabel.text = "Energia: infinita" if career.infinite_energy else "Energia: %d/%d" % [career.energy, GameManager.balance.max_energy]
	%LoadButton.disabled = not GameManager.has_save()


func _on_next_week_pressed() -> void:
	GameManager.next_week()
	navigate(Screen.WEEK_REPORT)


func _on_save_pressed() -> void:
	%MessageLabel.text = GameManager.save_game().message
	%LoadButton.disabled = not GameManager.has_save()


func _on_load_confirmed() -> void:
	%MessageLabel.text = GameManager.load_game().message
