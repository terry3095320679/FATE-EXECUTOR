class_name NodeFlowService
extends RefCounted

const NodeGeneratorType = preload("res://src/domain/node_generator.gd")
const ShopStateType = preload("res://src/domain/shop_state.gd")
const TreasureStateType = preload("res://src/domain/treasure_state.gd")
const CardOfferGeneratorType = preload("res://src/domain/card_offer_generator.gd")

var _config: Dictionary
var _trinkets: Array[Dictionary]
var _trinket_by_id: Dictionary = {}
var _generator: RefCounted


func _init(config: Dictionary = {}, trinkets: Array[Dictionary] = []) -> void:
	_config = config
	_trinkets = trinkets
	_generator = NodeGeneratorType.new(config)
	for definition in trinkets:
		_trinket_by_id[str(definition.get("id", ""))] = definition


func generate_map(run: RunState, seed_value: int) -> RefCounted:
	run.node_state = _generator.generate(run.stage, seed_value)
	run.shop_state = null
	run.treasure_state = null
	return run.node_state


func select_candidate(run: RunState, index: int) -> bool:
	return run.node_state != null and run.node_state.select(index)


func cancel_candidate_selection(run: RunState) -> bool:
	return run.node_state != null and run.node_state.cancel_selection()


func confirm_and_enter(run: RunState, content_seed: int) -> bool:
	if run.node_state == null or not run.node_state.confirm_selection():
		return false
	match run.node_state.selected_type:
		"shop":
			run.shop_state = _create_shop(run, content_seed)
		"treasure":
			run.treasure_state = _create_treasure(run, content_seed)
		"fountain":
			_resolve_fountain(run)
	return true


func complete_battle_reward_and_generate(run: RunState, next_map_seed: int) -> bool:
	if run.reward_state == null or not run.reward_state.can_continue():
		return false
	if run.node_state != null and run.node_state.node_entered:
		run.node_state.node_completed = true
	if not run.complete_reward_and_advance():
		return false
	generate_map(run, next_map_seed)
	return true


func complete_special_node_and_generate(run: RunState, next_map_seed: int) -> bool:
	if run.node_state == null or not run.node_state.node_entered or run.node_state.node_completed:
		return false
	if run.node_state.selected_type == "shop" and run.shop_state != null and run.shop_state.must_choose_card:
		return false
	if run.node_state.selected_type == "treasure" and run.treasure_state != null and run.treasure_state.must_choose:
		return false
	run.node_state.node_completed = true
	run.stage += 1
	generate_map(run, next_map_seed)
	return true


func shop_remove_card(run: RunState, instance_id: int) -> bool:
	var shop := run.shop_state
	if shop == null or shop.removal_uses_remaining <= 0:
		return false
	var price := int(shop.price_snapshot.get("remove_card", 15))
	if run.gold < price or run.deck.cards.size() <= run.minimum_deck_size:
		return false
	if not run.deck.remove_card(instance_id, run.minimum_deck_size):
		return false
	run.gold -= price
	shop.removal_uses_remaining -= 1
	return true


func shop_begin_card_purchase(run: RunState) -> bool:
	var shop := run.shop_state
	if shop == null or shop.must_choose_card or shop.card_purchase_uses_remaining <= 0:
		return false
	var price := int(shop.price_snapshot.get("buy_card", 5))
	if run.gold < price:
		return false
	run.gold -= price
	shop.card_purchase_uses_remaining -= 1
	shop.card_purchase_sequence += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = shop.inventory_seed + shop.card_purchase_sequence * 7919
	var shop_config: Dictionary = _config.get("shop", {})
	var buy_config: Dictionary = shop_config.get("buy_card", {})
	shop.card_candidates = CardOfferGeneratorType.generate(
		run.deck, rng, int(buy_config.get("candidate_count", 5))
	)
	shop.must_choose_card = true
	return true


func shop_choose_card(run: RunState, instance_id: int) -> bool:
	var shop := run.shop_state
	if shop == null or not shop.must_choose_card:
		return false
	var candidate := _candidate_by_id(shop.card_candidates, instance_id)
	if candidate.is_empty() or not run.add_card_candidate(candidate):
		return false
	shop.must_choose_card = false
	shop.card_candidates.clear()
	return true


func shop_heal(run: RunState) -> int:
	var shop := run.shop_state
	if shop == null or shop.heal_uses_remaining <= 0 or run.player_health >= run.player_max_health:
		return 0
	var price := int(shop.price_snapshot.get("heal", 20))
	if run.gold < price:
		return 0
	var shop_config: Dictionary = _config.get("shop", {})
	var heal_config: Dictionary = shop_config.get("heal", {})
	var restored := run.heal(roundi(run.player_max_health * float(heal_config.get("max_health_fraction", 0.30))))
	if restored <= 0:
		return 0
	run.gold -= price
	shop.heal_uses_remaining -= 1
	return restored


func shop_buy_trinket(run: RunState, trinket_id: String, replace_id: String = "") -> bool:
	var shop := run.shop_state
	if shop == null or not shop.trinket_inventory.has(trinket_id):
		return false
	if bool(shop.purchased_items.get(trinket_id, false)) or run.trinket_ids.has(trinket_id):
		return false
	var price := int(shop.price_snapshot.get("trinket:%s" % trinket_id, 1))
	if run.gold < price:
		return false
	if run.trinket_ids.size() >= run.trinket_slots and replace_id.is_empty():
		shop.pending_trinket_id = trinket_id
		return false
	if not run.add_or_replace_trinket(trinket_id, replace_id):
		return false
	run.gold -= price
	shop.purchased_items[trinket_id] = true
	shop.pending_trinket_id = ""
	return true


func shop_cancel_trinket_replacement(run: RunState) -> bool:
	if run.shop_state == null or run.shop_state.pending_trinket_id.is_empty():
		return false
	run.shop_state.pending_trinket_id = ""
	return true


func treasure_open(run: RunState) -> bool:
	var treasure := run.treasure_state
	if treasure == null or treasure.opened or treasure.skipped:
		return false
	treasure.opened = true
	treasure.must_choose = true
	return true


func treasure_skip(run: RunState) -> bool:
	var treasure := run.treasure_state
	if treasure == null or treasure.opened or treasure.skipped:
		return false
	treasure.skipped = true
	return true


func treasure_choose(run: RunState, trinket_id: String, replace_id: String = "") -> bool:
	var treasure := run.treasure_state
	if treasure == null or not treasure.must_choose or not treasure.candidates.has(trinket_id):
		return false
	if run.trinket_ids.size() >= run.trinket_slots and replace_id.is_empty():
		treasure.pending_trinket_id = trinket_id
		return false
	if not run.add_or_replace_trinket(trinket_id, replace_id):
		return false
	treasure.selected_trinket = trinket_id
	treasure.pending_trinket_id = ""
	treasure.must_choose = false
	return true


func trinket_definition(trinket_id: String) -> Dictionary:
	return (_trinket_by_id.get(trinket_id, {}) as Dictionary).duplicate(true)


func _create_shop(run: RunState, seed_value: int) -> RefCounted:
	var state := ShopStateType.new()
	state.inventory_seed = seed_value
	var shop_config: Dictionary = _config.get("shop", {})
	state.removal_uses_remaining = int((shop_config.get("remove_card", {}) as Dictionary).get("uses", 2))
	state.card_purchase_uses_remaining = int((shop_config.get("buy_card", {}) as Dictionary).get("uses", 3))
	state.heal_uses_remaining = int((shop_config.get("heal", {}) as Dictionary).get("uses", 1))
	var available: Array[String] = []
	for definition in _trinkets:
		var id := str(definition.get("id", ""))
		if not id.is_empty() and not run.trinket_ids.has(id):
			available.append(id)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var inventory_count := mini(int(shop_config.get("trinket_inventory_count", 6)), available.size())
	for _index in range(inventory_count):
		state.trinket_inventory.append(available.pop_at(rng.randi_range(0, available.size() - 1)))
	var discount := float(shop_config.get("black_wax_discount", 0.10)) if run.trinket_ids.has("black_wax_seal") else 0.0
	for service_id in ["remove_card", "buy_card", "heal"]:
		var service: Dictionary = shop_config.get(service_id, {})
		state.price_snapshot[service_id] = _discounted_price(int(service.get("price", 1)), discount)
	for trinket_id in state.trinket_inventory:
		var definition: Dictionary = _trinket_by_id.get(trinket_id, {})
		state.price_snapshot["trinket:%s" % trinket_id] = _discounted_price(
			int(definition.get("price", 1)), discount
		)
	return state


func _create_treasure(run: RunState, seed_value: int) -> RefCounted:
	var state := TreasureStateType.new()
	state.seed = seed_value
	var available: Array[String] = []
	for definition in _trinkets:
		var id := str(definition.get("id", ""))
		if not id.is_empty() and not run.trinket_ids.has(id):
			available.append(id)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var treasure_config: Dictionary = _config.get("treasure", {})
	var count := mini(int(treasure_config.get("candidate_count", 3)), available.size())
	for _index in range(count):
		state.candidates.append(available.pop_at(rng.randi_range(0, available.size() - 1)))
	return state


func _resolve_fountain(run: RunState) -> void:
	var fountain: Dictionary = _config.get("fountain", {})
	var before := run.player_health
	var restored := run.heal(roundi(run.player_max_health * float(fountain.get("max_health_fraction", 0.30))))
	run.node_state.resolution = {
		"health_before": before,
		"health_restored": restored,
		"health_after": run.player_health
	}


func _discounted_price(base_price: int, discount: float) -> int:
	return maxi(1, roundi(base_price * (1.0 - clampf(discount, 0.0, 0.99))))


func _candidate_by_id(candidates: Array[Dictionary], instance_id: int) -> Dictionary:
	for candidate in candidates:
		if int(candidate.get("instance_id", 0)) == instance_id:
			return candidate
	return {}
