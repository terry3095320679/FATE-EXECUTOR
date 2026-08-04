class_name DiscardCommandResult
extends RefCounted

var moved_cards: Array[CardData]
var hand_before: int
var hand_after: int
var discard_before: int
var discard_after: int


func _init(
	p_moved_cards: Array[CardData],
	p_hand_before: int,
	p_hand_after: int,
	p_discard_before: int,
	p_discard_after: int
) -> void:
	moved_cards = p_moved_cards.duplicate()
	hand_before = p_hand_before
	hand_after = p_hand_after
	discard_before = p_discard_before
	discard_after = p_discard_after
