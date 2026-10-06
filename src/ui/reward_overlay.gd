class_name RewardOverlay
extends ColorRect

signal remove_card_confirmed(instance_id: int)
signal remove_card_skipped
signal trinket_claim_requested(replace_id: String)
signal trinket_skipped
signal card_choice_open_requested
signal card_choice_skipped
signal card_chosen(instance_id: int)
signal continue_requested

enum View {
	OVERVIEW,
	REMOVE_CARD,
	CONFIRM_REMOVE,
	REPLACE_TRINKET,
	CARD_CHOICE
}

var _services: Node
var _run: RunState
var _trinkets: Dictionary = {}
var _view := View.OVERVIEW
var _pending_remove_id := 0
var _title: Label
var _gold_label: Label
var _content: VBoxContainer
var _continue_button: Button


func _init() -> void:
	name = "RewardOverlay"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0.015, 0.02, 0.035, 0.96)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func configure(services: Node, run: RunState, trinket_definitions: Array[Dictionary]) -> void:
	_services = services
	_run = run
	_trinkets.clear()
	for definition in trinket_definitions:
		_trinkets[str(definition.get("id", ""))] = definition
	if _services != null and not _services.language_changed.is_connected(_on_language_changed):
		_services.language_changed.connect(_on_language_changed)
	render()


func show_reward() -> void:
	if _run == null or _run.reward_state == null:
		return
	_view = View.CARD_CHOICE if _run.reward_state.must_choose else View.OVERVIEW
	visible = true
	render()


func hide_reward() -> void:
	visible = false


func return_to_overview() -> void:
	_view = View.OVERVIEW
	_pending_remove_id = 0
	render()


func render() -> void:
	if _services == null or _run == null or _run.reward_state == null:
		return
	var reward := _run.reward_state
	if reward.must_choose:
		_view = View.CARD_CHOICE
	_title.text = _services.t("reward.title")
	_gold_label.text = _services.t("reward.gold_earned", [reward.gold_amount])
	_clear_content()
	match _view:
		View.OVERVIEW:
			_render_overview(reward)
		View.REMOVE_CARD:
			_render_remove_cards()
		View.CONFIRM_REMOVE:
			_render_remove_confirmation()
		View.REPLACE_TRINKET:
			_render_trinket_replacement()
		View.CARD_CHOICE:
			_render_card_choice(reward)
	_continue_button.text = _services.t("reward.continue")
	_continue_button.visible = _view == View.OVERVIEW
	_continue_button.disabled = not reward.can_continue()


func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1040, 650)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#172235"), Color("#d5ae58"), 2))
	center.add_child(panel)
	var root_content := VBoxContainer.new()
	root_content.add_theme_constant_override("separation", 12)
	panel.add_child(root_content)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 32)
	_title.add_theme_color_override("font_color", Color("#f3d98b"))
	root_content.add_child(_title)
	_gold_label = Label.new()
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label.add_theme_font_size_override("font_size", 21)
	_gold_label.add_theme_color_override("font_color", Color("#ffd86b"))
	root_content.add_child(_gold_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_content.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	scroll.add_child(_content)
	_continue_button = Button.new()
	_continue_button.name = "RewardContinueButton"
	_continue_button.custom_minimum_size = Vector2(210, 46)
	_continue_button.pressed.connect(func() -> void: continue_requested.emit())
	root_content.add_child(_continue_button)


func _render_overview(reward: RewardState) -> void:
	_add_reward_row(
		"RemoveCardReward",
		"reward.remove_card",
		reward.remove_card_offered,
		reward.remove_card_claimed,
		reward.remove_card_skipped,
		_open_remove_cards,
		func() -> void: remove_card_skipped.emit(),
		_run.deck.cards.size() > _run.minimum_deck_size,
		"reward.minimum_deck" if _run.deck.cards.size() <= _run.minimum_deck_size else ""
	)
	var trinket_definition: Dictionary = _trinkets.get(reward.trinket_id, {})
	var trinket_details := ""
	if reward.trinket_offered:
		trinket_details = "%s [%s]\n%s" % [
			_services.t(str(trinket_definition.get("name_key", reward.trinket_id))),
			_services.t("trinket.rarity.%s" % str(trinket_definition.get("rarity", "common"))),
			_services.t(str(trinket_definition.get("effect_key", "")))
		]
	_add_reward_row(
		"TrinketReward",
		"reward.new_trinket",
		reward.trinket_offered,
		reward.trinket_claimed,
		reward.trinket_skipped,
		_claim_or_replace_trinket,
		func() -> void: trinket_skipped.emit(),
		true,
		trinket_details
	)
	_add_reward_row(
		"CardChoiceReward",
		"reward.card_choice",
		reward.card_choice_offered,
		reward.chosen_card_id > 0,
		reward.card_choice_skipped,
		func() -> void: card_choice_open_requested.emit(),
		func() -> void: card_choice_skipped.emit(),
		true,
		_services.t("reward.card_choice_warning") if reward.card_choice_offered else ""
	)


func _add_reward_row(
	node_name: String,
	title_key: String,
	offered: bool,
	claimed: bool,
	skipped: bool,
	claim_action: Callable,
	skip_action: Callable,
	claim_enabled: bool,
	details: String
) -> void:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#101a2a"), Color("#40516d"), 1))
	_content.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var description := Label.new()
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 17)
	var state_text: String = _services.t("reward.not_offered")
	if offered:
		state_text = _services.t("reward.claimed") if claimed else (
			_services.t("reward.skipped") if skipped else _services.t("reward.available")
		)
	description.text = "%s\n%s%s" % [
		_services.t(title_key),
		state_text,
		"\n%s" % details if not details.is_empty() else ""
	]
	row.add_child(description)
	if offered and not claimed and not skipped:
		var claim := Button.new()
		claim.name = "%sClaimButton" % node_name
		claim.text = _services.t("reward.claim")
		claim.disabled = not claim_enabled
		claim.custom_minimum_size = Vector2(110, 42)
		claim.pressed.connect(claim_action)
		row.add_child(claim)
		var skip := Button.new()
		skip.name = "%sSkipButton" % node_name
		skip.text = _services.t("reward.skip")
		skip.custom_minimum_size = Vector2(110, 42)
		skip.pressed.connect(skip_action)
		row.add_child(skip)


func _open_remove_cards() -> void:
	_view = View.REMOVE_CARD
	render()


func _render_remove_cards() -> void:
	_add_subpage_header("reward.remove_card", true)
	if _run.deck.cards.size() <= _run.minimum_deck_size:
		_add_message("reward.minimum_deck")
		return
	var grid := GridContainer.new()
	grid.name = "RemoveCardGrid"
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_content.add_child(grid)
	for card in CardDisplayOrder.descending(_run.deck.cards):
		var button := _card_button(card)
		button.pressed.connect(func() -> void:
			_pending_remove_id = card.instance_id
			_view = View.CONFIRM_REMOVE
			render()
		)
		grid.add_child(button)


func _render_remove_confirmation() -> void:
	_add_subpage_header("reward.confirm_removal", false)
	_add_message("reward.irreversible")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	_content.add_child(row)
	var confirm := Button.new()
	confirm.name = "ConfirmCardRemovalButton"
	confirm.text = _services.t("reward.confirm_removal")
	confirm.pressed.connect(func() -> void: remove_card_confirmed.emit(_pending_remove_id))
	row.add_child(confirm)
	var cancel := Button.new()
	cancel.name = "CancelCardRemovalButton"
	cancel.text = _services.t("battle.cancel")
	cancel.pressed.connect(func() -> void:
		_view = View.REMOVE_CARD
		render()
	)
	row.add_child(cancel)


func _claim_or_replace_trinket() -> void:
	if _run.trinket_ids.size() < _run.trinket_slots:
		trinket_claim_requested.emit("")
	else:
		_view = View.REPLACE_TRINKET
		render()


func _render_trinket_replacement() -> void:
	_add_subpage_header("reward.replace_trinket", true)
	_add_message("reward.choose_replacement")
	for owned_id in _run.trinket_ids:
		var definition: Dictionary = _trinkets.get(owned_id, {})
		var button := Button.new()
		button.name = "ReplaceTrinket_%s" % owned_id
		button.text = "%s — %s" % [
			_services.t(str(definition.get("name_key", owned_id))),
			_services.t(str(definition.get("effect_key", "")))
		]
		button.pressed.connect(func() -> void: trinket_claim_requested.emit(owned_id))
		_content.add_child(button)


func _render_card_choice(reward: RewardState) -> void:
	_add_subpage_header("reward.card_choice", false)
	_add_message("reward.must_choose")
	var row := HBoxContainer.new()
	row.name = "CardCandidateRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	_content.add_child(row)
	for candidate in reward.card_candidates:
		var card := _run.deck.card_from_spec(
			int(candidate.get("rank", 0)),
			int(candidate.get("suit", -1)),
			int(candidate.get("instance_id", 0))
		)
		if card == null:
			continue
		var button := _card_button(card)
		button.name = "CardCandidate_%d" % card.instance_id
		button.pressed.connect(func() -> void: card_chosen.emit(card.instance_id))
		row.add_child(button)


func _add_subpage_header(title_key: String, allow_back: bool) -> void:
	var row := HBoxContainer.new()
	_content.add_child(row)
	var title := Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 23)
	title.text = _services.t(title_key)
	row.add_child(title)
	if allow_back:
		var back := Button.new()
		back.name = "RewardBackButton"
		back.text = _services.t("settings.back")
		back.pressed.connect(func() -> void:
			_view = View.OVERVIEW
			render()
		)
		row.add_child(back)


func _add_message(key: String) -> void:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = _services.t(key)
	_content.add_child(label)


func _card_button(card: CardData) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(96, 116)
	button.text = "%s\n%s" % [card.rank_label, card.suit_symbol]
	button.tooltip_text = _services.t("card.tooltip", [
		_services.t(card.suit_name), card.rank_label, card.rank
	])
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", card.suit_color)
	button.set_meta("card_data", card)
	return button


func _clear_content() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()


func _on_language_changed(_language_code: String) -> void:
	if visible:
		render()


func _panel_style(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style
