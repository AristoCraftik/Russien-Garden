extends Control

func _ready() -> void:
	await get_tree().process_frame
	_spawn_initial_items()

func _spawn_initial_items() -> void:
	var inventory = $CanvasLayer/MarginContainer/Inventory
	if not inventory: return
	
	var carrot_data = preload("res://resources/plants/carrot.tres")
	
	inventory.fly_item_to_slot(0, carrot_data)
