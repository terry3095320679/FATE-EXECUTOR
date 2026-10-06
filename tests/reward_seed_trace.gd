extends SceneTree

const REWARD_SEED := 8
const NO_OPTIONAL_REWARD_SEED := 62

func _init() -> void:
	var run := RunState.new(
		DataRepository.load_deck_definition(),
		DataRepository.load_reward_config()
	)
	var generator := RewardGenerator.new(
		DataRepository.load_reward_config(),
		DataRepository.load_trinkets()
	)
	print("all_optional_rewards_seed=%d" % REWARD_SEED)
	print("no_optional_rewards_seed=%d" % NO_OPTIONAL_REWARD_SEED)
	_print_reward(generator.generate(1, run, REWARD_SEED), run)
	quit(0)


func _print_reward(reward: RewardState, run: RunState) -> void:
	print("stage=%d seed=%d gold=%d" % [reward.stage, reward.seed, reward.gold_amount])
	print("rolls=%s" % JSON.stringify(reward.rolls))
	print("offers=remove:%s trinket:%s card_choice:%s" % [
		reward.remove_card_offered,
		reward.trinket_offered,
		reward.card_choice_offered
	])
	print("trinket=%s" % reward.trinket_id)
	print("candidates=%s" % JSON.stringify(reward.card_candidates))
	run.reward_state = reward
	run.apply_reward_gold(reward)
	print("run_gold_after_auto_claim=%d" % run.gold)
