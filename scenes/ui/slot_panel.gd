extends Panel


func get_stack_label() -> Label:
	var it: TextureRect = get_item_node()
	if it:
		var on_item: Label = it.get_node_or_null("StackLabel") as Label
		if on_item:
			return on_item
	return get_node_or_null("StackLabel") as Label


func get_item_node() -> TextureRect:
	for c in get_children():
		if c.name == "StackLabel":
			continue
		if c is TextureRect and c.has_method("get_item_data"):
			return c as TextureRect
	return null


func has_item() -> bool:
	return get_item_node() != null


func clear_price_badge() -> void:
	var to_free: Array[Node] = []
	for c in get_children():
		if c.name == "PricePanel":
			to_free.append(c)
	for c in to_free:
		c.queue_free()


## Прикрепляет StackLabel к иконке, чтобы счётчик двигался вместе с ней (сортировка, drag).
func attach_stack_label_to_item(item: TextureRect) -> void:
	if item == null:
		return
	var on_item: Label = item.get_node_or_null("StackLabel") as Label
	if on_item:
		_force_stack_label_bottom_right(on_item)
		item.move_child(on_item, item.get_child_count() - 1)
		return
	var lbl: Label = get_node_or_null("StackLabel") as Label
	if lbl == null:
		return
	var par: Node = lbl.get_parent()
	if par:
		par.remove_child(lbl)
	item.add_child(lbl)
	_force_stack_label_bottom_right(lbl)
	item.move_child(lbl, item.get_child_count() - 1)


## Вернёт метку на панель слота перед удалением предмета.
func detach_stack_label_from_item(item: TextureRect) -> void:
	if item == null:
		return
	var lbl: Label = item.get_node_or_null("StackLabel") as Label
	if lbl == null:
		return
	item.remove_child(lbl)
	add_child(lbl)
	move_child(lbl, get_child_count() - 1)
	_force_stack_label_bottom_right(lbl)
	lbl.visible = false
	lbl.text = ""


func _force_stack_label_bottom_right(lbl: Label) -> void:
	# Важно: при сортировке предмет временно переподвешивается в другой Control.
	# У якорей иногда "прыжок" из-за смены layout_mode/offset — фиксируем здесь.
	if lbl == null:
		return
	lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	# Не трогаем font/size: пользователь может настроить их в сцене.
	# ТОЛЬКО геометрия привязки к углу.
	lbl.offset_left = -24.0
	lbl.offset_top = -16.0
	lbl.offset_right = -2.0
	lbl.offset_bottom = -2.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE



func reorder_stack_label_top() -> void:
	var it: TextureRect = get_item_node()
	if it:
		var lbl: Label = it.get_node_or_null("StackLabel") as Label
		if lbl:
			it.move_child(lbl, it.get_child_count() - 1)
		return
	var slot_lbl: Label = get_node_or_null("StackLabel") as Label
	if slot_lbl:
		move_child(slot_lbl, get_child_count() - 1)
