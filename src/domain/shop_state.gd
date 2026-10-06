class_name ShopState
extends RefCounted

var inventory_seed := 0
var removal_uses_remaining := 2
var card_purchase_uses_remaining := 3
var heal_uses_remaining := 1
var trinket_inventory: Array[String] = []
var purchased_items: Dictionary = {}
var price_snapshot: Dictionary = {}
var card_purchase_sequence := 0
var card_candidates: Array[Dictionary] = []
var must_choose_card := false
var pending_trinket_id := ""


func to_dict() -> Dictionary:
	return {
		"inventory_seed": inventory_seed,
		"removal_uses_remaining": removal_uses_remaining,
		"card_purchase_uses_remaining": card_purchase_uses_remaining,
		"heal_uses_remaining": heal_uses_remaining,
		"trinket_inventory": trinket_inventory.duplicate(),
		"purchased_items": purchased_items.duplicate(true),
		"price_snapshot": price_snapshot.duplicate(true),
		"card_purchase_sequence": card_purchase_sequence,
		"card_candidates": card_candidates.duplicate(true),
		"must_choose_card": must_choose_card,
		"pending_trinket_id": pending_trinket_id
	}


static func from_dict(payload: Dictionary) -> RefCounted:
	var state: RefCounted = load("res://src/domain/shop_state.gd").new()
	state.inventory_seed = int(payload.get("inventory_seed", 0))
	state.removal_uses_remaining = maxi(0, int(payload.get("removal_uses_remaining", 0)))
	state.card_purchase_uses_remaining = maxi(0, int(payload.get("card_purchase_uses_remaining", 0)))
	state.heal_uses_remaining = maxi(0, int(payload.get("heal_uses_remaining", 0)))
	for id: Variant in payload.get("trinket_inventory", []):
		state.trinket_inventory.append(str(id))
	var raw_purchased: Variant = payload.get("purchased_items", {})
	if raw_purchased is Dictionary:
		state.purchased_items = (raw_purchased as Dictionary).duplicate(true)
	var raw_prices: Variant = payload.get("price_snapshot", {})
	if raw_prices is Dictionary:
		state.price_snapshot = (raw_prices as Dictionary).duplicate(true)
	state.card_purchase_sequence = maxi(0, int(payload.get("card_purchase_sequence", 0)))
	for raw_candidate: Variant in payload.get("card_candidates", []):
		if raw_candidate is Dictionary:
			var candidate := raw_candidate as Dictionary
			state.card_candidates.append({
				"instance_id": int(candidate.get("instance_id", 0)),
				"rank": int(candidate.get("rank", 0)),
				"suit": int(candidate.get("suit", -1))
			})
	state.must_choose_card = bool(payload.get("must_choose_card", false))
	state.pending_trinket_id = str(payload.get("pending_trinket_id", ""))
	return state
