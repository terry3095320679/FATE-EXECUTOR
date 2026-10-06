extends SceneTree

const NodeFlowServiceType = preload("res://src/domain/node_flow_service.gd")
const FIRST_MAP_SEED := 7
const SHOP_INVENTORY_SEED := 90001


func _init() -> void:
	var config := DataRepository.load_node_config()
	var trinkets := DataRepository.load_trinkets()
	var flow: RefCounted = NodeFlowServiceType.new(config, trinkets)
	var run := RunState.new(DataRepository.load_deck_definition(), DataRepository.load_reward_config())
	var reward_generator := RewardGenerator.new(DataRepository.load_reward_config(), trinkets)
	run.reward_state = reward_generator.generate(1, run, 8)
	run.apply_reward_gold(run.reward_state)
	run.skip_remove_card()
	run.skip_trinket()
	run.open_card_choice()
	run.choose_card(int(run.reward_state.card_candidates[0].instance_id))

	var map_seed := FIRST_MAP_SEED
	flow.complete_battle_reward_and_generate(run, map_seed)
	print("battle_reward_seed=8 gold=%d" % run.gold)
	print("first_map_seed=%d stage=%d candidates=%s" % [
		map_seed, run.stage, _candidate_types(run.node_state.candidates)
	])
	var shop_index := _candidate_index(run.node_state.candidates, "shop")
	flow.select_candidate(run, shop_index)
	flow.confirm_and_enter(run, SHOP_INVENTORY_SEED)
	print("shop_inventory_seed=%d inventory=%s" % [SHOP_INVENTORY_SEED, JSON.stringify(run.shop_state.trinket_inventory)])
	flow.complete_special_node_and_generate(run, map_seed + 1)
	print("after_shop_stage=%d next_map_seed=%d candidates=%s" % [
		run.stage, map_seed + 1, _candidate_types(run.node_state.candidates)
	])
	quit(0)


func _candidate_index(candidates: Array[Dictionary], type_id: String) -> int:
	for index in range(candidates.size()):
		if str(candidates[index].get("type", "")) == type_id:
			return index
	return -1


func _candidate_types(candidates: Array[Dictionary]) -> String:
	var output: Array[String] = []
	for candidate in candidates:
		output.append(str(candidate.get("type", "")))
	return JSON.stringify(output)
