class_name SaveSystem
extends RefCounted
## Grava em user:// (res:// é somente leitura no .exe exportado).

## Aumente ao mudar o formato e adicione a conversão em SaveMigration.
const SAVE_VERSION := 10
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
	var payload := {"version": SAVE_VERSION, "saved_at": int(Time.get_unix_time_from_system()), "career": career.to_dict()}
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


## Cada carreira é um slot próprio (um arquivo). Um id novo nunca repete um existente.
func new_slot_id() -> String:
	var base := "career_%d" % int(Time.get_unix_time_from_system())
	var slot := base
	var suffix := 2
	while has_save(slot):
		slot = "%s_%d" % [base, suffix]
		suffix += 1
	return slot


## Resumo de todas as carreiras salvas, sem migrar nem carregar a carreira inteira.
## Saves antigos aparecem com os valores que tiverem; o que faltar fica vazio.
func list_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(save_dir):
		return slots
	for file_name in DirAccess.get_files_at(save_dir):
		if not file_name.ends_with(".json"):
			continue
		var path := save_dir.path_join(file_name)
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary or not parsed.get("career") is Dictionary:
			continue
		var data: Dictionary = parsed["career"]
		var saved_at := int(parsed.get("saved_at", FileAccess.get_modified_time(path)))
		slots.append({
			"slot": file_name.get_basename(), "version": int(parsed.get("version", 1)), "saved_at": saved_at,
			"artist_name": data.get("artist_name", ""), "real_name": data.get("real_name", ""),
			"age": int(data.get("age", _balance.character.default_age)), "country": data.get("country", ""),
			"city": data.get("city", ""), "fame": int(data.get("fame", 0)), "money": int(data.get("money", 0)),
			"week": int(data.get("current_week", 1)), "infinite_energy": bool(data.get("infinite_energy", false)),
			"appearance": data.get("appearance", {}),
		})
	slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["saved_at"] > b["saved_at"])
	return slots


## Apaga a carreira e as cópias de migração dela. Outras carreiras não são tocadas.
func delete_slot(slot: String) -> ActionResult:
	var path := _slot_path(slot)
	if slot.is_empty() or not FileAccess.file_exists(path):
		return ActionResult.failure("Carreira não encontrada.")
	var error := DirAccess.remove_absolute(path)
	if error != OK:
		return ActionResult.failure("Não foi possível excluir (%s)." % error_string(error))
	for file_name in DirAccess.get_files_at(save_dir):
		if file_name.begins_with(slot + ".json.v") and file_name.ends_with(".bak"):
			DirAccess.remove_absolute(save_dir.path_join(file_name))
	return ActionResult.success("Carreira excluída.")


## Guarda o arquivo original antes da migração. Uma cópia existente nunca é substituída.
func _backup_old_save(path: String, version: int) -> void:
	var backup_path := "%s.v%d.bak" % [path, version]
	if not FileAccess.file_exists(backup_path):
		DirAccess.copy_absolute(path, backup_path)


func _slot_path(slot: String) -> String:
	return save_dir.path_join(slot + ".json")
