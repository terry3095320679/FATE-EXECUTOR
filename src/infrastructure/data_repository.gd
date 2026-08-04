class_name DataRepository
extends RefCounted

const DECK_PATH := "res://data/deck.json"
const HANDS_PATH := "res://data/poker_hands.json"
const ENEMIES_PATH := "res://data/enemies.json"
const LOCALIZATION_PATH := "res://data/localization.json"


static func load_deck_definition() -> Dictionary:
	return _load_json(DECK_PATH)


static func load_poker_rules() -> Dictionary:
	var payload := _load_json(HANDS_PATH)
	var indexed: Dictionary = {}
	for raw_rule: Dictionary in payload.get("hands", []):
		indexed[StringName(raw_rule["id"])] = raw_rule
	return indexed


static func load_enemy(enemy_id: StringName) -> Dictionary:
	var payload := _load_json(ENEMIES_PATH)
	for raw_enemy: Dictionary in payload.get("enemies", []):
		if StringName(raw_enemy.get("id", "")) == enemy_id:
			return raw_enemy.duplicate(true)
	push_error("Enemy definition not found: %s" % enemy_id)
	return {}


static func load_localization() -> Dictionary:
	return _load_json(LOCALIZATION_PATH)


static func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Data file not found: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to open data file: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Expected a JSON object in: %s" % path)
		return {}
	return parsed
