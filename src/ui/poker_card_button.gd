class_name PokerCardButton
extends Button

enum VisualState {
	NORMAL,
	HOVERED,
	SELECTED,
	DISABLED
}

var card_data: CardData
var _is_scoring := false
var _is_unscored := false
var _is_hovered := false
var _services: Node

var _normal_style: StyleBoxFlat
var _hover_style: StyleBoxFlat
var _selected_style: StyleBoxFlat
var _disabled_style: StyleBoxFlat
var _lift_tween: Tween
var _last_visual_selected := false
var _is_face_down := false


func _ready() -> void:
	_services = get_node("/root/AppServices")
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(94, 132)
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 25)
	_build_styles()
	toggled.connect(_on_visual_toggled)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_services.language_changed.connect(_on_language_changed)
	_refresh_style()


func configure(value: CardData) -> void:
	card_data = value
	_is_face_down = false
	text = "%s\n%s" % [card_data.rank_label, card_data.suit_symbol]
	_update_tooltip()
	add_theme_color_override("font_color", card_data.suit_color)
	add_theme_color_override("font_hover_color", card_data.suit_color)
	add_theme_color_override("font_pressed_color", card_data.suit_color)
	add_theme_color_override("font_disabled_color", Color("#777b84"))


func show_card_back() -> void:
	_is_face_down = true
	text = "◆\nFATE"
	tooltip_text = ""
	add_theme_color_override("font_color", Color("#d4b45f"))
	add_theme_color_override("font_hover_color", Color("#d4b45f"))
	add_theme_color_override("font_pressed_color", Color("#d4b45f"))


func show_card_face() -> void:
	if card_data == null:
		return
	configure(card_data)


func set_evaluation_state(is_scoring: bool, is_unscored: bool) -> void:
	_is_scoring = is_scoring
	_is_unscored = is_unscored
	_refresh_style()


func set_interaction_disabled(value: bool) -> void:
	disabled = value
	_refresh_style()


func set_hovered_for_test(value: bool) -> void:
	_is_hovered = value
	_refresh_style()


func freeze_visual_motion() -> void:
	if _lift_tween != null and _lift_tween.is_valid():
		_lift_tween.kill()


func get_visual_state() -> VisualState:
	if disabled:
		return VisualState.DISABLED
	if button_pressed:
		return VisualState.SELECTED
	if _is_hovered:
		return VisualState.HOVERED
	return VisualState.NORMAL


func _build_styles() -> void:
	_normal_style = _make_style(Color("#f4f0e8"), Color("#b7b0a2"), 2)
	_hover_style = _make_style(Color("#fffdf7"), Color("#8fc7e8"), 3, 9)
	_selected_style = _make_style(Color("#fff9e8"), Color("#e7b64b"), 4)
	_disabled_style = _make_style(Color("#c7c5c0"), Color("#777b84"), 2)


func _make_style(
	background: Color,
	border: Color,
	width: int,
	shadow_size: int = 6
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
	style.shadow_size = shadow_size
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _refresh_style() -> void:
	if _normal_style == null:
		return
	var visual_state := get_visual_state()
	var active_style := _normal_style
	match visual_state:
		VisualState.DISABLED:
			active_style = _disabled_style
			modulate = Color(0.38, 0.39, 0.42, 1.0)
		VisualState.SELECTED:
			active_style = _selected_style
			modulate = Color.WHITE
		VisualState.HOVERED:
			active_style = _hover_style
			modulate = Color(0.82, 0.84, 0.88, 1.0)
		_:
			active_style = _normal_style
			modulate = Color(0.48, 0.50, 0.55, 1.0)
	add_theme_stylebox_override("normal", active_style)
	add_theme_stylebox_override(
		"hover",
		_selected_style if visual_state == VisualState.SELECTED else active_style
	)
	add_theme_stylebox_override("pressed", _selected_style)
	add_theme_stylebox_override("focus", active_style)
	add_theme_stylebox_override("disabled", _disabled_style)
	_update_lift(visual_state == VisualState.SELECTED)


func _on_visual_toggled(_is_pressed: bool) -> void:
	_refresh_style()


func _on_mouse_entered() -> void:
	_is_hovered = true
	_refresh_style()


func _on_mouse_exited() -> void:
	_is_hovered = false
	_refresh_style()


func _on_language_changed(_language_code: String) -> void:
	_update_tooltip()


func _update_tooltip() -> void:
	if card_data == null or _is_face_down:
		return
	tooltip_text = _services.t("card.tooltip", [
		_services.t(card_data.suit_name),
		card_data.rank_label,
		card_data.rank
	])


func _update_lift(is_selected: bool) -> void:
	if is_selected == _last_visual_selected:
		return
	_last_visual_selected = is_selected
	if _lift_tween != null and _lift_tween.is_valid():
		_lift_tween.kill()
	var target_y := -14.0 if is_selected else 0.0
	_lift_tween = create_tween()
	_lift_tween.set_trans(Tween.TRANS_QUAD)
	_lift_tween.set_ease(Tween.EASE_OUT)
	_lift_tween.tween_property(self, "position:y", target_y, 0.12)
