extends Control
@onready var settings = $SettingsPanelContainer



var settings_is_opened = 0


func _on_start_game_button_button_up() -> void:
	FadeManager.start_mode = "new"
	FadeManager.change_scene_with_fade("res://scenes/game.tscn")

func _on_settings_button_button_up() -> void:
	switch_settings()
	

func switch_settings():
	if settings_is_opened:
		settings_is_opened = 0
		settings.close_settings()
	else:
		settings_is_opened = 1
		settings.open()


func _on_load_game_button_button_up() -> void:
	FadeManager.start_mode = "load"
	FadeManager.change_scene_with_fade("res://scenes/game.tscn")
