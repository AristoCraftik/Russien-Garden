extends Control

@onready var settings: Node = $SettingsPanelContainer
@onready var discord_button: Button = $MarginContainer/SocialPanelContainer/MarginContainer/VBoxContainer/HBoxContainer/DiscordButton
@onready var telegram_button: Button = $MarginContainer/SocialPanelContainer/MarginContainer/VBoxContainer/HBoxContainer/TelegramButton
@onready var youtube_button: Button = $MarginContainer/SocialPanelContainer/MarginContainer/VBoxContainer/HBoxContainer/YouTubeButton
@onready var redit_button: Button = $MarginContainer/SocialPanelContainer/MarginContainer/VBoxContainer/HBoxContainer/ReditButton
@onready var tiktok_button: Button = $MarginContainer/SocialPanelContainer/MarginContainer/VBoxContainer/HBoxContainer/TikTokButton

const SOCIAL_URL: String = "https://t.me/sanchezavropod"

var settings_is_opened: bool = false


func _ready() -> void:
	add_to_group("i18n")
	_apply_i18n()
	_connect_social_buttons()


func _connect_social_buttons() -> void:
	var buttons: Array = [discord_button, telegram_button, youtube_button, redit_button, tiktok_button]
	for b in buttons:
		if b == null:
			continue
		if not b.button_up.is_connected(_on_social_button_button_up):
			b.button_up.connect(_on_social_button_button_up)


func _on_social_button_button_up() -> void:
	OS.shell_open(SOCIAL_URL)


func _apply_i18n() -> void:
	var title: Label = $MarginContainer/MainPanelContainer/MarginContainer/VBoxContainer/Label
	if title:
		title.text = tr("MENU_TITLE")

	var start_btn: Button = $MarginContainer/MainPanelContainer/MarginContainer/VBoxContainer/VBoxContainer/StartGameButton
	if start_btn:
		start_btn.text = tr("MENU_START_GAME")
	var load_btn: Button = $MarginContainer/MainPanelContainer/MarginContainer/VBoxContainer/VBoxContainer/LoadGameButton
	if load_btn:
		load_btn.text = tr("MENU_LOAD_GAME")
	var collection_btn: Button = $MarginContainer/MainPanelContainer/MarginContainer/VBoxContainer/VBoxContainer/CollectionButton
	if collection_btn:
		collection_btn.text = tr("MENU_COLLECTION")
	var settings_btn: Button = $MarginContainer/MainPanelContainer/MarginContainer/VBoxContainer/VBoxContainer/SettingsButton
	if settings_btn:
		settings_btn.text = tr("MENU_SETTINGS")
	var quit_btn: Button = $MarginContainer/MainPanelContainer/MarginContainer/VBoxContainer/VBoxContainer/QuitButton
	if quit_btn:
		quit_btn.text = tr("MENU_QUIT")

	var social_lbl: Label = $MarginContainer/SocialPanelContainer/MarginContainer/VBoxContainer/Label
	if social_lbl:
		social_lbl.text = tr("MENU_SOCIAL")


func _on_start_game_button_button_up() -> void:
	FadeManager.start_mode = "new"
	FadeManager.change_scene_with_fade("res://scenes/game.tscn", 0.5, 0.5, "Day 0")


func _on_load_game_button_button_up() -> void:
	var save: Dictionary = TimeManager.load_game()
	if save.is_empty():
		# Нет сейва — стартуем как новую игру, без падения.
		FadeManager.start_mode = "new"
		FadeManager.change_scene_with_fade("res://scenes/game.tscn", 0.5, 0.5, "Day 0")
		return
	FadeManager.start_mode = "load"
	var day: int = int(save.get("day", 0))
	FadeManager.change_scene_with_fade("res://scenes/game.tscn", 0.5, 0.5, "Day " + str(day))


func _on_settings_button_button_up() -> void:
	switch_settings()


func switch_settings() -> void:
	if settings_is_opened:
		settings_is_opened = false
		settings.close_settings()
	else:
		settings_is_opened = true
		settings.open()
