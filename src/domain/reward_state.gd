class_name RewardState
extends RefCounted

var stage := 1
var battle_type := "normal"
var seed := 0
var gold_amount := 0
var gold_claimed := false
var remove_card_offered := false
var remove_card_claimed := false
var remove_card_skipped := false
var removed_card_id := 0
var trinket_offered := false
var trinket_id := ""
var trinket_claimed := false
var trinket_skipped := false
var replaced_trinket_id := ""
var card_choice_offered := false
var card_choice_opened := false
var card_choice_skipped := false
var card_candidates: Array[Dictionary] = []
var chosen_card_id := 0
var reward_completed := false
var must_choose := false
var rolls: Dictionary = {}


func can_continue() -> bool:
	return (
		not must_choose
		and _remove_resolved()
		and _trinket_resolved()
		and _card_choice_resolved()
	)


func mark_card_choice_opened() -> bool:
	if not card_choice_offered or card_choice_skipped or chosen_card_id > 0:
		return false
	card_choice_opened = true
	must_choose = true
	return true


func to_dict() -> Dictionary:
	return {
		"stage": stage,
		"battle_type": battle_type,
		"seed": seed,
		"gold_amount": gold_amount,
		"gold_claimed": gold_claimed,
		"remove_card_offered": remove_card_offered,
		"remove_card_claimed": remove_card_claimed,
		"remove_card_skipped": remove_card_skipped,
		"removed_card_id": removed_card_id,
		"trinket_offered": trinket_offered,
		"trinket_id": trinket_id,
		"trinket_claimed": trinket_claimed,
		"trinket_skipped": trinket_skipped,
		"replaced_trinket_id": replaced_trinket_id,
		"card_choice_offered": card_choice_offered,
		"card_choice_opened": card_choice_opened,
		"card_choice_skipped": card_choice_skipped,
		"card_candidates": card_candidates.duplicate(true),
		"chosen_card_id": chosen_card_id,
		"reward_completed": reward_completed,
		"must_choose": must_choose,
		"rolls": rolls.duplicate(true)
	}


static func from_dict(payload: Dictionary) -> RewardState:
	var state := RewardState.new()
	state.stage = maxi(1, int(payload.get("stage", 1)))
	state.battle_type = str(payload.get("battle_type", "normal"))
	state.seed = int(payload.get("seed", 0))
	state.gold_amount = maxi(0, int(payload.get("gold_amount", 0)))
	state.gold_claimed = bool(payload.get("gold_claimed", false))
	state.remove_card_offered = bool(payload.get("remove_card_offered", false))
	state.remove_card_claimed = bool(payload.get("remove_card_claimed", false))
	state.remove_card_skipped = bool(payload.get("remove_card_skipped", false))
	state.removed_card_id = int(payload.get("removed_card_id", 0))
	state.trinket_offered = bool(payload.get("trinket_offered", false))
	state.trinket_id = str(payload.get("trinket_id", ""))
	state.trinket_claimed = bool(payload.get("trinket_claimed", false))
	state.trinket_skipped = bool(payload.get("trinket_skipped", false))
	state.replaced_trinket_id = str(payload.get("replaced_trinket_id", ""))
	state.card_choice_offered = bool(payload.get("card_choice_offered", false))
	state.card_choice_opened = bool(payload.get("card_choice_opened", false))
	state.card_choice_skipped = bool(payload.get("card_choice_skipped", false))
	for raw_candidate: Variant in payload.get("card_candidates", []):
		if raw_candidate is Dictionary:
			var candidate := raw_candidate as Dictionary
			state.card_candidates.append({
				"instance_id": int(candidate.get("instance_id", 0)),
				"rank": int(candidate.get("rank", 0)),
				"suit": int(candidate.get("suit", -1))
			})
	state.chosen_card_id = int(payload.get("chosen_card_id", 0))
	state.reward_completed = bool(payload.get("reward_completed", false))
	state.must_choose = bool(payload.get("must_choose", false))
	state.rolls = (payload.get("rolls", {}) as Dictionary).duplicate(true)
	return state


func _remove_resolved() -> bool:
	return not remove_card_offered or remove_card_claimed or remove_card_skipped


func _trinket_resolved() -> bool:
	return not trinket_offered or trinket_claimed or trinket_skipped


func _card_choice_resolved() -> bool:
	return not card_choice_offered or card_choice_skipped or chosen_card_id > 0
