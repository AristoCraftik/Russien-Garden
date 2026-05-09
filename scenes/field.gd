extends Node2D

@onready var WateredBedLayer: TileMapLayer = $WateredBedLayer
@onready var BedLayer: TileMapLayer = $BedLayer

const PLANT_SCENE: PackedScene = preload("res://resources/plants/plant.tscn")
## Вкл.: в консоли Godot — детали клика по полю (для отладки).
const DEBUG_HARVEST_AND_FIELD_CLICK: bool = false
const BED_TILE_SOURCE_ID: int = 0

enum HarvestOutcome {
	NO_PLANT,
	NOT_RIPE,
	HARVESTED,
	INVENTORY_FULL,
	NO_INVENTORY_GROUP,
	NO_YIELD_RESOURCE,
}

# Множество допустимых клеток грядки — для O(1) проверки.
var _bed_cells: Dictionary = {}        # Vector2i -> true
# Карта занятости клеток растениями — для O(1) lookup'ов.
var _cell_to_plant: Dictionary = {}    # Vector2i -> Plant


func _ready() -> void:
	add_to_group("field")
	set_process_input(true)
	_rebuild_bed_cells()
	if TimeManager:
		if not TimeManager.clear_watered_tiles.is_connected(clear_watered_tiles):
			TimeManager.clear_watered_tiles.connect(clear_watered_tiles)


func _rebuild_bed_cells() -> void:
	_bed_cells.clear()
	if BedLayer == null:
		return
	for cell in BedLayer.get_used_cells():
		_bed_cells[cell] = true


# ----------------- API ПОЛЯ -----------------

func get_plant_at(cell_pos: Vector2i) -> Node:
	return _cell_to_plant.get(cell_pos, null)


func is_bed(cell_pos: Vector2i) -> bool:
	return _bed_cells.has(cell_pos)


func is_cell_occupied(cell_pos: Vector2i) -> bool:
	var p: Node = _cell_to_plant.get(cell_pos, null)
	return is_instance_valid(p)


func is_cell_watered(cell_pos: Vector2i) -> bool:
	return WateredBedLayer.get_cell_tile_data(cell_pos) != null


func plant_seed(cell_pos: Vector2i, plant_data: PlantData, growth_stage: int = 0, watered_state: bool = false, save_state: Dictionary = {}) -> bool:
	if plant_data == null:
		return false
	if not is_bed(cell_pos):
		return false
	if is_cell_occupied(cell_pos):
		return false

	var plant: Node2D = PLANT_SCENE.instantiate()
	WateredBedLayer.add_child(plant)
	plant.setup_from_data(plant_data)
	plant.set_cell(cell_pos)
	plant.growth_stage = growth_stage
	if plant.has_method("_update_frame"):
		plant._update_frame()
	plant.position = WateredBedLayer.map_to_local(cell_pos)
	plant.z_index = 1

	if watered_state or is_cell_watered(cell_pos):
		plant.watered = true

	if plant is Plant:
		var p: Plant = plant as Plant
		if p.data:
			var cap: int = maxi(p.data.grow_days, 1) - 1
			if growth_stage >= cap:
				p.can_harvest = true
		if not save_state.is_empty() and p.has_method("apply_save_state"):
			p.apply_save_state(save_state)

	_cell_to_plant[cell_pos] = plant
	plant.tree_exiting.connect(_on_plant_exiting.bind(cell_pos, plant))
	return true


func harvest_plant_at(cell_pos: Vector2i) -> HarvestOutcome:
	var plant: Node = _cell_to_plant.get(cell_pos, null)
	if plant == null or not is_instance_valid(plant):
		if DEBUG_HARVEST_AND_FIELD_CLICK:
			print("[Field/harvest] ", cell_pos, ": нет растения в клетке")
		return HarvestOutcome.NO_PLANT
	if not (plant is Plant):
		if DEBUG_HARVEST_AND_FIELD_CLICK:
			print("[Field/harvest] ", cell_pos, ": узел не Plant: ", plant)
		return HarvestOutcome.NO_PLANT
	var p: Plant = plant as Plant
	if not p.can_harvest:
		if DEBUG_HARVEST_AND_FIELD_CLICK:
			var cap: int = 0
			if p.data:
				cap = maxi(p.data.grow_days, 1) - 1
			print(
				"[Field/harvest] ", cell_pos,
				": не созрело (stage=", p.growth_stage,
				", cap=", cap, ", grow_days=", (str(p.data.grow_days) if p.data else "?"), ", can_harvest=false)"
			)
		return HarvestOutcome.NOT_RIPE
	# Для плодоносящих растений: после сбора в этот же день плодов больше нет.
	if p.has_method("can_collect_yield_now") and not p.can_collect_yield_now():
		return HarvestOutcome.NOT_RIPE

	var inventory: Node = get_tree().get_first_node_in_group("inventory")
	if inventory == null:
		if DEBUG_HARVEST_AND_FIELD_CLICK:
			print("[Field/harvest] группа 'inventory' не найдена")
		push_warning("Field: нет узла в группе 'inventory', урожай не забрать.")
		return HarvestOutcome.NO_INVENTORY_GROUP

	var plant_data: PlantData = p.data
	if plant_data == null:
		if DEBUG_HARVEST_AND_FIELD_CLICK:
			print("[Field/harvest] plant.data == null")
		return HarvestOutcome.NO_YIELD_RESOURCE
	var bn: String = plant_data.resource_path.get_file().get_basename()
	var yield_path: String = "res://resources/items/yields/%s_yield.tres" % bn
	var yield_res: Resource = load(yield_path)
	if not (yield_res is ItemData):
		if DEBUG_HARVEST_AND_FIELD_CLICK:
			print("[Field/harvest] нет урожая: ", yield_path, " -> ", yield_res)
		push_warning("Field: не загрузился урожай: %s" % yield_path)
		return HarvestOutcome.NO_YIELD_RESOURCE
	var qty: int = plant_data.roll_yield_amount()
	var drop_from: Vector2 = Vector2.INF
	if p is Node2D:
		drop_from = (p as Node2D).global_position
	if not inventory.has_method("try_add_items") or not inventory.try_add_items(yield_res as ItemData, qty, drop_from):
		if DEBUG_HARVEST_AND_FIELD_CLICK:
			print(
				"[Field/harvest] try_add_items false (часто полный инвентарь), qty=", qty,
				" ", yield_path
			)
		var toast: Node = get_tree().get_first_node_in_group("toast_manager")
		if toast and toast.has_method("show_toast"):
			toast.call("show_toast", tr("TOAST_INVENTORY_FULL"))
		push_warning(tr("TOAST_INVENTORY_FULL"))
		return HarvestOutcome.INVENTORY_FULL
	var should_remove: bool = true
	if p.has_method("after_harvest"):
		should_remove = bool(p.after_harvest())
	if should_remove:
		p.queue_free()
	if DEBUG_HARVEST_AND_FIELD_CLICK:
		print("[Field/harvest] OK: ", cell_pos, " +", qty, " ", bn)
	return HarvestOutcome.HARVESTED


func pour_cell(cell_pos: Vector2i = Vector2i.ZERO) -> bool:
	if not is_bed(cell_pos):
		return false
	if is_cell_watered(cell_pos):
		return false
	WateredBedLayer.set_cells_terrain_connect([cell_pos], 0, 0)
	var plant: Node = _cell_to_plant.get(cell_pos, null)
	if is_instance_valid(plant):
		plant.watered = true
	return true


func depour_cell(cell_pos: Vector2i = Vector2i.ZERO) -> void:
	if not is_bed(cell_pos):
		return
	WateredBedLayer.set_cells_terrain_connect([cell_pos], 0, -1)
	var plant: Node = _cell_to_plant.get(cell_pos, null)
	if is_instance_valid(plant):
		plant.watered = false


func clear_watered_tiles() -> void:
	WateredBedLayer.clear()


func get_plants_save_data() -> Array:
	# Снимок всех растений на поле для сейва.
	var snapshot: Array = []
	for cell in _cell_to_plant.keys():
		var plant: Node = _cell_to_plant[cell]
		if is_instance_valid(plant) and plant.has_method("get_save_dict"):
			snapshot.append(plant.get_save_dict())
	return snapshot

func can_place_bed_tetromino(cells_world: Array[Vector2i]) -> bool:
	if cells_world.is_empty():
		return false
	for c in cells_world:
		if is_bed(c):
			return false
		if is_cell_occupied(c):
			return false
	return true

func place_bed_tetromino(cells_world: Array[Vector2i]) -> bool:
	if not can_place_bed_tetromino(cells_world):
		return false
	for c in cells_world:
		BedLayer.set_cell(c, BED_TILE_SOURCE_ID, Vector2i.ZERO)
		_bed_cells[c] = true
	return true

# ----------------- INPUT -----------------

func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	# Клик по слотам инвентаря и кнопкам должен их обрабатывать, не грядка.
	var hovered: Control = get_viewport().gui_get_hovered_control()
	if hovered != null:
		if DEBUG_HARVEST_AND_FIELD_CLICK:
			print("[Field/_input] клик по UI, пропуск: ", hovered.get_path())
		return
	var mouse_pos: Vector2 = get_global_mouse_position()
	var local_pos: Vector2 = WateredBedLayer.to_local(mouse_pos)
	var cell_pos: Vector2i = WateredBedLayer.local_to_map(local_pos)

	if event.button_index == MOUSE_BUTTON_LEFT:
		var ho: HarvestOutcome = harvest_plant_at(cell_pos)
		match ho:
			HarvestOutcome.HARVESTED:
				get_viewport().set_input_as_handled()
				return
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		depour_cell(cell_pos)


# ----------------- ВНУТРЕННЕЕ -----------------

func _on_plant_exiting(cell_pos: Vector2i, plant: Node) -> void:
	# Снимаем регистрацию ровно той клетки и того узла, чтобы не убрать соседнюю запись.
	var current: Node = _cell_to_plant.get(cell_pos, null)
	if current == plant:
		_cell_to_plant.erase(cell_pos)
