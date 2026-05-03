extends TextureRect

var dragging: bool = false
var drag_copy: TextureRect
var origin_pos_in_inventory: Vector2
var inventory_root: Control

# Данные о растении, которые несёт этот предмет
var plant_data: PlantData = null

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	set_process_input(true)
	inventory_root = _find_inventory_root()

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

	# Позиция предмета относительно инвентаря
	origin_pos_in_inventory = global_position - inventory_root.global_position

	hide()

	drag_copy = TextureRect.new()
	drag_copy.texture = texture
	drag_copy.expand_mode = expand_mode
	drag_copy.size = size
	drag_copy.modulate = Color(1, 1, 1, 1)
	drag_copy.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Копия становится дочерним элементом инвентаря
	inventory_root.add_child(drag_copy)

	var mouse_pos = inventory_root.get_local_mouse_position()
	drag_copy.position = mouse_pos - size / 2.0

func _process(_delta: float) -> void:
	if dragging and drag_copy:
		var mouse_pos = inventory_root.get_local_mouse_position()
		drag_copy.position = mouse_pos - size / 2.0

func end_drag() -> void:
	if not dragging: return
	dragging = false

	if not drag_copy: return

	# Пытаемся посадить
	if try_plant_on_field():
		if drag_copy:
			drag_copy.queue_free()
			drag_copy = null
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
		return false   # нет данных — сажать нечего

	var field = get_tree().get_first_node_in_group("field")
	if not field: return false

	var mouse_world = get_global_mouse_position()
	var water_layer = field.WateredBedLayer
	if not water_layer: return false

	var local_pos = water_layer.to_local(mouse_world)
	var cell_pos = water_layer.local_to_map(local_pos)

	# Вызываем посадку, передавая PlantData
	return field.plant_seed(cell_pos, plant_data)
