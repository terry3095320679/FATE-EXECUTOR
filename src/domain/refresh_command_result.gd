class_name RefreshCommandResult
extends RefCounted

var success: bool
var removed_cards: Array[CardData]
var drawn_cards: Array[CardData]
var retained_cards: Array[CardData]
var refreshes_before: int
var refreshes_after: int
var final_hand_internal: Array[CardData]
var final_hand_display: Array[CardData]
var draw_result: DrawCommandResult


func _init(
	p_success: bool,
	p_removed_cards: Array[CardData],
	p_drawn_cards: Array[CardData],
	p_retained_cards: Array[CardData],
	p_refreshes_before: int,
	p_refreshes_after: int,
	p_final_hand_internal: Array[CardData],
	p_final_hand_display: Array[CardData],
	p_draw_result: DrawCommandResult
) -> void:
	success = p_success
	removed_cards = p_removed_cards.duplicate()
	drawn_cards = p_drawn_cards.duplicate()
	retained_cards = p_retained_cards.duplicate()
	refreshes_before = p_refreshes_before
	refreshes_after = p_refreshes_after
	final_hand_internal = p_final_hand_internal.duplicate()
	final_hand_display = p_final_hand_display.duplicate()
	draw_result = p_draw_result


func removed_instance_ids() -> Array[int]:
	return _ids(removed_cards)


func drawn_instance_ids() -> Array[int]:
	return _ids(drawn_cards)


func retained_instance_ids() -> Array[int]:
	return _ids(retained_cards)


func final_hand_instance_ids() -> Array[int]:
	return _ids(final_hand_internal)


func final_display_instance_ids() -> Array[int]:
	return _ids(final_hand_display)


func _ids(cards: Array[CardData]) -> Array[int]:
	var ids: Array[int] = []
	for card in cards:
		ids.append(card.instance_id)
	return ids
