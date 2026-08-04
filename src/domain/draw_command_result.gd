class_name DrawCommandResult
extends RefCounted

var requested_count: int
var drawn_cards: Array[CardData]
var reshuffled_batches: Array
var reshuffle_draw_offsets: Array[int]
var draw_pile_before: int
var draw_pile_after: int
var discard_pile_before: int
var discard_pile_after: int
var shortage: bool


func _init(
	p_requested_count: int,
	p_drawn_cards: Array[CardData],
	p_reshuffled_batches: Array,
	p_reshuffle_draw_offsets: Array[int],
	p_draw_pile_before: int,
	p_draw_pile_after: int,
	p_discard_pile_before: int,
	p_discard_pile_after: int
) -> void:
	requested_count = p_requested_count
	drawn_cards = p_drawn_cards.duplicate()
	reshuffled_batches = p_reshuffled_batches.duplicate(true)
	reshuffle_draw_offsets = p_reshuffle_draw_offsets.duplicate()
	draw_pile_before = p_draw_pile_before
	draw_pile_after = p_draw_pile_after
	discard_pile_before = p_discard_pile_before
	discard_pile_after = p_discard_pile_after
	shortage = drawn_cards.size() < requested_count


func reshuffle_count() -> int:
	return reshuffled_batches.size()
