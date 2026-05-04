extends Control

func fly_item_to_slot(slot_index: int, plant_data: PlantData) -> void:
	var tab_container = $MarginContainer/TabContainer
	var seeds_tab = tab_container.get_node("Seeds")
	
	if slot_index >= seeds_tab.get_child_count(): return
	var slot = seeds_tab.get_child(slot_index)
	if slot.get_child_count() > 0: return
	
	var fly_item = TextureRect.new()
	fly_item.texture = plant_data.seed_texture
	fly_item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fly_item.size = Vector2i(32, 32)
	fly_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly_item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	add_child(fly_item)
	
	var screen_center_global = get_viewport().get_visible_rect().size / 2.0
	var screen_center_local = screen_center_global - global_position
	var start_pos = screen_center_local - fly_item.size / 2.0
	
	var slot_global = slot.global_position
	var target_pos = slot_global - global_position + slot.size / 2.0 - fly_item.size / 2.0
	
	fly_item.position = start_pos
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(fly_item, "position", target_pos, 0.5)
	
	tween.tween_callback(func():
		fly_item.queue_free()
		
		var item = TextureRect.new()
		item.texture = plant_data.seed_texture
		item.size = Vector2i(32, 32)
		
		item.mouse_filter = Control.MOUSE_FILTER_STOP
		item.stretch_mode = TextureRect.STRETCH_SCALE
		
		var drag_script = load("res://scenes/ui/item.gd")
		if drag_script:
			item.set_script(drag_script)
			item.set_plant_data(plant_data)
		
		slot.add_child(item)
	)
