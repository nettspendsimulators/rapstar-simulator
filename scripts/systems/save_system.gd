class_name SaveSystem
extends RefCounted
## Grava em user:// (res:// é somente leitura no .exe exportado).

## Aumente ao mudar o formato e adicione a conversão em SaveMigration.
const SAVE_VERSION := 5
const DEFAULT_SLOT := "career"

var save_dir: String = "user://saves"
var _balance: GameBalance


func _init(balance: GameBalance) -> void:
	_balance = balance


func has_save(slot: String = DEFAULT_SLOT) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


func save_career(career: CareerData, slot: String = DEFAULT_SLOT) -> ActionResult:
	var dir_error := DirAccess.make_dir_recursive_absolute(save_dir)
	if dir_error != OK:
		return ActionResult.failure("Não foi possível criar a pasta de saves (%s)." % error_string(dir_error))

	# Grava em um arquivo temporário para uma falha nunca corromper o save anterior.
	var path := _slot_path(slot)
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return ActionResult.failure("Não foi possível salvar (%s)." % error_string(FileAccess.get_open_error()))
	var payload := {"version": SAVE_VERSION, "career": career.to_dict()}
	file.store_string(JSON.stringify(payload, "\t"))
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temp_path)
		return ActionResult.failure("Não foi possível salvar (%s)." % error_string(write_error))

	var rename_error := DirAccess.rename_absolute(temp_path, path)
	if rename_error != OK:
		return ActionResult.failure("Não foi possível salvar (%s)." % error_string(rename_error))
	return ActionResult.success("Jogo salvo.")


## Em caso de sucesso, result.value contém a CareerData carregada.
func load_career(slot: String = DEFAULT_SLOT) -> ActionResult:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return ActionResult.failure("Nenhum jogo salvo encontrado.")
	var json := JSON.new()
	var parse_error := json.parse(FileAccess.get_file_as_string(path))
	var parsed: Variant = json.data
	if parse_error != OK or not parsed is Dictionary or not parsed.get("career") is Dictionary:
		return ActionResult.failure("O arquivo de save está corrompido.")
	var version := int(parsed.get("version", 1))
	if version > SAVE_VERSION:
		return ActionResult.failure("Este save foi criado por uma versão mais nova do jogo.")
	if version < SAVE_VERSION:
		_backup_old_save(path, version)
		SaveMigration.migrate(parsed, _balance)
	return ActionResult.success("Jogo carregado.", CareerData.from_dict(parsed["career"]))


## Guarda o arquivo original antes da migração. Uma cópia existente nunca é substituída.
func _backup_old_save(path: String, version: int) -> void:
	var backup_path := "%s.v%d.bak" % [path, version]
	if not FileAccess.file_exists(backup_path):
		DirAccess.copy_absolute(path, backup_path)


func _slot_path(slot: String) -> String:
	return save_dir.path_join(slot + ".json")
