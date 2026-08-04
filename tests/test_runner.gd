extends SceneTree

const PileSnapshotType = preload("res://src/domain/pile_snapshot.gd")

var _failures := 0
var _checks := 0
var _skips := 0
var _rules: Dictionary
var _evaluator: PokerEvaluator


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("FATE EXECUTOR battle-core tests")
	_rules = DataRepository.load_poker_rules()
	_evaluator = PokerEvaluator.new(_rules)
	_test_data_and_localization()
	_test_settings_persistence()
	_test_standard_deck()
	_test_hand_selection_limit()
	_test_display_sorting()
	_test_battle_deck_initialization_and_draw()
	_test_refresh_domain_rules()
	_test_judgment_discard_and_next_round()
	_test_reshuffle_boundaries()
	_test_pile_browser_projection_is_read_only()
	_test_pile_group_snapshots()
	_test_poker_evaluator()
	_test_battle_resolution()
	await _test_main_menu_localization()
	await _test_battle_ui()

	var passed := _checks - _failures
	print("TOTAL: %d | PASS: %d | FAIL: %d | SKIP: %d" % [
		_checks,
		passed,
		_failures,
		_skips
	])
	if _failures == 0:
		quit(0)
	else:
		push_error("FAIL: %d of %d checks failed" % [_failures, _checks])
		quit(1)


func _test_data_and_localization() -> void:
	_assert_equal(_rules.size(), 9, "loads nine poker hand definitions")
	var enemy := DataRepository.load_enemy(&"debt_gambler")
	_assert_equal(enemy.get("max_health"), 72, "loads enemy data")
	_assert_equal(enemy.get("name_key"), "enemy.debt_gambler.name", "enemy uses localization key")
	var localization := LocalizationService.new(DataRepository.load_localization())
	_assert_equal(localization.get_language(), "en", "default language is English")
	_assert_equal(localization.text("menu.start_game"), "Start Game", "English menu translation")
	_assert_equal(localization.text("pile.draw"), "Draw Pile", "English draw pile translation")
	_assert_equal(
		localization.text("battle.refresh_in_progress"),
		"Refresh in progress.",
		"English refresh progress translation"
	)
	_assert_equal(
		localization.text("pile.title_one", ["Draw Pile", 1]),
		"Draw Pile — 1 Card",
		"English uses singular Card"
	)
	_assert_equal(
		localization.text("pile.title_many", ["Draw Pile", 2]),
		"Draw Pile — 2 Cards",
		"English uses plural Cards"
	)
	_assert_true(localization.set_language("zh_CN"), "can switch to Simplified Chinese")
	_assert_equal(localization.text("menu.start_game"), "开始游戏", "Chinese updates immediately")
	_assert_equal(localization.text("hand.straight_flush"), "同花顺", "Chinese poker hand translation")
	_assert_equal(localization.text("pile.discard"), "弃牌堆", "Chinese discard pile translation")
	_assert_equal(
		localization.text("pile.empty_message"),
		"此牌堆中没有卡牌。",
		"Chinese empty pile translation"
	)
	_assert_true(localization.set_language("en"), "can switch back to English")
	_assert_equal(localization.text("hand.high_card"), "High Card", "English poker hand translation")


func _test_settings_persistence() -> void:
	var path := "res://test-artifacts/test_settings_%d.json" % Time.get_ticks_usec()
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute_path)
	var first := SettingsRepository.new(path)
	_assert_equal(first.load_language(), "en", "missing settings defaults to English")
	_assert_true(first.save_language("zh_CN"), "language setting saves")
	var second := SettingsRepository.new(path)
	_assert_equal(second.load_language(), "zh_CN", "language survives repository restart")
	var damaged := FileAccess.open(path, FileAccess.WRITE)
	damaged.store_string("{not valid json")
	damaged.close()
	_assert_equal(
		SettingsRepository.new(path).load_language(),
		"en",
		"damaged settings automatically fall back to English"
	)
	var unsupported := FileAccess.open(path, FileAccess.WRITE)
	unsupported.store_string(JSON.stringify({"language": "unknown"}))
	unsupported.close()
	_assert_equal(
		SettingsRepository.new(path).load_language(),
		"en",
		"unsupported saved language falls back to English"
	)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute_path)


func _test_standard_deck() -> void:
	var deck := Deck.new(DataRepository.load_deck_definition(), 12345)
	_assert_equal(deck.cards.size(), 52, "standard deck has 52 cards")
	_assert_true(_has_unique_instances(deck.cards), "all persistent deck instances are unique")
	var legacy_draw := deck.draw_unique(8)
	_assert_equal(legacy_draw.size(), 8, "legacy unique draw remains compatible")
	_assert_true(_has_unique_instances(legacy_draw), "legacy draw has no duplicate instances")
	_assert_equal(deck.cards.size(), 52, "persistent deck is not mutated by combat setup")


func _test_hand_selection_limit() -> void:
	var available := _cards([[1, 0], [2, 0], [3, 0], [4, 0], [5, 0], [6, 0]])
	var selection := HandSelection.new(5)
	for index in range(5):
		_assert_equal(
			selection.set_selected(available[index], true, available),
			HandSelection.ChangeResult.ADDED,
			"selection accepts card %d of five" % (index + 1)
		)
	var original_ids := _card_ids(selection.cards())
	_assert_equal(
		selection.set_selected(available[5], true, available),
		HandSelection.ChangeResult.REJECTED_LIMIT,
		"rule layer rejects sixth selected card"
	)
	_assert_equal(selection.size(), 5, "rejected sixth keeps five selections")
	_assert_equal(_card_ids(selection.cards()), original_ids, "rejected sixth preserves original five")
	_assert_equal(
		selection.set_selected(available[0], false, available),
		HandSelection.ChangeResult.REMOVED,
		"selected card can be cancelled"
	)
	_assert_equal(
		selection.set_selected(available[5], true, available),
		HandSelection.ChangeResult.ADDED,
		"another card can be selected after cancellation"
	)
	var invalid := _cards([[13, 3]])[0]
	_assert_equal(
		selection.set_selected(invalid, true, available),
		HandSelection.ChangeResult.REJECTED_INVALID,
		"selection rejects cards outside the current hand"
	)


func _test_display_sorting() -> void:
	var source := _cards([
		[13, 3], [1, 2], [7, 3], [7, 1], [7, 0], [7, 2], [4, 1], [11, 0]
	])
	var internal_ids := _card_ids(source)
	var ordered := CardDisplayOrder.descending(source)
	_assert_equal(_ranks(ordered), [13, 11, 7, 7, 7, 7, 4, 1], "display sorts K to A left to right")
	_assert_true(_is_descending(ordered), "display increases from right to left")
	_assert_equal(_suits_for_rank(ordered, 7), [0, 1, 2, 3], "equal ranks use fixed suit order")
	_assert_equal(_card_ids(source), internal_ids, "display sorting does not mutate source order")
	_assert_equal(
		_suits_for_rank(ordered, 7),
		[0, 1, 2, 3],
		"fixed suit order is clubs-diamonds-hearts-spades"
	)


func _test_battle_deck_initialization_and_draw() -> void:
	var deck := Deck.new(DataRepository.load_deck_definition(), 111)
	var state := BattleDeckState.new()
	state.initialize(deck.cards, 424242)
	_assert_equal(state.draw_pile.size(), 52, "battle start puts every card in draw pile")
	_assert_equal(state.hand.size(), 0, "battle state begins with empty hand before draw")
	_assert_equal(state.discard_pile.size(), 0, "battle start discard pile is empty")
	_assert_true(state.is_consistent(), "initialized battle zones are consistent")
	var shuffled_order := _card_ids(state.draw_pile)
	_assert_true(shuffled_order != _card_ids(deck.cards), "combat draw pile is deterministically shuffled")
	var rng_after_shuffle := state.random_state()
	var draw := state.draw_to_hand(8)
	_assert_equal(draw.drawn_cards.size(), 8, "initial draw obtains eight cards")
	_assert_equal(state.draw_pile.size(), 44, "initial draw removes eight from draw pile")
	_assert_equal(state.hand.size(), 8, "initial hand owns eight cards")
	_assert_equal(state.discard_pile.size(), 0, "initial draw does not add discards")
	_assert_true(_has_unique_instances(state.hand), "initial hand has eight distinct instances")
	_assert_true(state.is_consistent(), "zones remain consistent after initial draw")
	_assert_equal(state.random_state(), rng_after_shuffle, "drawing from a sufficient pile consumes no RNG")
	_assert_equal(
		draw.drawn_cards[0].instance_id,
		shuffled_order[shuffled_order.size() - 1],
		"draw pile top is the array end"
	)
	for card in state.hand:
		_assert_equal(state.zone_of(card.instance_id), BattleDeckState.Zone.HAND, "drawn instance only owns HAND zone")

	var state_repeat := BattleDeckState.new()
	state_repeat.initialize(deck.cards, 424242)
	var repeated := state_repeat.draw_to_hand(8)
	_assert_equal(_card_ids(repeated.drawn_cards), _card_ids(draw.drawn_cards), "fixed seed reproduces initial draw")


func _test_refresh_domain_rules() -> void:
	var deck := Deck.new(DataRepository.load_deck_definition(), 24680)
	var hand := HandState.new()
	hand.start_battle(deck, 24680)
	_assert_equal(hand.refreshes_remaining, 3, "new battle starts with three refreshes")
	_assert_equal(hand.battle_deck_state.hand.size(), 8, "new battle hand has eight cards")
	_assert_equal(hand.draw_pile_count(), 44, "new battle draw pile has 44 cards")
	_assert_equal(hand.discard_pile_count(), 0, "new battle discard pile is empty")
	_assert_true(_is_descending(hand.display_cards()), "new hand display is descending")
	var internal_before_display := _card_ids(hand.battle_deck_state.hand)
	hand.display_cards()
	_assert_equal(
		_card_ids(hand.battle_deck_state.hand),
		internal_before_display,
		"display sort does not alter internal hand order"
	)

	var failed := hand.refresh_selected()
	_assert_true(not failed.success, "domain rejects refresh with no selected cards")
	_assert_equal(hand.refreshes_remaining, 3, "empty refresh consumes no charge")
	var battle := BattleState.new(DataRepository.load_enemy(&"debt_gambler"))
	var round_before := battle.round_number
	var health_before := battle.player_health
	var intent_before := battle.enemy_intent_key
	var refreshed_card := hand.battle_deck_state.hand[0]
	var retained: Array[CardData] = hand.battle_deck_state.hand.slice(1)
	hand.set_card_selected(refreshed_card, true)
	var one := hand.refresh_selected()
	_assert_true(one.success, "one-card refresh succeeds")
	_assert_equal(one.removed_instance_ids(), [refreshed_card.instance_id], "result locks removed instance")
	_assert_equal(one.drawn_cards.size(), 1, "one-card refresh draws one replacement")
	_assert_equal(one.retained_cards.size(), 7, "one-card refresh retains seven instances")
	_assert_equal(one.refreshes_before, 3, "refresh result records pre-count")
	_assert_equal(one.refreshes_after, 2, "refresh result records post-count")
	_assert_equal(hand.refreshes_remaining, 2, "successful refresh consumes exactly one charge")
	_assert_equal(hand.battle_deck_state.hand.size(), 8, "one-card refresh restores eight cards")
	_assert_equal(hand.discard_pile_count(), 1, "refreshed card enters discard pile")
	_assert_equal(
		hand.battle_deck_state.zone_of(refreshed_card.instance_id),
		BattleDeckState.Zone.DISCARD_PILE,
		"refreshed card does not return directly to draw pile"
	)
	for card in retained:
		_assert_true(hand.battle_deck_state.hand.has(card), "unselected refresh card remains in hand")
	_assert_true(not hand.battle_deck_state.hand.has(refreshed_card), "refreshed card cannot immediately return when draw pile is sufficient")
	_assert_true(hand.battle_deck_state.is_consistent(), "one-card refresh zones are consistent")
	_assert_true(_has_unique_instances(hand.battle_deck_state.hand), "one-card refresh has no duplicate hand instances")
	_assert_equal(hand.selection.size(), 0, "refresh clears selection")
	_assert_equal(battle.round_number, round_before, "refresh does not advance round")
	_assert_equal(battle.player_health, health_before, "refresh does not trigger enemy damage")
	_assert_equal(battle.enemy_intent_key, intent_before, "refresh preserves enemy intent")
	_assert_true(_is_descending(one.final_hand_display), "refresh result contains descending UI order")

	var candidates := hand.display_cards()
	for index in range(5):
		hand.set_card_selected(candidates[index], true)
	var original_five := _card_ids(hand.selected_cards())
	_assert_equal(
		hand.set_card_selected(candidates[5], true),
		HandSelection.ChangeResult.REJECTED_LIMIT,
		"unified refresh/play selection rejects sixth card"
	)
	_assert_equal(_card_ids(hand.selected_cards()), original_five, "sixth rejection preserves five selections")
	var five := hand.refresh_selected()
	_assert_true(five.success, "five-card refresh succeeds")
	_assert_equal(five.removed_cards.size(), 5, "five-card refresh discards five")
	_assert_equal(five.drawn_cards.size(), 5, "five-card refresh draws five")
	_assert_equal(hand.battle_deck_state.hand.size(), 8, "five-card refresh restores eight")
	_assert_equal(hand.refreshes_remaining, 1, "five-card refresh still costs one charge")
	_assert_true(hand.battle_deck_state.is_consistent(), "five-card refresh preserves zones")

	var selected := hand.display_cards()[0]
	hand.set_card_selected(selected, true)
	_assert_true(hand.refresh_selected().success, "third refresh succeeds")
	_assert_equal(hand.refreshes_remaining, 0, "three refreshes exhaust charges")
	hand.set_card_selected(hand.display_cards()[0], true)
	_assert_true(not hand.refresh_selected().success, "fourth refresh is rejected")
	_assert_equal(hand.refreshes_remaining, 0, "refresh count never goes below zero")
	hand.start_battle(deck, 24680)
	_assert_equal(hand.refreshes_remaining, 3, "new battle or retry resets refresh charges")
	_assert_equal(hand.discard_pile_count(), 0, "retry rebuilds empty discard pile")
	_assert_equal(hand.draw_pile_count(), 44, "retry rebuilds full combat draw cycle")


func _test_judgment_discard_and_next_round() -> void:
	_test_hand_retention_case(1, 901)
	_test_hand_retention_case(3, 903)
	_test_hand_retention_case(5, 905)

	var deck := Deck.new(DataRepository.load_deck_definition())
	var hand := HandState.new()
	hand.start_battle(deck, 999)
	var internal_before := _card_ids(hand.battle_deck_state.hand)
	var rng_before := hand.battle_deck_state.random_state()
	var no_draw := hand.start_new_round()
	_assert_equal(no_draw.requested_count, 0, "full eight-card hand requests no new cards")
	_assert_equal(no_draw.drawn_cards.size(), 0, "full hand draws zero cards")
	_assert_equal(_card_ids(hand.battle_deck_state.hand), internal_before, "zero draw preserves all eight instances")
	_assert_equal(hand.battle_deck_state.random_state(), rng_before, "zero draw consumes no RNG")

	var custom_limit := HandState.new()
	custom_limit.start_battle(deck, 1000, 6)
	_assert_equal(custom_limit.max_hand_size, 6, "hand maximum is stored as battle state data")
	_assert_equal(custom_limit.battle_deck_state.max_hand_size, 6, "deck consistency uses configured hand maximum")
	_assert_equal(custom_limit.battle_deck_state.hand.size(), 6, "initial draw respects configured hand maximum")

	var reshuffle_hand := HandState.new()
	reshuffle_hand.start_battle(deck, 1001)
	var played := reshuffle_hand.battle_deck_state.hand.slice(0, 3)
	for card in played:
		reshuffle_hand.set_card_selected(card, true)
	reshuffle_hand.discard_selected_after_judgment()
	var retained_ids := _card_ids(reshuffle_hand.battle_deck_state.hand)
	reshuffle_hand.battle_deck_state.discard_pile.append_array(
		reshuffle_hand.battle_deck_state.draw_pile
	)
	reshuffle_hand.battle_deck_state.draw_pile.clear()
	var reshuffled_draw := reshuffle_hand.start_new_round()
	_assert_equal(reshuffled_draw.requested_count, 3, "five retained cards request three replacements")
	_assert_equal(reshuffled_draw.reshuffle_count(), 1, "retained-hand refill can trigger reshuffle")
	for retained_id in retained_ids:
		_assert_true(
			_contains_id(reshuffle_hand.battle_deck_state.hand, retained_id),
			"retained instance stays in HAND during reshuffle"
		)
		_assert_true(
			not _contains_id(reshuffled_draw.drawn_cards, retained_id),
			"retained instance is never redrawn"
		)
	_assert_true(reshuffle_hand.battle_deck_state.is_consistent(), "retained-hand reshuffle is consistent")


func _test_hand_retention_case(played_count: int, seed_value: int) -> void:
	var deck := Deck.new(DataRepository.load_deck_definition())
	var hand := HandState.new()
	hand.start_battle(deck, seed_value)
	var original := hand.battle_deck_state.hand.duplicate()
	var played: Array[CardData] = original.slice(0, played_count)
	var retained: Array[CardData] = original.slice(played_count)
	for card in played:
		hand.set_card_selected(card, true)
	var discarded := hand.discard_selected_after_judgment()
	_assert_equal(discarded.moved_cards.size(), played_count, "judgment discards only %d played card(s)" % played_count)
	_assert_equal(_card_ids(discarded.moved_cards), _card_ids(played), "all played cards enter discard in selection order")
	_assert_equal(hand.battle_deck_state.hand.size(), 8 - played_count, "unplayed cards remain in hand")
	_assert_equal(hand.discard_pile_count(), played_count, "discard grows only by played count")
	for card in retained:
		_assert_true(hand.battle_deck_state.hand.has(card), "unplayed instance remains across enemy action")
		_assert_true(not hand.battle_deck_state.discard_pile.has(card), "unplayed instance never enters discard")
	_assert_equal(hand.selection.size(), 0, "judgment clears selection")
	var retained_ids := _card_ids(retained)
	var battle := BattleState.new({"max_health": 999, "attack": 8})
	battle.resolve_enemy_action()
	_assert_equal(
		_card_ids(hand.battle_deck_state.hand),
		retained_ids,
		"enemy action does not clear retained hand"
	)
	var draw_before := hand.draw_pile_count()
	var refill := hand.start_new_round()
	_assert_equal(refill.requested_count, played_count, "next round requests only missing cards")
	_assert_equal(refill.drawn_cards.size(), played_count, "next round draws only missing cards")
	_assert_equal(hand.battle_deck_state.hand.size(), 8, "refill restores hand to maximum")
	_assert_equal(hand.draw_pile_count(), draw_before - played_count, "draw pile decreases by missing count")
	for retained_id in retained_ids:
		_assert_true(_contains_id(hand.battle_deck_state.hand, retained_id), "retained instance ID survives refill")
	_assert_true(_has_unique_instances(hand.battle_deck_state.hand), "refill creates no duplicate hand instances")
	_assert_true(hand.battle_deck_state.is_consistent(), "retained-hand turn remains zone-consistent")


func _test_reshuffle_boundaries() -> void:
	var cards13 := _sequential_cards(13)
	var state := BattleDeckState.new()
	state.initialize(cards13, 13579)
	state.draw_pile = cards13.slice(0, 3)
	state.hand = []
	state.discard_pile = cards13.slice(3, 13)
	var first_three_expected := [
		state.draw_pile[2].instance_id,
		state.draw_pile[1].instance_id,
		state.draw_pile[0].instance_id
	]
	var draw8 := state.draw_to_hand(8)
	_assert_equal(_card_ids(draw8.drawn_cards).slice(0, 3), first_three_expected, "short pile is exhausted before reshuffle")
	_assert_equal(draw8.drawn_cards.size(), 8, "3 draw + 10 discard can supply eight")
	_assert_equal(draw8.reshuffle_count(), 1, "short draw triggers one reshuffle")
	_assert_equal(draw8.reshuffle_draw_offsets, [3], "reshuffle result records draw offset")
	_assert_equal(state.discard_pile.size(), 0, "discard pile clears into draw pile")
	_assert_equal(state.draw_pile.size(), 5, "five shuffled cards remain after drawing eight")
	_assert_true(state.is_consistent(), "3/10 reshuffle zones are consistent")

	var cards8 := _sequential_cards(8)
	var empty_draw := BattleDeckState.new()
	empty_draw.initialize(cards8, 2468)
	empty_draw.draw_pile = []
	empty_draw.hand = []
	empty_draw.discard_pile = cards8.duplicate()
	var exact := empty_draw.draw_to_hand(8)
	_assert_equal(exact.drawn_cards.size(), 8, "zero draw + eight discard supplies eight")
	_assert_equal(empty_draw.draw_pile.size(), 0, "exact reshuffle leaves draw pile empty")
	_assert_equal(empty_draw.discard_pile.size(), 0, "exact reshuffle empties discard")
	_assert_equal(empty_draw.hand.size(), 8, "exact reshuffle owns all cards in hand")
	_assert_true(empty_draw.is_consistent(), "exact reshuffle is consistent")

	var cards10 := _sequential_cards(10)
	var refresh_state := BattleDeckState.new()
	refresh_state.initialize(cards10, 777)
	refresh_state.hand = cards10.slice(0, 5)
	refresh_state.draw_pile = [cards10[5]]
	refresh_state.discard_pile = cards10.slice(6, 10)
	var hand := HandState.new()
	hand.battle_deck_state = refresh_state
	for card in refresh_state.hand.duplicate():
		hand.set_card_selected(card, true)
	var refreshed := hand.refresh_selected()
	_assert_true(refreshed.success, "one draw + four discard boundary refresh executes")
	_assert_equal(refreshed.draw_result.reshuffle_count(), 1, "five-card refresh reshuffles when required")
	_assert_equal(refresh_state.hand.size(), 5, "small-deck refresh restores original hand size")
	_assert_true(refresh_state.is_consistent(), "refresh-triggered reshuffle remains consistent")
	_assert_true(_has_unique_instances(refresh_state.hand), "reshuffle never duplicates an instance")

	var scarce_cards := _sequential_cards(3)
	var scarce := BattleDeckState.new()
	scarce.initialize(scarce_cards, 88)
	scarce.draw_pile = [scarce_cards[0]]
	scarce.hand = []
	scarce.discard_pile = [scarce_cards[1], scarce_cards[2]]
	var shortage := scarce.draw_to_hand(8)
	_assert_equal(shortage.drawn_cards.size(), 3, "shortage draws every available card")
	_assert_true(shortage.shortage, "shortage is reported explicitly")
	_assert_equal(scarce.hand.size(), 3, "shortage permits a hand under eight")
	_assert_true(_has_unique_instances(scarce.hand), "shortage protection never creates duplicates")
	_assert_true(scarce.is_consistent(), "shortage zones remain consistent")

	var deterministic_a := BattleDeckState.new()
	var deterministic_b := BattleDeckState.new()
	deterministic_a.initialize(cards13, 3333)
	deterministic_b.initialize(cards13, 3333)
	deterministic_a.draw_pile = []
	deterministic_b.draw_pile = []
	deterministic_a.discard_pile = cards13.duplicate()
	deterministic_b.discard_pile = cards13.duplicate()
	var a := deterministic_a.draw_to_hand(8)
	var b := deterministic_b.draw_to_hand(8)
	_assert_equal(_card_ids(a.drawn_cards), _card_ids(b.drawn_cards), "reshuffle uses deterministic RNG stream")


func _test_pile_browser_projection_is_read_only() -> void:
	var deck := Deck.new(DataRepository.load_deck_definition())
	var state := BattleDeckState.new()
	state.initialize(deck.cards, 6060)
	state.draw_to_hand(8)
	state.discard_cards(state.hand.slice(0, 3))
	var draw_internal := _card_ids(state.draw_pile)
	var discard_internal := _card_ids(state.discard_pile)
	var rng_before := state.random_state()
	var draw_display := state.draw_pile_display_order()
	var discard_display := state.discard_pile_display_order()
	_assert_true(_is_descending(draw_display), "draw browser projection sorts K to A")
	_assert_true(_is_descending(discard_display), "discard browser projection sorts K to A")
	_assert_equal(_card_ids(state.draw_pile), draw_internal, "draw browser does not alter real pile order")
	_assert_equal(_card_ids(state.discard_pile), discard_internal, "discard browser does not alter real pile order")
	_assert_equal(state.random_state(), rng_before, "browser projections consume no random numbers")
	_assert_true(state.is_consistent(), "browsing leaves zones consistent")


func _test_pile_group_snapshots() -> void:
	var deck := Deck.new(DataRepository.load_deck_definition())
	var state := BattleDeckState.new()
	state.initialize(deck.cards, 7070)
	state.draw_to_hand(8)
	state.discard_cards(state.hand.slice(0, 3))
	var draw_order := _card_ids(state.draw_pile)
	var discard_order := _card_ids(state.discard_pile)
	var rng_before := state.random_state()
	var draw_snapshot := state.pile_snapshot(&"draw")
	var discard_snapshot := state.pile_snapshot(&"discard")
	_assert_equal(draw_snapshot.groups.size(), 4, "draw snapshot always contains four standard suit rows")
	_assert_equal(discard_snapshot.groups.size(), 4, "discard snapshot always contains four standard suit rows")
	_assert_equal(
		_snapshot_suit_ids(draw_snapshot),
		[3, 2, 0, 1],
		"snapshot suit order is spades-hearts-clubs-diamonds"
	)
	_assert_equal(
		_snapshot_suit_ids(discard_snapshot),
		[3, 2, 0, 1],
		"draw and discard snapshots share suit row order"
	)
	for group in draw_snapshot.groups:
		for card in group.display_cards:
			_assert_equal(card.suit, group.suit_id, "each draw row contains only its own suit")
		_assert_true(_is_rank_then_instance_descending(group.display_cards), "each draw suit row is K-to-A with stable duplicates")
	for group in discard_snapshot.groups:
		for card in group.display_cards:
			_assert_equal(card.suit, group.suit_id, "each discard row contains only its own suit")
	_assert_equal(draw_snapshot.grouped_count(), draw_snapshot.total_count, "draw row counts sum to title total")
	_assert_equal(discard_snapshot.grouped_count(), discard_snapshot.total_count, "discard row counts sum to title total")
	_assert_true(draw_snapshot.is_consistent(), "draw snapshot validates grouped count")
	_assert_true(discard_snapshot.is_consistent(), "discard snapshot validates grouped count")
	_assert_equal(_card_ids(state.draw_pile), draw_order, "group snapshot leaves draw order unchanged")
	_assert_equal(_card_ids(state.discard_pile), discard_order, "group snapshot leaves discard order unchanged")
	_assert_equal(state.random_state(), rng_before, "group snapshots consume no RNG")

	var duplicate_cards := _cards([[13, 3], [13, 3], [1, 3], [12, 2], [2, 0], [8, 1]])
	var duplicates := BattleDeckState.new()
	duplicates.initialize(duplicate_cards, 8080)
	duplicates.draw_pile = duplicate_cards.duplicate()
	duplicates.hand = []
	duplicates.discard_pile = []
	var duplicate_snapshot := duplicates.pile_snapshot(&"draw")
	var spades: Variant = duplicate_snapshot.group_for_suit(3)
	_assert_equal(spades.count, 3, "same-suit duplicate ranks are all displayed")
	_assert_equal(spades.display_card_ids.slice(0, 2), [1, 2], "same rank duplicates use stable instance ID")
	_assert_equal(duplicate_snapshot.group_for_suit(0).count, 1, "club count comes from domain cards")
	_assert_equal(duplicate_snapshot.group_for_suit(2).count, 1, "heart count comes from domain cards")
	var empty_discard := duplicates.pile_snapshot(&"discard")
	_assert_equal(empty_discard.groups.size(), 4, "empty pile still exposes four rows")
	for group in empty_discard.groups:
		_assert_equal(group.count, 0, "empty standard suit row remains visible with zero count")

	var wild_card := CardData.new(99, 7, 99, "7", "suit.wild", "★")
	var wild_registry: Array[CardData] = duplicate_cards.duplicate()
	wild_registry.append(wild_card)
	var wild_source: Array[CardData] = [wild_card]
	var wild_snapshot := PileSnapshotType.new(&"draw", wild_source, wild_registry)
	_assert_equal(wild_snapshot.groups.size(), 5, "wild compatibility adds a fifth row only when needed")
	_assert_equal(wild_snapshot.groups[4].suit_id, PileSnapshotType.WILD_SUIT_ID, "wild row follows four standard rows")


func _test_poker_evaluator() -> void:
	var high := _evaluator.evaluate(_cards([[3, 0], [13, 1], [8, 2]]))
	_assert_equal(high.hand_id, &"high_card", "recognizes high card")
	_assert_equal(high.attack_points, 13, "high card scores maximum rank")
	_assert_equal(high.damage, 13, "high card damage")
	var pair := _evaluator.evaluate(_cards([[12, 0], [12, 1], [3, 2], [7, 3]]))
	_assert_equal(pair.hand_id, &"pair", "recognizes pair")
	_assert_equal(pair.damage, 30, "pair multiplier")
	var two_pair := _evaluator.evaluate(_cards([[1, 0], [1, 1], [13, 0], [13, 2], [12, 3]]))
	_assert_equal(two_pair.hand_id, &"two_pair", "AAKKQ recognizes two pair")
	_assert_equal(two_pair.scoring_cards.size(), 4, "two pair ignores kicker")
	_assert_equal(two_pair.damage, 42, "two pair damage")
	var three := _evaluator.evaluate(_cards([[9, 0], [9, 1], [9, 2], [2, 3]]))
	_assert_equal(three.hand_id, &"three_of_a_kind", "recognizes three of a kind")
	_assert_equal(three.damage, 47, "three of a kind damage")
	var low := _evaluator.evaluate(_cards([[1, 0], [2, 1], [3, 2], [4, 3], [5, 0]]))
	_assert_equal(low.hand_id, &"straight", "A-2-3-4-5 is a straight")
	var high_ace := _evaluator.evaluate(_cards([[10, 0], [11, 1], [12, 2], [13, 3], [1, 0]]))
	_assert_true(high_ace.hand_id != &"straight", "10-J-Q-K-A is not a straight")
	var flush := _evaluator.evaluate(_cards([[2, 2], [4, 2], [6, 2], [8, 2], [10, 2]]))
	_assert_equal(flush.hand_id, &"flush", "recognizes flush")
	_assert_equal(flush.damage, 68, "flush damage")
	var full_house := _evaluator.evaluate(_cards([[11, 0], [11, 1], [11, 2], [4, 0], [4, 3]]))
	_assert_equal(full_house.hand_id, &"full_house", "recognizes full house")
	_assert_equal(full_house.damage, 103, "full house damage")
	var four := _evaluator.evaluate(_cards([[7, 0], [7, 1], [7, 2], [7, 3], [13, 0]]))
	_assert_equal(four.hand_id, &"four_of_a_kind", "recognizes four of a kind")
	_assert_equal(four.damage, 77, "four of a kind damage")
	var straight_flush := _evaluator.evaluate(_cards([[5, 3], [6, 3], [7, 3], [8, 3], [9, 3]]))
	_assert_equal(straight_flush.hand_id, &"straight_flush", "recognizes straight flush")
	_assert_equal(straight_flush.damage, 105, "straight flush damage")


func _test_battle_resolution() -> void:
	var victory := BattleState.new({"max_health": 10, "attack": 8})
	var king := _evaluator.evaluate(_cards([[13, 0]]))
	_assert_true(victory.apply_player_hand(king), "player phase reports enemy defeat")
	_assert_true(victory.is_finished, "battle ends when enemy reaches zero")
	_assert_equal(victory.player_health, 100, "defeated enemy cannot counterattack")

	var battle := BattleState.new({"max_health": 1000, "attack": 8})
	_assert_true(not battle.apply_player_hand(king), "surviving enemy proceeds to action")
	_assert_true(not battle.resolve_enemy_action(), "normal enemy action does not end battle")
	_assert_equal(battle.player_health, 92, "enemy action deals configured damage")
	_assert_equal(battle.round_number, 2, "enemy action advances round once")

	var defeat := BattleState.new({"max_health": 1000, "attack": 100})
	defeat.apply_player_hand(king)
	_assert_true(defeat.resolve_enemy_action(), "enemy phase reports player defeat")
	_assert_equal(defeat.player_health, 0, "player health clamps to zero")


func _test_main_menu_localization() -> void:
	_app_services().set_language("en", false)
	var packed_scene := load("res://scenes/main.tscn") as PackedScene
	_assert_true(packed_scene != null, "main menu scene loads")
	if packed_scene == null:
		return
	var main := packed_scene.instantiate()
	main.set("persist_language_changes", false)
	root.add_child(main)
	await process_frame
	await process_frame
	var start_button := main.find_child("StartGameButton", true, false) as Button
	var settings_button := main.find_child("SettingsButton", true, false) as Button
	var english_button := main.find_child("LanguageEnglishButton", true, false) as Button
	var chinese_button := main.find_child("LanguageChineseButton", true, false) as Button
	var back_button := main.find_child("SettingsBackButton", true, false) as Button
	_assert_equal(start_button.text, "Start Game", "start screen defaults to English")
	_assert_equal(settings_button.text, "Settings", "English settings button exists")
	settings_button.pressed.emit()
	await process_frame
	var settings_layer := main.get("_settings_layer") as ColorRect
	_assert_true(settings_layer.visible, "settings opens")
	chinese_button.pressed.emit()
	await process_frame
	_assert_equal(start_button.text, "开始游戏", "language switch updates current menu")
	_assert_equal(back_button.text, "返回", "settings screen updates immediately")
	_assert_equal(_app_services().get_language(), "zh_CN", "settings changes active language")
	english_button.pressed.emit()
	await process_frame
	_assert_equal(start_button.text, "Start Game", "settings can switch back to English")
	_assert_equal(back_button.text, "Back", "settings page switches back to English immediately")
	_app_services().set_language("en", false)
	main.queue_free()
	await process_frame


func _test_battle_ui() -> void:
	_app_services().set_language("en", false)
	var packed_scene := load("res://scenes/battle_screen.tscn") as PackedScene
	_assert_true(packed_scene != null, "battle scene loads")
	if packed_scene == null:
		return
	var screen := packed_scene.instantiate()
	screen.set("animation_duration_scale", 0.0)
	screen.set("fixed_battle_seed", 424242)
	root.add_child(screen)
	await _wait_for_animation(screen)
	var buttons := _collect_hand_card_buttons(screen)
	_assert_equal(buttons.size(), 8, "battle UI presents eight interactive hand cards")
	_assert_true(_button_cards_descending(buttons), "hand UI is K-to-A from left to right")
	_assert_equal((screen.get("_last_draw_entry_sequence") as Array).size(), 8, "initial draw animates eight cards sequentially")
	var draw_pile_button := screen.find_child("DrawPileButton", true, false) as Button
	var discard_pile_button := screen.find_child("DiscardPileButton", true, false) as Button
	_assert_equal(screen.get("_last_draw_animation_origin"), _pile_center(draw_pile_button), "new cards originate at right draw pile")
	var hand_state := screen.get("_hand_state") as HandState
	_assert_equal(
		hand_state.max_hand_size,
		(screen.get("_battle") as BattleState).player_hand_size,
		"UI hand maximum comes from player battle state"
	)
	_assert_equal(hand_state.draw_pile_count(), 44, "draw pile UI domain starts at 44")
	_assert_equal(hand_state.discard_pile_count(), 0, "discard pile domain starts empty")
	_assert_true(draw_pile_button.text.contains("44"), "draw pile count UI matches domain")
	_assert_true(discard_pile_button.text.contains("0"), "discard pile count UI matches domain")

	discard_pile_button.pressed.emit()
	await process_frame
	var pile_overlay := screen.get("_pile_overlay") as ColorRect
	_assert_true(pile_overlay.visible, "clicking empty discard opens browser")
	var browser_rows := screen.get("_pile_browser_rows") as VBoxContainer
	var browser_title := screen.get("_pile_browser_title") as Label
	_assert_equal(browser_rows.get_child_count(), 4, "empty discard browser keeps four suit rows")
	_assert_equal(_ui_suit_row_ids(browser_rows), [3, 2, 0, 1], "UI suit rows use required order")
	_assert_equal(browser_title.text, "Discard Pile — 0 Cards", "empty discard title shows plural total")
	for row in browser_rows.get_children():
		var empty_label := row.find_child("SuitEmptyLabel", true, false) as Label
		_assert_true(empty_label != null, "empty suit row shows an empty label")
		_assert_equal(empty_label.text, "No cards.", "empty suit row uses localized text")
	var close_button := screen.find_child("PileBrowserCloseButton", true, false) as Button
	close_button.pressed.emit()
	_assert_true(not pile_overlay.visible, "pile browser close button returns to battle")

	var initial_state := hand_state.battle_deck_state
	var saved_draw := initial_state.draw_pile.duplicate()
	initial_state.discard_pile.append_array(initial_state.draw_pile)
	initial_state.draw_pile.clear()
	screen.call("_update_pile_ui")
	draw_pile_button.pressed.emit()
	await process_frame
	_assert_true(pile_overlay.visible, "empty draw pile can still be opened")
	_assert_equal(browser_rows.get_child_count(), 4, "empty draw pile still shows four suit rows")
	for row in browser_rows.get_children():
		_assert_equal(int(row.get_meta("card_count")), 0, "empty draw suit count is zero")
	screen.call("_close_pile_browser")
	initial_state.draw_pile = saved_draw
	initial_state.discard_pile.clear()
	screen.call("_update_pile_ui")
	_assert_true(initial_state.is_consistent(), "empty-browser test restores all battle zones")

	var hovered := buttons[0] as PokerCardButton
	var start_position := hovered.position
	var start_size := hovered.size
	var normal_luminance := hovered.modulate.get_luminance()
	hovered.set_hovered_for_test(true)
	await process_frame
	_assert_equal(hovered.get_visual_state(), PokerCardButton.VisualState.HOVERED, "unselected hover highlights")
	_assert_equal(hovered.position, start_position, "unselected hover does not move")
	_assert_equal(hovered.size, start_size, "unselected hover does not resize")
	_assert_equal(hovered.rotation, 0.0, "unselected hover does not rotate")
	_assert_true(hovered.modulate.get_luminance() > normal_luminance, "unselected hover visibly brightens")
	hovered.set_hovered_for_test(false)
	_set_card_pressed(hovered, true)
	await create_timer(0.15).timeout
	var selected_position := hovered.position
	var selected_size := hovered.size
	var selected_modulate := hovered.modulate
	hovered.set_hovered_for_test(true)
	await process_frame
	_assert_equal(hovered.get_visual_state(), PokerCardButton.VisualState.SELECTED, "selected overrides hover")
	_assert_equal(hovered.modulate, selected_modulate, "selected hover adds no second highlight")
	_assert_equal(hovered.position, selected_position, "selected hover does not move")
	_assert_equal(hovered.size, selected_size, "selected hover does not resize")
	hovered.set_hovered_for_test(false)
	_set_card_pressed(hovered, false)
	await create_timer(0.15).timeout

	for index in range(5):
		_set_card_pressed(buttons[index], true)
	var original_five := _card_ids(hand_state.selected_cards())
	_set_card_pressed(buttons[5], true)
	await process_frame
	_assert_true(not buttons[5].button_pressed, "sixth UI card is rejected")
	_assert_equal(hand_state.selection.size(), 5, "domain still owns five selections")
	_assert_equal(_card_ids(hand_state.selected_cards()), original_five, "UI rejection preserves original five")
	var feedback := screen.get("_feedback_label") as Label
	_assert_equal(feedback.text, "You can select up to 5 cards.", "selection limit feedback is English")
	_set_card_pressed(buttons[0], false)
	_set_card_pressed(buttons[5], true)
	_assert_true(hand_state.selection.contains(buttons[5].card_data), "cancel then select another card works")
	for button in buttons:
		if button.button_pressed:
			_set_card_pressed(button, false)

	var refresh_button := screen.find_child("RefreshButton", true, false) as Button
	var play_button := screen.find_child("PlayButton", true, false) as Button
	screen.call("_on_refresh_pressed")
	_assert_equal(feedback.text, "Select at least 1 card to refresh.", "empty refresh gives localized feedback")
	_assert_true(refresh_button.disabled, "refresh button is disabled without selection")
	buttons = _collect_hand_card_buttons(screen)
	var refreshed_suit := buttons[0].card_data.suit
	_set_card_pressed(buttons[0], true)
	var retained_ids := _card_ids(hand_state.battle_deck_state.hand)
	retained_ids.erase(buttons[0].card_data.instance_id)
	var round_before := (screen.get("_battle") as BattleState).round_number
	var health_before := (screen.get("_battle") as BattleState).player_health
	refresh_button.pressed.emit()
	_assert_true(bool(screen.get("_animation_in_progress")), "refresh locks input immediately")
	_assert_true(play_button.disabled, "judgment is disabled during refresh animation")
	screen.call("_on_refresh_pressed")
	_assert_equal(screen.get("_refresh_execution_count"), 1, "rapid second refresh does not execute")
	await _wait_for_animation(screen)
	hand_state = screen.get("_hand_state") as HandState
	_assert_equal(hand_state.refreshes_remaining, 2, "UI refresh costs one charge")
	_assert_equal(hand_state.battle_deck_state.hand.size(), 8, "UI refresh restores eight cards")
	_assert_equal(hand_state.selection.size(), 0, "refresh animation ends with cleared selection")
	for retained_id in retained_ids:
		_assert_true(_contains_id(hand_state.battle_deck_state.hand, retained_id), "UI refresh retains unselected instance")
	_assert_equal((screen.get("_battle") as BattleState).round_number, round_before, "UI refresh does not advance round")
	_assert_equal((screen.get("_battle") as BattleState).player_health, health_before, "UI refresh does not trigger enemy")
	_assert_true(_button_cards_descending(_collect_hand_card_buttons(screen)), "refresh ends in descending display order")
	_assert_true(
		(screen.get("_last_discard_animation_target") as Vector2).distance_to(
			_pile_center(discard_pile_button)
		) <= 1.0,
		"refresh flies to left discard pile"
	)
	_assert_true(
		(screen.get("_last_draw_animation_origin") as Vector2).distance_to(
			_pile_center(draw_pile_button)
		) <= 1.0,
		"refresh draws from right pile"
	)
	_assert_equal((screen.get("_last_draw_entry_sequence") as Array).size(), 1, "one replacement enters sequential draw track")
	_assert_true(not bool(screen.get("_input_locked")), "input restores after refresh animation")
	_assert_true(discard_pile_button.text.contains("1"), "discard count UI updates after refresh")
	var discard_after_refresh: Variant = hand_state.pile_snapshot(&"discard")
	_assert_equal(
		discard_after_refresh.group_for_suit(refreshed_suit).count,
		1,
		"refresh increases the selected card's suit row"
	)

	var draw_internal := _card_ids(hand_state.battle_deck_state.draw_pile)
	var rng_before := hand_state.battle_deck_state.random_state()
	var refreshes_before_browser := hand_state.refreshes_remaining
	var round_before_browser := (screen.get("_battle") as BattleState).round_number
	draw_pile_button.pressed.emit()
	await process_frame
	_assert_true(pile_overlay.visible, "draw pile button opens browser")
	_assert_equal(browser_rows.get_child_count(), 4, "draw browser shows four standard suit rows")
	_assert_equal(_ui_suit_row_ids(browser_rows), [3, 2, 0, 1], "draw browser row order is fixed")
	_assert_equal(_ui_suit_count_sum(browser_rows), hand_state.draw_pile_count(), "UI suit counts sum to draw total")
	for row in browser_rows.get_children():
		_assert_true(_ui_suit_row_is_valid(row), "UI row contains one suit in K-to-A order")
	_assert_equal(_card_ids(hand_state.battle_deck_state.draw_pile), draw_internal, "UI browser leaves internal draw order unchanged")
	_assert_equal(hand_state.battle_deck_state.random_state(), rng_before, "UI browser consumes no RNG")
	_assert_equal(_count_type_recursive(browser_rows, PokerCardButton), 0, "browser contains no hand card buttons")
	var first_pile_card := _first_pile_card_button(browser_rows)
	_assert_true(first_pile_card != null, "browser exposes read-only card detail buttons")
	first_pile_card.pressed.emit()
	await process_frame
	var detail_overlay := screen.get("_card_detail_overlay") as ColorRect
	_assert_true(detail_overlay.visible, "clicking pile card opens read-only detail")
	(screen.get("_card_detail_close") as Button).pressed.emit()
	_assert_true(not detail_overlay.visible, "card detail close returns to pile browser")

	_app_services().set_language("zh_CN", false)
	await process_frame
	_assert_true(browser_title.text.begins_with("牌堆 — "), "open pile title updates to Chinese")
	_assert_true(browser_title.text.ends_with("张"), "Chinese pile title uses 张")
	var spade_label := browser_rows.get_child(0).find_child("SuitCountLabel", true, false) as Label
	_assert_true(spade_label.text.contains("黑桃"), "open suit row name updates to Chinese")
	_assert_true(spade_label.text.ends_with("张"), "Chinese suit count uses 张")
	_app_services().set_language("en", false)
	await process_frame
	screen.call("_close_pile_browser")
	_assert_equal(hand_state.refreshes_remaining, refreshes_before_browser, "pile browser consumes no refreshes")
	_assert_equal((screen.get("_battle") as BattleState).round_number, round_before_browser, "closing browser leaves battle round unchanged")

	_app_services().set_language("zh_CN", false)
	await process_frame
	_assert_equal(play_button.text, "确认", "battle confirm updates to Chinese immediately")
	_assert_true(draw_pile_button.text.contains("牌堆"), "pile count updates to Chinese immediately")
	buttons = _collect_hand_card_buttons(screen)
	_set_card_pressed(buttons[0], true)
	var preview := screen.get("_preview_label") as Label
	_assert_true(preview.text.contains("单张"), "current poker-hand preview updates to Chinese")
	_set_card_pressed(buttons[0], false)
	_app_services().set_language("en", false)
	await process_frame

	buttons = _collect_hand_card_buttons(screen)
	var played_card := buttons[0].card_data
	var retained_after_play := _card_ids(hand_state.battle_deck_state.hand)
	retained_after_play.erase(played_card.instance_id)
	var discard_suits_before := _snapshot_suit_counts(hand_state.pile_snapshot(&"discard"))
	_set_card_pressed(buttons[0], true)
	play_button.pressed.emit()
	await _wait_for_animation(screen)
	hand_state = screen.get("_hand_state") as HandState
	var battle := screen.get("_battle") as BattleState
	_assert_equal(battle.round_number, 2, "judgment enemy action advances to next round")
	_assert_equal(battle.player_health, 92, "enemy counterattacks after judgment discard")
	_assert_equal(hand_state.battle_deck_state.hand.size(), 8, "next round refills hand to eight")
	_assert_equal(hand_state.discard_pile_count(), 2, "refresh card plus only one played card are discarded")
	_assert_equal(hand_state.draw_pile_count(), 42, "next round draws only one missing card")
	for retained_id in retained_after_play:
		_assert_true(_contains_id(hand_state.battle_deck_state.hand, retained_id), "unplayed UI card persists into next round")
	_assert_equal(
		screen.get("_last_discard_entry_sequence"),
		[played_card.instance_id],
		"judgment animation discards only the played card"
	)
	_assert_equal(
		(screen.get("_last_draw_entry_sequence") as Array).size(),
		1,
		"next round animates only one replacement card"
	)
	var discard_suits_after := _snapshot_suit_counts(hand_state.pile_snapshot(&"discard"))
	for suit_id in [3, 2, 0, 1]:
		var expected_delta := 1 if suit_id == played_card.suit else 0
		_assert_equal(
			int(discard_suits_after[suit_id]) - int(discard_suits_before[suit_id]),
			expected_delta,
			"judgment increases only the played suit row"
		)
	_assert_true(_button_cards_descending(_collect_hand_card_buttons(screen)), "next round hand is descending")
	_assert_true(hand_state.battle_deck_state.is_consistent(), "UI turn leaves zones consistent")

	var shuffle_before: int = screen.get("_shuffle_animation_count")
	var deck_state := hand_state.battle_deck_state
	deck_state.discard_pile.append_array(deck_state.draw_pile)
	deck_state.draw_pile.clear()
	buttons = _collect_hand_card_buttons(screen)
	_set_card_pressed(buttons[0], true)
	refresh_button.pressed.emit()
	await _wait_for_animation(screen)
	_assert_equal(screen.get("_shuffle_animation_count"), shuffle_before + 1, "refresh-triggered reshuffle plays feedback")
	_assert_true(deck_state.is_consistent(), "UI reshuffle retains zone consistency")

	var restart_button := screen.find_child("RestartButton", true, false) as Button
	restart_button.pressed.emit()
	await _wait_for_animation(screen)
	hand_state = screen.get("_hand_state") as HandState
	_assert_equal(hand_state.refreshes_remaining, 3, "retry resets three refreshes")
	_assert_equal(hand_state.draw_pile_count(), 44, "retry creates a fresh draw pile")
	_assert_equal(hand_state.discard_pile_count(), 0, "retry clears discard pile")
	_assert_equal(hand_state.battle_deck_state.hand.size(), 8, "retry draws eight")

	buttons = _collect_hand_card_buttons(screen)
	var battle_for_win := screen.get("_battle") as BattleState
	battle_for_win.enemy_health = 1
	_set_card_pressed(buttons[0], true)
	play_button.pressed.emit()
	await _wait_for_result(screen)
	_assert_true((screen.get("_result_overlay") as ColorRect).visible, "victory result appears")
	_assert_equal(hand_state.battle_deck_state.all_cards.size(), 0, "battle end clears combat deck registry")
	_assert_equal(hand_state.draw_pile_count(), 0, "battle end clears draw pile")
	_assert_equal(hand_state.discard_pile_count(), 0, "battle end clears discard pile")
	_app_services().set_language("zh_CN", false)
	await process_frame
	_assert_equal((screen.get("_result_title") as Label).text, "胜利", "visible result updates to Chinese")
	_assert_equal((screen.get("_retry_button") as Button).text, "重试", "retry button updates to Chinese")

	screen.queue_free()
	_app_services().set_language("en", false)
	await process_frame


func _wait_for_animation(screen: Node, max_frames: int = 120) -> void:
	for _index in range(max_frames):
		await process_frame
		if not bool(screen.get("_animation_in_progress")):
			return
	_assert_true(false, "animation completed within frame budget")


func _wait_for_result(screen: Node, max_frames: int = 120) -> void:
	for _index in range(max_frames):
		await process_frame
		if (screen.get("_result_overlay") as ColorRect).visible:
			return
	_assert_true(false, "result appeared within frame budget")


func _collect_hand_card_buttons(screen: Node) -> Array[PokerCardButton]:
	var output: Array[PokerCardButton] = []
	var container := screen.find_child("HandContainer", true, false)
	if container == null:
		return output
	for child in container.get_children():
		if child is PokerCardButton:
			output.append(child)
	return output


func _button_cards_descending(buttons: Array[PokerCardButton]) -> bool:
	var cards: Array[CardData] = []
	for button in buttons:
		cards.append(button.card_data)
	return _is_descending(cards)


func _browser_views_descending(grid: GridContainer) -> bool:
	var ranks: Array[int] = []
	var labels := {"A": 1, "J": 11, "Q": 12, "K": 13}
	for panel in grid.get_children():
		var label := panel.get_child(0) as Label
		var rank_text := label.text.split("\n")[0]
		ranks.append(int(labels.get(rank_text, int(rank_text))))
	for index in range(1, ranks.size()):
		if ranks[index - 1] < ranks[index]:
			return false
	return true


func _ui_suit_row_ids(rows: VBoxContainer) -> Array[int]:
	var output: Array[int] = []
	for row in rows.get_children():
		output.append(int(row.get_meta("suit_id")))
	return output


func _ui_suit_count_sum(rows: VBoxContainer) -> int:
	var output := 0
	for row in rows.get_children():
		output += int(row.get_meta("card_count"))
	return output


func _ui_suit_row_is_valid(row: Node) -> bool:
	var suit_id := int(row.get_meta("suit_id"))
	var cards: Array[CardData] = []
	var cards_row := row.find_child("SuitCards", true, false)
	for child in cards_row.get_children():
		if child is Button and child.has_meta("card_data"):
			var card := child.get_meta("card_data") as CardData
			if card.suit != suit_id:
				return false
			cards.append(card)
	return _is_rank_then_instance_descending(cards)


func _first_pile_card_button(rows: VBoxContainer) -> Button:
	for row in rows.get_children():
		var cards_row := row.find_child("SuitCards", true, false)
		for child in cards_row.get_children():
			if child is Button and child.has_meta("card_data"):
				return child
	return null


func _count_type_recursive(node: Node, type_script: Variant) -> int:
	var count := 0
	for child in node.get_children():
		if is_instance_of(child, type_script):
			count += 1
		count += _count_type_recursive(child, type_script)
	return count


func _count_type(node: Node, type_script: Variant) -> int:
	var count := 0
	for child in node.get_children():
		if is_instance_of(child, type_script):
			count += 1
	return count


func _pile_center(button: Control) -> Vector2:
	return button.global_position + button.size * 0.5


func _ranks(cards: Array[CardData]) -> Array[int]:
	var output: Array[int] = []
	for card in cards:
		output.append(card.rank)
	return output


func _suits_for_rank(cards: Array[CardData], rank: int) -> Array[int]:
	var output: Array[int] = []
	for card in cards:
		if card.rank == rank:
			output.append(card.suit)
	return output


func _is_descending(cards: Array[CardData]) -> bool:
	for index in range(1, cards.size()):
		var previous := cards[index - 1]
		var current := cards[index]
		if previous.rank < current.rank:
			return false
		if previous.rank == current.rank and previous.suit > current.suit:
			return false
	return true


func _is_rank_then_instance_descending(cards: Array[CardData]) -> bool:
	for index in range(1, cards.size()):
		var previous := cards[index - 1]
		var current := cards[index]
		if previous.rank < current.rank:
			return false
		if previous.rank == current.rank and previous.instance_id > current.instance_id:
			return false
	return true


func _snapshot_suit_ids(snapshot: Variant) -> Array[int]:
	var output: Array[int] = []
	for group in snapshot.groups:
		output.append(group.suit_id)
	return output


func _snapshot_suit_counts(snapshot: Variant) -> Dictionary:
	var output: Dictionary = {}
	for group in snapshot.groups:
		output[group.suit_id] = group.count
	return output


func _has_unique_instances(cards: Array[CardData]) -> bool:
	var seen: Dictionary = {}
	for card in cards:
		if seen.has(card.instance_id):
			return false
		seen[card.instance_id] = true
	return true


func _contains_id(cards: Array[CardData], instance_id: int) -> bool:
	for card in cards:
		if card.instance_id == instance_id:
			return true
	return false


func _card_ids(cards: Array[CardData]) -> Array[int]:
	var output: Array[int] = []
	for card in cards:
		output.append(card.instance_id)
	return output


func _set_card_pressed(button: PokerCardButton, value: bool) -> void:
	button.set_pressed_no_signal(value)
	button.toggled.emit(value)


func _app_services() -> Node:
	return root.get_node("AppServices")


func _sequential_cards(count: int) -> Array[CardData]:
	var output: Array[CardData] = []
	for index in range(count):
		var rank := index % 13 + 1
		var suit := index / 13
		output.append(CardData.new(
			index + 1,
			rank,
			suit,
			_rank_label(rank),
			"suit",
			"♣"
		))
	return output


func _cards(specifications: Array) -> Array[CardData]:
	var output: Array[CardData] = []
	var suit_names := ["梅花", "方片", "红桃", "黑桃"]
	var suit_symbols := ["♣", "♦", "♥", "♠"]
	for index in range(specifications.size()):
		var rank_value: int = specifications[index][0]
		var suit_value: int = specifications[index][1]
		output.append(CardData.new(
			index + 1,
			rank_value,
			suit_value,
			_rank_label(rank_value),
			suit_names[suit_value],
			suit_symbols[suit_value]
		))
	return output


func _rank_label(rank: int) -> String:
	match rank:
		1:
			return "A"
		11:
			return "J"
		12:
			return "Q"
		13:
			return "K"
		_:
			return str(rank)


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	_checks += 1
	if actual != expected:
		_failures += 1
		push_error("%s: expected %s, got %s" % [message, expected, actual])


func _assert_true(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		push_error(message)
