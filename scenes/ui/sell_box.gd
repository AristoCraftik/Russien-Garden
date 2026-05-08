extends Control

const ITEM_SCRIPT: GDScript = preload("res://scenes/ui/item.gd")
const ITEM_SIZE: Vector2 = Vector2(32, 32)
const SLOT_SCENE: PackedScene = preload("res://scenes/ui/slot.tscn")

@onready var slots_host: VBoxContainer = $VBox/Scroll/SlotsHost


func _ready() -> void:
	add_to_group("sell_box")
	TimeManager.day_advanced.connect(_on_day_advanced)


func _on_day_advanced() -> void:
	var total: int = 0
	for slot in slots_host.get_children():
		if not slot.has_method("has_item") or not slot.has_item():
			continue
		var item: Node = slot.call("get_item_node")
		var idata: ItemData = _read_item_data(item)
		var qty: int = int(item.call("get_stack_count")) if item.has_method("get_stack_count") else 1
		if idata != null and idata is YieldData:
			var yd: YieldData = idata as YieldData
			total += yd.base_price * qty
			
		if idata != null and idata is YieldData:
			var yd := idata as YieldData
			total += yd.base_price * qty
			# влияние на рынок семян соответствующего растения
			var seed_path := "res://resources/items/seeds/%s_seed.tres" % yd.plant.resource_path.get_file().get_basename()
			MarketState.register_sale(seed_path, qty)
	TimeManager.add_coins(total)
	_reset_to_single_empty_slot()


func get_save_data() -> Array:
	var data: Array = []
	for slot in slots_host.get_children():
		if not slot.has_method("has_item") or not slot.has_item():
			continue
		var item: Node = slot.call("get_item_node")
		var idata: ItemData = _read_item_data(item)
		if idata == null or idata.resource_path.is_empty():
			continue
		var qty: int = item.call("get_stack_count") if item.has_method("get_stack_count") else 1
		data.append({"path": idata.resource_path, "qty": qty})
	return data


func load_save_data(raw: Variant) -> void:
	_reset_to_single_empty_slot()
	if raw == null or not (raw is Array):
		return
	for entry in raw:
		var path: String = ""
		var qty: int = 1
		if typeof(entry) == TYPE_DICTIONARY:
			path = str(entry.get("path", ""))
			qty = int(entry.get("qty", 1))
		if path.is_empty():
			continue
		var resource: Resource = load(path)
		if not (resource is YieldData):
			continue
		var target: Panel = _first_empty_slot()
		if target == null:
			_append_empty_slot()
			target = _first_empty_slot()
		if target == null:
			continue
		var put: int = maxi(qty, 1)
		_create_yield_uncapped_in_slot(target, resource, put)
	_ensure_trailing_empty()


func try_accept_drop(screen_pos: Vector2, dragged: TextureRect) -> bool:
	if slots_host == null or not is_instance_valid(dragged):
		return false
	var as_item: ItemData = dragged.get_item_data() if dragged.has_method("get_item_data") else null
	if as_item == null or not (as_item is YieldData):
		return false
	if not get_global_rect().has_point(screen_pos):
		return false
	var data: YieldData = as_item as YieldData
	if data == null or dragged.get_stack_count() < 1:
		return false
	for slot in slots_host.get_children():
		if not slot is Panel:
			continue
		if not slot.has_method("has_item") or not slot.has_item():
			continue
		var existing: TextureRect = slot.call("get_item_node") as TextureRect
		var ed: ItemData = existing.get_item_data() if existing and existing.has_method("get_item_data") else null
		if ed and ed.resource_path == data.resource_path and existing.has_method("add_stack_ignore_cap"):
			existing.call("add_stack_ignore_cap", 1)
			return true
	for slot in slots_host.get_children():
		if not slot is Panel:
			continue
		if not slot.get_global_rect().has_point(screen_pos):
			continue
		if slot.has_method("has_item") and slot.has_item():
			return false
		_create_yield_uncapped_in_slot(slot, data, 1)
		_ensure_trailing_empty()
		return true
	return false


func _read_item_data(item: Node) -> ItemData:
	return item.call("get_item_data") if item and item.has_method("get_item_data") else null


func _ensure_trailing_empty() -> void:
	var last_slot: Panel = slots_host.get_child(slots_host.get_child_count() - 1) as Panel
	if last_slot and last_slot.has_method("has_item") and last_slot.has_item():
		_append_empty_slot()


func _append_empty_slot() -> void:
	slots_host.add_child(SLOT_SCENE.instantiate())


func _first_empty_slot() -> Panel:
	for child in slots_host.get_children():
		if child is Panel and child.has_method("has_item") and not child.has_item():
			return child as Panel
	return null


func _clear_slots_host_children() -> void:
	for child in slots_host.get_children():
		child.queue_free()


func _reset_to_single_empty_slot() -> void:
	_clear_slots_host_children()
	slots_host.add_child(SLOT_SCENE.instantiate())


func _create_yield_uncapped_in_slot(which: Panel, item_data: ItemData, count: int = 1) -> void:
	var to_rm: Array = []
	for child in which.get_children():
		if child.name == "StackLabel":
			continue
		to_rm.append(child)
	for child in to_rm:
		if child is TextureRect and which.has_method("detach_stack_label_from_item"):
			which.call("detach_stack_label_from_item", child)
		child.queue_free()
	var lbl_on_slot: Node = which.get_node_or_null("StackLabel")
	if lbl_on_slot is Label:
		(lbl_on_slot as Label).visible = false
		(lbl_on_slot as Label).text = ""
	var item: TextureRect = TextureRect.new()
	item.texture = item_data.get_icon()
	item.custom_minimum_size = ITEM_SIZE
	item.size = ITEM_SIZE
	item.mouse_filter = Control.MOUSE_FILTER_STOP
	item.stretch_mode = TextureRect.STRETCH_SCALE
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.set_script(ITEM_SCRIPT)
	which.add_child(item)
	if which.has_method("attach_stack_label_to_item"):
		which.call("attach_stack_label_to_item", item)
	if which.has_method("reorder_stack_label_top"):
		which.call("reorder_stack_label_top")
	item.set_item_data(item_data, maxi(count, 1), true)
	item.position = (which.size - item.size) / 2.0
