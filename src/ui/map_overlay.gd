class_name MapOverlay
extends ColorRect

signal candidate_selected(index: int)
signal destination_confirmed(index: int)
signal selection_cancelled

var _services: Node
var _state: RefCounted
var _title: Label
var _node_row: HBoxContainer
var _confirmation: PanelContainer
var _confirmation_label: Label
var _confirm_button: Button
var _cancel_button: Button


func _init() -> void:
	name = "MapOverlay"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0.02, 0.025, 0.045, 0.97)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func configure(services: Node, state: RefCounted) -> void:
	_services = services
	_state = state
	if _services != null and not _services.language_changed.is_connected(_on_language_changed):
		_services.language_changed.connect(_on_language_changed)
	render()


func show_map() -> void:
	visible = true
	render()


func hide_map() -> void:
	visible = false


func render() -> void:
	if _services == null or _state == null:
		return
	_title.text = _services.t("map.choose_next")
	for child in _node_row.get_children():
		_node_row.remove_child(child)
		child.queue_free()
	for index in range(_state.candidates.size()):
		_node_row.add_child(_node_button(index, _state.candidates[index]))
	_confirmation.visible = _state.selected_index >= 0 and not _state.selection_confirmed
	if _confirmation.visible:
		var candidate: Dictionary = _state.candidates[_state.selected_index]
		_confirmation_label.text = _services.t("map.confirm_destination_detail", [
			_services.t(str(candidate.get("name_key", "node.battle")))
		])
	_confirm_button.text = _services.t("map.confirm_destination")
	_cancel_button.text = _services.t("battle.cancel")


func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1120, 620)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#142033"), Color("#6f86aa"), 2))
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 24)
	panel.add_child(content)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", Color("#f3d98b"))
	content.add_child(_title)
	_node_row = HBoxContainer.new()
	_node_row.name = "MapNodeRow"
	_node_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_node_row.add_theme_constant_override("separation", 24)
	_node_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_node_row)
	_confirmation = PanelContainer.new()
	_confirmation.name = "DestinationConfirmation"
	_confirmation.add_theme_stylebox_override("panel", _panel_style(Color("#1c2b43"), Color("#d5ae58"), 2))
	content.add_child(_confirmation)
	var confirmation_content := HBoxContainer.new()
	confirmation_content.alignment = BoxContainer.ALIGNMENT_CENTER
	confirmation_content.add_theme_constant_override("separation", 14)
	_confirmation.add_child(confirmation_content)
	_confirmation_label = Label.new()
	_confirmation_label.custom_minimum_size.x = 430
	_confirmation_label.add_theme_font_size_override("font_size", 18)
	confirmation_content.add_child(_confirmation_label)
	_confirm_button = Button.new()
	_confirm_button.name = "ConfirmDestinationButton"
	_confirm_button.custom_minimum_size = Vector2(160, 42)
	_confirm_button.pressed.connect(func() -> void:
		if _state != null and _state.selected_index >= 0:
			destination_confirmed.emit(_state.selected_index)
	)
	confirmation_content.add_child(_confirm_button)
	_cancel_button = Button.new()
	_cancel_button.name = "CancelDestinationButton"
	_cancel_button.custom_minimum_size = Vector2(110, 42)
	_cancel_button.pressed.connect(func() -> void:
		selection_cancelled.emit()
	)
	confirmation_content.add_child(_cancel_button)


func _node_button(index: int, candidate: Dictionary) -> Button:
	var button := Button.new()
	button.name = "MapNodeButton_%d" % index
	button.custom_minimum_size = Vector2(290, 330)
	var danger_key := "map.dangerous" if bool(candidate.get("dangerous", false)) else "map.safe"
	button.text = "%s\n\n%s\n\n%s\n\n%s\n%s" % [
		str(candidate.get("icon", "?")),
		_services.t(str(candidate.get("name_key", "node.battle"))),
		_services.t(str(candidate.get("description_key", ""))),
		_services.t(danger_key),
		_services.t("run.stage", [int(candidate.get("stage", 1))])
	]
	button.add_theme_font_size_override("font_size", 19)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(func() -> void:
		candidate_selected.emit(index)
	)
	return button


func _on_language_changed(_language_code: String) -> void:
	if visible:
		render()


func _panel_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(12)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	return style
