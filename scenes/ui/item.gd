extends TextureRect

const TOOLTIP_DELAY: float = 0.3
const RETURN_DURATION: float = 0.3
const DRAG_VISUAL_SIZE: Vector2 = Vector2(32, 32)
const STACK_LABEL_PAD: Vector2 = Vector2(2, 2)
const TOOLTIP_SCENE: PackedScene = preload("res://scenes/ui/tooltip.tscn")

var dragging: bool = false
var drag_copy: TextureRect = null
var origin_global_pos: Vector2 = Vector2.ZERO
var inventory_root: Control = null
var drag_root: Control = null

var item_data: ItemData = null
var stack_count: int = 1
var _ignore_stack_cap: bool = false

var _tooltip: Control = null
var _tooltip_layer: Node = null
var _mouse_over: bool = false
var _tooltip_timer: float = 0.0
var _drag_consumed_early: bool = false

var _tetro_rotation: int = 0

var origin_kind: String = "inventory" # "inventory" | "shop"
var unit_buy_price: int = 0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	inventory_root = _find_inventory_root()
	drag_root = _find_drag_root()
	call_deferred("_refresh_drag_root")
	call_deferred("_defer_slot_label_order")
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	tree_exiting.connect(_on_tree_exiting)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_refresh_stack_visuals()


func _exit_tree() -> void:
	_destroy_tooltip()


func _on_tree_exiting() -> void:
	_destroy_tooltip()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(drag_copy):
		drag_copy.queue_free()
		drag_copy = null
		
	_clear_tetro_preview()


func _find_inventory_root() -> Control:
	var node: Node = self
	while node:
		if node.name == "Inventory" and node is Control:
			return node
		node = node.get_parent()
	return self


func _find_drag_root() -> Control:
	var node: Node = self
	while node:
		if node is Control and node.is_in_group("ui_drag_root"):
			return node as Control
		node = node.get_parent()
	var tree := get_tree()
	if tree:
		var g: Node = tree.get_first_node_in_group("ui_drag_root")
		if g is Control:
			return g as Control
	return _find_inventory_root()


func _refresh_drag_root() -> void:
	drag_root = _find_drag_root()


func _defer_slot_label_order() -> void:
	var p: Node = get_parent()
	if p and p.has_method("attach_stack_label_to_item"):
		p.call("attach_stack_label_to_item", self)
	if p and p.has_method("reorder_stack_label_top"):
		p.call("reorder_stack_label_top")


func _get_slot_stack_label() -> Label:
	var on_self: Label = get_node_or_null("StackLabel") as Label
	if on_self:
		return on_self
	var p: Node = get_parent()
	if p:
		return p.get_node_or_null("StackLabel") as Label
	return null


func set_item_data(data: ItemData, count: int = 1, ignore_stack_cap: bool = false) -> void:
	item_data = data
	_ignore_stack_cap = ignore_stack_cap
	if data:
		texture = data.get_icon()
		stack_count = maxi(count, 1) if ignore_stack_cap else clampi(count, 1, data.stack_size)
		_refresh_stack_visuals()


func get_item_data() -> ItemData:
	return item_data


func get_stack_count() -> int:
	return stack_count


func is_drag_busy() -> bool:
	return dragging or is_instance_valid(drag_copy)


func try_add_stack(delta: int) -> int:
	if item_data == null or delta <= 0:
		return delta
	var room: int = item_data.stack_size - stack_count
	var addn: int = mini(room, delta)
	stack_count += addn
	_refresh_stack_visuals()
	return delta - addn


func add_stack_ignore_cap(delta: int) -> void:
	if item_data == null or delta <= 0:
		return
	stack_count += delta
	_refresh_stack_visuals()


func consume_amount(amount: int) -> void:
	if amount <= 0:
		return
	stack_count -= amount
	if stack_count <= 0:
		var par: Node = get_parent()
		if par and par.has_method("detach_stack_label_from_item"):
			par.call("detach_stack_label_from_item", self)
		else:
			var lbl_f: Label = get_node_or_null("StackLabel") as Label
			if lbl_f and par is Control:
				remove_child(lbl_f)
				par.add_child(lbl_f)
				(par as Control).move_child(lbl_f, par.get_child_count() - 1)
				lbl_f.visible = false
				lbl_f.text = ""
		queue_free()
	else:
		_refresh_stack_visuals()


func _refresh_stack_visuals() -> void:
	var lbl: Label = _get_slot_stack_label()
	if lbl == null:
		return
	var show_count: bool = stack_count > 1
	lbl.visible = show_count
	if show_count:
		lbl.text = str(stack_count)
		_position_stack_label(lbl)


func _position_stack_label(lbl: Label) -> void:
	if lbl == null:
		return
	var host: Control = lbl.get_parent() as Control
	if host == null:
		return
	var host_size: Vector2 = host.size
	if host == self:
		host_size = DRAG_VISUAL_SIZE
	lbl.anchor_left = 0.0
	lbl.anchor_top = 0.0
	lbl.anchor_right = 0.0
	lbl.anchor_bottom = 0.0
	var s: Vector2 = lbl.get_minimum_size()
	lbl.size = s
	var x: float = host_size.x - s.x - STACK_LABEL_PAD.x
	var y: float = host_size.y - s.y - STACK_LABEL_PAD.y
	lbl.position = Vector2(maxf(x, 0.0), maxf(y, 0.0))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_mouse_entered() -> void:
	_mouse_over = true
	_tooltip_timer = TOOLTIP_DELAY


func _on_mouse_exited() -> void:
	_mouse_over = false
	_tooltip_timer = 0.0
	_hide_tooltip()


func _process(delta: float) -> void:
	if dragging and is_instance_valid(drag_copy):
		var mouse_global: Vector2 = get_viewport().get_mouse_position()
		drag_copy.global_position = mouse_global - drag_copy.size * 0.5
	var lbl_rt: Label = _get_slot_stack_label()
	if lbl_rt and lbl_rt.visible:
		_position_stack_label(lbl_rt)
	if _mouse_over and not dragging:
		_tooltip_timer -= delta
		if _tooltip_timer <= 0.0 and (_tooltip == null or not _tooltip.visible):
			_show_tooltip()
	else:
		_tooltip_timer = TOOLTIP_DELAY
		if _tooltip:
			_hide_tooltip()
			
	if dragging and item_data is BedTetrominoData:
		_update_tetromino_preview()


func _ensure_tooltip() -> void:
	if is_instance_valid(_tooltip):
		return
	_tooltip = TOOLTIP_SCENE.instantiate() if TOOLTIP_SCENE else Control.new()
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layer: Node = drag_root.get_parent() if drag_root else (inventory_root.get_parent() if inventory_root else null)
	while layer and not (layer is CanvasLayer):
		layer = layer.get_parent()
	if layer == null:
		layer = get_tree().root
	_tooltip_layer = layer


func _show_tooltip() -> void:
	if item_data == null:
		return
	_ensure_tooltip()
	if _tooltip.get_parent() != _tooltip_layer:
		if _tooltip.get_parent():
			_tooltip.get_parent().remove_child(_tooltip)
		_tooltip_layer.add_child(_tooltip)
	_tooltip_layer.move_child(_tooltip, _tooltip_layer.get_child_count() - 1)
	var name_text: String = item_data.item_name if item_data.item_name else "—"
	var desc_text: String = item_data.description if item_data.description else ""
	var text: String = name_text + ("\n" + desc_text if desc_text.length() > 0 else "")
	if _tooltip.has_method("set_text"):
		_tooltip.call("set_text", text)
	elif _tooltip.has_node("Label"):
		var lbl := _tooltip.get_node("Label") as Label
		if lbl:
			lbl.text = text
	var item_global_rect: Rect2 = get_global_rect()
	var tip_size: Vector2 = _tooltip.size
	_tooltip.global_position = item_global_rect.position + Vector2(item_global_rect.size.x, -tip_size.y)
	if _tooltip.has_method("clamp_inside_viewport"):
		_tooltip.call("clamp_inside_viewport", get_viewport())
	_tooltip.visible = true


func _hide_tooltip() -> void:
	if is_instance_valid(_tooltip):
		_tooltip.visible = false


func _destroy_tooltip() -> void:
	if is_instance_valid(_tooltip):
		_tooltip.queue_free()
	_tooltip = null


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# ЛКМ: нажал — взял, нажал ещё раз — отпустил.
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if dragging:
				end_drag()
			else:
				start_drag()
			get_viewport().set_input_as_handled()
			return
		# ПКМ: использовать предмет, если он "в руке".
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if dragging:
				_try_use_in_hand()
				get_viewport().set_input_as_handled()
				return


func _input(event: InputEvent) -> void:
	# Когда предмет "в руке", ловим клики глобально.
	# Важно: поле тоже слушает _input и может помечать событие как handled,
	# поэтому для ЛКМ используем _input (а не только _unhandled_input).
	if not dragging:
		return

	if dragging and origin_kind == "shop" and event is InputEventMouseButton and event.pressed:
		if event.button_index != MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			return
		
	if dragging and origin_kind != "shop" and item_data is BedTetrominoData and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_tetro_rotation = (_tetro_rotation + 1) % 4
			_update_tetromino_preview()
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_tetro_rotation = (_tetro_rotation + 3) % 4
			_update_tetromino_preview()
			get_viewport().set_input_as_handled()
			return
	
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			end_drag()
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_try_use_in_hand()
			get_viewport().set_input_as_handled()
			return


func _unhandled_input(event: InputEvent) -> void:
	if not dragging:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			end_drag()
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_try_use_in_hand()
			get_viewport().set_input_as_handled()
			return


func _is_in_flight() -> bool:
	return get_parent() == inventory_root


func start_drag() -> void:
	if _is_in_flight():
		return
	if dragging:
		return
	if is_instance_valid(drag_copy):
		return
	dragging = true
	_drag_consumed_early = false
	_destroy_tooltip()
	_mouse_over = false
	if not drag_root:
		drag_root = _find_drag_root()
	origin_global_pos = global_position
	if origin_kind == "inventory":
		if stack_count > 1:
			consume_amount(1)
			_drag_consumed_early = true
		else:
			hide()
	else:
		_drag_consumed_early = false
		hide()

	drag_copy = TextureRect.new()
	drag_copy.texture = texture
	drag_copy.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	drag_copy.stretch_mode = TextureRect.STRETCH_SCALE
	drag_copy.custom_minimum_size = DRAG_VISUAL_SIZE
	drag_copy.size = DRAG_VISUAL_SIZE
	drag_copy.modulate = Color(1, 1, 1, 1)
	drag_copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_root.add_child(drag_copy)
	var mouse_global: Vector2 = get_viewport().get_mouse_position()
	drag_copy.global_position = mouse_global - drag_copy.size * 0.5
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	# Если это инструмент — считаем его активным на время использования (только не с витрины).
	if origin_kind != "shop" and item_data is ToolData and TimeManager and TimeManager.has_method("set_active_tool"):
		TimeManager.set_active_tool(item_data)


func end_drag() -> void:
	if origin_kind == "shop":
		dragging = false
		if _try_buy_into_inventory():
			if is_instance_valid(drag_copy):
				drag_copy.queue_free()
				drag_copy = null
			_destroy_tooltip()
			_remove_item_from_slot_and_free()
			return
		_return_drag_copy()
		return

	if not dragging:
		return
	dragging = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not is_instance_valid(drag_copy):
		return
	var screen_mouse: Vector2 = get_viewport().get_mouse_position()
	if _try_drop_on_trash(screen_mouse):
		drag_copy.queue_free()
		drag_copy = null
		_destroy_tooltip()
		if not _drag_consumed_early:
			consume_amount(1)
		_drag_consumed_early = false
		if is_instance_valid(self) and stack_count > 0:
			show()
		return
	if _try_drop_on_sell(screen_mouse):
		drag_copy.queue_free()
		drag_copy = null
		_destroy_tooltip()
		if not _drag_consumed_early:
			consume_amount(1)
		_drag_consumed_early = false
		if is_instance_valid(self) and stack_count > 0:
			show()
		return
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(drag_copy, "global_position", origin_global_pos, RETURN_DURATION)
	tween.tween_callback(_on_return_finished)
	
	_clear_tetro_preview()


func _on_return_finished() -> void:
	if is_instance_valid(drag_copy):
		drag_copy.queue_free()
		drag_copy = null
	if _drag_consumed_early:
		if _ignore_stack_cap:
			add_stack_ignore_cap(1)
		else:
			try_add_stack(1)
		_drag_consumed_early = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()
	
	_clear_tetro_preview()


func _try_use_in_hand() -> void:
	if not dragging or not is_instance_valid(drag_copy) or item_data == null:
		return
	if origin_kind == "shop":
		return
	# 1) Семена: посадить.
	if item_data is SeedData:
		if _try_plant_on_field():
			_commit_used_one()
		return
	# 2) Инструменты: пока только лейка.
	if item_data is ToolData:
		_try_water_on_field()
		return
	# 3) Тетрамино грядок
	if item_data is BedTetrominoData:
		if _try_place_tetromino_on_field():
			_commit_used_one()
		return


func _try_water_on_field() -> void:
	var field: Node = get_tree().get_first_node_in_group("field")
	if field == null:
		return
	if not (item_data is ToolData):
		return
	var td: ToolData = item_data as ToolData
	if td.tool_type != ToolData.ToolType.WATERING_CAN:
		return
	var viewport: Viewport = get_viewport()
	var screen_mouse: Vector2 = viewport.get_mouse_position()
	var mouse_world: Vector2 = viewport.get_canvas_transform().affine_inverse() * screen_mouse
	var map_layer: Node = _field_cell_map_layer(field)
	if map_layer == null:
		return
	var local_pos: Vector2 = map_layer.to_local(mouse_world)
	var cell_pos: Vector2i = map_layer.local_to_map(local_pos)
	if not field.is_bed(cell_pos):
		return
	if field.has_method("pour_cell"):
		var ok: bool = bool(field.call("pour_cell", cell_pos))
		if ok and TimeManager and TimeManager.has_method("register_watering_action"):
			TimeManager.register_watering_action()


func _commit_used_one() -> void:
	# Фиксируем использование 1 единицы из "руки", сохраняя режим удержания, если ещё есть.
	_destroy_tooltip()
	if not _drag_consumed_early:
		consume_amount(1)
	# ранний расход (для стака >1) уже уменьшил stack_count — считаем это "использованием".
	_drag_consumed_early = false
	if not is_instance_valid(self):
		# Предмет закончился и был удалён.
		if is_instance_valid(drag_copy):
			drag_copy.queue_free()
		drag_copy = null
		dragging = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if stack_count <= 0:
		if is_instance_valid(drag_copy):
			drag_copy.queue_free()
		drag_copy = null
		dragging = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	show()


func _try_drop_on_trash(screen_pos: Vector2) -> bool:
	var trash: Node = get_tree().get_first_node_in_group("trash_can")
	if trash == null or not trash.has_method("try_accept_drop"):
		return false
	return bool(trash.call("try_accept_drop", screen_pos, self))


func _try_drop_on_sell(screen_pos: Vector2) -> bool:
	var sell: Node = get_tree().get_first_node_in_group("sell_box")
	if sell == null or not sell.has_method("try_accept_drop"):
		return false
	return bool(sell.call("try_accept_drop", screen_pos, self))


func _try_plant_on_field() -> bool:
	if item_data == null:
		return false
	if not (item_data is SeedData):
		return false
	var field: Node = get_tree().get_first_node_in_group("field")
	if field == null:
		return false
	var viewport: Viewport = get_viewport()
	var screen_mouse: Vector2 = viewport.get_mouse_position()
	var mouse_world: Vector2 = viewport.get_canvas_transform().affine_inverse() * screen_mouse
	var map_layer: Node = _field_cell_map_layer(field)
	if map_layer == null:
		return false
	var local_pos: Vector2 = map_layer.to_local(mouse_world)
	var cell_pos: Vector2i = map_layer.local_to_map(local_pos)
	if not field.is_bed(cell_pos) or field.is_cell_occupied(cell_pos):
		return false
	return field.plant_seed(cell_pos, (item_data as SeedData).plant)


func _return_drag_copy() -> void:
	if not is_instance_valid(drag_copy):
		return
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(drag_copy, "global_position", origin_global_pos, RETURN_DURATION)
	tween.tween_callback(_on_return_finished)


func setup_shop_item(price: int) -> void:
	origin_kind = "shop"
	unit_buy_price = maxi(price, 1)


func _try_buy_into_inventory() -> bool:
	if item_data == null:
		return false
	if not (item_data is SeedData or item_data is BedTetrominoData):
		return false
	if unit_buy_price <= 0:
		return false

	var inv: Node = get_tree().get_first_node_in_group("inventory")
	if inv == null or not inv.has_method("try_add_items"):
		return false
	var mouse_global: Vector2 = get_viewport().get_mouse_position()
	if inv.has_method("is_global_point_on_any_slot"):
		if not bool(inv.call("is_global_point_on_any_slot", mouse_global)):
			return false

	var qty: int = max(1, stack_count)
	var total_price: int = unit_buy_price * qty
	
	if TimeManager.get_balance() < total_price:
		return false

	var ok: bool = inv.try_add_items(item_data, qty, Vector2.INF)
	if not ok:
		return false

	TimeManager.add_coins(-total_price)
	MarketState.register_buy(item_data.resource_path, qty)
	_clear_shop_slot_price_visual()
	return true


func _clear_shop_slot_price_visual() -> void:
	var p: Node = get_parent()
	var depth: int = 0
	while p != null and depth < 12:
		if p.has_method("clear_price_badge"):
			p.call("clear_price_badge")
			return
		var pp: Node = p.get_node_or_null("PricePanel")
		if pp != null:
			pp.queue_free()
			return
		p = p.get_parent()
		depth += 1


func _remove_item_from_slot_and_free() -> void:
	_clear_shop_slot_price_visual()
	var par: Node = get_parent()
	if par and par.has_method("detach_stack_label_from_item"):
		par.call("detach_stack_label_from_item", self)

	queue_free()

# Тетрамино
func _rotate_cell(c: Vector2i, rot: int) -> Vector2i:
	match rot % 4:
		0:
			return c
		1:
			return Vector2i(-c.y, c.x)
		2:
			return Vector2i(-c.x, -c.y)
		_:
			return Vector2i(c.y, -c.x)

func _field_cell_map_layer(field: Node) -> Node:
	if field.has_node("BedLayer"):
		return field.get_node("BedLayer")
	return field.get_node_or_null("WateredBedLayer")


func _mouse_to_field_cell(field: Node) -> Vector2i:
	var viewport: Viewport = get_viewport()
	var screen_mouse: Vector2 = viewport.get_mouse_position()
	var mouse_world: Vector2 = viewport.get_canvas_transform().affine_inverse() * screen_mouse
	var layer: Node = _field_cell_map_layer(field)
	if layer == null:
		return Vector2i.ZERO
	var local_pos: Vector2 = layer.to_local(mouse_world)
	return layer.local_to_map(local_pos)

func _build_tetromino_cells_world(field: Node, data: BedTetrominoData) -> Array[Vector2i]:
	var anchor: Vector2i = _mouse_to_field_cell(field)
	var out: Array[Vector2i] = []
	for c in data.cells:
		out.append(anchor + _rotate_cell(c, _tetro_rotation))
	return out

func _try_place_tetromino_on_field() -> bool:
	if not (item_data is BedTetrominoData):
		return false
	var data := item_data as BedTetrominoData
	var field: Node = get_tree().get_first_node_in_group("field")
	if field == null:
		return false
	var cells_world := _build_tetromino_cells_world(field, data)
	if not field.has_method("place_bed_tetromino"):
		return false
	return bool(field.call("place_bed_tetromino", cells_world))


func _clear_tetro_preview() -> void:
	var field: Node = get_tree().get_first_node_in_group("field") if get_tree() else null
	if field and field.has_method("clear_bed_tetromino_preview"):
		field.call("clear_bed_tetromino_preview")


func _update_tetromino_preview() -> void:
	if origin_kind == "shop":
		_clear_tetro_preview()
		return
	if not dragging or not (item_data is BedTetrominoData):
		_clear_tetro_preview()
		return
	var field: Node = get_tree().get_first_node_in_group("field")
	if field == null:
		_clear_tetro_preview()
		return
	var data := item_data as BedTetrominoData
	var cells_world := _build_tetromino_cells_world(field, data)
	var valid: bool = false
	if field.has_method("can_place_bed_tetromino"):
		valid = bool(field.call("can_place_bed_tetromino", cells_world))
	if field.has_method("update_bed_tetromino_preview"):
		field.call("update_bed_tetromino_preview", cells_world, valid)
