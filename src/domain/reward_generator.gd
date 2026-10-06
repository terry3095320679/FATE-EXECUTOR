class_name RewardGenerator
extends RefCounted

const CardOfferGeneratorType = preload("res://src/domain/card_offer_generator.gd")

var _config: Dictionary
var _trinkets: Array[Dictionary]


func _init(config: Dictionary = {}, trinkets: Array[Dictionary] = []) -> void:
	_config = config
	_trinkets = trinkets


func generate(
	stage: int,
	run: RunState,
	seed_value: int = 0,
	reward_multiplier: float = 1.0,
	battle_type: String = "normal"
) -> RewardState:
	var seed := seed_value if seed_value != 0 else Time.get_ticks_usec()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var normal: Dictionary = _config.get("normal_battle", {})
	var state := RewardState.new()
	state.stage = maxi(1, stage)
	state.battle_type = battle_type
	state.seed = seed
	var base_gold := rng.randi_range(
		int(normal.get("gold_min", 5)),
		int(normal.get("gold_max", 15))
	)
	state.gold_amount = roundi(base_gold * maxf(0.0, reward_multiplier))
	var remove_roll := rng.randf()
	var trinket_roll := rng.randf()
	var card_roll := rng.randf()
	state.rolls = {
		"remove_card": remove_roll,
		"trinket": trinket_roll,
		"card_choice": card_roll
	}
	state.remove_card_offered = remove_roll < minf(1.0, float(normal.get("remove_card_chance", 0.40)) * reward_multiplier)
	state.trinket_offered = trinket_roll < minf(1.0, float(normal.get("trinket_chance", 0.60)) * reward_multiplier)
	state.card_choice_offered = card_roll < minf(1.0, float(normal.get("card_choice_chance", 0.80)) * reward_multiplier)

	if state.trinket_offered:
		var available: Array[Dictionary] = []
		for definition in _trinkets:
			if not run.trinket_ids.has(str(definition.get("id", ""))):
				available.append(definition)
		if available.is_empty():
			state.trinket_offered = false
		else:
			state.trinket_id = str(available[rng.randi_range(0, available.size() - 1)].get("id", ""))

	if state.card_choice_offered:
		state.card_candidates = CardOfferGeneratorType.generate(
			run.deck,
			rng,
			int(normal.get("card_choice_count", 5))
		)
	return state
