class_name HandSelection
extends RefCounted

enum ChangeResult {
	UNCHANGED,
	ADDED,
	REMOVED,
	REJECTED_LIMIT,
	REJECTED_INVALID
}

var max_selected: int
var _selected: Array[CardData] = []


func _init(limit: int = 5) -> void:
	max_selected = limit


func set_selected(card: CardData, should_select: bool, valid_cards: Array[CardData]) -> ChangeResult:
	if not valid_cards.has(card):
		return ChangeResult.REJECTED_INVALID
	if should_select:
		if _selected.has(card):
			return ChangeResult.UNCHANGED
		if _selected.size() >= max_selected:
			return ChangeResult.REJECTED_LIMIT
		_selected.append(card)
		return ChangeResult.ADDED
	if not _selected.has(card):
		return ChangeResult.UNCHANGED
	_selected.erase(card)
	return ChangeResult.REMOVED


func clear() -> void:
	_selected.clear()


func contains(card: CardData) -> bool:
	return _selected.has(card)


func size() -> int:
	return _selected.size()


func cards() -> Array[CardData]:
	return _selected.duplicate()

