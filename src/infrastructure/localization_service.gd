class_name LocalizationService
extends RefCounted

signal language_changed(language_code: String)

const FALLBACK_LANGUAGE := "en"

var _languages: Dictionary = {}
var _current_language := FALLBACK_LANGUAGE


func _init(localization_data: Dictionary = {}) -> void:
	_languages = localization_data.get("languages", {}).duplicate(true)
	_current_language = str(localization_data.get("default_language", FALLBACK_LANGUAGE))
	if not _languages.has(_current_language):
		_current_language = FALLBACK_LANGUAGE


func set_language(language_code: String) -> bool:
	if not _languages.has(language_code):
		return false
	if _current_language == language_code:
		return true
	_current_language = language_code
	language_changed.emit(_current_language)
	return true


func get_language() -> String:
	return _current_language


func has_language(language_code: String) -> bool:
	return _languages.has(language_code)


func text(key: String, arguments: Array = []) -> String:
	var active: Dictionary = _languages.get(_current_language, {})
	var fallback: Dictionary = _languages.get(FALLBACK_LANGUAGE, {})
	var template := str(active.get(key, fallback.get(key, key)))
	if arguments.is_empty():
		return template
	return template % arguments

