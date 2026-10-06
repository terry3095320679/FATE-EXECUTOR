class_name HandState
extends RefCounted

const PileSnapshotType = preload("res://src/domain/pile_snapshot.gd")

const DEFAULT_HAND_SIZE := 8
const MAX_SELECTED := 5
const MAX_REFRESHES := 3

var refreshes_remaining := MAX_REFRESHES
var max_hand_size := DEFAULT_HAND_SIZE
var selection := HandSelection.new(MAX_SELECTED)
var battle_deck_state: BattleDeckState


func start_battle(
	deck: Deck,
	seed_value: int = 0,
	p_max_hand_size: int = DEFAULT_HAND_SIZE
) -> DrawCommandResult:
	refreshes_remaining = MAX_REFRESHES
	max_hand_size = maxi(1, p_max_hand_size)
	selection.clear()
	battle_deck_state = BattleDeckState.new()
	battle_deck_state.initialize(deck.cards, seed_value, max_hand_size)
	return battle_deck_state.draw_to_hand(max_hand_size)


func start_new_round() -> DrawCommandResult:
	selection.clear()
	if battle_deck_state == null:
		return _empty_draw_result(max_hand_size)
	var needed := cards_needed_to_fill_hand()
	return battle_deck_state.draw_to_hand(needed)


func set_card_selected(card: CardData, should_select: bool) -> HandSelection.ChangeResult:
	if battle_deck_state == null:
		return HandSelection.ChangeResult.REJECTED_INVALID
	return selection.set_selected(card, should_select, battle_deck_state.hand)


func selected_cards() -> Array[CardData]:
	return selection.cards()


func display_cards() -> Array[CardData]:
	if battle_deck_state == null:
		return []
	return CardDisplayOrder.descending(battle_deck_state.hand)


func can_refresh() -> bool:
	return (
		battle_deck_state != null
		and refreshes_remaining > 0
		and selection.size() >= 1
		and selection.size() <= MAX_SELECTED
	)


func restore_refreshes(amount: int) -> int:
	if amount <= 0:
		return refreshes_remaining
	refreshes_remaining = mini(MAX_REFRESHES, refreshes_remaining + amount)
	return refreshes_remaining


func refresh_selected() -> RefreshCommandResult:
	var before := refreshes_remaining
	if not can_refresh():
		return _failed_refresh(before)

	var removed := selection.cards()
	var retained: Array[CardData] = []
	for card in battle_deck_state.hand:
		if not removed.has(card):
			retained.append(card)
	var discard_result := battle_deck_state.discard_cards(removed)
	if discard_result.moved_cards.size() != removed.size():
		return _failed_refresh(before)
	var draw_result := battle_deck_state.draw_to_hand(removed.size())
	refreshes_remaining = maxi(0, refreshes_remaining - 1)
	selection.clear()
	return RefreshCommandResult.new(
		true,
		discard_result.moved_cards,
		draw_result.drawn_cards,
		retained,
		before,
		refreshes_remaining,
		battle_deck_state.hand,
		display_cards(),
		draw_result
	)


func discard_selected_after_judgment() -> DiscardCommandResult:
	if battle_deck_state == null:
		return DiscardCommandResult.new([], 0, 0, 0, 0)
	var result := battle_deck_state.discard_cards(selection.cards())
	selection.clear()
	return result


func cards_needed_to_fill_hand() -> int:
	if battle_deck_state == null:
		return max_hand_size
	return maxi(0, max_hand_size - battle_deck_state.hand.size())


func draw_pile_display_order() -> Array[CardData]:
	if battle_deck_state == null:
		return []
	return battle_deck_state.draw_pile_display_order()


func discard_pile_display_order() -> Array[CardData]:
	if battle_deck_state == null:
		return []
	return battle_deck_state.discard_pile_display_order()


func pile_snapshot(pile_type: StringName) -> RefCounted:
	if battle_deck_state == null:
		return PileSnapshotType.new(pile_type, [], [])
	return battle_deck_state.pile_snapshot(pile_type)


func draw_pile_count() -> int:
	return 0 if battle_deck_state == null else battle_deck_state.draw_pile.size()


func discard_pile_count() -> int:
	return 0 if battle_deck_state == null else battle_deck_state.discard_pile.size()


func clear_battle() -> void:
	selection.clear()
	if battle_deck_state != null:
		battle_deck_state.clear()


func _failed_refresh(before: int) -> RefreshCommandResult:
	var current_hand: Array[CardData] = []
	if battle_deck_state != null:
		current_hand = battle_deck_state.hand
	return RefreshCommandResult.new(
		false,
		[],
		[],
		current_hand,
		before,
		before,
		current_hand,
		CardDisplayOrder.descending(current_hand),
		_empty_draw_result(0)
	)


func _empty_draw_result(requested: int) -> DrawCommandResult:
	return DrawCommandResult.new(requested, [], [], [], 0, 0, 0, 0)
