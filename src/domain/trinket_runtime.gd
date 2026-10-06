class_name TrinketRuntime
extends RefCounted

var _owned: Dictionary = {}
var _definitions: Dictionary = {}
var _first_pair_used := false
var _first_refresh_used := false
var _first_straight_used := false
var _funeral_cup_triggers := 0


func _init(owned_ids: Array[String] = [], definitions: Array[Dictionary] = []) -> void:
	for owned_id in owned_ids:
		_owned[owned_id] = true
	for definition in definitions:
		_definitions[str(definition.get("id", ""))] = definition


func preview_hand(
	base_result: PokerHandResult,
	enemy_type: String,
	player_health_ratio: float = 1.0
) -> PokerHandResult:
	return _apply_hand_modifiers(base_result, enemy_type, false, player_health_ratio)


func commit_hand(
	base_result: PokerHandResult,
	enemy_type: String,
	player_health_ratio: float = 1.0
) -> PokerHandResult:
	return _apply_hand_modifiers(base_result, enemy_type, true, player_health_ratio)


func block_after_hand(result: PokerHandResult) -> int:
	var block := 0
	if result.hand_id == &"two_pair" and _owned.has("split_coin"):
		block += int(_definitions.get("split_coin", {}).get("value", 5))
	if result.hand_id == &"flush" and _owned.has("velvet_thread"):
		block += result.scoring_cards.size() * int(
			_definitions.get("velvet_thread", {}).get("value", 1)
		)
	if result.hand_id == &"four_of_a_kind" and _owned.has("fourfold_crown"):
		block += int(_definitions.get("fourfold_crown", {}).get("block_value", 13))
	return block


func block_after_refresh() -> int:
	if _owned.has("cracked_hourglass") and not _first_refresh_used:
		_first_refresh_used = true
		return int(_definitions.get("cracked_hourglass", {}).get("value", 4))
	return 0


func refreshes_after_hand(result: PokerHandResult) -> int:
	if result.hand_id == &"straight" and _owned.has("silver_compass") and not _first_straight_used:
		_first_straight_used = true
		return int(_definitions.get("silver_compass", {}).get("value", 1))
	return 0


func healing_after_hand(result: PokerHandResult) -> int:
	if result.hand_id != &"full_house" or not _owned.has("funeral_cup"):
		return 0
	var definition: Dictionary = _definitions.get("funeral_cup", {})
	if _funeral_cup_triggers >= int(definition.get("trigger_limit", 3)):
		return 0
	_funeral_cup_triggers += 1
	return int(definition.get("value", 3))


func healing_multiplier(player_health_ratio: float) -> float:
	if _owned.has("razor_ribbon"):
		var definition: Dictionary = _definitions.get("razor_ribbon", {})
		if player_health_ratio < float(definition.get("health_threshold", 0.35)):
			return 1.0 - float(definition.get("healing_penalty", 0.25))
	return 1.0


func _apply_hand_modifiers(
	base_result: PokerHandResult,
	enemy_type: String,
	commit: bool,
	player_health_ratio: float
) -> PokerHandResult:
	var result := _copy_result(base_result)
	var multiplier_changed := false
	if result.hand_id == &"pair" and _owned.has("sharpened_clip") and not _first_pair_used:
		result.attack_points += int(_definitions.get("sharpened_clip", {}).get("value", 3))
		if commit:
			_first_pair_used = true
	if result.hand_id == &"pair" and _owned.has("twin_lens"):
		result.multiplier += float(_definitions.get("twin_lens", {}).get("value", 0.15))
		multiplier_changed = true
	if result.hand_id == &"four_of_a_kind" and _owned.has("fourfold_crown"):
		result.multiplier += float(_definitions.get("fourfold_crown", {}).get("multiplier_value", 0.40))
		multiplier_changed = true
	if multiplier_changed or result.attack_points != base_result.attack_points:
		result.damage = roundi(result.attack_points * result.multiplier)
	if result.hand_id == &"straight" and _owned.has("straight_ruler"):
		result.damage = roundi(result.damage * (
			1.0 + float(_definitions.get("straight_ruler", {}).get("value", 0.08))
		))
	if (enemy_type == "elite" or enemy_type == "boss") and _owned.has("hunters_mark"):
		result.damage = roundi(result.damage * (
			1.0 + float(_definitions.get("hunters_mark", {}).get("value", 0.06))
		))
	if _owned.has("razor_ribbon"):
		var ribbon: Dictionary = _definitions.get("razor_ribbon", {})
		if player_health_ratio < float(ribbon.get("health_threshold", 0.35)):
			result.damage = roundi(result.damage * (1.0 + float(ribbon.get("damage_value", 0.18))))
	return result


func _copy_result(source: PokerHandResult) -> PokerHandResult:
	var result := PokerHandResult.new()
	result.hand_id = source.hand_id
	result.display_name = source.display_name
	result.priority = source.priority
	result.attack_points = source.attack_points
	result.multiplier = source.multiplier
	result.damage = source.damage
	result.scoring_cards = source.scoring_cards.duplicate()
	result.unscored_cards = source.unscored_cards.duplicate()
	return result
