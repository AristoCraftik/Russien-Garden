extends Control

func _ready() -> void:
	add_to_group("inventory")

# --- Базовые функции инвентаря ---

func fly_item_to_slot(slot_index: int, plant_data: PlantData) -> void:
	var slots = $MarginContainer/TextureRect/Slots
	
	if slot_index >= slots.get_child_count(): return
	var slot = slots.get_child(slot_index)
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
		
		# Центрируем в слоте (хотя здесь без якорей, просто позиция)
		item.position = (slot.size - item.size) / 2.0
	)

func get_first_empty_slot_index() -> int:
	var slots = $MarginContainer/TextureRect/Slots
	for i in range(slots.get_child_count()):
		if slots.get_child(i).get_child_count() == 0:
			return i
	return -1

func get_slots_container() -> Node:
	return $MarginContainer/TextureRect/Slots

# --- Сбор данных о предметах ---

func get_all_items() -> Array:
	var items = []
	var slots = get_slots_container()
	for slot in slots.get_children():
		if slot.get_child_count() > 0:
			var item = slot.get_child(0)
			if item is TextureRect and item.has_method("get_plant_data"):
				items.append(item)
	return items

func get_item_data(item: TextureRect) -> PlantData:
	if item.has_method("get_plant_data"):
		return item.get_plant_data()
	return null

# --- Сортировка (публичные методы, вызываются кнопками) ---

func sort_by_type() -> void:
	var items = get_all_items()
	items.sort_custom(func(a, b):
		var da = get_item_data(a)
		var db = get_item_data(b)
		if not da or not db: return false
		return da.type < db.type
	)
	_animate_sort(items)

func sort_by_name() -> void:
	var items = get_all_items()
	items.sort_custom(func(a, b):
		var da = get_item_data(a)
		var db = get_item_data(b)
		if not da or not db: return false
		return da.plant_name.nocasecmp_to(db.plant_name) < 0
	)
	_animate_sort(items)

# --- Анимированное перемещение предметов по новым слотам ---

func _animate_sort(sorted_items: Array) -> void:
	var slots = get_slots_container()
	
	# Запоминаем начальные позиции (центры слотов) и удаляем предметы из слотов
	var start_positions = {}
	for item in sorted_items:
		var old_slot = item.get_parent()
		if old_slot:
			start_positions[item] = old_slot.global_position + old_slot.size / 2.0
			old_slot.remove_child(item)
			# Временно кладём предмет в этот же Inventory для анимации
			add_child(item)
			item.global_position = start_positions[item] - item.size / 2.0
			item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Для каждого предмета создаём свой твин
	for i in range(sorted_items.size()):
		if i >= slots.get_child_count():
			break
		var item = sorted_items[i]
		var target_slot = slots.get_child(i)
		var target_global = target_slot.global_position + target_slot.size / 2.0
		var target_local_pos = target_global - item.size / 2.0
		
		var item_tween = create_tween()
		item_tween.set_ease(Tween.EASE_OUT)
		item_tween.set_trans(Tween.TRANS_BACK)
		item_tween.tween_property(item, "global_position", target_local_pos, 0.4)
		
		# По завершении – переносим в целевой слот и настраиваем
		var slot_ref = target_slot
		item_tween.tween_callback(func():
			if item.get_parent():
				item.get_parent().remove_child(item)
			slot_ref.add_child(item)
			item.position = (slot_ref.size - item.size) / 2.0
			item.mouse_filter = Control.MOUSE_FILTER_STOP
		)
	
