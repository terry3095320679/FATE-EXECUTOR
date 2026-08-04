class_name BattleDeckState
extends RefCounted

const PileSnapshotType = preload("res://src/domain/pile_snapshot.gd")

enum Zone {
	NONE,
	DRAW_PILE,
	HAND,
	DISCARD_PILE
}

var all_cards: Array[CardData] = []
var draw_pile: Array[CardData] = []
var hand: Array[CardData] = []
var discard_pile: Array[CardData] = []
var seed: int
var max_hand_size := 8

var _rng := RandomNumberGenerator.new()


func initialize(
	source_cards: Array[CardData],
	seed_value: int = 0,
	p_max_hand_size: int = 8
) -> void:
	seed = seed_value if seed_value != 0 else Time.get_ticks_usec()
	max_hand_size = maxi(1, p_max_hand_size)
	_rng.seed = seed
	all_cards = source_cards.duplicate()
	draw_pile = all_cards.duplicate()
	hand.clear()
	discard_pile.clear()
	_shuffle_draw_pile()
	_check_and_report("initialize")


func draw_to_hand(count: int) -> DrawCommandResult:
	var requested := maxi(0, count)
	var drawn: Array[CardData] = []
	var reshuffled_batches: Array = []
	var reshuffle_offsets: Array[int] = []
	var draw_before := draw_pile.size()
	var discard_before := discard_pile.size()

	while drawn.size() < requested:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			var moved_ids: Array[int] = []
			for card in discard_pile:
				moved_ids.append(card.instance_id)
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			_shuffle_draw_pile()
			reshuffled_batches.append(moved_ids)
			reshuffle_offsets.append(drawn.size())
		var card: CardData = draw_pile.pop_back()
		hand.append(card)
		drawn.append(card)

	if drawn.size() < requested:
		printerr(
			"BattleDeckState: requested %d cards but only %d were available; no instances were duplicated."
			% [requested, drawn.size()]
		)
	_check_and_report("draw_to_hand")
	return DrawCommandResult.new(
		requested,
		drawn,
		reshuffled_batches,
		reshuffle_offsets,
		draw_before,
		draw_pile.size(),
		discard_before,
		discard_pile.size()
	)


func discard_cards(cards_to_discard: Array[CardData]) -> DiscardCommandResult:
	var hand_before := hand.size()
	var discard_before := discard_pile.size()
	var moved: Array[CardData] = []
	var seen: Dictionary = {}
	for card in cards_to_discard:
		if seen.has(card.instance_id) or not hand.has(card):
			continue
		seen[card.instance_id] = true
		hand.erase(card)
		discard_pile.append(card)
		moved.append(card)
	_check_and_report("discard_cards")
	return DiscardCommandResult.new(
		moved,
		hand_before,
		hand.size(),
		discard_before,
		discard_pile.size()
	)


func draw_pile_display_order() -> Array[CardData]:
	return CardDisplayOrder.descending(draw_pile)


func discard_pile_display_order() -> Array[CardData]:
	return CardDisplayOrder.descending(discard_pile)


func pile_snapshot(pile_type: StringName) -> RefCounted:
	var source: Array[CardData] = (
		draw_pile if pile_type == &"draw" else discard_pile
	)
	return PileSnapshotType.new(pile_type, source, all_cards)


func random_state() -> int:
	return _rng.state


func zone_of(instance_id: int) -> Zone:
	if _contains_id(draw_pile, instance_id):
		return Zone.DRAW_PILE
	if _contains_id(hand, instance_id):
		return Zone.HAND
	if _contains_id(discard_pile, instance_id):
		return Zone.DISCARD_PILE
	return Zone.NONE


func consistency_errors() -> Array[String]:
	var errors: Array[String] = []
	var all_ids: Dictionary = {}
	for card in all_cards:
		if all_ids.has(card.instance_id):
			errors.append("duplicate instance %d in battle card registry" % card.instance_id)
		all_ids[card.instance_id] = true

	var zone_ids: Dictionary = {}
	for zone_cards: Array[CardData] in [draw_pile, hand, discard_pile]:
		for card in zone_cards:
			if not all_ids.has(card.instance_id):
				errors.append("unknown instance %d in a battle zone" % card.instance_id)
			if zone_ids.has(card.instance_id):
				errors.append("instance %d appears in multiple zones" % card.instance_id)
			zone_ids[card.instance_id] = true
	if zone_ids.size() != all_ids.size():
		errors.append(
			"zone total %d does not match battle registry total %d"
			% [zone_ids.size(), all_ids.size()]
		)
	if hand.size() > max_hand_size:
		errors.append("hand exceeds maximum size %d" % max_hand_size)
	return errors


func is_consistent() -> bool:
	return consistency_errors().is_empty()


func clear() -> void:
	all_cards.clear()
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()


func _shuffle_draw_pile() -> void:
	for index in range(draw_pile.size() - 1, 0, -1):
		var other := _rng.randi_range(0, index)
		var temporary := draw_pile[index]
		draw_pile[index] = draw_pile[other]
		draw_pile[other] = temporary


func _contains_id(cards: Array[CardData], instance_id: int) -> bool:
	for card in cards:
		if card.instance_id == instance_id:
			return true
	return false


func _check_and_report(context: String) -> void:
	for error in consistency_errors():
		printerr("BattleDeckState consistency error after %s: %s" % [context, error])
