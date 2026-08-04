class_name PileSnapshot
extends RefCounted

const STANDARD_SUIT_ORDER: Array[int] = [3, 2, 0, 1]
const WILD_SUIT_ID := -1

class SuitGroup:
	extends RefCounted

	var suit_id: int
	var name_key: String
	var symbol: String
	var count: int
	var display_cards: Array[CardData]
	var display_card_ids: Array[int]

	func _init(
		p_suit_id: int,
		p_name_key: String,
		p_symbol: String,
		p_cards: Array[CardData]
	) -> void:
		suit_id = p_suit_id
		name_key = p_name_key
		symbol = p_symbol
		display_cards = CardDisplayOrder.descending(p_cards)
		display_card_ids = []
		for card in display_cards:
			display_card_ids.append(card.instance_id)
		count = display_cards.size()


var pile_type: StringName
var total_count: int
var groups: Array[SuitGroup] = []


func _init(
	p_pile_type: StringName,
	source_cards: Array[CardData],
	battle_registry: Array[CardData]
) -> void:
	pile_type = p_pile_type
	total_count = source_cards.size()
	var metadata := _suit_metadata(battle_registry)
	for suit_id in STANDARD_SUIT_ORDER:
		var group_cards: Array[CardData] = []
		for card in source_cards:
			if card.suit == suit_id:
				group_cards.append(card)
		var fallback: Dictionary = _fallback_metadata(suit_id)
		var suit_data: Dictionary = metadata.get(suit_id, fallback)
		groups.append(SuitGroup.new(
			suit_id,
			str(suit_data.get("name_key", fallback["name_key"])),
			str(suit_data.get("symbol", fallback["symbol"])),
			group_cards
		))

	var wild_cards: Array[CardData] = []
	for card in source_cards:
		if not STANDARD_SUIT_ORDER.has(card.suit):
			wild_cards.append(card)
	if not wild_cards.is_empty():
		groups.append(SuitGroup.new(WILD_SUIT_ID, "suit.wild", "★", wild_cards))


func grouped_count() -> int:
	var output := 0
	for group in groups:
		output += group.count
	return output


func is_consistent() -> bool:
	return grouped_count() == total_count


func group_for_suit(suit_id: int) -> SuitGroup:
	for group in groups:
		if group.suit_id == suit_id:
			return group
	return null


func _suit_metadata(registry: Array[CardData]) -> Dictionary:
	var output: Dictionary = {}
	for card in registry:
		if STANDARD_SUIT_ORDER.has(card.suit) and not output.has(card.suit):
			output[card.suit] = {
				"name_key": card.suit_name,
				"symbol": card.suit_symbol
			}
	return output


func _fallback_metadata(suit_id: int) -> Dictionary:
	match suit_id:
		3:
			return {"name_key": "suit.spades", "symbol": "♠"}
		2:
			return {"name_key": "suit.hearts", "symbol": "♥"}
		0:
			return {"name_key": "suit.clubs", "symbol": "♣"}
		_:
			return {"name_key": "suit.diamonds", "symbol": "♦"}
