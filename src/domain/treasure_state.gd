class_name TreasureState
extends RefCounted

var seed := 0
var opened := false
var candidates: Array[String] = []
var must_choose := false
var selected_trinket := ""
var skipped := false
var pending_trinket_id := ""


func to_dict() -> Dictionary:
	return {
		"seed": seed,
		"opened": opened,
		"candidates": candidates.duplicate(),
		"must_choose": must_choose,
		"selected_trinket": selected_trinket,
		"skipped": skipped,
		"pending_trinket_id": pending_trinket_id
	}


static func from_dict(payload: Dictionary) -> RefCounted:
	var state: RefCounted = load("res://src/domain/treasure_state.gd").new()
	state.seed = int(payload.get("seed", 0))
	state.opened = bool(payload.get("opened", false))
	for id: Variant in payload.get("candidates", []):
		state.candidates.append(str(id))
	state.must_choose = bool(payload.get("must_choose", false))
	state.selected_trinket = str(payload.get("selected_trinket", ""))
	state.skipped = bool(payload.get("skipped", false))
	state.pending_trinket_id = str(payload.get("pending_trinket_id", ""))
	return state
