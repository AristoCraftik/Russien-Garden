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
var _is_compacting: bool = false
var _fly_root: Control = null


func _ready() -> void:
	add_to_group("inventory")
	add_to_group("i18n")
	_apply_i18n()
	_fly_root = _find_fly_root()
	call_deferred("_refresh_fly_root")


func _refresh_fly_root() -> void:
	_fly_root = _find_fly_root()


func _find_fly_root() -> Control:
	# Летающие визуальные иконки нельзя добавлять в Container (Inventory),
	# иначе контейнер будет менять их размер/позицию и появится "растягивание".
	var tree := get_tree()
	if tree:
		var g: Node = tree.get_first_node_in_group("ui_drag_root")
		if g is Control:
			return g as Control
	return self


func _ensure_fly_root() -> Control:
	if is_instance_valid(_fly_root) and _fly_root.is_in_group("ui_drag_root"):
		return _fly_root
	_fly_root = _find_fly_root()
	return _fly_root


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


func compact_items() -> void:
	# Сдвигаем всё влево, чтобы не оставлять "дырки" в слотах.
	if _is_sorting or _is_compacting:
		return
	if slots == null:
		return
	# Если что-то "в полёте" — не трогаем.
	if not _slots_in_flight.is_empty():
		return
	# Если что-то держат в руке — не трогаем.
	for it in get_all_items():
		if it and it.has_method("is_drag_busy") and it.call("is_drag_busy"):
			return

	var n: int = slot_count()
	var write_i: int = 0
	for read_i in range(n):
		var slot_r: Control = slots.get_child(read_i) as Control
		var item: Node = _slot_get_item_node(slot_r)
		if item == null:
			continue
		if read_i != write_i:
			var slot_w: Control = slots.get_child(write_i) as Control
			# Перепривязываем item в более ранний слот.
			slot_r.remove_child(item)
			slot_w.add_child(item)
			if slot_w.has_method("attach_stack_label_to_item") and item is TextureRect:
				slot_w.call("attach_stack_label_to_item", item)
			if slot_w.has_method("reorder_stack_label_top"):
				slot_w.call("reorder_stack_label_top")
			if item is Control:
				(item as Control).size = ITEM_SIZE
				(item as Control).custom_minimum_size = ITEM_SIZE
			if item is TextureRect:
				(item as TextureRect).expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			if slot_w:
				(item as Control).position = (slot_w.size - (item as Control).size) / 2.0
		write_i += 1


func request_compact() -> void:
	# Уплотнение нужно делать ПОСЛЕ того, как Godot реально удалит queue_free() предмет
	# (иначе слот ещё не считается пустым и сдвига "не видно" до следующего удаления).
	call_deferred("_compact_next_frame")


func _compact_next_frame() -> void:
	await get_tree().process_frame
	compact_items_animated()


func compact_items_animated() -> void:
	# То же, что compact_items(), но с анимацией как при сортировке.
	if _is_sorting or _is_compacting:
		return
	if slots == null:
		return
	if not _slots_in_flight.is_empty():
		return
	for it in get_all_items():
		if it and it.has_method("is_drag_busy") and it.call("is_drag_busy"):
			return

	var n: int = slot_count()
	var current: Array = []
	current.resize(n)
	for i in range(n):
		current[i] = _slot_get_item_node(slots.get_child(i))

	var packed: Array = []
	for i in range(n):
		var it: Node = current[i]
		if it != null:
			packed.append(it)

	# Список перемещений: {item, from_slot, to_slot}
	var moves: Array = []
	for to_i in range(packed.size()):
		var it: Control = packed[to_i] as Control
		if it == null:
			continue
		var from_slot: Control = it.get_parent() as Control
		var to_slot: Control = slots.get_child(to_i) as Control
		if from_slot == to_slot:
			continue
		moves.append({"item": it, "to": to_slot})

	if moves.is_empty():
		return

	_is_compacting = true
	var pending: Array = [moves.size()]

	# Подготовка: фиксируем размер и переводим в top-level, чтобы не зависеть от родителя.
	for m in moves:
		var it: Control = m["item"]
		if not is_instance_valid(it):
			pending[0] -= 1
			continue
		var start_gp: Vector2 = it.global_position
		it.custom_minimum_size = ITEM_SIZE
		it.size = ITEM_SIZE
		it.scale = Vector2.ONE
		if it is TextureRect:
			(it as TextureRect).expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		it.set_as_top_level(true)
		# Важно: при переключении top_level позиция может сброситься; возвращаем на старт.
		it.global_position = start_gp
		it.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Анимация к целевым слотам
	for m in moves:
		var it: Control = m["item"]
		var to_slot: Control = m["to"]
		if not is_instance_valid(it) or not is_instance_valid(to_slot):
			pending[0] -= 1
			continue
		var target_global_pos: Vector2 = to_slot.global_position + (to_slot.size - it.size) / 2.0
		var tw: Tween = create_tween()
		tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_property(it, "global_position", target_global_pos, SORT_DURATION)
		tw.tween_callback(_finish_compact_item.bind(it, to_slot, pending))


func _finish_compact_item(item: Control, target_slot: Control, pending: Array) -> void:
	if is_instance_valid(item) and is_instance_valid(target_slot):
		item.set_as_top_level(false)
		var par: Node = item.get_parent()
		if par:
			par.remove_child(item)
		target_slot.add_child(item)
		item.custom_minimum_size = ITEM_SIZE
		item.size = ITEM_SIZE
		item.scale = Vector2.ONE
		if item is TextureRect:
			(item as TextureRect).expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		if target_slot.has_method("attach_stack_label_to_item"):
			target_slot.call("attach_stack_label_to_item", item)
		if target_slot.has_method("reorder_stack_label_top"):
			target_slot.call("reorder_stack_label_top")
		item.position = (target_slot.size - item.size) / 2.0
		item.mouse_filter = Control.MOUSE_FILTER_STOP

	pending[0] -= 1
	if pending[0] <= 0:
		_is_compacting = false


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
	var fly_root: Control = _ensure_fly_root()
	var fly_item: TextureRect = TextureRect.new()
	fly_item.texture = item_data.get_icon()
	fly_item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fly_item.size = ITEM_SIZE
	fly_item.custom_minimum_size = ITEM_SIZE
	fly_item.scale = Vector2.ONE
	fly_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly_item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fly_item.z_index = 4096
	fly_root.add_child(fly_item)
	var start_global: Vector2 = from_global if from_global != Vector2.INF else get_viewport().get_visible_rect().size / 2.0
	fly_item.global_position = start_global - ITEM_SIZE / 2.0
	fly_item.set_as_top_level(true)
	var target_global: Vector2 = slot.global_position + (slot.size - ITEM_SIZE) / 2.0
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(fly_item, "global_position", target_global, FLY_DURATION)
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
	var fly_root: Control = _ensure_fly_root()
	var fly_item: TextureRect = TextureRect.new()
	fly_item.texture = item_data.get_icon()
	fly_item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fly_item.size = ITEM_SIZE
	fly_item.custom_minimum_size = ITEM_SIZE
	fly_item.scale = Vector2.ONE
	fly_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly_item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fly_item.z_index = 4096
	fly_root.add_child(fly_item)
	fly_item.global_position = from_global - ITEM_SIZE / 2.0
	fly_item.set_as_top_level(true)
	var target_global: Vector2 = slot.global_position + (slot.size - ITEM_SIZE) / 2.0
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(fly_item, "global_position", target_global, FLY_DURATION)
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
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.size = ITEM_SIZE
	item.custom_minimum_size = ITEM_SIZE
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
		var old_slot: Control = item.get_parent() as Control
		if old_slot == null:
			continue
		# Фиксируем размер и переводим в top-level, чтобы анимация по global_position
		# не зависела от скейла/лейаута родителя.
		if item is Control:
			(item as Control).custom_minimum_size = ITEM_SIZE
		if item is TextureRect:
			(item as TextureRect).expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		item.size = ITEM_SIZE
		item.scale = Vector2.ONE
		item.set_as_top_level(true)
		var start_global_center: Vector2 = old_slot.global_position + old_slot.size / 2.0
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
	if is_instance_valid(item) and is_instance_valid(target_slot):
		# Возвращаем из top-level и перепривязываем к целевому слоту.
		item.set_as_top_level(false)
		var par: Node = item.get_parent()
		if par:
			par.remove_child(item)
		target_slot.add_child(item)
		item.custom_minimum_size = ITEM_SIZE
		item.size = ITEM_SIZE
		item.scale = Vector2.ONE
		if item is TextureRect:
			(item as TextureRect).expand_mode = TextureRect.EXPAND_IGNORE_SIZE
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
