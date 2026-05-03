extends Control

func _ready() -> void:
	await get_tree().process_frame
	_spawn_initial_items()

func _spawn_initial_items() -> void:
	var inventory = $CanvasLayer/MarginContainer/Inventory
	if not inventory: return
	
	var texture = preload("res://assets/button_defoult.png")
	
	for i in range(5):
		inventory.fly_item_to_slot(i, texture)
		await get_tree().create_timer(0.5).timeout
