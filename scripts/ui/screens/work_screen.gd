extends Screen


func _ready() -> void:
	%JobsTable.set_headers(["Trabalho", "Ganho"])
	for job in GameManager.balance.jobs:
		%JobsTable.add_row([job.display_name, "+" + Fmt.money(job.pay)], job.id)
	%JobsTable.item_selected.connect(%MessageLabel.set_text.bind(""))
	%ConfirmButton.pressed.connect(_on_confirm_pressed)
	%BackButton.pressed.connect(navigate.bind(Screen.HUB))
	super()


func _on_confirm_pressed() -> void:
	var job_id: Variant = %JobsTable.selected_value()
	if job_id == null:
		%MessageLabel.text = "Selecione um trabalho."
		return
	var result := GameManager.work_job(job_id)
	if result.ok:
		GameManager.save_game()
		navigate(Screen.WEEK_REPORT)
	else:
		%MessageLabel.text = result.message
