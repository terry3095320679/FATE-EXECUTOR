class_name RunState
extends RefCounted

const NodeStateType = preload("res://src/domain/node_state.gd")
const ShopStateType = preload("res://src/domain/shop_state.gd")
const TreasureStateType = preload("res://src/domain/treasure_state.gd")

var stage := 1
var gold := 0
var player_max_health := 100
var player_health := 100
var deck: Deck
var trinket_ids: Array[String] = []
var reward_state: RewardState
var minimum_deck_size := 20
var trinket_slots := 6
var node_state: RefCounted
var shop_state: RefCounted
var treasure_state: RefCounted


func _init(
	deck_definition: Dictionary = {},
	reward_config: Dictionary = {}
) -> void:
	var run_config: Dictionary = reward_config.get("run", {})
	stage = maxi(1, int(run_config.get("initial_stage", 1)))
	gold = maxi(0, int(run_config.get("initial_gold", 0)))
	minimum_deck_size = maxi(1, int(run_config.get("minimum_deck_size", 20)))
	trinket_slots = maxi(1, int(run_config.get("trinket_slots", 6)))
	deck = Deck.new(deck_definition)


func apply_reward_gold(reward: RewardState) -> bool:
	if reward == null or reward.gold_claimed or reward.stage != stage:
		return false
	gold += reward.gold_amount
	reward.gold_claimed = true
	return true


func remove_reward_card(instance_id: int) -> bool:
	if reward_state == null or not reward_state.remove_card_offered:
		return false
	if reward_state.remove_card_claimed or reward_state.remove_card_skipped:
		return false
	if not deck.remove_card(instance_id, minimum_deck_size):
		return false
	reward_state.remove_card_claimed = true
	reward_state.removed_card_id = instance_id
	return true


func skip_remove_card() -> bool:
	if reward_state == null or not reward_state.remove_card_offered:
		return false
	if reward_state.remove_card_claimed or reward_state.remove_card_skipped:
		return false
	reward_state.remove_card_skipped = true
	return true


func claim_trinket(replace_id: String = "") -> bool:
	if reward_state == null or not reward_state.trinket_offered:
		return false
	if reward_state.trinket_claimed or reward_state.trinket_skipped:
		return false
	if not add_or_replace_trinket(reward_state.trinket_id, replace_id):
		return false
	if not replace_id.is_empty():
		reward_state.replaced_trinket_id = replace_id
	reward_state.trinket_claimed = true
	return true


func skip_trinket() -> bool:
	if reward_state == null or not reward_state.trinket_offered:
		return false
	if reward_state.trinket_claimed or reward_state.trinket_skipped:
		return false
	reward_state.trinket_skipped = true
	return true


func open_card_choice() -> bool:
	return reward_state != null and reward_state.mark_card_choice_opened()


func skip_card_choice() -> bool:
	if reward_state == null or not reward_state.card_choice_offered:
		return false
	if reward_state.card_choice_opened or reward_state.card_choice_skipped:
		return false
	reward_state.card_choice_skipped = true
	return true


func choose_card(candidate_instance_id: int) -> bool:
	if reward_state == null or not reward_state.must_choose:
		return false
	var candidate: Dictionary = {}
	for raw_candidate in reward_state.card_candidates:
		if int(raw_candidate.get("instance_id", 0)) == candidate_instance_id:
			candidate = raw_candidate
			break
	if candidate.is_empty():
		return false
	var added := deck.add_card_from_spec(
		int(candidate.get("rank", 0)),
		int(candidate.get("suit", -1)),
		candidate_instance_id
	)
	if added == null:
		return false
	reward_state.chosen_card_id = candidate_instance_id
	reward_state.must_choose = false
	return true


func complete_reward_and_advance() -> bool:
	if reward_state == null or not reward_state.can_continue():
		return false
	reward_state.reward_completed = true
	stage += 1
	reward_state = null
	return true


func add_or_replace_trinket(trinket_id: String, replace_id: String = "") -> bool:
	if trinket_id.is_empty() or trinket_ids.has(trinket_id):
		return false
	if trinket_ids.size() >= trinket_slots:
		if replace_id.is_empty() or not trinket_ids.has(replace_id):
			return false
		trinket_ids.erase(replace_id)
	trinket_ids.append(trinket_id)
	return true


func add_card_candidate(candidate: Dictionary) -> bool:
	var added := deck.add_card_from_spec(
		int(candidate.get("rank", 0)),
		int(candidate.get("suit", -1)),
		int(candidate.get("instance_id", 0))
	)
	return added != null


func healing_multiplier() -> float:
	if (
		trinket_ids.has("razor_ribbon")
		and player_max_health > 0
		and float(player_health) / float(player_max_health) < 0.35
	):
		return 0.75
	return 1.0


func heal(base_amount: int) -> int:
	if base_amount <= 0 or player_health >= player_max_health:
		return 0
	var adjusted := maxi(0, roundi(base_amount * healing_multiplier()))
	var before := player_health
	player_health = mini(player_max_health, player_health + adjusted)
	return player_health - before


func to_dict() -> Dictionary:
	return {
		"version": 2,
		"stage": stage,
		"gold": gold,
		"player_max_health": player_max_health,
		"player_health": player_health,
		"minimum_deck_size": minimum_deck_size,
		"trinket_slots": trinket_slots,
		"trinket_ids": trinket_ids.duplicate(),
		"deck": deck.to_records(),
		"reward_state": null if reward_state == null else reward_state.to_dict(),
		"node_state": null if node_state == null else node_state.to_dict(),
		"shop_state": null if shop_state == null else shop_state.to_dict(),
		"treasure_state": null if treasure_state == null else treasure_state.to_dict()
	}


static func from_dict(
	payload: Dictionary,
	deck_definition: Dictionary,
	reward_config: Dictionary
) -> RunState:
	var state := RunState.new(deck_definition, reward_config)
	state.stage = maxi(1, int(payload.get("stage", state.stage)))
	state.gold = maxi(0, int(payload.get("gold", state.gold)))
	state.player_max_health = maxi(1, int(payload.get("player_max_health", 100)))
	state.player_health = clampi(int(payload.get("player_health", state.player_max_health)), 0, state.player_max_health)
	state.minimum_deck_size = maxi(1, int(payload.get("minimum_deck_size", state.minimum_deck_size)))
	state.trinket_slots = maxi(1, int(payload.get("trinket_slots", state.trinket_slots)))
	state.trinket_ids.clear()
	for trinket_id: Variant in payload.get("trinket_ids", []):
		var id := str(trinket_id)
		if not id.is_empty() and not state.trinket_ids.has(id):
			state.trinket_ids.append(id)
	var deck_records: Variant = payload.get("deck", [])
	if not deck_records is Array or not state.deck.restore_records(deck_records):
		return null
	var reward_payload: Variant = payload.get("reward_state", null)
	if reward_payload is Dictionary:
		state.reward_state = RewardState.from_dict(reward_payload)
	var node_payload: Variant = payload.get("node_state", null)
	if node_payload is Dictionary:
		state.node_state = NodeStateType.from_dict(node_payload)
	var shop_payload: Variant = payload.get("shop_state", null)
	if shop_payload is Dictionary:
		state.shop_state = ShopStateType.from_dict(shop_payload)
	var treasure_payload: Variant = payload.get("treasure_state", null)
	if treasure_payload is Dictionary:
		state.treasure_state = TreasureStateType.from_dict(treasure_payload)
	return state
