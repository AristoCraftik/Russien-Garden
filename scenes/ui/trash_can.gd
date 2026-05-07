extends Control

const ITEM_SCRIPT: GDScript = preload("res://scenes/ui/item.gd")
const ITEM_SIZE: Vector2 = Vector2(32, 32)

@onready var slot: Panel = $VBox/Slot


func _ready() -> void:
	add_to_group("trash_can")
	TimeManager.day_advanced.connect(_on_day_advanced)


func _on_day_advanced() -> void:
	_clear_slot()


func get_save_data() -> Dictionary:
	if slot == null:
		return {}
	if slot.has_method("has_item") and not slot.has_item():
		return {}
	if not slot.has_method("has_item") and slot.get_child_count() == 0:
		return {}
	var item: Node = slot.get_item_node() if slot.has_method("get_item_node") else slot.get_child(0)
	if not item.has_method("get_item_data"):
		return {}
	var idata: ItemData = item.call("get_item_data")
	if idata == null or idata.resource_path.is_empty():
		return {}
	var qty: int = item.call("get_stack_count")
	return {"path": idata.resource_path, "qty": qty}


func load_save_data(raw: Variant) -> void:
	_clear_slot()
	if typeof(raw) != TYPE_DICTIONARY:
		return
	var path: String = str(raw.get("path", ""))
	var qty: int = int(raw.get("qty", 1))
	if path.is_empty():
		return
	var resource: Resource = load(path)
	if resource is ItemData:
		var put: int = clampi(qty, 1, resource.stack_size)
		_create_item_in_slot(slot, resource, put)


func try_accept_drop(screen_pos: Vector2, dragged: TextureRect) -> bool:
	if slot == null or not is_instance_valid(dragged):
		return false
	if not get_global_rect().has_point(screen_pos):
		return false
	var data: ItemData = dragged.get_item_data() if dragged.has_method("get_item_data") else null
	if data == null or dragged.get_stack_count() < 1:
		return false
	_existing_item_free()
	_create_item_in_slot(slot, data, 1)
	return true


func _existing_item_free() -> void:
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


func _clear_slot() -> void:
	_existing_item_free()


func _create_item_in_slot(which: Panel, item_data: ItemData, count: int = 1) -> void:
	_existing_item_free()
	var item: TextureRect = TextureRect.new()
	item.texture = item_data.get_icon()
	item.size = ITEM_SIZE
	item.mouse_filter = Control.MOUSE_FILTER_STOP
	item.stretch_mode = TextureRect.STRETCH_SCALE
	item.set_script(ITEM_SCRIPT)
	which.add_child(item)
	if which.has_method("attach_stack_label_to_item"):
		which.call("attach_stack_label_to_item", item)
	if which.has_method("reorder_stack_label_top"):
		which.call("reorder_stack_label_top")
	item.set_item_data(item_data, clampi(count, 1, item_data.stack_size))
	item.position = (which.size - item.size) / 2.0
