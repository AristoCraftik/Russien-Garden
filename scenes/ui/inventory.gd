extends Control

@onready var slots: GridContainer = $MarginContainer/VBoxContainer/Panel/Slots
@onready var sort_type_btn: Button = $MarginContainer/VBoxContainer/HBoxContainer/SortTypeBtn
@onready var sort_name_btn: Button = $MarginContainer/VBoxContainer/HBoxContainer/SortNameBtn

const ITEM_SCRIPT: GDScript = preload("res://scenes/ui/item.gd")
const ITEM_SIZE: Vector2 = Vector2(32, 32)
const FLY_DURATION: float = 0.5
const SORT_DURATION: float = 0.4

var _is_sorting: bool = false
var _slots_in_flight: Dictionary = {}


func _ready() -> void:
	add_to_group("inventory")
	add_to_group("i18n")
	_apply_i18n()


func _apply_i18n() -> void:
	if is_instance_valid(sort_type_btn):
		sort_type_btn.text = tr("SORT_TYPE")
	if is_instance_valid(sort_name_btn):
		sort_name_btn.text = tr("SORT_NAME")


func _slot_get_item_node(slot: Node) -> Node:
	if slot.has_method("get_item_node"):
		return slot.call("get_item_node")
	for c in slot.get_children():
		if c.name == "StackLabel":
			continue
		if c is TextureRect and c.has_method("get_item_data"):
			return c
	return null


func _slot_has_item(slot: Node) -> bool:
	return _slot_get_item_node(slot) != null


func slot_count() -> int:
	return slots.get_child_count() if slots else 0


## Точка в глобальных координатах лежит внутри одной из ячеек-слотов (не кнопки, не поля вокруг).
func is_global_point_on_any_slot(global_pt: Vector2) -> bool:
	if slots == null:
		return false
	for i in range(slot_count()):
		var slot: Control = slots.get_child(i) as Control
		if slot == null:
			continue
		if slot.get_global_rect().has_point(global_pt):
			return true
	return false


func get_first_empty_slot_index() -> int:
	for i in range(slot_count()):
		if _is_slot_free(i):
			return i
	return -1


func _is_slot_free(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= slot_count():
		return false
	if _slots_in_flight.has(slot_index):
		return false
	return not _slot_has_item(slots.get_child(slot_index))


## Добавляет предметы по стакам. Возвращает false, если не влезает весь объём.
func try_add_items(item_data: ItemData, amount: int, fly_from_global: Vector2 = Vector2.INF) -> bool:
	if item_data == null or amount <= 0:
		return true
	var remaining: int = amount
	# 1) Докидываем в существующие стаки
	for i in range(slot_count()):
		if remaining <= 0:
			return true
		var slot: Control = slots.get_child(i) as Control
		if not _slot_has_item(slot):
			continue
		var node: Node = _slot_get_item_node(slot)
		if not node.has_method("get_item_data") or not node.has_method("try_add_stack"):
			continue
		var held: ItemData = node.get_item_data()
		if held == null or held.resource_path != item_data.resource_path:
			continue
		var before: int = remaining
		remaining = node.try_add_stack(remaining)
		if before != remaining and fly_from_global != Vector2.INF:
			_fly_visual_to_slot(i, item_data, fly_from_global)
	if remaining <= 0:
		return true
	# 2) Новые слоты
	while remaining > 0:
		var idx: int = get_first_empty_slot_index()
		if idx == -1:
			return false
		var put: int = mini(remaining, item_data.stack_size)
		if fly_from_global != Vector2.INF:
			fly_item_to_slot(idx, item_data, fly_from_global, put)
		else:
			_create_item_in_slot(slots.get_child(idx), item_data, put)
		remaining -= put
	return true


func fly_item_to_slot(
	slot_index: int,
	item_data: ItemData,
	from_global: Vector2 = Vector2.INF,
	count: int = 1
) -> void:
	if item_data == null:
		return
	if not _is_slot_free(slot_index):
		return
	var slot: Control = slots.get_child(slot_index) as Control
	if slot == null:
		return
	_slots_in_flight[slot_index] = true
	var fly_item: TextureRect = TextureRect.new()
	fly_item.texture = item_data.get_icon()
	fly_item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fly_item.size = ITEM_SIZE
	fly_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly_item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(fly_item)
	var start_global: Vector2 = from_global if from_global != Vector2.INF else get_viewport().get_visible_rect().size / 2.0
	var start_local: Vector2 = start_global - global_position - ITEM_SIZE / 2.0
	var target_local: Vector2 = slot.global_position - global_position + (slot.size - ITEM_SIZE) / 2.0
	fly_item.position = start_local
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(fly_item, "position", target_local, FLY_DURATION)
	tween.tween_callback(_on_fly_finished.bind(fly_item, slot, slot_index, item_data, count))


func _fly_visual_to_slot(slot_index: int, item_data: ItemData, from_global: Vector2) -> void:
	# Чисто визуальная анимация "полет в слот", когда предмет стакается в уже занятый слот.
	if item_data == null or from_global == Vector2.INF:
		return
	if slot_index < 0 or slot_index >= slot_count():
		return
	var slot: Control = slots.get_child(slot_index) as Control
	if slot == null:
		return
	var fly_item: TextureRect = TextureRect.new()
	fly_item.texture = item_data.get_icon()
	fly_item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fly_item.size = ITEM_SIZE
	fly_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly_item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(fly_item)
	var start_local: Vector2 = from_global - global_position - ITEM_SIZE / 2.0
	var target_local: Vector2 = slot.global_position - global_position + (slot.size - ITEM_SIZE) / 2.0
	fly_item.position = start_local
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(fly_item, "position", target_local, FLY_DURATION)
	tween.tween_callback(func() -> void:
		if is_instance_valid(fly_item):
			fly_item.queue_free()
	)


func _on_fly_finished(
	fly_item: Control,
	slot: Control,
	slot_index: int,
	item_data: ItemData,
	count: int
) -> void:
	if is_instance_valid(fly_item):
		fly_item.queue_free()
	_slots_in_flight.erase(slot_index)
	if not is_instance_valid(slot) or _slot_has_item(slot):
		return
	_create_item_in_slot(slot, item_data, count)


func _create_item_in_slot(slot: Control, item_data: ItemData, count: int = 1) -> void:
	var item: TextureRect = TextureRect.new()
	item.texture = item_data.get_icon()
	item.size = ITEM_SIZE
	item.mouse_filter = Control.MOUSE_FILTER_STOP
	item.stretch_mode = TextureRect.STRETCH_SCALE
	item.set_script(ITEM_SCRIPT)
	slot.add_child(item)
	if slot.has_method("attach_stack_label_to_item"):
		slot.call("attach_stack_label_to_item", item)
	if slot.has_method("reorder_stack_label_top"):
		slot.call("reorder_stack_label_top")
	item.set_item_data(item_data, clampi(count, 1, item_data.stack_size))
	item.position = (slot.size - item.size) / 2.0


func get_all_items() -> Array:
	var items: Array = []
	for slot in slots.get_children():
		var it: Node = _slot_get_item_node(slot)
		if it != null:
			items.append(it)
	return items


func get_item_data(item: Node) -> ItemData:
	return item.get_item_data() if item and item.has_method("get_item_data") else null


func sort_by_type() -> void:
	_sort_items(func(a: Node, b: Node) -> bool:
		var da: ItemData = get_item_data(a)
		var db: ItemData = get_item_data(b)
		if da == null or db == null:
			return false
		var ca: String = da.get_sort_category()
		var cb: String = db.get_sort_category()
		if ca == cb:
			return da.item_name.nocasecmp_to(db.item_name) < 0
		return ca.nocasecmp_to(cb) < 0
	)


func sort_by_name() -> void:
	_sort_items(func(a: Node, b: Node) -> bool:
		var da: ItemData = get_item_data(a)
		var db: ItemData = get_item_data(b)
		if da == null or db == null:
			return false
		return da.item_name.nocasecmp_to(db.item_name) < 0
	)


func _sort_items(comparator: Callable) -> void:
	if _is_sorting:
		return
	# Убедимся, что StackLabel прикреплён к иконкам перед переносом в root (иначе текст остаётся в слоте и "прыгает").
	for slot in slots.get_children():
		if slot and slot.has_method("attach_stack_label_to_item"):
			var it: Node = _slot_get_item_node(slot)
			if it is TextureRect:
				slot.call("attach_stack_label_to_item", it)
	for busy in get_all_items():
		if busy.has_method("is_drag_busy") and busy.call("is_drag_busy"):
			return
	var items: Array = get_all_items()
	if items.is_empty():
		return
	items.sort_custom(comparator)
	_animate_sort(items)


func _animate_sort(sorted_items: Array) -> void:
	var n: int = sorted_items.size()
	if n == 0:
		return
	_is_sorting = true
	var pending: Array = [n]
	for item in sorted_items:
		var old_slot: Node = item.get_parent()
		if old_slot == null:
			continue
		var start_global_center: Vector2 = old_slot.global_position + old_slot.size / 2.0
		old_slot.remove_child(item)
		add_child(item)
		item.global_position = start_global_center - item.size / 2.0
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(n):
		if i >= slot_count():
			pending[0] -= 1
			continue
		var item: Control = sorted_items[i]
		var target_slot: Control = slots.get_child(i)
		var target_global_pos: Vector2 = target_slot.global_position + (target_slot.size - item.size) / 2.0
		var item_tween: Tween = create_tween()
		item_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		item_tween.tween_property(item, "global_position", target_global_pos, SORT_DURATION)
		item_tween.tween_callback(_finish_sort_item.bind(item, target_slot, pending))
	if pending[0] <= 0:
		_is_sorting = false


func _finish_sort_item(item: Control, target_slot: Control, pending: Array) -> void:
	if is_instance_valid(item) and item.get_parent() == self and is_instance_valid(target_slot):
		remove_child(item)
		target_slot.add_child(item)
		if target_slot.has_method("attach_stack_label_to_item"):
			target_slot.call("attach_stack_label_to_item", item)
		if target_slot.has_method("reorder_stack_label_top"):
			target_slot.call("reorder_stack_label_top")
		item.position = (target_slot.size - item.size) / 2.0
		item.mouse_filter = Control.MOUSE_FILTER_STOP
	pending[0] -= 1
	if pending[0] <= 0:
		_is_sorting = false


func get_save_data() -> Array:
	var data: Array = []
	for i in range(slot_count()):
		var slot: Node = slots.get_child(i)
		var item: Node = _slot_get_item_node(slot)
		if item == null:
			data.append({})
			continue
		var idata: ItemData = get_item_data(item)
		if idata == null:
			data.append({})
			continue
		var qty: int = item.get_stack_count() if item.has_method("get_stack_count") else 1
		data.append({"path": idata.resource_path, "qty": qty})
	return data


func load_save_data(raw: Array) -> void:
	clear_all_items()
	if raw == null:
		return
	var n: int = mini(raw.size(), slot_count())
	for i in range(n):
		var entry = raw[i]
		var path: String = ""
		var qty: int = 1
		if typeof(entry) == TYPE_STRING:
			path = str(entry)
		elif typeof(entry) == TYPE_DICTIONARY:
			path = str(entry.get("path", ""))
			qty = int(entry.get("qty", 1))
		if path.is_empty():
			continue
		var resource: Resource = load(path)
		if resource is ItemData:
			var put: int = clampi(qty, 1, resource.stack_size)
			_create_item_in_slot(slots.get_child(i), resource, put)


func clear_all_items() -> void:
	for slot in slots.get_children():
		var to_free: Array = []
		for child in slot.get_children():
			if child.name == "StackLabel":
				continue
			to_free.append(child)
		for child in to_free:
			if child is TextureRect and slot.has_method("detach_stack_label_from_item"):
				slot.call("detach_stack_label_from_item", child)
			child.queue_free()
		var lbl: Node = slot.get_node_or_null("StackLabel")
		if lbl is Label:
			(lbl as Label).visible = false
			(lbl as Label).text = ""
	_slots_in_flight.clear()
	_is_sorting = false
