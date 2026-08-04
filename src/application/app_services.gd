extends Node

signal language_changed(language_code: String)

var _localization: LocalizationService
var _settings: SettingsRepository


func _ready() -> void:
	_localization = LocalizationService.new(DataRepository.load_localization())
	_settings = SettingsRepository.new()
	_localization.language_changed.connect(_on_language_changed)
	var saved_language := _settings.load_language()
	if not _localization.set_language(saved_language):
		_localization.set_language(SettingsRepository.DEFAULT_LANGUAGE)


func t(key: String, arguments: Array = []) -> String:
	return _localization.text(key, arguments)


func set_language(language_code: String, persist: bool = true) -> bool:
	if not _localization.set_language(language_code):
		return false
	if persist:
		_settings.save_language(language_code)
	return true


func get_language() -> String:
	return _localization.get_language()


func _on_language_changed(language_code: String) -> void:
	language_changed.emit(language_code)

