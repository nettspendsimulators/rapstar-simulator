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


const GOOD := Color("#46d483")
const WAIT := Color("#4fa3ff")
const BUSY := Color("#f5b82e")
const BAD := Color("#ff5f6d")
const DIM := Color("#8c86a0")
## Estados reconhecidos pelo começo do texto da célula. Todas as tabelas usam as mesmas cores.
const STATE_COLORS := [
	["Lançad", GOOD], ["Disponível", GOOD], ["Pronta", GOOD], ["Pronto", GOOD], ["Concluíd", GOOD], ["Realizado", GOOD],
	["Liberad", GOOD], ["Agendad", WAIT], ["Confirmad", WAIT], ["Em planejamento", WAIT], ["Oferta", WAIT],
	["Em produção", BUSY], ["Em andamento", BUSY], ["Ativa", BUSY], ["Pausad", BUSY], ["Planejad", WAIT],
	["Bloquead", BAD], ["Cancelad", BAD], ["Esgotad", BAD], ["Sem estoque", BAD], ["Recusad", BAD],
	["Não lançad", DIM], ["Inédita", DIM], ["—", DIM],
]


## Linhas de mídia (com cover_file informado) sem capa recebem a arte gerada pelo nome.
func add_row(cells: Array, row_value: Variant = null, cover_file: Variant = null) -> void:
	var item := create_item(get_root())
	for column in cells.size():
		var text := str(cells[column])
		item.set_text(column, text)
		var color := cell_color(text)
		if color != Color.TRANSPARENT:
			item.set_custom_color(column, color)
	item.set_metadata(0, row_value)
	var texture: Texture2D = null
	if cover_file is String:
		texture = CoverArt.texture_for(cover_file, str(cells[0]) if not cells.is_empty() else "")
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


## Cor de destaque para estados e valores com sinal; transparente quando o texto é comum.
static func cell_color(text: String) -> Color:
	if text.begins_with("+$") or (text.begins_with("+") and text.length() > 1 and text[1].is_valid_int()):
		return GOOD
	if text.begins_with("-$") or (text.begins_with("-") and text.length() > 1 and text[1].is_valid_int()):
		return BAD
	for pair: Array in STATE_COLORS:
		if text.begins_with(pair[0]):
			return pair[1]
	return Color.TRANSPARENT
