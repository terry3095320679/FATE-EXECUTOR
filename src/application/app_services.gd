extends Node

signal language_changed(language_code: String)

var _localization: LocalizationService
var _settings: SettingsRepository
var _run_save: RunSaveRepository
var _run_state: RunState


func _ready() -> void:
	_localization = LocalizationService.new(DataRepository.load_localization())
	_settings = SettingsRepository.new()
	_run_save = RunSaveRepository.new()
	_localization.language_changed.connect(_on_language_changed)
	var saved_language := _settings.load_language()
	if not _localization.set_language(saved_language):
		_localization.set_language(SettingsRepository.DEFAULT_LANGUAGE)
	_run_state = _run_save.load_run(
		DataRepository.load_deck_definition(),
		DataRepository.load_reward_config()
	)
	if _run_state == null:
		_run_state = RunState.new(
			DataRepository.load_deck_definition(),
			DataRepository.load_reward_config()
		)


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


func run_state() -> RunState:
	return _run_state


func new_run(persist: bool = true) -> RunState:
	_run_state = RunState.new(
		DataRepository.load_deck_definition(),
		DataRepository.load_reward_config()
	)
	if persist:
		_run_save.save_run(_run_state)
	return _run_state


func save_run() -> bool:
	return _run_save.save_run(_run_state)


func replace_run_for_test(run: RunState) -> void:
	_run_state = run


func _on_language_changed(language_code: String) -> void:
	language_changed.emit(language_code)
