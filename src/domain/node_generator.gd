class_name NodeGenerator
extends RefCounted

const NodeStateType = preload("res://src/domain/node_state.gd")

var _node_types: Array[Dictionary] = []


func _init(config: Dictionary = {}) -> void:
	for raw_type: Dictionary in config.get("node_types", []):
		_node_types.append(raw_type.duplicate(true))


func generate(stage: int, seed_value: int) -> RefCounted:
	var state := NodeStateType.new()
	state.current_stage = maxi(1, stage)
	state.candidate_seed = seed_value
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for index in range(3):
		var selected := _type_for_roll(rng.randf())
		state.candidates.append({
			"index": index,
			"type": str(selected.get("id", "battle")),
			"name_key": str(selected.get("name_key", "node.battle")),
			"description_key": str(selected.get("description_key", "")),
			"icon": str(selected.get("icon", "?")),
			"dangerous": bool(selected.get("dangerous", false)),
			"stage": state.current_stage
		})
	return state


func probability(type_id: String) -> float:
	for definition in _node_types:
		if str(definition.get("id", "")) == type_id:
			return float(definition.get("chance", 0.0))
	return 0.0


func _type_for_roll(roll: float) -> Dictionary:
	var cumulative := 0.0
	for definition in _node_types:
		cumulative += float(definition.get("chance", 0.0))
		if roll < cumulative:
			return definition
	return _node_types.back() if not _node_types.is_empty() else {"id": "battle"}
