extends Control

const ENEMY_ID := &"debt_gambler"

var animation_duration_scale := 1.0
var fixed_battle_seed := 0

var _deck: Deck
var _evaluator: PokerEvaluator
var _battle: BattleState
var _hand_state := HandState.new()
var _card_buttons: Array[PokerCardButton] = []
var _input_locked := false
var _animation_in_progress := false
var _enemy_definition: Dictionary
var _log_events: Array[Dictionary] = []
var _finished_result: Variant = null
var _services: Node

var _refresh_execution_count := 0
var _last_discard_animation_target := Vector2.ZERO
var _last_draw_animation_origin := Vector2.ZERO
var _last_draw_entry_sequence: Array[int] = []
var _last_discard_entry_sequence: Array[int] = []
var _shuffle_animation_count := 0

var _title_label: Label
var _subtitle_label: Label
var _round_label: Label
var _restart_button: Button
var _player_title: Label
var _player_hint: Label
var _player_health_label: Label
var _player_health_bar: ProgressBar
var _rules_label: Label
var _log_title: Label
var _enemy_caption: Label
var _enemy_name_label: Label
var _enemy_health_label: Label
var _enemy_health_bar: ProgressBar
var _intent_caption: Label
var _enemy_intent_label: Label
var _hand_title: Label
var _selection_label: Label
var _preview_label: Label
var _feedback_label: Label
var _hand_panel: PanelContainer
var _hand_container: HBoxContainer
var _play_button: Button
var _refresh_button: Button
var _battle_log: RichTextLabel
var _enemy_panel: PanelContainer
var _draw_pile_button: Button
var _discard_pile_button: Button
var _animation_layer: Control
var _pile_overlay: ColorRect
var _pile_browser_panel: PanelContainer
var _pile_browser_title: Label
var _pile_browser_rows: VBoxContainer
var _pile_browser_close: Button
var _card_detail_overlay: ColorRect
var _card_detail_label: Label
var _card_detail_close: Button
var _detail_card: CardData
var _open_pile_kind := ""
var _result_overlay: ColorRect
var _result_title: Label
var _result_detail: Label
var _retry_button: Button


func _ready() -> void:
	_services = get_node("/root/AppServices")
	_build_interface()
	_services.language_changed.connect(_on_language_changed)
	_start_battle()


func _build_interface() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#111827")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var glow := ColorRect.new()
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.color = Color(0.16, 0.11, 0.20, 0.34)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)

	var page_margin := MarginContainer.new()
	page_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_margin.add_theme_constant_override("margin_left", 34)
	page_margin.add_theme_constant_override("margin_right", 34)
	page_margin.add_theme_constant_override("margin_top", 20)
	page_margin.add_theme_constant_override("margin_bottom", 20)
	add_child(page_margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 11)
	page_margin.add_child(page)
	page.add_child(_build_header())
	page.add_child(_build_arena())
	page.add_child(_build_hand_area())

	_animation_layer = Control.new()
	_animation_layer.name = "AnimationLayer"
	_animation_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_animation_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_animation_layer)
	_build_pile_browser()
	_build_result_overlay()


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 48
	header.add_theme_constant_override("separation", 12)

	var title_group := VBoxContainer.new()
	title_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color("#f3d98b"))
	title_group.add_child(_title_label)
	_subtitle_label = Label.new()
	_subtitle_label.add_theme_font_size_override("font_size", 13)
	_subtitle_label.add_theme_color_override("font_color", Color("#9ca8bd"))
	title_group.add_child(_subtitle_label)
	header.add_child(title_group)

	_round_label = Label.new()
	_round_label.add_theme_font_size_override("font_size", 18)
	_round_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_round_label)

	_restart_button = Button.new()
	_restart_button.name = "RestartButton"
	_restart_button.custom_minimum_size = Vector2(110, 38)
	_restart_button.pressed.connect(_start_battle)
	header.add_child(_restart_button)
	return header


func _build_arena() -> Control:
	var arena := HBoxContainer.new()
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena.add_theme_constant_override("separation", 18)

	var player_panel := PanelContainer.new()
	player_panel.custom_minimum_size = Vector2(270, 220)
	player_panel.add_theme_stylebox_override("panel", _panel_style(Color("#172338"), Color("#355174")))
	var player_content := VBoxContainer.new()
	player_content.add_theme_constant_override("separation", 9)
	_player_title = Label.new()
	_player_title.add_theme_font_size_override("font_size", 23)
	_player_title.add_theme_color_override("font_color", Color("#b9d6ff"))
	player_content.add_child(_player_title)
	_player_hint = Label.new()
	_player_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_player_hint.add_theme_color_override("font_color", Color("#9ca8bd"))
	player_content.add_child(_player_hint)
	_player_health_label = Label.new()
	_player_health_label.add_theme_font_size_override("font_size", 17)
	player_content.add_child(_player_health_label)
	_player_health_bar = _health_bar(Color("#3dbf8f"))
	player_content.add_child(_player_health_bar)
	_rules_label = Label.new()
	_rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rules_label.add_theme_color_override("font_color", Color("#8290a7"))
	player_content.add_spacer(false)
	player_content.add_child(_rules_label)
	player_panel.add_child(player_content)
	arena.add_child(player_panel)

	var center_panel := PanelContainer.new()
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_panel.add_theme_stylebox_override("panel", _panel_style(Color("#111a29"), Color("#293851")))
	var center_content := VBoxContainer.new()
	_log_title = Label.new()
	_log_title.add_theme_font_size_override("font_size", 16)
	center_content.add_child(_log_title)
	_battle_log = RichTextLabel.new()
	_battle_log.bbcode_enabled = true
	_battle_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_battle_log.add_theme_font_size_override("normal_font_size", 15)
	center_content.add_child(_battle_log)
	center_panel.add_child(center_content)
	arena.add_child(center_panel)

	_enemy_panel = PanelContainer.new()
	_enemy_panel.custom_minimum_size = Vector2(310, 220)
	_enemy_panel.add_theme_stylebox_override("panel", _panel_style(Color("#321d27"), Color("#713849")))
	var enemy_content := VBoxContainer.new()
	enemy_content.add_theme_constant_override("separation", 8)
	_enemy_caption = Label.new()
	_enemy_caption.add_theme_color_override("font_color", Color("#d99aaa"))
	enemy_content.add_child(_enemy_caption)
	_enemy_name_label = Label.new()
	_enemy_name_label.add_theme_font_size_override("font_size", 24)
	_enemy_name_label.add_theme_color_override("font_color", Color("#ffd0d7"))
	enemy_content.add_child(_enemy_name_label)
	_enemy_health_label = Label.new()
	_enemy_health_label.add_theme_font_size_override("font_size", 17)
	enemy_content.add_child(_enemy_health_label)
	_enemy_health_bar = _health_bar(Color("#d65d72"))
	enemy_content.add_child(_enemy_health_bar)
	_intent_caption = Label.new()
	_intent_caption.add_theme_color_override("font_color", Color("#9ca8bd"))
	enemy_content.add_child(_intent_caption)
	_enemy_intent_label = Label.new()
	_enemy_intent_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_enemy_intent_label.add_theme_font_size_override("font_size", 16)
	_enemy_intent_label.add_theme_color_override("font_color", Color("#ffbd8a"))
	enemy_content.add_child(_enemy_intent_label)
	_enemy_panel.add_child(enemy_content)
	arena.add_child(_enemy_panel)
	return arena


func _build_hand_area() -> Control:
	_hand_panel = PanelContainer.new()
	_hand_panel.custom_minimum_size.y = 268
	_hand_panel.add_theme_stylebox_override("panel", _panel_style(Color("#182131"), Color("#35445d")))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)

	var heading_row := HBoxContainer.new()
	_hand_title = Label.new()
	_hand_title.add_theme_font_size_override("font_size", 17)
	_hand_title.add_theme_color_override("font_color", Color("#cbd5e1"))
	heading_row.add_child(_hand_title)
	_feedback_label = Label.new()
	_feedback_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_feedback_label.add_theme_color_override("font_color", Color("#ff9a9a"))
	heading_row.add_child(_feedback_label)
	content.add_child(heading_row)

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 10)
	_selection_label = Label.new()
	_selection_label.custom_minimum_size.x = 115
	_selection_label.add_theme_font_size_override("font_size", 16)
	status_row.add_child(_selection_label)
	_preview_label = Label.new()
	_preview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_label.add_theme_font_size_override("font_size", 16)
	_preview_label.add_theme_color_override("font_color", Color("#f3d98b"))
	status_row.add_child(_preview_label)
	_play_button = _action_button("PlayButton", 120)
	_play_button.pressed.connect(_on_play_pressed)
	status_row.add_child(_play_button)
	_refresh_button = _action_button("RefreshButton", 125)
	_refresh_button.pressed.connect(_on_refresh_pressed)
	status_row.add_child(_refresh_button)
	content.add_child(status_row)

	var table_row := HBoxContainer.new()
	table_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table_row.add_theme_constant_override("separation", 10)
	_discard_pile_button = _pile_button("DiscardPileButton")
	_discard_pile_button.pressed.connect(_open_pile_browser.bind("discard"))
	table_row.add_child(_discard_pile_button)
	_hand_container = HBoxContainer.new()
	_hand_container.name = "HandContainer"
	_hand_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_hand_container.add_theme_constant_override("separation", 8)
	_hand_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table_row.add_child(_hand_container)
	_draw_pile_button = _pile_button("DrawPileButton")
	_draw_pile_button.pressed.connect(_open_pile_browser.bind("draw"))
	table_row.add_child(_draw_pile_button)
	content.add_child(table_row)
	_hand_panel.add_child(content)
	return _hand_panel


func _build_pile_browser() -> void:
	_pile_overlay = ColorRect.new()
	_pile_overlay.name = "PileBrowserOverlay"
	_pile_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pile_overlay.color = Color(0.01, 0.015, 0.025, 0.82)
	_pile_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_pile_overlay.visible = false
	_pile_overlay.gui_input.connect(_on_pile_overlay_input)
	add_child(_pile_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pile_overlay.add_child(center)
	_pile_browser_panel = PanelContainer.new()
	_pile_browser_panel.custom_minimum_size = Vector2(1120, 650)
	_pile_browser_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_pile_browser_panel.add_theme_stylebox_override(
		"panel", _panel_style(Color("#172235"), Color("#7586a3"), 2)
	)
	center.add_child(_pile_browser_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	_pile_browser_panel.add_child(content)
	var header := HBoxContainer.new()
	_pile_browser_title = Label.new()
	_pile_browser_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pile_browser_title.add_theme_font_size_override("font_size", 26)
	header.add_child(_pile_browser_title)
	_pile_browser_close = Button.new()
	_pile_browser_close.name = "PileBrowserCloseButton"
	_pile_browser_close.custom_minimum_size = Vector2(100, 38)
	_pile_browser_close.pressed.connect(_close_pile_browser)
	header.add_child(_pile_browser_close)
	content.add_child(header)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_pile_browser_rows = VBoxContainer.new()
	_pile_browser_rows.name = "PileSuitRows"
	_pile_browser_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pile_browser_rows.add_theme_constant_override("separation", 8)
	scroll.add_child(_pile_browser_rows)

	_card_detail_overlay = ColorRect.new()
	_card_detail_overlay.name = "PileCardDetailOverlay"
	_card_detail_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card_detail_overlay.color = Color(0.01, 0.015, 0.025, 0.82)
	_card_detail_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_card_detail_overlay.visible = false
	_pile_overlay.add_child(_card_detail_overlay)
	var detail_center := CenterContainer.new()
	detail_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card_detail_overlay.add_child(detail_center)
	var detail_panel := PanelContainer.new()
	detail_panel.custom_minimum_size = Vector2(360, 250)
	detail_panel.add_theme_stylebox_override(
		"panel", _panel_style(Color("#172235"), Color("#e4bd62"), 2)
	)
	detail_center.add_child(detail_panel)
	var detail_content := VBoxContainer.new()
	detail_content.alignment = BoxContainer.ALIGNMENT_CENTER
	detail_content.add_theme_constant_override("separation", 18)
	detail_panel.add_child(detail_content)
	_card_detail_label = Label.new()
	_card_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_detail_label.add_theme_font_size_override("font_size", 25)
	detail_content.add_child(_card_detail_label)
	_card_detail_close = Button.new()
	_card_detail_close.name = "PileCardDetailCloseButton"
	_card_detail_close.custom_minimum_size = Vector2(110, 38)
	_card_detail_close.pressed.connect(_close_card_detail)
	detail_content.add_child(_card_detail_close)


func _build_result_overlay() -> void:
	_result_overlay = ColorRect.new()
	_result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_overlay.color = Color(0.02, 0.025, 0.04, 0.88)
	_result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_result_overlay.visible = false
	add_child(_result_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_result_overlay.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(460, 260)
	card.add_theme_stylebox_override("panel", _panel_style(Color("#172235"), Color("#e4bd62"), 3))
	center.add_child(card)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 18)
	_result_title = Label.new()
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_title.add_theme_font_size_override("font_size", 38)
	content.add_child(_result_title)
	_result_detail = Label.new()
	_result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_detail.add_theme_font_size_override("font_size", 17)
	content.add_child(_result_detail)
	_retry_button = Button.new()
	_retry_button.name = "RetryButton"
	_retry_button.custom_minimum_size = Vector2(170, 46)
	_retry_button.pressed.connect(_start_battle)
	content.add_child(_retry_button)
	card.add_child(content)


func _start_battle() -> void:
	if _animation_in_progress:
		return
	_close_pile_browser()
	if _hand_state != null:
		_hand_state.clear_battle()
	_enemy_definition = DataRepository.load_enemy(ENEMY_ID)
	_deck = Deck.new(DataRepository.load_deck_definition())
	_evaluator = PokerEvaluator.new(DataRepository.load_poker_rules())
	_battle = BattleState.new(_enemy_definition)
	_hand_state = HandState.new()
	var initial_draw := _hand_state.start_battle(
		_deck,
		fixed_battle_seed,
		_battle.player_hand_size
	)
	_battle.health_changed.connect(_on_health_changed)
	_player_health_bar.max_value = _battle.player_max_health
	_enemy_health_bar.max_value = _battle.enemy_max_health
	_log_events.clear()
	_append_log_event("battle.start_log", [], [], "#f3d98b")
	_finished_result = null
	_result_overlay.visible = false
	_feedback_label.text = ""
	_input_locked = true
	_animation_in_progress = true
	_refresh_execution_count = 0
	_on_health_changed(_battle.player_health, _battle.enemy_health)
	_rebuild_hand_buttons(_id_set(initial_draw.drawn_cards))
	_apply_localization()
	call_deferred("_animate_initial_draw", initial_draw)


func _animate_initial_draw(result: DrawCommandResult) -> void:
	await get_tree().process_frame
	await _animate_draw_result(result, {})
	_animation_in_progress = false
	_input_locked = false
	_update_interaction()


func _rebuild_hand_buttons(hidden_ids: Dictionary = {}) -> void:
	for child in _hand_container.get_children():
		_hand_container.remove_child(child)
		child.queue_free()
	_card_buttons.clear()
	for card in _hand_state.display_cards():
		var button := PokerCardButton.new()
		_hand_container.add_child(button)
		button.configure(card)
		button.toggled.connect(_on_card_toggled.bind(button))
		button.visible = not hidden_ids.has(card.instance_id)
		_card_buttons.append(button)
	_update_interaction()


func _on_card_toggled(is_pressed: bool, button: PokerCardButton) -> void:
	if _input_locked or _battle.is_finished:
		button.set_pressed_no_signal(_hand_state.selected_cards().has(button.card_data))
		return
	var change := _hand_state.set_card_selected(button.card_data, is_pressed)
	if change == HandSelection.ChangeResult.REJECTED_LIMIT:
		button.set_pressed_no_signal(false)
		button.set_evaluation_state(false, false)
		_show_feedback("battle.selection_limit")
		return
	if change == HandSelection.ChangeResult.REJECTED_INVALID:
		button.set_pressed_no_signal(false)
		return
	_feedback_label.text = ""
	_update_interaction()


func _update_interaction() -> void:
	if _battle == null:
		return
	var selected := _hand_state.selected_cards()
	_selection_label.text = _services.t("battle.selected_count", [selected.size(), HandState.MAX_SELECTED])
	var result := _evaluator.evaluate(selected)
	_preview_label.text = _localized_result_summary(result)
	_play_button.text = _services.t("battle.confirm")
	_play_button.disabled = selected.is_empty() or _input_locked or _battle.is_finished
	_refresh_button.text = _services.t("battle.refresh", [_hand_state.refreshes_remaining])
	_refresh_button.disabled = (
		selected.is_empty()
		or _hand_state.refreshes_remaining <= 0
		or _input_locked
		or _battle.is_finished
	)
	_restart_button.disabled = _animation_in_progress
	_retry_button.disabled = _animation_in_progress
	for button in _card_buttons:
		button.set_interaction_disabled(_input_locked or _battle.is_finished)
		button.set_evaluation_state(
			result.scoring_cards.has(button.card_data),
			result.unscored_cards.has(button.card_data)
		)
	_update_pile_ui()


func _on_refresh_pressed() -> void:
	if _animation_in_progress or _input_locked:
		_show_feedback("battle.refresh_in_progress")
		return
	if _battle.is_finished:
		return
	if _hand_state.refreshes_remaining <= 0:
		_show_feedback("battle.refresh_unavailable")
		return
	if _hand_state.selected_cards().is_empty():
		_show_feedback("battle.refresh_empty")
		return

	_input_locked = true
	_animation_in_progress = true
	_refresh_execution_count += 1
	var retained_positions := _current_card_global_positions()
	var result := _hand_state.refresh_selected()
	if not result.success:
		_input_locked = false
		_animation_in_progress = false
		_update_interaction()
		return
	_feedback_label.text = _services.t("battle.refresh_in_progress")
	_append_log_event(
		"battle.refresh_complete",
		[result.removed_cards.size(), result.refreshes_after],
		[],
		"#7dd3fc"
	)
	_update_interaction()
	await _animate_cards_to_discard(result.removed_cards)
	if result.draw_result.reshuffle_count() > 0:
		await _animate_shuffle(result.draw_result)
	_rebuild_hand_buttons(_id_set(result.drawn_cards))
	await get_tree().process_frame
	await _animate_retained_reorder(retained_positions, result.retained_cards)
	await _animate_draw_result(result.draw_result, {})
	_feedback_label.text = ""
	_animation_in_progress = false
	_input_locked = false
	_update_interaction()


func _on_play_pressed() -> void:
	if _input_locked or _battle.is_finished or _hand_state.selected_cards().is_empty():
		return
	_input_locked = true
	_animation_in_progress = true
	_update_interaction()
	var selected := _hand_state.selected_cards()
	var result := _evaluator.evaluate(selected)
	_append_log_event(
		"battle.play_log",
		[_battle.round_number, result.display_name, result.damage],
		[1],
		"#f3d98b"
	)
	var enemy_defeated := _battle.apply_player_hand(result)
	_animate_enemy_hit()
	var retained_positions := _current_card_global_positions()
	var discard_result := _hand_state.discard_selected_after_judgment()
	var retained_cards := _hand_state.battle_deck_state.hand.duplicate()
	_update_pile_ui()
	await _animate_cards_to_discard(discard_result.moved_cards)
	_rebuild_hand_buttons()
	await get_tree().process_frame
	await _animate_retained_reorder(retained_positions, retained_cards)
	if enemy_defeated:
		await _finish_battle(true)
		return

	_append_log_event(
		"battle.counter_log",
		[_battle.enemy_name_key, _battle.enemy_attack],
		[0],
		"#ff9a9a"
	)
	var player_defeated := _battle.resolve_enemy_action()
	await _wait(0.22)
	if player_defeated:
		await _finish_battle(false)
		return

	var before_draw_positions := _current_card_global_positions()
	var round_draw := _hand_state.start_new_round()
	if round_draw.reshuffle_count() > 0:
		await _animate_shuffle(round_draw)
	_rebuild_hand_buttons(_id_set(round_draw.drawn_cards))
	_apply_localization()
	await get_tree().process_frame
	await _animate_retained_reorder(before_draw_positions, retained_cards)
	await _animate_draw_result(round_draw, {})
	_animation_in_progress = false
	_input_locked = false
	_update_interaction()


func _finish_battle(player_won: bool) -> void:
	_finished_result = player_won
	if player_won:
		_append_log_event("battle.victory_log", [], [], "#8ee6b9")
	else:
		_append_log_event("battle.defeat_log", [], [], "#ff9a9a")
	_hand_state.clear_battle()
	_clear_hand_buttons()
	_update_pile_ui()
	_apply_result_localization()
	_animation_in_progress = false
	_input_locked = true
	await _wait(0.35)
	_result_overlay.visible = true
	_retry_button.disabled = false


func _animate_cards_to_discard(cards: Array[CardData]) -> void:
	_last_discard_entry_sequence.clear()
	if cards.is_empty():
		return
	_last_discard_animation_target = _pile_center(_discard_pile_button)
	var max_delay := 0.0
	for index in range(cards.size()):
		_last_discard_entry_sequence.append(cards[index].instance_id)
		var button := _button_for_card(cards[index])
		if button == null:
			continue
		button.freeze_visual_motion()
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.reparent(_animation_layer, true)
		button.z_index = 20 + index
		var duration := 0.19 * animation_duration_scale
		var delay := float(index) * 0.045 * animation_duration_scale
		max_delay = maxf(max_delay, delay + duration)
		var tween := create_tween()
		if delay > 0.0:
			tween.tween_interval(delay)
		tween.tween_property(
			button,
			"global_position",
			_last_discard_animation_target - button.size * 0.5,
			duration
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(button, "rotation", -0.08 + index * 0.025, duration)
		tween.parallel().tween_property(button, "scale", Vector2(0.72, 0.72), duration)
		tween.parallel().tween_property(button, "modulate:a", 0.0, duration)
	await _wait(max_delay)
	for card in cards:
		var button := _button_for_card(card)
		if button != null and button.get_parent() == _animation_layer:
			_card_buttons.erase(button)
			button.queue_free()


func _animate_draw_result(result: DrawCommandResult, _unused_positions: Dictionary) -> void:
	_last_draw_animation_origin = _pile_center(_draw_pile_button)
	_last_draw_entry_sequence.clear()
	for card in result.drawn_cards:
		_last_draw_entry_sequence.append(card.instance_id)
		var target_button := _button_for_card(card)
		if target_button == null:
			continue
		target_button.visible = false
		var flying := PokerCardButton.new()
		_animation_layer.add_child(flying)
		flying.configure(card)
		flying.show_card_back()
		flying.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flying.global_position = _last_draw_animation_origin - flying.custom_minimum_size * 0.5
		flying.pivot_offset = flying.custom_minimum_size * 0.5
		var target_position := target_button.global_position
		var duration := 0.17 * animation_duration_scale
		var movement := create_tween()
		movement.tween_property(flying, "global_position", target_position, duration).set_trans(
			Tween.TRANS_QUAD
		).set_ease(Tween.EASE_OUT)
		var flip := create_tween()
		flip.tween_property(flying, "scale:x", 0.05, duration * 0.48)
		flip.tween_callback(flying.show_card_face)
		flip.tween_property(flying, "scale:x", 1.0, duration * 0.52)
		await _wait(duration)
		target_button.visible = true
		flying.queue_free()
		await _wait(0.025)


func _animate_retained_reorder(
	old_positions: Dictionary,
	retained_cards: Array[CardData]
) -> void:
	var tweens: Array[Tween] = []
	for card in retained_cards:
		var button := _button_for_card(card)
		if button == null or not old_positions.has(card.instance_id):
			continue
		var target := button.position
		button.global_position = old_positions[card.instance_id]
		var tween := create_tween()
		tween.tween_property(button, "position", target, 0.16 * animation_duration_scale).set_trans(
			Tween.TRANS_QUAD
		).set_ease(Tween.EASE_OUT)
		tweens.append(tween)
	if not tweens.is_empty():
		await _wait(0.16)


func _animate_shuffle(_result: DrawCommandResult) -> void:
	_shuffle_animation_count += 1
	_feedback_label.text = _services.t("pile.shuffling")
	var proxy := Button.new()
	proxy.custom_minimum_size = Vector2(84, 112)
	proxy.text = "◆\nFATE"
	proxy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	proxy.add_theme_font_size_override("font_size", 18)
	_animation_layer.add_child(proxy)
	proxy.global_position = _pile_center(_discard_pile_button) - proxy.custom_minimum_size * 0.5
	var duration := 0.22 * animation_duration_scale
	var tween := create_tween()
	tween.tween_property(
		proxy,
		"global_position",
		_pile_center(_draw_pile_button) - proxy.custom_minimum_size * 0.5,
		duration
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(proxy, "rotation", 0.18, duration * 0.5)
	await _wait(duration)
	proxy.queue_free()


func _open_pile_browser(kind: String) -> void:
	if _input_locked or _battle == null or _battle.is_finished:
		return
	_open_pile_kind = kind
	_render_pile_browser()
	_pile_overlay.visible = true


func _render_pile_browser() -> void:
	for child in _pile_browser_rows.get_children():
		_pile_browser_rows.remove_child(child)
		child.queue_free()
	var snapshot := _hand_state.pile_snapshot(StringName(_open_pile_kind))
	var title_key := "pile.draw" if _open_pile_kind == "draw" else "pile.discard"
	var title_quantity_key := "pile.title_one" if snapshot.total_count == 1 else "pile.title_many"
	_pile_browser_title.text = _services.t(title_quantity_key, [
		_services.t(title_key),
		snapshot.total_count
	])
	_pile_browser_close.text = _services.t("common.close")
	for group in snapshot.groups:
		_pile_browser_rows.add_child(_build_pile_suit_row(group))
	if _card_detail_overlay.visible:
		_apply_card_detail_localization()


func _build_pile_suit_row(group: Variant) -> Control:
	var row := PanelContainer.new()
	row.name = "PileSuitRow_%d" % group.suit_id
	row.custom_minimum_size.y = 122
	row.set_meta("suit_id", group.suit_id)
	row.set_meta("card_count", group.count)
	row.set_meta("display_card_ids", group.display_card_ids)
	row.add_theme_stylebox_override(
		"panel", _panel_style(Color("#101a2a"), Color("#33445f"), 1)
	)
	var row_content := HBoxContainer.new()
	row_content.add_theme_constant_override("separation", 12)
	row.add_child(row_content)
	var count_label := Label.new()
	count_label.name = "SuitCountLabel"
	count_label.custom_minimum_size.x = 220
	count_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	count_label.add_theme_font_size_override("font_size", 17)
	var quantity_key := "pile.suit_count_one" if group.count == 1 else "pile.suit_count_many"
	count_label.text = _services.t(quantity_key, [
		group.symbol,
		_services.t(group.name_key),
		group.count
	])
	row_content.add_child(count_label)

	var horizontal_scroll := ScrollContainer.new()
	horizontal_scroll.name = "SuitCardsScroll"
	horizontal_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	horizontal_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row_content.add_child(horizontal_scroll)
	var cards_row := HBoxContainer.new()
	cards_row.name = "SuitCards"
	cards_row.add_theme_constant_override("separation", 8)
	horizontal_scroll.add_child(cards_row)
	if group.display_cards.is_empty():
		var empty_label := Label.new()
		empty_label.name = "SuitEmptyLabel"
		empty_label.text = _services.t("pile.no_cards")
		empty_label.add_theme_color_override("font_color", Color("#8996aa"))
		empty_label.add_theme_font_size_override("font_size", 16)
		cards_row.add_child(empty_label)
	else:
		for card in group.display_cards:
			cards_row.add_child(_build_pile_card_view(card))
	return row


func _build_pile_card_view(card: CardData) -> Button:
	var view := Button.new()
	view.name = "PileCard_%d" % card.instance_id
	view.custom_minimum_size = Vector2(72, 96)
	view.text = "%s\n%s" % [card.rank_label, card.suit_symbol]
	view.add_theme_font_size_override("font_size", 21)
	view.add_theme_color_override("font_color", card.suit_color)
	view.add_theme_color_override("font_hover_color", card.suit_color)
	view.add_theme_color_override("font_pressed_color", card.suit_color)
	view.add_theme_stylebox_override(
		"normal", _panel_style(Color("#f4f0e8"), Color("#aaa395"), 2)
	)
	view.add_theme_stylebox_override(
		"hover", _panel_style(Color("#fffdf7"), Color("#8fc7e8"), 3)
	)
	view.add_theme_stylebox_override(
		"pressed", _panel_style(Color("#fff9e8"), Color("#e7b64b"), 3)
	)
	view.add_theme_stylebox_override(
		"focus", _panel_style(Color("#fffdf7"), Color("#8fc7e8"), 2)
	)
	view.tooltip_text = _services.t("card.tooltip", [
		_services.t(card.suit_name),
		card.rank_label,
		card.rank
	])
	view.set_meta("card_data", card)
	view.set_meta("instance_id", card.instance_id)
	view.pressed.connect(_open_card_detail.bind(card))
	return view


func _open_card_detail(card: CardData) -> void:
	_detail_card = card
	_apply_card_detail_localization()
	_card_detail_overlay.visible = true


func _close_card_detail() -> void:
	_card_detail_overlay.visible = false
	_detail_card = null


func _apply_card_detail_localization() -> void:
	if _detail_card == null:
		return
	_card_detail_label.text = "%s\n%s" % [
		_detail_card.display_name(),
		_services.t("card.tooltip", [
			_services.t(_detail_card.suit_name),
			_detail_card.rank_label,
			_detail_card.rank
		])
	]
	_card_detail_close.text = _services.t("common.close")


func _close_pile_browser() -> void:
	_close_card_detail()
	if _pile_overlay != null:
		_pile_overlay.visible = false
	_open_pile_kind = ""


func _on_pile_overlay_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
		and not _pile_browser_panel.get_global_rect().has_point(event.global_position)
	):
		_close_pile_browser()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _pile_overlay.visible:
		if _card_detail_overlay.visible:
			_close_card_detail()
		else:
			_close_pile_browser()
		get_viewport().set_input_as_handled()


func _update_pile_ui() -> void:
	if _draw_pile_button == null:
		return
	var draw_count := _hand_state.draw_pile_count()
	var discard_count := _hand_state.discard_pile_count()
	_draw_pile_button.text = _services.t("pile.count", [
		_services.t("pile.draw"),
		draw_count
	])
	_discard_pile_button.text = _services.t("pile.count", [
		_services.t("pile.discard"),
		discard_count
	])
	_draw_pile_button.tooltip_text = _services.t("pile.view_draw")
	_discard_pile_button.tooltip_text = _services.t("pile.view_discard")
	var unavailable := _input_locked or _battle == null or _battle.is_finished
	_draw_pile_button.disabled = unavailable
	_discard_pile_button.disabled = unavailable


func _on_health_changed(player_health: int, enemy_health: int) -> void:
	_player_health_bar.value = player_health
	_enemy_health_bar.value = enemy_health
	_player_health_label.text = _services.t("battle.health", [player_health, _battle.player_max_health])
	_enemy_health_label.text = _services.t("battle.health", [enemy_health, _battle.enemy_max_health])


func _on_language_changed(_language_code: String) -> void:
	_apply_localization()


func _apply_localization() -> void:
	if _battle == null:
		return
	_title_label.text = _services.t("app.title")
	_subtitle_label.text = _services.t("battle.prototype")
	_round_label.text = _services.t("battle.round", [_battle.round_number])
	_restart_button.text = _services.t("battle.restart")
	_player_title.text = _services.t("battle.player")
	_player_hint.text = _services.t("battle.player_hint")
	_rules_label.text = _services.t("battle.rules")
	_log_title.text = _services.t("battle.log_title")
	_enemy_caption.text = _services.t("battle.enemy_type")
	_enemy_name_label.text = _services.t(_battle.enemy_name_key)
	_intent_caption.text = _services.t("battle.intent_caption")
	_enemy_intent_label.text = _services.t(_battle.enemy_intent_key)
	_hand_title.text = _services.t("battle.hand")
	_retry_button.text = _services.t("result.retry")
	_on_health_changed(_battle.player_health, _battle.enemy_health)
	_update_interaction()
	_render_log()
	_apply_result_localization()
	if _pile_overlay.visible:
		_render_pile_browser()


func _apply_result_localization() -> void:
	if _finished_result == null:
		return
	if bool(_finished_result):
		_result_title.text = _services.t("result.victory")
		_result_title.add_theme_color_override("font_color", Color("#f3d98b"))
		_result_detail.text = _services.t("result.victory_detail", [
			_services.t(_battle.enemy_name_key),
			_battle.round_number
		])
	else:
		_result_title.text = _services.t("result.defeat")
		_result_title.add_theme_color_override("font_color", Color("#ff9a9a"))
		_result_detail.text = _services.t("result.defeat_detail")


func _localized_result_summary(result: PokerHandResult) -> String:
	if result.hand_id == &"":
		return _services.t("battle.no_selection")
	return _services.t("battle.damage_preview", [
		_services.t(result.display_name),
		result.attack_points,
		result.multiplier,
		result.damage
	])


func _append_log_event(
	key: String,
	arguments: Array,
	localized_argument_indices: Array,
	color: String
) -> void:
	_log_events.append({
		"key": key,
		"arguments": arguments.duplicate(),
		"localized_indices": localized_argument_indices.duplicate(),
		"color": color
	})
	_render_log()


func _render_log() -> void:
	if _battle_log == null:
		return
	_battle_log.clear()
	for event in _log_events:
		var arguments: Array = event["arguments"].duplicate()
		for index in event["localized_indices"]:
			arguments[index] = _services.t(str(arguments[index]))
		var line := str(_services.t(str(event["key"]), arguments))
		_battle_log.append_text("[color=%s]%s[/color]\n" % [event["color"], line])
	_battle_log.scroll_to_line(_battle_log.get_line_count())


func _show_feedback(key: String) -> void:
	_feedback_label.text = _services.t(key)


func _animate_enemy_hit() -> void:
	var original_position := _enemy_panel.position
	var tween := create_tween()
	tween.tween_property(_enemy_panel, "position:x", original_position.x + 8.0, 0.05)
	tween.tween_property(_enemy_panel, "position:x", original_position.x - 6.0, 0.05)
	tween.tween_property(_enemy_panel, "position:x", original_position.x, 0.07)


func _current_card_global_positions() -> Dictionary:
	var positions: Dictionary = {}
	for button in _card_buttons:
		positions[button.card_data.instance_id] = button.global_position
	return positions


func _button_for_card(card: CardData) -> PokerCardButton:
	for button in _card_buttons:
		if button.card_data == card:
			return button
	return null


func _clear_hand_buttons() -> void:
	for button in _card_buttons:
		if is_instance_valid(button):
			button.queue_free()
	_card_buttons.clear()


func _id_set(cards: Array[CardData]) -> Dictionary:
	var ids: Dictionary = {}
	for card in cards:
		ids[card.instance_id] = true
	return ids


func _pile_center(button: Control) -> Vector2:
	return button.global_position + button.size * 0.5


func _wait(base_seconds: float) -> void:
	var duration := base_seconds * animation_duration_scale
	if duration <= 0.0:
		await get_tree().process_frame
	else:
		await get_tree().create_timer(duration).timeout


func _action_button(node_name: String, width: float) -> Button:
	var button := Button.new()
	button.name = node_name
	button.custom_minimum_size = Vector2(width, 40)
	button.add_theme_font_size_override("font_size", 16)
	return button


func _pile_button(node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.custom_minimum_size = Vector2(106, 142)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_stylebox_override(
		"normal", _panel_style(Color("#24324b"), Color("#71809d"), 2)
	)
	button.add_theme_stylebox_override(
		"hover", _panel_style(Color("#2e405e"), Color("#94b6df"), 3)
	)
	return button


func _health_bar(fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 18
	bar.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color("#0b101b")
	background.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _panel_style(
	background: Color,
	border: Color,
	border_width: int = 1
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 7
	return style
