class_name NodeState
extends RefCounted

var current_stage := 1
var candidates: Array[Dictionary] = []
var candidate_seed := 0
var selected_index := -1
var selected_type := ""
var selection_confirmed := false
var node_entered := false
var node_completed := false
var resolution: Dictionary = {}


func select(index: int) -> bool:
	if selection_confirmed or node_entered or node_completed:
		return false
	if index < 0 or index >= candidates.size():
		return false
	selected_index = index
	selected_type = str(candidates[index].get("type", ""))
	return not selected_type.is_empty()


func confirm_selection() -> bool:
	if selected_index < 0 or selected_index >= candidates.size():
		return false
	if selection_confirmed or node_completed:
		return false
	selection_confirmed = true
	node_entered = true
	return true


func cancel_selection() -> bool:
	if selection_confirmed or node_entered or node_completed:
		return false
	selected_index = -1
	selected_type = ""
	return true


func to_dict() -> Dictionary:
	return {
		"current_stage": current_stage,
		"candidates": candidates.duplicate(true),
		"candidate_seed": candidate_seed,
		"selected_index": selected_index,
		"selected_type": selected_type,
		"selection_confirmed": selection_confirmed,
		"node_entered": node_entered,
		"node_completed": node_completed,
		"resolution": resolution.duplicate(true)
	}


static func from_dict(payload: Dictionary) -> RefCounted:
	var state: RefCounted = load("res://src/domain/node_state.gd").new()
	state.current_stage = maxi(1, int(payload.get("current_stage", 1)))
	state.candidate_seed = int(payload.get("candidate_seed", 0))
	for raw_candidate: Variant in payload.get("candidates", []):
		if raw_candidate is Dictionary:
			state.candidates.append((raw_candidate as Dictionary).duplicate(true))
	state.selected_index = int(payload.get("selected_index", -1))
	state.selected_type = str(payload.get("selected_type", ""))
	state.selection_confirmed = bool(payload.get("selection_confirmed", false))
	state.node_entered = bool(payload.get("node_entered", false))
	state.node_completed = bool(payload.get("node_completed", false))
	var raw_resolution: Variant = payload.get("resolution", {})
	if raw_resolution is Dictionary:
		state.resolution = (raw_resolution as Dictionary).duplicate(true)
	return state
