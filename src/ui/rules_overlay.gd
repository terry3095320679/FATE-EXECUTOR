class_name RulesOverlay
extends ColorRect

signal closed

const HAND_IDS: Array[StringName] = [
	&"high_card",
	&"pair",
	&"two_pair",
	&"three_of_a_kind",
	&"straight",
	&"flush",
	&"full_house",
	&"four_of_a_kind",
	&"straight_flush"
]

var _services: Node
var _panel: PanelContainer
var _title_label: Label
var _close_button: Button
var _back_button: Button
var _content: VBoxContainer
var _localized_labels: Array[Label] = []


func configure(services: Node) -> void:
	_services = services
	name = "RulesOverlay"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0.01, 0.015, 0.025, 0.88)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	gui_input.connect(_on_overlay_input)
	_build_interface()
	apply_localization()


func show_rules() -> void:
	apply_localization()
	visible = true
	_close_button.grab_focus()


func hide_rules() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func apply_localization() -> void:
	if _services == null:
		return
	for label in _localized_labels:
		label.text = _services.t(str(label.get_meta("localization_key")))
	_close_button.text = _services.t("common.close")
	_back_button.text = _services.t("settings.back")


func hand_entry_count() -> int:
	var entries := find_child("RulesHandEntries", true, false)
	return entries.get_child_count() if entries != null else 0


func _build_interface() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.name = "RulesPanel"
	_panel.custom_minimum_size = Vector2(1080, 650)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override(
		"panel",
		_panel_style(Color("#172235"), Color("#7586a3"), 2, 20)
	)
	center.add_child(_panel)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	_panel.add_child(page)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	_title_label = _localized_label(header, "rules.title", 28, Color("#f3d98b"))
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_close_button = Button.new()
	_close_button.name = "RulesCloseButton"
	_close_button.custom_minimum_size = Vector2(110, 40)
	_close_button.pressed.connect(hide_rules)
	header.add_child(_close_button)
	page.add_child(header)

	var divider := HSeparator.new()
	page.add_child(divider)

	var scroll := ScrollContainer.new()
	scroll.name = "RulesScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)

	_content = VBoxContainer.new()
	_content.name = "RulesContent"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	scroll.add_child(_content)

	_add_section("CardValues", "rules.card_values", "rules.card_values.body")
	_add_section("PlayingCards", "rules.playing_cards", "rules.playing_cards.body")

	var poker_heading := _localized_label(
		_content,
		"rules.poker_hands",
		24,
		Color("#f3d98b")
	)
	poker_heading.name = "RulesPokerHandsHeading"
	var hand_entries := VBoxContainer.new()
	hand_entries.name = "RulesHandEntries"
	hand_entries.add_theme_constant_override("separation", 8)
	_content.add_child(hand_entries)
	for hand_id in HAND_IDS:
		_add_hand_entry(hand_entries, hand_id)

	_add_section("Damage", "rules.damage", "rules.damage.body")

	_back_button = Button.new()
	_back_button.name = "RulesBackButton"
	_back_button.custom_minimum_size = Vector2(150, 42)
	_back_button.pressed.connect(hide_rules)
	page.add_child(_back_button)


func _add_section(section_id: String, title_key: String, body_key: String) -> void:
	var section := PanelContainer.new()
	section.name = "RulesSection_%s" % section_id
	section.set_meta("title_key", title_key)
	section.set_meta("body_key", body_key)
	section.add_theme_stylebox_override(
		"panel",
		_panel_style(Color("#101a2a"), Color("#33445f"), 1, 14)
	)
	_content.add_child(section)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	section.add_child(content)
	_localized_label(content, title_key, 21, Color("#b9d6ff"))
	var body := _localized_label(content, body_key, 15, Color("#d6deea"))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _add_hand_entry(parent: VBoxContainer, hand_id: StringName) -> void:
	var entry := PanelContainer.new()
	entry.name = "RulesHand_%s" % hand_id
	entry.set_meta("hand_id", hand_id)
	entry.add_theme_stylebox_override(
		"panel",
		_panel_style(Color("#151f30"), Color("#40516c"), 1, 12)
	)
	parent.add_child(entry)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	entry.add_child(content)
	_localized_label(content, "hand.%s" % hand_id, 19, Color("#e8c873"))
	var body := _localized_label(
		content,
		"rules.hand.%s" % hand_id,
		14,
		Color("#d6deea")
	)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _localized_label(
	parent: Node,
	key: String,
	font_size: int,
	font_color: Color
) -> Label:
	var label := Label.new()
	label.set_meta("localization_key", key)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	parent.add_child(label)
	_localized_labels.append(label)
	return label


func _on_overlay_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
		and not _panel.get_global_rect().has_point(event.global_position)
	):
		hide_rules()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide_rules()
		get_viewport().set_input_as_handled()


func _panel_style(
	background: Color,
	border: Color,
	border_width: int,
	content_margin: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(10)
	style.content_margin_left = content_margin
	style.content_margin_right = content_margin
	style.content_margin_top = content_margin
	style.content_margin_bottom = content_margin
	return style
