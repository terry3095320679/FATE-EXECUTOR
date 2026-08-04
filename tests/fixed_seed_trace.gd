extends SceneTree

const SEED := 424242


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var deck := Deck.new(DataRepository.load_deck_definition())
	var hand := HandState.new()
	var initial := hand.start_battle(deck, SEED)
	print("seed=%d" % SEED)
	print("initial_draw=%s" % [_ids(initial.drawn_cards)])
	print("zones_after_initial=draw:%d hand:%d discard:%d" % [
		hand.draw_pile_count(),
		hand.battle_deck_state.hand.size(),
		hand.discard_pile_count()
	])

	var played_cards := hand.display_cards().slice(0, 3)
	for card in played_cards:
		hand.set_card_selected(card, true)
	var judgment_discard := hand.discard_selected_after_judgment()
	print("played=%s" % [_ids(judgment_discard.moved_cards)])
	print("retained=%s" % [_ids(hand.battle_deck_state.hand)])
	print("zones_after_play=draw:%d hand:%d discard:%d" % [
		hand.draw_pile_count(),
		hand.battle_deck_state.hand.size(),
		hand.discard_pile_count()
	])

	var refill := hand.start_new_round()
	print("refill_requested=%d" % refill.requested_count)
	print("refill_drawn=%s" % [_ids(refill.drawn_cards)])
	print("final_hand_internal=%s" % [_ids(hand.battle_deck_state.hand)])
	print("final_hand_display=%s" % [_ids(hand.display_cards())])
	print("zones_after_refill=draw:%d hand:%d discard:%d" % [
		hand.draw_pile_count(),
		hand.battle_deck_state.hand.size(),
		hand.discard_pile_count()
	])
	quit(0)


func _ids(cards: Array[CardData]) -> Array[int]:
	var output: Array[int] = []
	for card in cards:
		output.append(card.instance_id)
	return output
