class_name PokerEvaluator
extends RefCounted

const MIN_STRAIGHT_RANK := 2
const ACE_HIGH_RANK := 14

var _rules: Dictionary


func _init(p_rules: Dictionary = {}) -> void:
	_rules = p_rules


func evaluate(selected_cards: Array[CardData]) -> PokerHandResult:
	var result := PokerHandResult.new()
	if selected_cards.is_empty():
		return result

	var rank_groups := _group_by_rank(selected_cards)
	var is_five_cards := selected_cards.size() == 5
	var is_flush := is_five_cards and _all_same_suit(selected_cards)
	var is_straight := is_five_cards and _is_straight(selected_cards)
	var candidate_id: StringName
	var scoring: Array[CardData]

	if is_flush and is_straight:
		candidate_id = &"straight_flush"
		scoring = selected_cards.duplicate()
	elif _groups_with_size(rank_groups, 4).size() > 0:
		candidate_id = &"four_of_a_kind"
		scoring = _highest_group_cards(rank_groups, 4)
	elif is_five_cards and _groups_with_size(rank_groups, 3).size() == 1 and _groups_with_size(rank_groups, 2).size() == 1:
		candidate_id = &"full_house"
		scoring = selected_cards.duplicate()
	elif is_flush:
		candidate_id = &"flush"
		scoring = selected_cards.duplicate()
	elif is_straight:
		candidate_id = &"straight"
		scoring = selected_cards.duplicate()
	elif _groups_with_size(rank_groups, 3).size() > 0:
		candidate_id = &"three_of_a_kind"
		scoring = _highest_group_cards(rank_groups, 3)
	elif _groups_with_size(rank_groups, 2).size() >= 2:
		candidate_id = &"two_pair"
		scoring = _highest_pair_cards(rank_groups, 2)
	elif _groups_with_size(rank_groups, 2).size() == 1:
		candidate_id = &"pair"
		scoring = _highest_group_cards(rank_groups, 2)
	else:
		candidate_id = &"high_card"
		scoring = [_highest_card(selected_cards)]

	return _build_result(candidate_id, selected_cards, scoring)


func _build_result(
	hand_id: StringName,
	selected_cards: Array[CardData],
	scoring_cards: Array[CardData]
) -> PokerHandResult:
	var rule: Dictionary = _rules.get(hand_id, {})
	var result := PokerHandResult.new()
	result.hand_id = hand_id
	result.display_name = str(rule.get("name_key", "hand.%s" % hand_id))
	result.priority = int(rule.get("priority", 0))
	result.multiplier = float(rule.get("multiplier", 1.0))
	result.scoring_cards = scoring_cards.duplicate()
	for card in scoring_cards:
		result.attack_points += card.rank
	result.damage = roundi(result.attack_points * result.multiplier)
	for card in selected_cards:
		if not scoring_cards.has(card):
			result.unscored_cards.append(card)
	return result


func _group_by_rank(cards_to_group: Array[CardData]) -> Dictionary:
	var groups: Dictionary = {}
	for card in cards_to_group:
		if not groups.has(card.rank):
			groups[card.rank] = [] as Array[CardData]
		groups[card.rank].append(card)
	return groups


func _groups_with_size(groups: Dictionary, group_size: int) -> Array[int]:
	var ranks: Array[int] = []
	for rank_value: Variant in groups:
		if groups[rank_value].size() == group_size:
			ranks.append(int(rank_value))
	ranks.sort()
	ranks.reverse()
	return ranks


func _highest_group_cards(groups: Dictionary, group_size: int) -> Array[CardData]:
	var matching_ranks := _groups_with_size(groups, group_size)
	if matching_ranks.is_empty():
		return []
	return (groups[matching_ranks[0]] as Array[CardData]).duplicate()


func _highest_pair_cards(groups: Dictionary, pair_count: int) -> Array[CardData]:
	var scoring: Array[CardData] = []
	var pair_ranks := _groups_with_size(groups, 2)
	for index in range(mini(pair_count, pair_ranks.size())):
		scoring.append_array(groups[pair_ranks[index]] as Array[CardData])
	return scoring


func _highest_card(cards_to_check: Array[CardData]) -> CardData:
	var highest := cards_to_check[0]
	for card in cards_to_check:
		if card.rank > highest.rank:
			highest = card
	return highest


func _all_same_suit(cards_to_check: Array[CardData]) -> bool:
	var first_suit := cards_to_check[0].suit
	for card in cards_to_check:
		if card.suit != first_suit:
			return false
	return true


func _is_straight(cards_to_check: Array[CardData]) -> bool:
	if cards_to_check.size() != 5:
		return false
	var ranks: Array[int] = []
	for card in cards_to_check:
		if card.rank < MIN_STRAIGHT_RANK or card.rank > ACE_HIGH_RANK:
			return false
		if ranks.has(card.rank):
			return false
		ranks.append(card.rank)
	ranks.sort()
	if ranks[ranks.size() - 1] - ranks[0] != 4:
		return false
	for index in range(1, ranks.size()):
		if ranks[index] != ranks[index - 1] + 1:
			return false
	return true
