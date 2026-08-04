extends Control

const BATTLE_SCENE := preload("res://scenes/battle_screen.tscn")

var persist_language_changes := true
var _services: Node
var _menu_layer: Control
var _settings_layer: ColorRect
var _title_label: Label
var _subtitle_label: Label
var _start_button: Button
var _settings_button: Button
var _quit_button: Button
var _settings_title: Label
var _language_label: Label
var _english_button: Button
var _chinese_button: Button
var _back_button: Button


func _ready() -> void:
	_services = get_node("/root/AppServices")
	_build_interface()
	_services.language_changed.connect(_on_language_changed)
	_apply_localization()


func _build_interface() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#0e1625")
	add_child(background)

	var accent := ColorRect.new()
	accent.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	accent.color = Color(0.22, 0.12, 0.22, 0.28)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(accent)

	_menu_layer = CenterContainer.new()
	_menu_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_menu_layer)

	var menu_card := PanelContainer.new()
	menu_card.custom_minimum_size = Vector2(520, 470)
	menu_card.add_theme_stylebox_override(
		"panel",
		_panel_style(Color("#172235"), Color("#d5ae58"), 2)
	)
	_menu_layer.add_child(menu_card)

	var menu := VBoxContainer.new()
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.add_theme_constant_override("separation", 16)
	menu_card.add_child(menu)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 43)
	_title_label.add_theme_color_override("font_color", Color("#f3d98b"))
	menu.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 18)
	_subtitle_label.add_theme_color_override("font_color", Color("#9eabc0"))
	menu.add_child(_subtitle_label)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 20
	menu.add_child(spacer)

	_start_button = _menu_button("StartGameButton")
	_start_button.pressed.connect(_start_game)
	menu.add_child(_start_button)

	_settings_button = _menu_button("SettingsButton")
	_settings_button.pressed.connect(_open_settings)
	menu.add_child(_settings_button)

	_quit_button = _menu_button("QuitButton")
	_quit_button.pressed.connect(func() -> void: get_tree().quit())
	menu.add_child(_quit_button)

	_build_settings_layer()


func _build_settings_layer() -> void:
	_settings_layer = ColorRect.new()
	_settings_layer.name = "SettingsLayer"
	_settings_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_layer.color = Color(0.02, 0.03, 0.05, 0.92)
	_settings_layer.visible = false
	add_child(_settings_layer)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_layer.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(520, 410)
	card.add_theme_stylebox_override(
		"panel",
		_panel_style(Color("#172235"), Color("#5d7ca5"), 2)
	)
	center.add_child(card)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 18)
	card.add_child(content)

	_settings_title = Label.new()
	_settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settings_title.add_theme_font_size_override("font_size", 34)
	_settings_title.add_theme_color_override("font_color", Color("#f3d98b"))
	content.add_child(_settings_title)

	_language_label = Label.new()
	_language_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_language_label.add_theme_font_size_override("font_size", 19)
	_language_label.add_theme_color_override("font_color", Color("#b8c6dc"))
	content.add_child(_language_label)

	_english_button = _menu_button("LanguageEnglishButton")
	_english_button.pressed.connect(func() -> void:
		_services.set_language("en", persist_language_changes)
	)
	content.add_child(_english_button)

	_chinese_button = _menu_button("LanguageChineseButton")
	_chinese_button.pressed.connect(func() -> void:
		_services.set_language("zh_CN", persist_language_changes)
	)
	content.add_child(_chinese_button)

	_back_button = _menu_button("SettingsBackButton")
	_back_button.pressed.connect(_close_settings)
	content.add_child(_back_button)


func _start_game() -> void:
	_menu_layer.visible = false
	var battle := BATTLE_SCENE.instantiate()
	battle.name = "ActiveBattle"
	add_child(battle)


func _open_settings() -> void:
	_settings_layer.visible = true


func _close_settings() -> void:
	_settings_layer.visible = false


func _on_language_changed(_language_code: String) -> void:
	_apply_localization()


func _apply_localization() -> void:
	_title_label.text = _services.t("app.title")
	_subtitle_label.text = _services.t("app.subtitle")
	_start_button.text = _services.t("menu.start_game")
	_settings_button.text = _services.t("menu.settings")
	_quit_button.text = _services.t("menu.quit")
	_settings_title.text = _services.t("settings.title")
	_language_label.text = _services.t("settings.language")
	_english_button.text = _services.t("settings.english")
	_chinese_button.text = _services.t("settings.chinese")
	_back_button.text = _services.t("settings.back")


func _menu_button(node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.custom_minimum_size = Vector2(280, 48)
	button.add_theme_font_size_override("font_size", 18)
	return button


func _panel_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 34
	style.content_margin_right = 34
	style.content_margin_top = 30
	style.content_margin_bottom = 30
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	style.shadow_size = 12
	return style
