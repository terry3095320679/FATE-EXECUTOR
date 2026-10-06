class_name RunSaveRepository
extends RefCounted

const DEFAULT_PATH := "user://fate_executor/run.json"

var save_path: String


func _init(path: String = DEFAULT_PATH) -> void:
	save_path = path


func save_run(run: RunState) -> bool:
	if run == null:
		return false
	var directory := save_path.get_base_dir()
	if DirAccess.open(directory) == null:
		var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		if error != OK and error != ERR_ALREADY_EXISTS:
			push_error("Unable to create run save directory: %s" % directory)
			return false
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to save run: %s" % save_path)
		return false
	file.store_string(JSON.stringify(run.to_dict(), "\t"))
	return true


func load_run(deck_definition: Dictionary, reward_config: Dictionary) -> RunState:
	if not FileAccess.file_exists(save_path):
		return null
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return null
	return RunState.from_dict(parsed, deck_definition, reward_config)


func clear_run() -> bool:
	if not FileAccess.file_exists(save_path):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path)) == OK
