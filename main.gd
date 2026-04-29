extends Control

func _on_start_game_button_button_up() -> void:
	FadeManager.change_scene_with_fade("res://scenes/field.tscn")
