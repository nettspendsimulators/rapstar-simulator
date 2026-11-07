class_name DataTable
extends Tree
## Tabela simples usada nas listas do jogo. Cada linha pode carregar um valor (como um id)
## e uma capa em miniatura na primeira coluna.

const ICON_SIZE := 28


func set_headers(titles: PackedStringArray) -> void:
	columns = titles.size()
	column_titles_visible = true
	hide_root = true
	select_mode = Tree.SELECT_ROW
	for column in titles.size():
		set_column_title(column, titles[column])
		set_column_title_alignment(column, HORIZONTAL_ALIGNMENT_LEFT)
	set_column_expand_ratio(0, 3)
	clear_rows()


func clear_rows() -> void:
	clear()
	create_item()


func add_row(cells: Array, row_value: Variant = null, cover_file: String = "") -> void:
	var item := create_item(get_root())
	for column in cells.size():
		item.set_text(column, str(cells[column]))
	item.set_metadata(0, row_value)
	var texture := GameManager.covers.get_texture(cover_file)
	if texture != null:
		item.set_icon(0, texture)
		item.set_icon_max_width(0, ICON_SIZE)


func selected_value() -> Variant:
	var item := get_selected()
	return item.get_metadata(0) if item != null else null


## Seleciona a linha com este valor, se existir.
func select_value(row_value: Variant) -> void:
	for item in get_root().get_children():
		if item.get_metadata(0) == row_value:
			item.select(0)
			return
