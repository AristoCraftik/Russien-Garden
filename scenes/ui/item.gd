extends TextureRect

var dragging: bool = false
var drag_copy: TextureRect
var origin_pos_in_inventory: Vector2
var inventory_root: Control

# Данные о растении
var plant_data: PlantData = null

# --- Тултип ---
var tooltip: Control = null
var mouse_over: bool = false
var tooltip_delay: float = 0.3
var tooltip_timer: float = 0.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	set_process_input(true)
	inventory_root = _find_inventory_root()
	
	# Сигналы входа/выхода мыши
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _find_inventory_root() -> Control:
	var node: Node = self
	while node:
		if node.name == "Inventory" and node is Control:
			return node
		node = node.get_parent()
	return self

func set_plant_data(data: PlantData) -> void:
	plant_data = data
	if data and data.seed_texture:
		texture = data.seed_texture

# Обработчики наведения
func _on_mouse_entered() -> void:
	mouse_over = true
	tooltip_timer = tooltip_delay

func _on_mouse_exited() -> void:
	mouse_over = false
	tooltip_timer = 0.0
	_hide_tooltip()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			start_drag()

func _input(event: InputEvent) -> void:
	if dragging and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			end_drag()
			get_viewport().set_input_as_handled()

func start_drag() -> void:
	dragging = true
	
	# Прячем тултип, если есть
	_hide_tooltip()
	mouse_over = false
	
	origin_pos_in_inventory = global_position - inventory_root.global_position
	hide()
	
	drag_copy = TextureRect.new()
	drag_copy.texture = texture
	drag_copy.expand_mode = expand_mode
	drag_copy.size = size
	drag_copy.modulate = Color(1, 1, 1, 1)
	drag_copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	inventory_root.add_child(drag_copy)
	var mouse_pos = inventory_root.get_local_mouse_position()
	drag_copy.position = mouse_pos - size / 2.0

func _process(delta: float) -> void:
	# Движение перетаскиваемой копии
	if dragging and drag_copy:
		var mouse_pos = inventory_root.get_local_mouse_position()
		drag_copy.position = mouse_pos - size / 2.0
	
	# Логика тултипа
	if mouse_over and not dragging:
		tooltip_timer -= delta
		if tooltip_timer <= 0.0 and not tooltip:
			_show_tooltip()
	else:
		tooltip_timer = tooltip_delay
		if tooltip:
			_hide_tooltip()

func _show_tooltip() -> void:
	if not plant_data:
		return

	tooltip = Control.new()
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Фон
	var panel = Panel.new()
	panel.self_modulate = Color(0, 0, 0, 0.8)
	tooltip.add_child(panel)

	# Текст
	var label = Label.new()
	label.text = plant_data.plant_name + "\n" + plant_data.description
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 12)
	tooltip.add_child(label)

	# Ищем CanvasLayer, в котором лежит инвентарь
	var layer = inventory_root.get_parent()
	while layer and not layer is CanvasLayer:
		layer = layer.get_parent()
	if not layer:
		layer = get_tree().root   # запасной вариант

	layer.add_child(tooltip)

	# Поднимаем тултип на передний план (последний ребёнок в слое)
	var parent = tooltip.get_parent()
	parent.move_child(tooltip, parent.get_child_count() - 1)

	# Позиционируем справа от предмета
	var item_global_rect = get_global_rect()
	tooltip.global_position = item_global_rect.position + Vector2(item_global_rect.size.x, 0)

	# Подгоняем размеры
	label.size = label.get_minimum_size()
	panel.size = label.size + Vector2(8, 4)
	label.position = Vector2(4, 2)
	tooltip.size = panel.size

func _hide_tooltip() -> void:
	if tooltip:
		tooltip.queue_free()
		tooltip = null

func end_drag() -> void:
	if not dragging: return
	dragging = false
	
	if not drag_copy: return
	
	if try_plant_on_field():
		if drag_copy:
			drag_copy.queue_free()
			drag_copy = null
		_hide_tooltip()
		queue_free()
		return
	
	# Возврат анимацией
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(drag_copy, "position", origin_pos_in_inventory, 0.3)
	tween.tween_callback(func():
		if drag_copy:
			drag_copy.queue_free()
			drag_copy = null
		show()
	)

func try_plant_on_field() -> bool:
	if not plant_data:
		return false
	
	var field = get_tree().get_first_node_in_group("field")
	if not field: return false
	
	var mouse_world = get_global_mouse_position()
	var water_layer = field.WateredBedLayer
	if not water_layer: return false
	
	var local_pos = water_layer.to_local(mouse_world)
	var cell_pos = water_layer.local_to_map(local_pos)
	
	if field.has_method("is_cell_occupied") and field.is_cell_occupied(cell_pos):
		return false
	
	return field.plant_seed(cell_pos, plant_data)
