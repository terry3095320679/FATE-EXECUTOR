class_name SpecialNodeOverlay
extends ColorRect

signal shop_remove_confirmed(instance_id: int)
signal shop_card_purchase_requested
signal shop_card_chosen(instance_id: int)
signal shop_heal_requested
signal shop_trinket_requested(trinket_id: String, replace_id: String)
signal shop_trinket_replacement_cancelled
signal shop_leave_requested
signal fountain_continue_requested
signal treasure_open_requested
signal treasure_skip_requested
signal treasure_trinket_requested(trinket_id: String, replace_id: String)

enum View {
	MAIN,
	SHOP_REMOVE,
	SHOP_REMOVE_CONFIRM,
	SHOP_CARD_CHOICE,
	SHOP_TRINKET_REPLACE,
	TREASURE_CHOICE,
	TREASURE_REPLACE
}

var _services: Node
var _run: RunState
var _flow: RefCounted
var _node_type := ""
var _view := View.MAIN
var _pending_remove_id := 0
var _title: Label
var _status: Label
var _content: VBoxContainer


func _init() -> void:
	name = "SpecialNodeOverlay"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0.015, 0.02, 0.035, 0.97)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func configure(services: Node, run: RunState, flow: RefCounted) -> void:
	_services = services
	_run = run
	_flow = flow
	if _services != null and not _services.language_changed.is_connected(_on_language_changed):
		_services.language_changed.connect(_on_language_changed)


func show_node(node_type: String) -> void:
	_node_type = node_type
	_view = View.MAIN
	if node_type == "shop" and _run.shop_state != null and _run.shop_state.must_choose_card:
		_view = View.SHOP_CARD_CHOICE
	if node_type == "shop" and _run.shop_state != null and not _run.shop_state.pending_trinket_id.is_empty():
		_view = View.SHOP_TRINKET_REPLACE
	if node_type == "treasure" and _run.treasure_state != null and _run.treasure_state.must_choose:
		_view = View.TREASURE_REPLACE if not _run.treasure_state.pending_trinket_id.is_empty() else View.TREASURE_CHOICE
	visible = true
	render()


func hide_node() -> void:
	visible = false
	_node_type = ""


func return_to_main() -> void:
	_view = View.MAIN
	_pending_remove_id = 0
	render()


func show_shop_card_choice() -> void:
	_view = View.SHOP_CARD_CHOICE
	render()


func show_shop_trinket_replacement() -> void:
	_view = View.SHOP_TRINKET_REPLACE
	render()


func show_treasure_choice() -> void:
	_view = View.TREASURE_CHOICE
	render()


func show_treasure_replacement() -> void:
	_view = View.TREASURE_REPLACE
	render()


func render() -> void:
	if _services == null or _run == null:
		return
	_clear_content()
	_status.text = _services.t("run.status", [_run.gold, _run.player_health, _run.player_max_health])
	match _node_type:
		"shop":
			_title.text = _services.t("node.shop")
			_render_shop()
		"fountain":
			_title.text = _services.t("node.fountain")
			_render_fountain()
		"treasure":
			_title.text = _services.t("node.treasure")
			_render_treasure()


func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1100, 660)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#152136"), Color("#7189ad"), 2))
	center.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	panel.add_child(layout)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 32)
	_title.add_theme_color_override("font_color", Color("#f3d98b"))
	layout.add_child(_title)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 17)
	layout.add_child(_status)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	scroll.add_child(_content)


func _render_shop() -> void:
	if _run.shop_state == null:
		return
	match _view:
		View.SHOP_REMOVE:
			_render_shop_remove_cards()
		View.SHOP_REMOVE_CONFIRM:
			_render_shop_remove_confirm()
		View.SHOP_CARD_CHOICE:
			_render_card_candidates(_run.shop_state.card_candidates, true)
		View.SHOP_TRINKET_REPLACE:
			_render_owned_replacements(true)
		_:
			_render_shop_main()


func _render_shop_main() -> void:
	var shop := _run.shop_state
	var services_panel := HBoxContainer.new()
	services_panel.name = "ShopServices"
	services_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	services_panel.add_theme_constant_override("separation", 12)
	_content.add_child(services_panel)
	services_panel.add_child(_shop_service_button(
		"ShopRemoveCardButton", "shop.remove_card", "remove_card",
		shop.removal_uses_remaining,
		shop.removal_uses_remaining > 0 and _run.deck.cards.size() > _run.minimum_deck_size,
		func() -> void: _view = View.SHOP_REMOVE; render()
	))
	services_panel.add_child(_shop_service_button(
		"ShopBuyCardButton", "shop.buy_card", "buy_card",
		shop.card_purchase_uses_remaining,
		shop.card_purchase_uses_remaining > 0,
		func() -> void: shop_card_purchase_requested.emit()
	))
	services_panel.add_child(_shop_service_button(
		"ShopHealButton", "shop.restore_health", "heal",
		shop.heal_uses_remaining,
		shop.heal_uses_remaining > 0 and _run.player_health < _run.player_max_health,
		func() -> void: shop_heal_requested.emit()
	))

	var heading := Label.new()
	heading.text = _services.t("shop.trinkets")
	heading.add_theme_font_size_override("font_size", 22)
	_content.add_child(heading)
	var grid := GridContainer.new()
	grid.name = "ShopTrinketGrid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_content.add_child(grid)
	for trinket_id in shop.trinket_inventory:
		grid.add_child(_shop_trinket_button(trinket_id))
	var leave := Button.new()
	leave.name = "LeaveShopButton"
	leave.text = _services.t("shop.leave")
	leave.custom_minimum_size = Vector2(210, 44)
	leave.pressed.connect(func() -> void: shop_leave_requested.emit())
	_content.add_child(leave)


func _shop_service_button(
	node_name: String,
	label_key: String,
	price_key: String,
	uses: int,
	available: bool,
	action: Callable
) -> Button:
	var price := int(_run.shop_state.price_snapshot.get(price_key, 1))
	var button := Button.new()
	button.name = node_name
	button.custom_minimum_size = Vector2(290, 105)
	button.text = "%s\n%s\n%s" % [
		_services.t(label_key),
		_services.t("shop.price", [price]),
		_services.t("shop.uses_remaining", [uses])
	]
	button.disabled = not available or _run.gold < price
	button.tooltip_text = _shortage_tooltip(price, available)
	button.pressed.connect(action)
	return button


func _shop_trinket_button(trinket_id: String) -> Button:
	var shop := _run.shop_state
	var definition: Dictionary = _flow.trinket_definition(trinket_id)
	var price := int(shop.price_snapshot.get("trinket:%s" % trinket_id, 1))
	var sold := bool(shop.purchased_items.get(trinket_id, false))
	var button := Button.new()
	button.name = "ShopTrinket_%s" % trinket_id
	button.custom_minimum_size = Vector2(320, 120)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.text = "%s\n%s\n%s%s" % [
		_services.t(str(definition.get("name_key", trinket_id))),
		_services.t(str(definition.get("effect_key", ""))),
		_services.t("shop.price", [price]),
		" — %s" % _services.t("shop.sold") if sold else ""
	]
	button.disabled = sold or _run.gold < price
	button.tooltip_text = _shortage_tooltip(price, not sold)
	button.pressed.connect(func() -> void: shop_trinket_requested.emit(trinket_id, ""))
	return button


func _render_shop_remove_cards() -> void:
	_add_back_header("shop.remove_card")
	var grid := GridContainer.new()
	grid.name = "ShopRemoveCardGrid"
	grid.columns = 8
	_content.add_child(grid)
	for card in CardDisplayOrder.descending(_run.deck.cards):
		var button := _card_button(card)
		button.pressed.connect(func() -> void:
			_pending_remove_id = card.instance_id
			_view = View.SHOP_REMOVE_CONFIRM
			render()
		)
		grid.add_child(button)


func _render_shop_remove_confirm() -> void:
	_add_message("reward.irreversible")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(row)
	var confirm := Button.new()
	confirm.name = "ShopConfirmRemovalButton"
	confirm.text = _services.t("reward.confirm_removal")
	confirm.pressed.connect(func() -> void: shop_remove_confirmed.emit(_pending_remove_id))
	row.add_child(confirm)
	var cancel := Button.new()
	cancel.name = "ShopCancelRemovalButton"
	cancel.text = _services.t("battle.cancel")
	cancel.pressed.connect(func() -> void: _view = View.SHOP_REMOVE; render())
	row.add_child(cancel)


func _render_card_candidates(candidates: Array[Dictionary], is_shop: bool) -> void:
	_add_message("reward.must_choose")
	var row := HBoxContainer.new()
	row.name = "ShopCardCandidateRow" if is_shop else "CardCandidateRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(row)
	for candidate in candidates:
		var card := _run.deck.card_from_spec(
			int(candidate.get("rank", 0)), int(candidate.get("suit", -1)), int(candidate.get("instance_id", 0))
		)
		if card == null:
			continue
		var button := _card_button(card)
		button.name = "ShopCardCandidate_%d" % card.instance_id
		button.pressed.connect(func() -> void: shop_card_chosen.emit(card.instance_id))
		row.add_child(button)


func _render_owned_replacements(is_shop: bool) -> void:
	_add_message("shop.choose_replacement")
	for owned_id in _run.trinket_ids:
		var definition: Dictionary = _flow.trinket_definition(owned_id)
		var button := Button.new()
		button.name = "NodeReplaceTrinket_%s" % owned_id
		button.text = "%s — %s" % [
			_services.t(str(definition.get("name_key", owned_id))),
			_services.t(str(definition.get("effect_key", "")))
		]
		button.pressed.connect(func() -> void:
			if is_shop:
				shop_trinket_requested.emit(_run.shop_state.pending_trinket_id, owned_id)
			else:
				treasure_trinket_requested.emit(_run.treasure_state.pending_trinket_id, owned_id)
		)
		_content.add_child(button)
	if is_shop:
		var cancel := Button.new()
		cancel.name = "CancelShopTrinketReplacementButton"
		cancel.text = _services.t("battle.cancel")
		cancel.pressed.connect(func() -> void: shop_trinket_replacement_cancelled.emit())
		_content.add_child(cancel)


func _render_fountain() -> void:
	var resolution: Dictionary = _run.node_state.resolution
	_add_message("fountain.restored")
	var details := Label.new()
	details.name = "FountainResultLabel"
	details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details.add_theme_font_size_override("font_size", 21)
	details.text = _services.t("fountain.result", [
		int(resolution.get("health_before", _run.player_health)),
		int(resolution.get("health_restored", 0)),
		int(resolution.get("health_after", _run.player_health))
	])
	_content.add_child(details)
	var button := Button.new()
	button.name = "FountainContinueButton"
	button.text = _services.t("reward.continue")
	button.pressed.connect(func() -> void: fountain_continue_requested.emit())
	_content.add_child(button)


func _render_treasure() -> void:
	var treasure := _run.treasure_state
	match _view:
		View.TREASURE_CHOICE:
			_add_message("treasure.choose_three")
			_render_treasure_candidates(treasure.candidates)
		View.TREASURE_REPLACE:
			_render_owned_replacements(false)
		_:
			_add_message("treasure.description")
			var open := Button.new()
			open.name = "OpenTreasureButton"
			open.text = _services.t("treasure.open")
			open.pressed.connect(func() -> void: treasure_open_requested.emit())
			_content.add_child(open)
			var leave := Button.new()
			leave.name = "LeaveTreasureButton"
			leave.text = _services.t("treasure.leave")
			leave.pressed.connect(func() -> void: treasure_skip_requested.emit())
			_content.add_child(leave)


func _render_treasure_candidates(candidates: Array[String]) -> void:
	var row := HBoxContainer.new()
	row.name = "TreasureCandidateRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(row)
	for trinket_id in candidates:
		var definition: Dictionary = _flow.trinket_definition(trinket_id)
		var button := Button.new()
		button.name = "TreasureTrinket_%s" % trinket_id
		button.custom_minimum_size = Vector2(300, 180)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = "%s\n\n%s" % [
			_services.t(str(definition.get("name_key", trinket_id))),
			_services.t(str(definition.get("effect_key", "")))
		]
		button.pressed.connect(func() -> void: treasure_trinket_requested.emit(trinket_id, ""))
		row.add_child(button)


func _add_back_header(key: String) -> void:
	var row := HBoxContainer.new()
	_content.add_child(row)
	var label := Label.new()
	label.text = _services.t(key)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var back := Button.new()
	back.name = "SpecialNodeBackButton"
	back.text = _services.t("settings.back")
	back.pressed.connect(func() -> void: return_to_main())
	row.add_child(back)


func _add_message(key: String) -> void:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 19)
	label.text = _services.t(key)
	_content.add_child(label)


func _card_button(card: CardData) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(92, 112)
	button.text = "%s\n%s" % [card.rank_label, card.suit_symbol]
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_color_override("font_color", card.suit_color)
	button.set_meta("card_data", card)
	return button


func _shortage_tooltip(price: int, available: bool) -> String:
	if not available:
		return _services.t("shop.unavailable")
	if _run.gold < price:
		return _services.t("shop.missing_gold", [price - _run.gold])
	return ""


func _clear_content() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()


func _on_language_changed(_language_code: String) -> void:
	if visible:
		render()


func _panel_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(12)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style
