extends Control

@onready var field = $Field
var day_counter = 0

func _ready() -> void:
	if FadeManager.start_mode == "load":
		load_game()
		
	# Ждём, пока весь интерфейс отрисуется
	await get_tree().process_frame
	_spawn_initial_items()

func _spawn_initial_items() -> void:
	var inventory = $CanvasLayer/MarginContainer/Inventory
	if not inventory: return
	var carrot_data = preload("res://resources/plants/carrot.tres")
	var potato_data = preload("res://resources/plants/potato.tres")
	for i in range(0, 10, 2):
		inventory.fly_item_to_slot(i, carrot_data)
		inventory.fly_item_to_slot(i+1, potato_data)


func _on_quit_to_menu_button_button_up() -> void:
	FadeManager.change_scene_with_fade("res://main.tscn", 0.5, 0.5, "Main menu")


func _on_next_day_button_button_up() -> void:
	day_counter += 1
	FadeManager.change_scene_with_fade('', 0.5, 0.5, 'day ' + str(day_counter))
	await get_tree().create_timer(0.5).timeout
	TimeManager.next_day(day_counter)


func load_game():
	var plants = TimeManager.load_game()[0]
	day_counter = TimeManager.load_game()[1]
	for plant in plants:
		field.plant_seed(plant[0], load(str(plant[1])), plant[2])
