class_name CollaboratorPicker
extends VBoxContainer
## Lista de colaboradores de uma função, com limite de seleção.

signal selection_changed

var _title: String = ""
var _limit: int = 0
var _header := Label.new()
var _checks: Dictionary[String, CheckBox] = {}


func setup(title: String, options: Array[CollaboratorDefinition], limit: int) -> void:
	_title = title
	_limit = limit
	_header.theme_type_variation = &"HeaderLabel"
	add_child(_header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 0)
	scroll.add_child(list)

	for person in options:
		var check := CheckBox.new()
		check.text = "%s (%d) %s" % [person.display_name, person.skill, Fmt.money(person.cost)]
		check.tooltip_text = "Talento %d, consistência %d, custo %s" % [person.skill, person.consistency, Fmt.money(person.cost)]
		check.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		check.toggled.connect(_on_toggled)
		list.add_child(check)
		_checks[String(person.id)] = check
	_refresh_state()


func set_selected_ids(ids: Array[String]) -> void:
	for id in _checks:
		_checks[id].set_pressed_no_signal(id in ids)
	_refresh_state()


func selected_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _checks:
		if _checks[id].button_pressed:
			ids.append(id)
	return ids


func _on_toggled(_pressed: bool) -> void:
	_refresh_state()
	selection_changed.emit()


func _refresh_state() -> void:
	var count := selected_ids().size()
	_header.text = "%s (%d/%d)" % [_title, count, _limit]
	for id in _checks:
		var check := _checks[id]
		check.disabled = count >= _limit and not check.button_pressed
