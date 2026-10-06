extends SceneTree

const PileSnapshotType = preload("res://src/domain/pile_snapshot.gd")
const NodeGeneratorType = preload("res://src/domain/node_generator.gd")
const NodeFlowServiceType = preload("res://src/domain/node_flow_service.gd")
const NodeStateType = preload("res://src/domain/node_state.gd")

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
	_test_stage_enemy_growth()
	_test_reward_generation_and_run_state()
	_test_trinket_runtime()
	_test_run_save_persistence()
	_test_node_generation()
	_test_elite_scaling_and_rewards()
	_test_shop_domain()
	_test_fountain_and_treasure_domain()
	_test_extended_trinkets()
	await _test_main_menu_localization()
	await _test_battle_ui()
	await _test_reward_ui_flow()
	await _test_special_node_ui()
	await _test_elite_battle_ui()

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
	_assert_equal(enemy.get("base_health"), 35.0, "loads stage-scaled enemy data")
	_assert_equal(enemy.get("name_key"), "enemy.debt_gambler.name", "enemy uses localization key")
	var reward_config := DataRepository.load_reward_config()
	_assert_equal(reward_config.get("normal_battle", {}).get("remove_card_chance"), 0.4, "remove-card chance is data driven")
	_assert_equal(reward_config.get("normal_battle", {}).get("trinket_chance"), 0.6, "trinket chance is data driven")
	_assert_equal(reward_config.get("normal_battle", {}).get("card_choice_chance"), 0.8, "card-choice chance is data driven")
	_assert_equal(DataRepository.load_trinkets().size(), 12, "loads twelve shop-ready trinkets")
	var node_config := DataRepository.load_node_config()
	_assert_equal((node_config.get("node_types", []) as Array).size(), 5, "loads five node types")
	var localization := LocalizationService.new(DataRepository.load_localization())
	_assert_equal(localization.get_language(), "en", "default language is English")
	_assert_equal(localization.text("menu.start_game"), "Start Game", "English menu translation")
	_assert_equal(localization.text("pile.draw"), "Draw Pile", "English draw pile translation")
	_assert_equal(localization.text("battle.rules_button"), "Rules", "English rules button translation")
	_assert_equal(localization.text("run.stage", [1]), "Stage 1", "English stage translation")
	_assert_equal(localization.text("reward.gold_earned", [10]), "Gold Earned: 10", "English gold reward translation")
	_assert_equal(
		localization.text("rules.card_values.body"),
		"J = 11\nQ = 12\nK = 13\nA = 14",
		"English card-value rules contain only the value table"
	)
	var english_play_rules := localization.text("rules.playing_cards.body")
	_assert_true(english_play_rules.contains("replacing 1 to 5 selected cards"), "English combined rules retain refresh limit")
	_assert_true(english_play_rules.contains("shuffled into a new draw pile"), "English combined rules retain reshuffle behavior")
	_assert_true(not english_play_rules.contains("cannot select a sixth"), "English combined rules remove sixth-card explanation")
	_assert_true(not english_play_rules.contains("does not trigger the enemy"), "English combined rules remove enemy-action explanation")
	_assert_true(not english_play_rules.contains("viewed at any time"), "English combined rules remove pile-view explanation")
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
	_assert_equal(localization.text("battle.rules_button"), "规则详细", "Chinese rules button translation")
	_assert_equal(localization.text("run.stage", [1]), "第1关", "Chinese stage translation")
	_assert_equal(localization.text("reward.gold_earned", [10]), "获得金币：10", "Chinese gold reward translation")
	_assert_equal(
		localization.text("rules.card_values.body"),
		"J = 11\nQ = 12\nK = 13\nA = 14",
		"Chinese card-value rules contain only the value table"
	)
	var chinese_play_rules := localization.text("rules.playing_cards.body")
	_assert_true(chinese_play_rules.contains("每次判决可以打出1～5张牌"), "Chinese combined rules retain judgment limit")
	_assert_true(chinese_play_rules.contains("每次可以刷新选中的1～5张牌"), "Chinese combined rules retain refresh limit")
	_assert_true(chinese_play_rules.contains("将弃牌堆洗入新的牌堆"), "Chinese combined rules retain reshuffle behavior")
	_assert_true(not chinese_play_rules.contains("不允许选择第六张牌"), "Chinese combined rules remove sixth-card explanation")
	_assert_true(not chinese_play_rules.contains("刷新不会触发敌人行动"), "Chinese combined rules remove enemy-action explanation")
	_assert_true(not chinese_play_rules.contains("可以随时查看牌堆"), "Chinese combined rules remove pile-view explanation")
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
	var aces: Array[CardData] = []
	var kings: Array[CardData] = []
	for card in deck.cards:
		if card.rank_label == "A":
			aces.append(card)
		elif card.rank_label == "K":
			kings.append(card)
	_assert_equal(aces.size(), 4, "standard deck contains four Aces")
	_assert_equal(kings.size(), 4, "standard deck contains four Kings")
	_assert_true(aces.all(func(card: CardData) -> bool: return card.rank == 14), "Ace rank is always 14")
	_assert_true(kings.all(func(card: CardData) -> bool: return card.rank == 13), "King rank remains 13")
	_assert_true(aces[0].rank > kings[0].rank, "Ace ranks above King")
	_assert_true(deck.cards.all(func(card: CardData) -> bool: return card.rank != 1), "standard deck has no rank-one card")
	var legacy_draw := deck.draw_unique(8)
	_assert_equal(legacy_draw.size(), 8, "legacy unique draw remains compatible")
	_assert_true(_has_unique_instances(legacy_draw), "legacy draw has no duplicate instances")
	_assert_equal(deck.cards.size(), 52, "persistent deck is not mutated by combat setup")


func _test_hand_selection_limit() -> void:
	var available := _cards([[14, 0], [2, 0], [3, 0], [4, 0], [5, 0], [6, 0]])
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
		[13, 3], [14, 2], [7, 3], [7, 1], [7, 0], [7, 2], [4, 1], [11, 0]
	])
	var internal_ids := _card_ids(source)
	var ordered := CardDisplayOrder.descending(source)
	_assert_equal(_ranks(ordered), [14, 13, 11, 7, 7, 7, 7, 4], "display sorts Ace before King")
	_assert_equal(ordered[0].rank_label, "A", "Ace is the leftmost high card")
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
	_assert_true(_is_descending(draw_display), "draw browser projection sorts Ace to 2")
	_assert_true(_is_descending(discard_display), "discard browser projection sorts Ace to 2")
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
		_assert_true(_is_rank_then_instance_descending(group.display_cards), "each draw suit row is Ace-to-2 with stable duplicates")
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

	var duplicate_cards := _cards([[13, 3], [13, 3], [14, 3], [12, 2], [2, 0], [8, 1]])
	var duplicates := BattleDeckState.new()
	duplicates.initialize(duplicate_cards, 8080)
	duplicates.draw_pile = duplicate_cards.duplicate()
	duplicates.hand = []
	duplicates.discard_pile = []
	var duplicate_snapshot := duplicates.pile_snapshot(&"draw")
	var spades: Variant = duplicate_snapshot.group_for_suit(3)
	_assert_equal(spades.count, 3, "same-suit duplicate ranks are all displayed")
	_assert_equal(_ranks(spades.display_cards), [14, 13, 13], "draw pile browser places Ace before King")
	_assert_equal(spades.display_card_ids.slice(1, 3), [1, 2], "same rank duplicates use stable instance ID")
	_assert_equal(duplicate_snapshot.group_for_suit(0).count, 1, "club count comes from domain cards")
	_assert_equal(duplicate_snapshot.group_for_suit(2).count, 1, "heart count comes from domain cards")
	var empty_discard := duplicates.pile_snapshot(&"discard")
	_assert_equal(empty_discard.groups.size(), 4, "empty pile still exposes four rows")
	for group in empty_discard.groups:
		_assert_equal(group.count, 0, "empty standard suit row remains visible with zero count")
	var ace_king_cards := _cards([[13, 3], [14, 3]])
	var discard_order_snapshot := PileSnapshotType.new(&"discard", ace_king_cards, ace_king_cards)
	_assert_equal(
		_ranks(discard_order_snapshot.group_for_suit(3).display_cards),
		[14, 13],
		"discard pile browser places Ace before King"
	)

	var wild_card := CardData.new(99, 7, 99, "7", "suit.wild", "★")
	var wild_registry: Array[CardData] = duplicate_cards.duplicate()
	wild_registry.append(wild_card)
	var wild_source: Array[CardData] = [wild_card]
	var wild_snapshot := PileSnapshotType.new(&"draw", wild_source, wild_registry)
	_assert_equal(wild_snapshot.groups.size(), 5, "wild compatibility adds a fifth row only when needed")
	_assert_equal(wild_snapshot.groups[4].suit_id, PileSnapshotType.WILD_SUIT_ID, "wild row follows four standard rows")


func _test_poker_evaluator() -> void:
	var high := _evaluator.evaluate(_cards([[3, 0], [13, 1], [14, 2]]))
	_assert_equal(high.hand_id, &"high_card", "recognizes high card")
	_assert_equal(high.attack_points, 14, "single Ace uses rank 14")
	_assert_equal(high.damage, 14, "single Ace deals 14 high-card damage")
	_assert_equal(high.scoring_cards[0].rank, 14, "single Ace is the scoring card")
	var ace_pair := _evaluator.evaluate(_cards([[14, 0], [14, 1], [3, 2], [7, 3]]))
	_assert_equal(ace_pair.hand_id, &"pair", "recognizes a pair of Aces")
	_assert_equal(ace_pair.attack_points, 28, "pair of Aces has 28 Base Power")
	_assert_equal(ace_pair.damage, 35, "pair of Aces applies the pair multiplier")
	var pair := _evaluator.evaluate(_cards([[12, 0], [12, 1], [3, 2], [7, 3]]))
	_assert_equal(pair.hand_id, &"pair", "recognizes pair")
	_assert_equal(pair.damage, 30, "pair multiplier")
	var two_pair := _evaluator.evaluate(_cards([[14, 0], [14, 1], [13, 0], [13, 2], [12, 3]]))
	_assert_equal(two_pair.hand_id, &"two_pair", "AAKKQ recognizes two pair")
	_assert_equal(two_pair.scoring_cards.size(), 4, "two pair ignores kicker")
	_assert_equal(two_pair.damage, 81, "Ace-high two pair damage")
	var three := _evaluator.evaluate(_cards([[9, 0], [9, 1], [9, 2], [2, 3]]))
	_assert_equal(three.hand_id, &"three_of_a_kind", "recognizes three of a kind")
	_assert_equal(three.damage, 47, "three of a kind damage")
	var low := _evaluator.evaluate(_cards([[14, 0], [2, 1], [3, 2], [4, 3], [5, 0]]))
	_assert_true(low.hand_id != &"straight", "A-2-3-4-5 is not a straight")
	var wrapped := _evaluator.evaluate(_cards([[12, 0], [13, 1], [14, 2], [2, 3], [3, 0]]))
	_assert_true(wrapped.hand_id != &"straight", "Q-K-A-2-3 is not a straight")
	var high_ace := _evaluator.evaluate(_cards([[10, 0], [11, 1], [12, 2], [13, 3], [14, 0]]))
	_assert_equal(high_ace.hand_id, &"straight", "10-J-Q-K-A is a straight")
	_assert_equal(high_ace.attack_points, 60, "Ace-high straight Base Power is 60")
	_assert_equal(high_ace.damage, 120, "Ace-high straight damage is 120")
	var royal_flush := _evaluator.evaluate(_cards([[10, 2], [11, 2], [12, 2], [13, 2], [14, 2]]))
	_assert_equal(royal_flush.hand_id, &"straight_flush", "same-suit 10-J-Q-K-A is a straight flush")
	_assert_equal(royal_flush.damage, 180, "Ace-high straight flush damage is 180")
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


func _test_stage_enemy_growth() -> void:
	var definition := DataRepository.load_enemy(&"debt_gambler")
	var expected := {
		1: [35, 5],
		5: [57, 7],
		10: [90, 11],
		15: [129, 16],
		20: [173, 21],
		30: [281, 34]
	}
	for stage: int in expected:
		var generated := EnemyScaler.generate(definition, stage)
		_assert_equal(generated.stage, stage, "enemy generation records stage %d" % stage)
		_assert_equal(generated.base_health, expected[stage][0], "stage %d health matches formula" % stage)
		_assert_equal(generated.final_health, expected[stage][0], "stage %d final health is stable" % stage)
		_assert_equal(generated.base_attack, expected[stage][1], "stage %d attack matches formula" % stage)
		_assert_equal(generated.final_attack, expected[stage][1], "stage %d final attack is stable" % stage)
		_assert_equal(generated.enemy_type, "normal", "enemy generation records normal type")
		_assert_equal(EnemyScaler.generate(definition, stage), generated, "same stage generates identical enemy")
	var previous := EnemyScaler.generate(definition, 1)
	for stage in range(2, 51):
		var current := EnemyScaler.generate(definition, stage)
		_assert_true(current.final_health >= previous.final_health, "enemy health grows monotonically at stage %d" % stage)
		_assert_true(current.final_attack >= previous.final_attack, "enemy attack grows monotonically at stage %d" % stage)
		_assert_true(current.final_health > 0 and current.final_attack >= 0, "enemy values remain non-negative at stage %d" % stage)
		_assert_true(current.final_attack <= 40, "normal enemy attack respects 40 percent cap")
		previous = current
	var battle := BattleState.new(EnemyScaler.generate(definition, 1))
	_assert_equal(battle.stage, 1, "battle records generated stage")
	_assert_equal(battle.enemy_base_health, 35, "battle records enemy base health")
	_assert_equal(battle.enemy_max_health, 35, "battle uses final enemy health")
	_assert_equal(battle.enemy_attack, 5, "battle uses final enemy attack")
	battle.enemy_health = 1
	var ace := _evaluator.evaluate(_cards([[14, 0]]))
	_assert_true(battle.apply_player_hand(ace), "stage enemy can be defeated")
	var health_after_victory := battle.player_health
	_assert_true(not battle.resolve_enemy_action(), "defeated enemy cannot act")
	_assert_equal(battle.player_health, health_after_victory, "victory prevents later enemy damage")


func _test_reward_generation_and_run_state() -> void:
	var config := DataRepository.load_reward_config()
	var trinkets := DataRepository.load_trinkets()
	var generator := RewardGenerator.new(config, trinkets)
	var run := _new_test_run()
	_assert_equal(run.stage, 1, "new game starts at stage one")
	_assert_equal(run.gold, 0, "new game starts with configured gold")
	var saw_five := false
	var saw_fifteen := false
	var all_seed := 0
	var none_seed := 0
	for seed in range(1, 20000):
		var sample := generator.generate(1, run, seed)
		saw_five = saw_five or sample.gold_amount == 5
		saw_fifteen = saw_fifteen or sample.gold_amount == 15
		if all_seed == 0 and sample.remove_card_offered and sample.trinket_offered and sample.card_choice_offered:
			all_seed = seed
		if none_seed == 0 and not sample.remove_card_offered and not sample.trinket_offered and not sample.card_choice_offered:
			none_seed = seed
		if saw_five and saw_fifteen and all_seed > 0 and none_seed > 0:
			break
	_assert_true(saw_five, "uniform gold range can produce five")
	_assert_true(saw_fifteen, "uniform gold range can produce fifteen")
	_assert_true(all_seed > 0, "a deterministic seed can offer all three rewards")
	_assert_true(none_seed > 0, "a deterministic seed can offer no optional rewards")

	var reward := generator.generate(1, run, all_seed)
	_assert_true(reward.gold_amount >= 5 and reward.gold_amount <= 15, "victory gold stays in five-to-fifteen range")
	_assert_equal(reward.rolls.size(), 3, "three reward offers use three independent rolls")
	_assert_true(reward.remove_card_offered and reward.trinket_offered and reward.card_choice_offered, "all-offer seed is reproducible")
	_assert_equal(reward.card_candidates.size(), 5, "card reward generates five candidates")
	_assert_true(_candidate_specs_unique(reward.card_candidates), "five candidates have distinct rank-suit combinations")
	var owned_filter_run := _new_test_run()
	owned_filter_run.trinket_ids.append(reward.trinket_id)
	for seed in range(1, 500):
		var filtered := generator.generate(1, owned_filter_run, seed)
		if filtered.trinket_offered:
			_assert_true(not owned_filter_run.trinket_ids.has(filtered.trinket_id), "trinket generation excludes owned names")
			break
	run.reward_state = reward
	_assert_true(run.apply_reward_gold(reward), "victory gold is automatically applied once")
	var gold_after_claim := run.gold
	_assert_true(not run.apply_reward_gold(reward), "same gold reward cannot be claimed twice")
	_assert_equal(run.gold, gold_after_claim, "duplicate gold claim changes nothing")
	var defeated_run := _new_test_run()
	var defeat_battle := BattleState.new({"max_health": 999, "attack": 100})
	defeat_battle.resolve_enemy_action()
	_assert_true(defeat_battle.is_finished, "defeat fixture ends battle")
	_assert_equal(defeated_run.gold, 0, "defeat grants no gold")

	var deck_size_before := run.deck.cards.size()
	var removed_card := run.deck.cards[0]
	var rank_before := int(run.deck.distribution_by_rank().get(removed_card.rank, 0))
	var suit_before := int(run.deck.distribution_by_suit().get(removed_card.suit, 0))
	_assert_equal(run.deck.cards.size(), deck_size_before, "opening removal selection does not remove a card")
	_assert_true(run.remove_reward_card(removed_card.instance_id), "legal reward card can be removed")
	_assert_equal(run.deck.cards.size(), deck_size_before - 1, "removal permanently shrinks run deck")
	_assert_equal(int(run.deck.distribution_by_rank().get(removed_card.rank, 0)), rank_before - 1, "rank distribution updates after removal")
	_assert_equal(int(run.deck.distribution_by_suit().get(removed_card.suit, 0)), suit_before - 1, "suit distribution updates after removal")

	var minimum_run := _new_test_run()
	while minimum_run.deck.cards.size() > minimum_run.minimum_deck_size:
		minimum_run.deck.remove_card(minimum_run.deck.cards[0].instance_id, minimum_run.minimum_deck_size)
	var minimum_reward := RewardState.new()
	minimum_reward.remove_card_offered = true
	minimum_run.reward_state = minimum_reward
	_assert_true(not minimum_run.remove_reward_card(minimum_run.deck.cards[0].instance_id), "minimum deck size blocks removal")
	_assert_equal(minimum_run.deck.cards.size(), minimum_run.minimum_deck_size, "blocked removal preserves minimum deck")

	_assert_true(run.claim_trinket(), "offered unowned trinket can be claimed")
	_assert_true(run.trinket_ids.has(reward.trinket_id), "claimed trinket enters run slots")
	var duplicate_reward := RewardState.new()
	duplicate_reward.trinket_offered = true
	duplicate_reward.trinket_id = reward.trinket_id
	run.reward_state = duplicate_reward
	_assert_true(not run.claim_trinket(), "same trinket cannot be obtained twice")

	var full_run := _new_test_run()
	for index in range(5):
		full_run.trinket_ids.append(str(trinkets[index].id))
	full_run.trinket_ids.append("legacy_trinket")
	var replacement_reward := RewardState.new()
	replacement_reward.trinket_offered = true
	replacement_reward.trinket_id = str(trinkets[5].id)
	full_run.reward_state = replacement_reward
	_assert_true(not full_run.claim_trinket(), "full slots never auto-replace a trinket")
	_assert_true(full_run.claim_trinket("legacy_trinket"), "explicit replacement can claim a trinket")
	_assert_true(not full_run.trinket_ids.has("legacy_trinket"), "chosen old trinket is replaced")

	var skip_run := _new_test_run()
	var skip_reward := RewardState.new()
	skip_reward.remove_card_offered = true
	skip_reward.trinket_offered = true
	skip_reward.trinket_id = str(trinkets[0].id)
	skip_reward.card_choice_offered = true
	skip_reward.card_candidates = generator.generate(1, skip_run, all_seed).card_candidates
	skip_run.reward_state = skip_reward
	_assert_true(skip_run.skip_remove_card(), "remove reward can be skipped")
	_assert_true(skip_run.skip_trinket(), "trinket reward can be skipped")
	_assert_true(skip_run.skip_card_choice(), "unopened card choice can be skipped")
	_assert_true(skip_reward.can_continue(), "all explicitly skipped rewards allow continue")
	_assert_true(skip_run.complete_reward_and_advance(), "completed reward advances run")
	_assert_equal(skip_run.stage, 2, "next normal battle increments stage")

	var choice_run := _new_test_run()
	var choice_reward := generator.generate(1, choice_run, all_seed)
	choice_run.reward_state = choice_reward
	var choice_deck_before := choice_run.deck.cards.size()
	_assert_true(choice_run.open_card_choice(), "card choice can be opened")
	_assert_true(choice_reward.must_choose, "opening card choice activates mustChoose")
	_assert_true(not choice_run.skip_card_choice(), "opened card choice cannot be skipped")
	_assert_true(not choice_run.complete_reward_and_advance(), "mustChoose blocks continue")
	var chosen_id := int(choice_reward.card_candidates[0].instance_id)
	_assert_true(choice_run.choose_card(chosen_id), "one generated card can be chosen")
	_assert_equal(choice_run.deck.cards.size(), choice_deck_before + 1, "chosen card permanently joins run deck")
	_assert_true(not choice_reward.must_choose, "choosing a card clears mustChoose")
	_assert_equal(choice_reward.chosen_card_id, chosen_id, "chosen candidate ID is recorded")


func _test_trinket_runtime() -> void:
	var definitions := DataRepository.load_trinkets()
	var pair := _evaluator.evaluate(_cards([[12, 0], [12, 1]]))
	var clip := TrinketRuntime.new(["sharpened_clip"], definitions)
	_assert_equal(clip.preview_hand(pair, "normal").attack_points, 27, "Sharpened Clip previews plus three Base Power")
	_assert_equal(clip.preview_hand(pair, "normal").attack_points, 27, "preview does not consume first-pair trigger")
	_assert_equal(clip.commit_hand(pair, "normal").attack_points, 27, "first committed Pair gains Base Power")
	_assert_equal(clip.commit_hand(pair, "normal").attack_points, 24, "later Pair does not retrigger Sharpened Clip")
	var two_pair := _evaluator.evaluate(_cards([[13, 0], [13, 1], [7, 0], [7, 1]]))
	_assert_equal(TrinketRuntime.new(["split_coin"], definitions).block_after_hand(two_pair), 5, "Split Coin grants five Block")
	var straight := _evaluator.evaluate(_cards([[10, 0], [11, 1], [12, 2], [13, 3], [14, 0]]))
	_assert_equal(TrinketRuntime.new(["straight_ruler"], definitions).commit_hand(straight, "normal").damage, 130, "Straight Ruler adds eight percent damage")
	var flush := _evaluator.evaluate(_cards([[2, 2], [4, 2], [6, 2], [8, 2], [10, 2]]))
	_assert_equal(TrinketRuntime.new(["velvet_thread"], definitions).block_after_hand(flush), 5, "Velvet Thread grants one Block per Flush scoring card")
	var hourglass := TrinketRuntime.new(["cracked_hourglass"], definitions)
	_assert_equal(hourglass.block_after_refresh(), 4, "Cracked Hourglass triggers after first refresh")
	_assert_equal(hourglass.block_after_refresh(), 0, "Cracked Hourglass triggers only once per battle")
	var mark := TrinketRuntime.new(["hunters_mark"], definitions)
	_assert_equal(mark.commit_hand(straight, "normal").damage, 120, "Hunter's Mark is inactive against normal enemies")
	_assert_equal(mark.commit_hand(straight, "boss").damage, 127, "Hunter's Mark is saved and works against bosses")
	var shield_battle := BattleState.new({"max_health": 100, "attack": 8})
	shield_battle.gain_block(5)
	shield_battle.resolve_enemy_action()
	_assert_equal(shield_battle.player_health, 97, "Block absorbs enemy damage before health")
	_assert_equal(shield_battle.player_block, 0, "spent Block is removed")


func _test_run_save_persistence() -> void:
	var path := "res://test-artifacts/test_run_%d.json" % Time.get_ticks_usec()
	var repository := RunSaveRepository.new(path)
	var run := _new_test_run()
	var generator := RewardGenerator.new(DataRepository.load_reward_config(), DataRepository.load_trinkets())
	var seed := _find_reward_seed(generator, run, true)
	run.reward_state = generator.generate(1, run, seed)
	run.apply_reward_gold(run.reward_state)
	_assert_true(run.open_card_choice(), "save fixture enters forced card choice")
	var candidates_before := run.reward_state.card_candidates.duplicate(true)
	_assert_true(repository.save_run(run), "run state saves to JSON")
	var loaded := repository.load_run(DataRepository.load_deck_definition(), DataRepository.load_reward_config())
	_assert_true(loaded != null, "saved run loads")
	_assert_equal(loaded.stage, run.stage, "loaded run preserves stage")
	_assert_equal(loaded.gold, run.gold, "loaded run preserves gold")
	_assert_true(loaded.reward_state.must_choose, "loaded run restores mustChoose")
	_assert_equal(loaded.reward_state.card_candidates, candidates_before, "loaded run preserves exact five candidates")
	_assert_equal(loaded.deck.to_records(), run.deck.to_records(), "loaded run preserves run deck instances")
	_assert_true(repository.clear_run(), "test run save can be cleared")


func _test_node_generation() -> void:
	var config := DataRepository.load_node_config()
	var generator: RefCounted = NodeGeneratorType.new(config)
	_assert_equal(generator.probability("battle"), 0.35, "battle node chance is 35 percent")
	_assert_equal(generator.probability("shop"), 0.10, "shop node chance is 10 percent")
	_assert_equal(generator.probability("elite"), 0.20, "elite node chance is 20 percent")
	_assert_equal(generator.probability("fountain"), 0.15, "fountain node chance is 15 percent")
	_assert_equal(generator.probability("treasure"), 0.20, "treasure node chance is 20 percent")
	var state: RefCounted = generator.generate(7, 24680)
	_assert_equal(state.candidates.size(), 3, "map generation always creates three candidates")
	_assert_equal(state.current_stage, 7, "map candidates record current depth")
	_assert_equal(state.candidate_seed, 24680, "map state records deterministic seed")
	_assert_equal(generator.generate(7, 24680).candidates, state.candidates, "same map seed reproduces candidates")
	var repeated_seed := 0
	for seed in range(1, 10000):
		var sample: RefCounted = generator.generate(1, seed)
		if (
			sample.candidates[0].type == sample.candidates[1].type
			and sample.candidates[1].type == sample.candidates[2].type
		):
			repeated_seed = seed
			break
	_assert_true(repeated_seed > 0, "independent node positions allow three identical nodes")
	var repeated: RefCounted = generator.generate(1, repeated_seed)
	_assert_equal(repeated.candidates[0].type, repeated.candidates[2].type, "duplicate node candidates are not rerolled")
	_assert_true(state.select(1), "one map candidate can be selected")
	_assert_equal(state.selected_index, 1, "selected map index is recorded")
	_assert_true(state.confirm_selection(), "selected destination can be confirmed")
	_assert_true(not state.select(2), "other candidates become invalid after confirmation")
	var snapshot: Dictionary = state.to_dict()
	var restored: RefCounted = NodeStateType.from_dict(snapshot)
	_assert_equal(restored.candidates, state.candidates, "saved map candidates restore unchanged")
	_assert_equal(restored.selected_type, state.selected_type, "saved map selection restores unchanged")
	var hand := HandState.new()
	hand.start_battle(Deck.new(DataRepository.load_deck_definition()), 991122)
	var battle_rng_before := hand.battle_deck_state.random_state()
	var unrelated_map: RefCounted = generator.generate(3, 445566)
	unrelated_map.select(0)
	unrelated_map.confirm_selection()
	_assert_equal(hand.battle_deck_state.random_state(), battle_rng_before, "map viewing and confirmation do not consume battle RNG")


func _test_elite_scaling_and_rewards() -> void:
	var normal_definition := DataRepository.load_enemy(&"debt_gambler")
	var node_config := DataRepository.load_node_config()
	var elite_config: Dictionary = node_config.get("elite", {})
	var multiplier := float(elite_config.get("stat_multiplier", 1.5))
	for stage in [1, 10, 30]:
		var normal := EnemyScaler.generate(normal_definition, stage)
		var elite := EnemyScaler.generate_elite(normal_definition, stage, multiplier)
		_assert_equal(elite.final_health, roundi(normal.final_health * 1.5), "elite health is 1.5 times normal at stage %d" % stage)
		_assert_equal(elite.final_attack, roundi(normal.final_attack * 1.5), "elite attack is 1.5 times normal at stage %d" % stage)
		_assert_equal(elite.enemy_type, "elite", "elite generation records enemy type")
	var run := _new_test_run()
	var generator := RewardGenerator.new(DataRepository.load_reward_config(), DataRepository.load_trinkets())
	var reward_multiplier := float(elite_config.get("reward_multiplier", 1.5))
	for seed in [1, 8, 62, 777]:
		var normal_reward := generator.generate(1, run, seed)
		var elite_reward := generator.generate(1, run, seed, reward_multiplier, "elite")
		_assert_equal(elite_reward.gold_amount, roundi(normal_reward.gold_amount * 1.5), "elite Gold is rounded normal Gold times 1.5")
		_assert_true(elite_reward.card_choice_offered, "elite card-choice chance is capped at 100 percent")
		_assert_equal(elite_reward.rolls.size(), 3, "elite optional rewards still use independent rolls")
	var remove_upgrade_found := false
	var trinket_upgrade_found := false
	for seed in range(1, 10000):
		var normal_reward := generator.generate(1, run, seed)
		var elite_reward := generator.generate(1, run, seed, 1.5, "elite")
		if not normal_reward.remove_card_offered and elite_reward.remove_card_offered:
			remove_upgrade_found = true
		if not normal_reward.trinket_offered and elite_reward.trinket_offered:
			trinket_upgrade_found = true
		if remove_upgrade_found and trinket_upgrade_found:
			break
	_assert_true(remove_upgrade_found, "elite remove chance expands from 40 to 60 percent")
	_assert_true(trinket_upgrade_found, "elite trinket chance expands from 60 to 90 percent")


func _test_shop_domain() -> void:
	var flow: RefCounted = NodeFlowServiceType.new(DataRepository.load_node_config(), DataRepository.load_trinkets())
	var run := _new_test_run()
	run.gold = 500
	_enter_special_node(run, flow, "shop", 41001)
	var shop: RefCounted = run.shop_state
	_assert_equal(shop.removal_uses_remaining, 2, "shop starts with two removals")
	_assert_equal(shop.card_purchase_uses_remaining, 3, "shop starts with three card purchases")
	_assert_equal(shop.heal_uses_remaining, 1, "shop starts with one heal")
	_assert_equal(int(shop.price_snapshot.remove_card), 15, "shop removal costs 15 Gold")
	_assert_equal(int(shop.price_snapshot.buy_card), 5, "shop card purchase costs 5 Gold")
	_assert_equal(int(shop.price_snapshot.heal), 20, "shop heal costs 20 Gold")
	_assert_equal(shop.trinket_inventory.size(), 6, "shop generates six trinkets")
	_assert_true(_strings_unique(shop.trinket_inventory), "shop trinket inventory has no duplicates")
	for trinket_id in shop.trinket_inventory:
		var definition: Dictionary = flow.trinket_definition(trinket_id)
		_assert_equal(int(shop.price_snapshot["trinket:%s" % trinket_id]), int(definition.price), "shop trinket uses configured price")
	var first_remove := run.deck.cards[0].instance_id
	var second_remove := run.deck.cards[1].instance_id
	_assert_true(flow.shop_remove_card(run, first_remove), "first paid shop removal succeeds")
	_assert_true(flow.shop_remove_card(run, second_remove), "second paid shop removal succeeds")
	_assert_true(not flow.shop_remove_card(run, run.deck.cards[0].instance_id), "third shop removal is rejected")
	_assert_equal(shop.removal_uses_remaining, 0, "shop removal counter reaches zero")
	for purchase in range(3):
		_assert_true(flow.shop_begin_card_purchase(run), "shop card purchase %d begins" % (purchase + 1))
		_assert_true(shop.must_choose_card, "paid shop card purchase enters forced choice")
		_assert_equal(shop.card_candidates.size(), 5, "shop purchase creates five candidates")
		_assert_true(_candidate_specs_unique(shop.card_candidates), "shop card candidates are distinct")
		_assert_true(flow.shop_choose_card(run, int(shop.card_candidates[0].instance_id)), "shop card choice completes")
	_assert_true(not flow.shop_begin_card_purchase(run), "fourth shop card purchase is rejected")
	_assert_equal(shop.card_purchase_uses_remaining, 0, "shop card purchase counter reaches zero")
	run.player_health = 40
	var gold_before_heal := run.gold
	_assert_equal(flow.shop_heal(run), 30, "shop heals 30 percent maximum health")
	_assert_equal(run.player_health, 70, "shop healing updates persistent health")
	_assert_equal(run.gold, gold_before_heal - 20, "shop healing costs 20 Gold")
	_assert_equal(flow.shop_heal(run), 0, "second shop heal is rejected")

	var poor_run := _new_test_run()
	poor_run.gold = 0
	_enter_special_node(poor_run, flow, "shop", 41002)
	var poor_shop: RefCounted = poor_run.shop_state
	var poor_deck_size := poor_run.deck.cards.size()
	_assert_true(not flow.shop_remove_card(poor_run, poor_run.deck.cards[0].instance_id), "insufficient Gold blocks shop removal")
	_assert_equal(poor_run.deck.cards.size(), poor_deck_size, "failed purchase does not mutate deck")
	_assert_true(not flow.shop_begin_card_purchase(poor_run), "insufficient Gold blocks card purchase")
	var paid_run := _new_test_run()
	paid_run.gold = 100
	_enter_special_node(paid_run, flow, "shop", 41006)
	_assert_true(flow.shop_begin_card_purchase(paid_run), "paid card purchase creates persistent forced state")
	var paid_gold := paid_run.gold
	var paid_candidates: Array = paid_run.shop_state.card_candidates.duplicate(true)
	var paid_loaded := RunState.from_dict(
		paid_run.to_dict(), DataRepository.load_deck_definition(), DataRepository.load_reward_config()
	)
	_assert_equal(paid_loaded.gold, paid_gold, "shop card payment survives reload without duplicate deduction")
	_assert_true(paid_loaded.shop_state.must_choose_card, "shop forced card choice survives reload")
	_assert_equal(paid_loaded.shop_state.card_candidates, paid_candidates, "shop card candidates survive reload unchanged")

	var full_run := _new_test_run()
	full_run.gold = 500
	var definitions := DataRepository.load_trinkets()
	for index in range(6):
		full_run.trinket_ids.append(str(definitions[index].id))
	_enter_special_node(full_run, flow, "shop", 41003)
	var offered_id := str(full_run.shop_state.trinket_inventory[0])
	var gold_before_pending := full_run.gold
	_assert_true(not flow.shop_buy_trinket(full_run, offered_id), "full slots require explicit shop replacement")
	_assert_equal(full_run.gold, gold_before_pending, "pending replacement does not deduct Gold")
	_assert_true(flow.shop_cancel_trinket_replacement(full_run), "shop trinket replacement can be cancelled")
	_assert_equal(full_run.gold, gold_before_pending, "cancelled replacement never deducts Gold")
	_assert_true(not flow.shop_buy_trinket(full_run, offered_id), "full slots reopen explicit replacement selection")
	var replaced_id := full_run.trinket_ids[0]
	_assert_true(flow.shop_buy_trinket(full_run, offered_id, replaced_id), "explicit shop trinket replacement succeeds")
	_assert_true(not full_run.trinket_ids.has(replaced_id), "shop replacement removes selected owned trinket")
	_assert_true(full_run.gold < gold_before_pending, "successful replacement deducts snapshot price once")

	var wax_run := _new_test_run()
	wax_run.gold = 500
	wax_run.trinket_ids.append("black_wax_seal")
	_enter_special_node(wax_run, flow, "shop", 41004)
	_assert_equal(int(wax_run.shop_state.price_snapshot.remove_card), 14, "Black Wax Seal snapshots discounted service price")
	var wax_prices: Dictionary = wax_run.shop_state.price_snapshot.duplicate(true)
	_assert_equal(wax_run.shop_state.price_snapshot, wax_prices, "shop price snapshot does not recursively change")

	var first_inventory: Array = run.shop_state.trinket_inventory.duplicate()
	_assert_true(flow.complete_special_node_and_generate(run, 51001), "leaving shop completes node")
	_assert_true(run.shop_state == null, "completed shop inventory cannot be reused")
	_enter_special_node(run, flow, "shop", 41005)
	_assert_equal(run.shop_state.removal_uses_remaining, 2, "new shop resets removal uses")
	_assert_equal(run.shop_state.card_purchase_uses_remaining, 3, "new shop resets card purchase uses")
	_assert_true(run.shop_state.trinket_inventory != first_inventory or run.shop_state.inventory_seed != 41001, "new shop has independent inventory state")


func _test_fountain_and_treasure_domain() -> void:
	var flow: RefCounted = NodeFlowServiceType.new(DataRepository.load_node_config(), DataRepository.load_trinkets())
	var fountain_run := _new_test_run()
	fountain_run.gold = 37
	fountain_run.player_health = 50
	_enter_special_node(fountain_run, flow, "fountain", 62001)
	_assert_equal(fountain_run.player_health, 80, "fountain restores 30 percent maximum health")
	_assert_equal(fountain_run.gold, 37, "fountain consumes no Gold")
	_assert_equal(int(fountain_run.node_state.resolution.health_restored), 30, "fountain records actual restored health")
	_assert_true(flow.complete_special_node_and_generate(fountain_run, 62002), "fountain completion advances node")
	_assert_equal(fountain_run.stage, 2, "fountain advances global stage")
	_assert_equal(fountain_run.node_state.candidates.size(), 3, "fountain completion creates next three nodes")

	var capped_run := _new_test_run()
	capped_run.player_health = 90
	_enter_special_node(capped_run, flow, "fountain", 62003)
	_assert_equal(capped_run.player_health, 100, "fountain healing cannot exceed maximum health")
	_assert_equal(int(capped_run.node_state.resolution.health_restored), 10, "fountain reports capped healing")

	var treasure_run := _new_test_run()
	_enter_special_node(treasure_run, flow, "treasure", 63001)
	var treasure: RefCounted = treasure_run.treasure_state
	_assert_equal(treasure.candidates.size(), 3, "treasure generates three trinkets")
	_assert_true(_strings_unique(treasure.candidates), "treasure candidates are distinct")
	var candidates_before: Array = treasure.candidates.duplicate()
	_assert_true(flow.treasure_open(treasure_run), "treasure can be opened")
	_assert_true(treasure.must_choose, "opened treasure requires a choice")
	_assert_true(not flow.treasure_skip(treasure_run), "opened treasure cannot be skipped")
	var payload := treasure_run.to_dict()
	var restored := RunState.from_dict(payload, DataRepository.load_deck_definition(), DataRepository.load_reward_config())
	_assert_equal(restored.treasure_state.candidates, candidates_before, "treasure candidates survive save and load")
	_assert_true(restored.treasure_state.must_choose, "treasure mustChoose survives save and load")
	var selected := str(treasure.candidates[0])
	_assert_true(flow.treasure_choose(treasure_run, selected), "treasure choice adds unowned trinket")
	_assert_true(treasure_run.trinket_ids.has(selected), "chosen treasure trinket enters slots")
	_assert_true(flow.complete_special_node_and_generate(treasure_run, 63002), "chosen treasure completes node")
	_assert_equal(treasure_run.stage, 2, "treasure advances global stage")

	var skipped_run := _new_test_run()
	_enter_special_node(skipped_run, flow, "treasure", 63003)
	_assert_true(flow.treasure_skip(skipped_run), "unopened treasure can be abandoned")
	_assert_true(flow.complete_special_node_and_generate(skipped_run, 63004), "abandoned treasure still completes node")

	var full_run := _new_test_run()
	var definitions := DataRepository.load_trinkets()
	for index in range(6):
		full_run.trinket_ids.append(str(definitions[index].id))
	_enter_special_node(full_run, flow, "treasure", 63005)
	flow.treasure_open(full_run)
	var new_id := str(full_run.treasure_state.candidates[0])
	_assert_true(not flow.treasure_choose(full_run, new_id), "full treasure slots require replacement")
	_assert_true(full_run.treasure_state.must_choose, "full-slot treasure remains mandatory")
	_assert_true(flow.treasure_choose(full_run, new_id, full_run.trinket_ids[0]), "explicit treasure replacement succeeds")


func _test_extended_trinkets() -> void:
	var definitions := DataRepository.load_trinkets()
	var pair := _evaluator.evaluate(_cards([[12, 0], [12, 1]]))
	var lens := TrinketRuntime.new(["twin_lens"], definitions)
	var lens_result := lens.commit_hand(pair, "normal")
	_assert_equal(lens_result.multiplier, 1.40, "Twin Lens adds 0.15 Pair multiplier")
	_assert_equal(lens_result.damage, 34, "Twin Lens recalculates Pair damage")
	var straight := _evaluator.evaluate(_cards([[10, 0], [11, 1], [12, 2], [13, 3], [14, 0]]))
	var compass := TrinketRuntime.new(["silver_compass"], definitions)
	_assert_equal(compass.refreshes_after_hand(straight), 1, "Silver Compass restores first Straight refresh")
	_assert_equal(compass.refreshes_after_hand(straight), 0, "Silver Compass triggers once per battle")
	var hand := HandState.new()
	hand.refreshes_remaining = 3
	_assert_equal(hand.restore_refreshes(1), 3, "restored refresh cannot exceed battle maximum")
	var full_house := _evaluator.evaluate(_cards([[10, 0], [10, 1], [10, 2], [6, 0], [6, 1]]))
	var cup := TrinketRuntime.new(["funeral_cup"], definitions)
	for trigger in range(3):
		_assert_equal(cup.healing_after_hand(full_house), 3, "Funeral Cup heals on trigger %d" % (trigger + 1))
	_assert_equal(cup.healing_after_hand(full_house), 0, "Funeral Cup stops after three triggers")
	var ribbon := TrinketRuntime.new(["razor_ribbon"], definitions)
	_assert_equal(ribbon.commit_hand(straight, "normal", 0.34).damage, 142, "Razor Ribbon adds 18 percent low-health damage")
	_assert_equal(ribbon.commit_hand(straight, "normal", 0.35).damage, 120, "Razor Ribbon does not trigger at 35 percent")
	_assert_equal(ribbon.healing_multiplier(0.20), 0.75, "Razor Ribbon reduces low-health healing by 25 percent")
	var four := _evaluator.evaluate(_cards([[7, 0], [7, 1], [7, 2], [7, 3]]))
	var crown := TrinketRuntime.new(["fourfold_crown"], definitions)
	var crown_result := crown.commit_hand(four, "normal")
	_assert_equal(crown_result.multiplier, 3.15, "Fourfold Crown adds 0.40 multiplier")
	_assert_equal(crown.block_after_hand(crown_result), 13, "Fourfold Crown grants 13 Block")


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
	screen.set("fixed_reward_seed", 13579)
	screen.set("run_state_override", _new_test_run())
	root.add_child(screen)
	await _wait_for_animation(screen)
	var buttons := _collect_hand_card_buttons(screen)
	var stage_label := screen.find_child("StageLabel", true, false) as Label
	_assert_equal(stage_label.text, "Stage 1", "battle UI displays initial stage")
	_assert_equal(buttons.size(), 8, "battle UI presents eight interactive hand cards")
	_assert_true(_button_cards_descending(buttons), "hand UI is Ace-to-2 from left to right")
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
	var rules_button := screen.find_child("RulesButton", true, false) as Button
	var rules_overlay: Variant = screen.get("_rules_overlay")
	_assert_true(rules_button != null, "Rules button exists")
	_assert_equal(rules_button.text, "Rules", "Rules button defaults to English")
	_assert_true(not rules_button.disabled, "Rules button is available during player input")
	_assert_true(not _visible_ui_text_contains(screen, "A = 1"), "battle UI no longer displays the old A equals 1 rule")
	_assert_true(
		not _visible_ui_text_contains(screen, "The enemy counterattacks after a played hand."),
		"battle UI no longer displays the old enemy explanation"
	)

	_set_card_pressed(buttons[0], true)
	var hand_before_rules := _card_ids(hand_state.battle_deck_state.hand)
	var draw_before_rules := _card_ids(hand_state.battle_deck_state.draw_pile)
	var discard_before_rules := _card_ids(hand_state.battle_deck_state.discard_pile)
	var selection_before_rules := _card_ids(hand_state.selected_cards())
	var refreshes_before_rules := hand_state.refreshes_remaining
	var rng_before_rules := hand_state.battle_deck_state.random_state()
	var round_before_rules := (screen.get("_battle") as BattleState).round_number
	var player_health_before_rules := (screen.get("_battle") as BattleState).player_health
	var enemy_health_before_rules := (screen.get("_battle") as BattleState).enemy_health
	var paused_before_rules := paused
	rules_button.pressed.emit()
	await process_frame
	_assert_true(rules_overlay.visible, "Rules button opens the read-only rules page")
	_assert_equal(rules_overlay.hand_entry_count(), 9, "rules page lists all nine poker hands")
	_assert_true(
		_rule_localized_text(rules_overlay, "rules.card_values.body") == "J = 11\nQ = 12\nK = 13\nA = 14",
		"English rules page shows only the card value table"
	)
	_assert_true(
		_rule_localized_text(rules_overlay, "rules.playing_cards.body").contains("1 to 5 cards"),
		"English rules page states at most five cards per judgment"
	)
	_assert_true(
		_rule_localized_text(rules_overlay, "rules.playing_cards.body").contains("replacing 1 to 5 selected cards"),
		"English Playing Cards section contains the refresh rule"
	)
	_assert_true(screen.find_child("RulesSection_Refresh", true, false) == null, "rules page has no separate Refresh section")
	_assert_true(screen.find_child("RulesSection_Piles", true, false) == null, "rules page has no separate pile section")
	for hand_id in [
		"high_card", "pair", "two_pair", "three_of_a_kind", "straight",
		"flush", "full_house", "four_of_a_kind", "straight_flush"
	]:
		_assert_true(
			_rule_localized_text(rules_overlay, "hand.%s" % hand_id) != "",
			"rules page localizes poker hand %s" % hand_id
		)
	var refresh_button_during_rules := screen.find_child("RefreshButton", true, false) as Button
	refresh_button_during_rules.pressed.emit()
	await process_frame
	_assert_equal(_card_ids(hand_state.battle_deck_state.hand), hand_before_rules, "opening rules leaves hand unchanged")
	_assert_equal(_card_ids(hand_state.battle_deck_state.draw_pile), draw_before_rules, "opening rules leaves draw pile unchanged")
	_assert_equal(_card_ids(hand_state.battle_deck_state.discard_pile), discard_before_rules, "opening rules leaves discard pile unchanged")
	_assert_equal(_card_ids(hand_state.selected_cards()), selection_before_rules, "opening rules leaves selection unchanged")
	_assert_equal(hand_state.refreshes_remaining, refreshes_before_rules, "opening rules consumes no refresh")
	_assert_equal(hand_state.battle_deck_state.random_state(), rng_before_rules, "opening rules consumes no RNG")
	_assert_equal((screen.get("_battle") as BattleState).round_number, round_before_rules, "opening rules does not advance battle")
	_assert_equal((screen.get("_battle") as BattleState).player_health, player_health_before_rules, "opening rules leaves player health unchanged")
	_assert_equal((screen.get("_battle") as BattleState).enemy_health, enemy_health_before_rules, "opening rules leaves enemy health unchanged")
	_assert_equal(paused, paused_before_rules, "rules page does not pause the scene tree")

	_app_services().set_language("zh_CN", false)
	await process_frame
	_assert_equal(rules_button.text, "规则详细", "Rules button updates to Chinese immediately")
	_assert_equal(_rule_localized_text(rules_overlay, "rules.title"), "规则详细", "open rules title updates immediately")
	_assert_true(
		_rule_localized_text(rules_overlay, "rules.card_values.body") == "J = 11\nQ = 12\nK = 13\nA = 14",
		"Chinese rules page shows only the card value table"
	)
	_assert_true(
		_rule_localized_text(rules_overlay, "rules.playing_cards.body").contains("1～5张牌"),
		"Chinese rules page states at most five played cards"
	)
	_assert_true(
		_rule_localized_text(rules_overlay, "rules.playing_cards.body").contains("每场战斗最多刷新3次"),
		"Chinese Playing Cards section contains the refresh rule"
	)
	_app_services().set_language("en", false)
	await process_frame
	_assert_equal(_rule_localized_text(rules_overlay, "rules.title"), "Rules", "rules page switches back to English")

	var rules_close := screen.find_child("RulesCloseButton", true, false) as Button
	rules_close.pressed.emit()
	_assert_true(not rules_overlay.visible, "Close button closes rules page")
	_assert_equal(_card_ids(hand_state.selected_cards()), selection_before_rules, "closing rules preserves selection")
	rules_button.pressed.emit()
	await process_frame
	var rules_back := screen.find_child("RulesBackButton", true, false) as Button
	rules_back.pressed.emit()
	_assert_true(not rules_overlay.visible, "Back button closes rules page")
	rules_button.pressed.emit()
	await process_frame
	var cancel_event := InputEventAction.new()
	cancel_event.action = "ui_cancel"
	cancel_event.pressed = true
	Input.parse_input_event(cancel_event)
	await process_frame
	_assert_true(not rules_overlay.visible, "Esc closes rules page")
	_set_card_pressed(buttons[0], false)
	await create_timer(0.15).timeout

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
	_assert_true(rules_button.disabled, "Rules button is disabled during refresh animation")
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
		_assert_true(_ui_suit_row_is_valid(row), "UI row contains one suit in Ace-to-2 order")
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
	_assert_equal(battle.player_health, 95, "stage-one enemy counterattacks for configured damage")
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
	var reward_overlay := screen.get("_reward_overlay") as RewardOverlay
	_assert_true(reward_overlay.visible, "victory reward overview appears")
	_assert_true(rules_button.disabled, "Rules button remains disabled after battle resolution")
	_assert_equal(hand_state.battle_deck_state.all_cards.size(), 0, "battle end clears combat deck registry")
	_assert_equal(hand_state.draw_pile_count(), 0, "battle end clears draw pile")
	_assert_equal(hand_state.discard_pile_count(), 0, "battle end clears discard pile")
	_app_services().set_language("zh_CN", false)
	await process_frame
	_assert_true(_visible_ui_text_contains(reward_overlay, "胜利奖励"), "visible reward page updates to Chinese")
	_assert_true(_visible_ui_text_contains(reward_overlay, "获得金币"), "gold reward updates to Chinese")

	screen.queue_free()
	_app_services().set_language("en", false)
	await process_frame


func _test_reward_ui_flow() -> void:
	_app_services().set_language("en", false)
	var run := _new_test_run()
	var generator := RewardGenerator.new(DataRepository.load_reward_config(), DataRepository.load_trinkets())
	var all_seed := 0
	for seed in range(1, 20000):
		var candidate := generator.generate(1, run, seed)
		if candidate.remove_card_offered and candidate.trinket_offered and candidate.card_choice_offered:
			all_seed = seed
			break
	_assert_true(all_seed > 0, "reward UI fixture finds all-offer seed")
	run.reward_state = generator.generate(1, run, all_seed)
	run.apply_reward_gold(run.reward_state)
	var packed_scene := load("res://scenes/battle_screen.tscn") as PackedScene
	var screen := packed_scene.instantiate()
	screen.set("animation_duration_scale", 0.0)
	screen.set("fixed_battle_seed", 31337)
	screen.set("fixed_map_seed", 7000)
	screen.set("run_state_override", run)
	root.add_child(screen)
	await process_frame
	await process_frame
	var overlay := screen.get("_reward_overlay") as RewardOverlay
	_assert_true(overlay.visible, "saved pending reward reopens instead of rerolling")
	_assert_true(_visible_ui_text_contains(overlay, "Gold Earned: %d" % run.reward_state.gold_amount), "reward overview displays exact automatic gold")
	_assert_true(screen.find_child("RemoveCardReward", true, false) != null, "reward overview shows remove-card result")
	_assert_true(screen.find_child("TrinketReward", true, false) != null, "reward overview shows trinket result")
	_assert_true(screen.find_child("CardChoiceReward", true, false) != null, "reward overview shows card-choice result independently")
	var continue_button := screen.find_child("RewardContinueButton", true, false) as Button
	_assert_true(continue_button.disabled, "unresolved optional rewards block Continue")
	var open_choice := screen.find_child("CardChoiceRewardClaimButton", true, false) as Button
	open_choice.pressed.emit()
	await process_frame
	_assert_true(run.reward_state.must_choose, "opening UI card choice immediately sets mustChoose")
	_assert_true(not continue_button.visible, "forced card choice hides Continue")
	_assert_equal(_count_named_prefix(overlay, "CardCandidate_"), 5, "UI renders five persistent card candidates")
	var first_candidate := _find_named_prefix(overlay, "CardCandidate_") as Button
	first_candidate.pressed.emit()
	await process_frame
	_assert_true(not run.reward_state.must_choose, "UI card selection clears mustChoose")
	var deck_before_cancel := run.deck.cards.size()
	var open_remove := screen.find_child("RemoveCardRewardClaimButton", true, false) as Button
	open_remove.pressed.emit()
	await process_frame
	var remove_grid := screen.find_child("RemoveCardGrid", true, false) as GridContainer
	var removal_candidate := remove_grid.get_child(0) as Button
	removal_candidate.pressed.emit()
	await process_frame
	var cancel_removal := screen.find_child("CancelCardRemovalButton", true, false) as Button
	cancel_removal.pressed.emit()
	await process_frame
	_assert_equal(run.deck.cards.size(), deck_before_cancel, "canceling removal confirmation preserves the deck")
	var removal_back := screen.find_child("RewardBackButton", true, false) as Button
	removal_back.pressed.emit()
	await process_frame
	var remove_skip := screen.find_child("RemoveCardRewardSkipButton", true, false) as Button
	var trinket_skip := screen.find_child("TrinketRewardSkipButton", true, false) as Button
	remove_skip.pressed.emit()
	trinket_skip.pressed.emit()
	await process_frame
	continue_button = screen.find_child("RewardContinueButton", true, false) as Button
	_assert_true(not continue_button.disabled, "resolved independent rewards enable Continue")
	continue_button.pressed.emit()
	await _wait_for_animation(screen)
	_assert_equal(run.stage, 2, "Continue advances to the next stage")
	_assert_true(run.reward_state == null, "leaving reward page permanently closes stage reward")
	var map_overlay: Variant = screen.get("_map_overlay")
	_assert_true(map_overlay.visible, "completed reward opens the three-node map")
	_assert_equal(run.node_state.candidates.size(), 3, "reward completion generates three next nodes")
	_assert_equal(run.node_state.candidate_seed, 7000, "UI map uses deterministic configured seed")
	_assert_equal(_count_named_prefix(map_overlay, "MapNodeButton_"), 3, "map UI renders three large node buttons")
	var first_node := screen.find_child("MapNodeButton_0", true, false) as Button
	first_node.pressed.emit()
	await process_frame
	_assert_equal(run.node_state.selected_index, 0, "map UI records selected destination")
	var destination_confirmation := screen.find_child("DestinationConfirmation", true, false) as PanelContainer
	_assert_true(destination_confirmation.visible, "map selection requires confirmation")
	var cancel_destination := screen.find_child("CancelDestinationButton", true, false) as Button
	cancel_destination.pressed.emit()
	await process_frame
	_assert_equal(run.node_state.selected_index, -1, "cancelled destination returns to all three choices")
	first_node = screen.find_child("MapNodeButton_0", true, false) as Button
	first_node.pressed.emit()
	await process_frame
	var confirm_destination := screen.find_child("ConfirmDestinationButton", true, false) as Button
	confirm_destination.pressed.emit()
	await process_frame
	_assert_true(run.node_state.selection_confirmed, "confirmed destination invalidates other choices")
	_assert_true(not map_overlay.visible, "other map candidates disappear after confirmation")
	_assert_true(not overlay.visible, "reward overlay closes after Continue")
	screen.queue_free()
	await process_frame


func _test_special_node_ui() -> void:
	_app_services().set_language("en", false)
	var flow: RefCounted = NodeFlowServiceType.new(DataRepository.load_node_config(), DataRepository.load_trinkets())
	var packed_scene := load("res://scenes/battle_screen.tscn") as PackedScene

	var shop_run := _new_test_run()
	shop_run.gold = 500
	shop_run.player_health = 50
	_enter_special_node(shop_run, flow, "shop", 81001)
	var shop_screen := packed_scene.instantiate()
	shop_screen.set("animation_duration_scale", 0.0)
	shop_screen.set("fixed_map_seed", 81010)
	shop_screen.set("run_state_override", shop_run)
	root.add_child(shop_screen)
	await process_frame
	await process_frame
	var special_overlay: Variant = shop_screen.get("_special_node_overlay")
	_assert_true(special_overlay.visible, "confirmed shop node opens shop UI")
	_assert_true(_visible_ui_text_contains(special_overlay, "Shop"), "shop UI has localized title")
	_assert_equal(_count_named_prefix(special_overlay, "ShopTrinket_"), 6, "shop UI displays six trinket products")
	var buy_card := shop_screen.find_child("ShopBuyCardButton", true, false) as Button
	buy_card.pressed.emit()
	await process_frame
	_assert_true(shop_run.shop_state.must_choose_card, "paid shop card purchase locks forced choice")
	_assert_equal(_count_named_prefix(special_overlay, "ShopCardCandidate_"), 5, "shop UI displays five card candidates")
	var shop_candidate := _find_named_prefix(special_overlay, "ShopCardCandidate_") as Button
	var shop_deck_before := shop_run.deck.cards.size()
	shop_candidate.pressed.emit()
	await process_frame
	_assert_equal(shop_run.deck.cards.size(), shop_deck_before + 1, "shop UI choice adds one permanent card")
	var remove_button := shop_screen.find_child("ShopRemoveCardButton", true, false) as Button
	remove_button.pressed.emit()
	await process_frame
	var remove_grid := shop_screen.find_child("ShopRemoveCardGrid", true, false) as GridContainer
	remove_grid.get_child(0).pressed.emit()
	await process_frame
	var cancel_remove := shop_screen.find_child("ShopCancelRemovalButton", true, false) as Button
	cancel_remove.pressed.emit()
	await process_frame
	_assert_equal(shop_run.deck.cards.size(), shop_deck_before + 1, "shop removal cancellation preserves deck")
	(shop_screen.find_child("SpecialNodeBackButton", true, false) as Button).pressed.emit()
	await process_frame
	var heal_button := shop_screen.find_child("ShopHealButton", true, false) as Button
	heal_button.pressed.emit()
	await process_frame
	_assert_equal(shop_run.player_health, 80, "shop UI heal restores persistent health")
	var first_product := _find_named_prefix(special_overlay, "ShopTrinket_") as Button
	var trinkets_before := shop_run.trinket_ids.size()
	first_product.pressed.emit()
	await process_frame
	_assert_equal(shop_run.trinket_ids.size(), trinkets_before + 1, "shop UI purchase adds trinket")
	var leave_shop := shop_screen.find_child("LeaveShopButton", true, false) as Button
	leave_shop.pressed.emit()
	await process_frame
	_assert_equal(shop_run.stage, 2, "leaving shop advances stage")
	_assert_true((shop_screen.get("_map_overlay") as CanvasItem).visible, "leaving shop opens next three-node map")
	shop_screen.queue_free()
	await process_frame

	var fountain_run := _new_test_run()
	fountain_run.player_health = 50
	_enter_special_node(fountain_run, flow, "fountain", 82001)
	var fountain_screen := packed_scene.instantiate()
	fountain_screen.set("animation_duration_scale", 0.0)
	fountain_screen.set("fixed_map_seed", 82010)
	fountain_screen.set("run_state_override", fountain_run)
	root.add_child(fountain_screen)
	await process_frame
	await process_frame
	var fountain_result := fountain_screen.find_child("FountainResultLabel", true, false) as Label
	_assert_true(fountain_result.text.contains("Restored: 30"), "fountain UI reports actual restoration")
	(fountain_screen.find_child("FountainContinueButton", true, false) as Button).pressed.emit()
	await process_frame
	_assert_equal(fountain_run.stage, 2, "fountain UI Continue advances stage")
	fountain_screen.queue_free()
	await process_frame

	var treasure_run := _new_test_run()
	_enter_special_node(treasure_run, flow, "treasure", 83001)
	var treasure_screen := packed_scene.instantiate()
	treasure_screen.set("animation_duration_scale", 0.0)
	treasure_screen.set("fixed_map_seed", 83010)
	treasure_screen.set("run_state_override", treasure_run)
	root.add_child(treasure_screen)
	await process_frame
	await process_frame
	var open_treasure := treasure_screen.find_child("OpenTreasureButton", true, false) as Button
	_assert_true(open_treasure != null, "treasure UI can be opened or abandoned before commitment")
	open_treasure.pressed.emit()
	await process_frame
	_assert_true(treasure_run.treasure_state.must_choose, "opening treasure UI activates mustChoose")
	_assert_equal(_count_named_prefix(treasure_screen.get("_special_node_overlay"), "TreasureTrinket_"), 3, "opened treasure displays three trinkets")
	_assert_true(treasure_screen.find_child("LeaveTreasureButton", true, false) == null, "opened treasure cannot return or skip")
	var treasure_choice := _find_named_prefix(treasure_screen.get("_special_node_overlay"), "TreasureTrinket_") as Button
	treasure_choice.pressed.emit()
	await process_frame
	_assert_equal(treasure_run.stage, 2, "treasure selection completes and advances node")
	_assert_true((treasure_screen.get("_map_overlay") as CanvasItem).visible, "treasure completion opens next map")
	treasure_screen.queue_free()
	await process_frame


func _test_elite_battle_ui() -> void:
	_app_services().set_language("en", false)
	var flow: RefCounted = NodeFlowServiceType.new(DataRepository.load_node_config(), DataRepository.load_trinkets())
	var run := _new_test_run()
	_enter_special_node(run, flow, "elite", 84001)
	var packed_scene := load("res://scenes/battle_screen.tscn") as PackedScene
	var screen := packed_scene.instantiate()
	screen.set("animation_duration_scale", 0.0)
	screen.set("fixed_battle_seed", 84002)
	screen.set("fixed_reward_seed", 8)
	screen.set("run_state_override", run)
	root.add_child(screen)
	await _wait_for_animation(screen)
	var battle := screen.get("_battle") as BattleState
	_assert_equal(battle.enemy_type, "elite", "elite map node creates elite battle state")
	_assert_equal(battle.enemy_max_health, 53, "stage-one elite UI uses 1.5 health")
	_assert_equal(battle.enemy_attack, 8, "stage-one elite UI uses rounded 1.5 attack")
	_assert_equal((screen.get("_enemy_caption") as Label).text, "Elite", "battle UI clearly labels Elite")
	var buttons := _collect_hand_card_buttons(screen)
	battle.enemy_health = 1
	_set_card_pressed(buttons[0], true)
	(screen.find_child("PlayButton", true, false) as Button).pressed.emit()
	await _wait_for_result(screen)
	_assert_true((screen.get("_reward_overlay") as RewardOverlay).visible, "elite victory opens reward overview")
	_assert_equal(run.reward_state.battle_type, "elite", "elite reward records source type")
	_assert_equal(run.reward_state.gold_amount, 21, "elite reward seed scales normal 14 Gold to 21")
	_assert_true(run.reward_state.card_choice_offered, "elite victory always offers card choice")
	screen.queue_free()
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
		if (
			(screen.get("_result_overlay") as ColorRect).visible
			or (screen.get("_reward_overlay") as RewardOverlay).visible
		):
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
	var labels := {"A": 14, "J": 11, "Q": 12, "K": 13}
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


func _rule_localized_text(node: Node, localization_key: String) -> String:
	if (
		node is Label
		and node.has_meta("localization_key")
		and str(node.get_meta("localization_key")) == localization_key
	):
		return (node as Label).text
	for child in node.get_children():
		var text := _rule_localized_text(child, localization_key)
		if text != "":
			return text
	return ""


func _visible_ui_text_contains(node: Node, needle: String) -> bool:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return false
	if node is Label and (node as Label).text.contains(needle):
		return true
	if node is Button and (node as Button).text.contains(needle):
		return true
	if node is RichTextLabel and (node as RichTextLabel).text.contains(needle):
		return true
	for child in node.get_children():
		if _visible_ui_text_contains(child, needle):
			return true
	return false


func _count_type_recursive(node: Node, type_script: Variant) -> int:
	var count := 0
	for child in node.get_children():
		if is_instance_of(child, type_script):
			count += 1
		count += _count_type_recursive(child, type_script)
	return count


func _count_named_prefix(node: Node, prefix: String) -> int:
	var count := 1 if node.name.begins_with(prefix) else 0
	for child in node.get_children():
		count += _count_named_prefix(child, prefix)
	return count


func _find_named_prefix(node: Node, prefix: String) -> Node:
	if node.name.begins_with(prefix):
		return node
	for child in node.get_children():
		var found := _find_named_prefix(child, prefix)
		if found != null:
			return found
	return null


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
		var rank_index := index % 13
		var rank := 14 if rank_index == 0 else rank_index + 1
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


func _new_test_run() -> RunState:
	return RunState.new(
		DataRepository.load_deck_definition(),
		DataRepository.load_reward_config()
	)


func _candidate_specs_unique(candidates: Array[Dictionary]) -> bool:
	var seen: Dictionary = {}
	for candidate in candidates:
		var key := "%d:%d" % [int(candidate.get("rank", 0)), int(candidate.get("suit", -1))]
		if seen.has(key):
			return false
		seen[key] = true
	return true


func _find_reward_seed(generator: RewardGenerator, run: RunState, require_card_choice: bool) -> int:
	for seed in range(1, 20000):
		var reward := generator.generate(run.stage, run, seed)
		if not require_card_choice or reward.card_choice_offered:
			return seed
	return 0


func _enter_special_node(
	run: RunState,
	flow: RefCounted,
	node_type: String,
	content_seed: int
) -> void:
	var state: RefCounted = NodeStateType.new()
	state.current_stage = run.stage
	state.candidates.append({
		"index": 0,
		"type": node_type,
		"name_key": "node.%s" % node_type,
		"description_key": "node.%s.description" % node_type,
		"icon": "?",
		"dangerous": node_type in ["battle", "elite"],
		"stage": run.stage
	})
	run.node_state = state
	flow.select_candidate(run, 0)
	flow.confirm_and_enter(run, content_seed)


func _strings_unique(values: Array) -> bool:
	var seen: Dictionary = {}
	for value in values:
		var key := str(value)
		if seen.has(key):
			return false
		seen[key] = true
	return true


func _rank_label(rank: int) -> String:
	match rank:
		14:
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
