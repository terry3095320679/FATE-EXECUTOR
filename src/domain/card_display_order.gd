class_name CardDisplayOrder
extends RefCounted


static func descending(cards: Array[CardData]) -> Array[CardData]:
	var ordered: Array[CardData] = cards.duplicate()
	ordered.sort_custom(_comes_before)
	return ordered


static func _comes_before(left: CardData, right: CardData) -> bool:
	if left.rank == right.rank:
		if left.suit == right.suit:
			return left.instance_id < right.instance_id
		return left.suit < right.suit
	return left.rank > right.rank
