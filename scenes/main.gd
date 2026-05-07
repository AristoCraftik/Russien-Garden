extends Control

@onready var settings: Node = $SettingsPanelContainer

var settings_is_opened: bool = false


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

