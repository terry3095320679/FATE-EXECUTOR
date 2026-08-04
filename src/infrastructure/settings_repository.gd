class_name SettingsRepository
extends RefCounted

const DEFAULT_PATH := "user://fate_executor/settings.json"
const DEFAULT_LANGUAGE := "en"
const SUPPORTED_LANGUAGES := ["en", "zh_CN"]

var settings_path: String


func _init(path: String = DEFAULT_PATH) -> void:
	settings_path = path


func load_language() -> String:
	if not FileAccess.file_exists(settings_path):
		return DEFAULT_LANGUAGE
	var file := FileAccess.open(settings_path, FileAccess.READ)
	if file == null:
		return DEFAULT_LANGUAGE
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return DEFAULT_LANGUAGE
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		return DEFAULT_LANGUAGE
	var language_code := str(parsed.get("language", DEFAULT_LANGUAGE))
	if not SUPPORTED_LANGUAGES.has(language_code):
		return DEFAULT_LANGUAGE
	return language_code


func save_language(language_code: String) -> bool:
	var settings_directory := settings_path.get_base_dir()
	if DirAccess.open(settings_directory) == null:
		var absolute_directory := ProjectSettings.globalize_path(settings_directory)
		var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
		if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
			push_error("Unable to create settings directory: %s" % absolute_directory)
			return false
	var file := FileAccess.open(settings_path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to save settings: %s" % settings_path)
		return false
	file.store_string(JSON.stringify({"language": language_code}, "\t"))
	return true
