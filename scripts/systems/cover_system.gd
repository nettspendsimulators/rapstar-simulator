class_name CoverSystem
extends RefCounted
## Importa capas de arquivos ou da área de transferência e as guarda ao lado do save.
## O nome do arquivo vem do conteúdo da imagem, então duas carreiras nunca se sobrescrevem
## e a mesma imagem não ocupa espaço duas vezes.

const COVERS_FOLDER := "covers"
const IMAGE_EXTENSIONS := ["png", "jpg", "jpeg", "webp", "bmp"]
const WEBP_QUALITY := 0.9

var _balance: GameBalance
var _saves: SaveSystem
var _textures: Dictionary[String, Texture2D] = {}


func _init(balance: GameBalance, saves: SaveSystem) -> void:
	_balance = balance
	_saves = saves


## Em caso de sucesso, result.value contém o nome do arquivo da capa.
func import_file(path: String) -> ActionResult:
	if not FileAccess.file_exists(path):
		return ActionResult.failure("Arquivo não encontrado.")
	if path.get_extension().to_lower() not in IMAGE_EXTENSIONS:
		return ActionResult.failure("Use uma imagem PNG, JPG, WEBP ou BMP.")
	var image := Image.new()
	if image.load(path) != OK:
		return ActionResult.failure("Não foi possível abrir essa imagem.")
	return import_image(image)


func clipboard_has_image() -> bool:
	return DisplayServer.clipboard_has_image()


## Aceita uma imagem copiada ou o caminho de uma imagem copiado como texto.
func import_clipboard() -> ActionResult:
	if DisplayServer.clipboard_has_image():
		var image := DisplayServer.clipboard_get_image()
		if image != null and not image.is_empty():
			return import_image(image)
	var text := DisplayServer.clipboard_get().strip_edges().trim_prefix("\"").trim_suffix("\"")
	if text.begins_with("http://") or text.begins_with("https://"):
		return ActionResult.failure("Você copiou um link. Copie a própria imagem (botão direito > Copiar imagem).")
	if not text.is_empty() and text.get_extension().to_lower() in IMAGE_EXTENSIONS and FileAccess.file_exists(text):
		return import_file(text)
	return ActionResult.failure("Não há imagem na área de transferência. Copie a imagem ou escolha um arquivo.")


func import_image(source: Image) -> ActionResult:
	if source == null or source.is_empty():
		return ActionResult.failure("Imagem vazia.")
	var image := Image.new()
	image.copy_from(source)
	# Capas são opacas. Descartar o alfa também evita capas invisíveis quando
	# uma imagem da área de transferência chega com o canal alfa zerado.
	image.convert(Image.FORMAT_RGB8)
	var side := mini(image.get_width(), image.get_height())
	var offset := (image.get_size() - Vector2i(side, side)) / 2
	image = image.get_region(Rect2i(offset, Vector2i(side, side)))
	image.resize(_balance.cover_size, _balance.cover_size, Image.INTERPOLATE_LANCZOS)

	var data := image.save_webp_to_buffer(true, WEBP_QUALITY)
	if data.is_empty():
		return ActionResult.failure("Não foi possível converter a imagem.")
	var folder := _covers_dir()
	var folder_error := DirAccess.make_dir_recursive_absolute(folder)
	if folder_error != OK:
		return ActionResult.failure("Não foi possível criar a pasta de capas (%s)." % error_string(folder_error))
	var file_name := "%s.webp" % _hash(data)
	var path := folder.path_join(file_name)
	if not FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return ActionResult.failure("Não foi possível salvar a capa (%s)." % error_string(FileAccess.get_open_error()))
		file.store_buffer(data)
		file.close()
	return ActionResult.success("Capa pronta.", file_name)


## Devolve a textura da capa, ou null se não houver capa ou se o arquivo tiver sumido.
func get_texture(file_name: String) -> Texture2D:
	if file_name.is_empty():
		return null
	if _textures.has(file_name):
		return _textures[file_name]
	var path := _covers_dir().path_join(file_name)
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	if image.load_webp_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		return null
	var texture := ImageTexture.create_from_image(image)
	_textures[file_name] = texture
	return texture


func _covers_dir() -> String:
	return _saves.save_dir.path_join(COVERS_FOLDER)


func _hash(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode().left(32)
