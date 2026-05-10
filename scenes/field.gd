extends Node2D

@onready var BackGrassLayer: TileMapLayer = $BackGrassLayer
@onready var WateredBedLayer: TileMapLayer = $WateredBedLayer
@onready var BedLayer: TileMapLayer = $BedLayer
@onready var GrassLayer: TileMapLayer = $GrassLayer
@onready var AmbientLayer: TileMapLayer = $AmbientLayer

const PLANT_SCENE: PackedScene = preload("res://resources/plants/plant.tscn")
## Вкл.: в консоли Godot — детали клика по полю (для отладки).
const DEBUG_HARVEST_AND_FIELD_CLICK: bool = false
const BED_TILE_SOURCE_ID: int = 0
const GRASS_OUTLINE_TERRAIN_SET: int = 0
const GRASS_OUTLINE_TERRAIN: int = 0

## Тайловое превью грядки-тетрамино (создаётся в `_setup_bed_preview_layers`).
var BedPreviewLayer: TileMapLayer
var GrassPreviewLayer: TileMapLayer

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

## Кодовая доступная территория: размер после ваучера = initial ± 2*margin каждую сторону.
## Центр — центр AABB занятых клеток BackGrass + Grass (визуальное «поле»).
@export_range(1, 512, 1) var initial_accessible_width: int = 20
@export_range(1, 512, 1) var initial_accessible_height: int = 20

var _access_margin_expansions: int = 0
var _logical_field_center: Vector2i = Vector2i.ZERO


func _ready() -> void:
	add_to_group("field")
	set_process_input(true)
	_rebuild_bed_cells()
	_recompute_logical_field_center_from_map()
	_setup_bed_preview_layers()
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
		if not is_cell_in_access_territory(c):
			return false
		if is_bed(c):
			return false
		if is_cell_occupied(c):
			return false
	return true


func get_field_save_state() -> Dictionary:
	return {"margin_expansions": _access_margin_expansions}


func apply_field_save_state(data: Variant) -> void:
	if typeof(data) != TYPE_DICTIONARY:
		return
	var d: Dictionary = data
	_access_margin_expansions = maxi(0, int(d.get("margin_expansions", 0)))


## Новый ваучер: +1 к доступной территории по периметру (ширина/высота +2 каждый покупкой).
func expand_access_territory_by_one_margin_in_all_directions() -> void:
	_access_margin_expansions += 1


func is_cell_in_access_territory(cell: Vector2i) -> bool:
	return _get_access_territory_rect().has_point(cell)


func _get_access_territory_rect() -> Rect2i:
	var w: int = initial_accessible_width + 2 * _access_margin_expansions
	var h: int = initial_accessible_height + 2 * _access_margin_expansions
	w = maxi(w, 1)
	h = maxi(h, 1)
	var cx: int = _logical_field_center.x
	var cy: int = _logical_field_center.y
	var x0: int = cx - int((w - 1) / 2)
	var y0: int = cy - int((h - 1) / 2)
	return Rect2i(x0, y0, w, h)


func _recompute_logical_field_center_from_map() -> void:
	var bbox: Variant = _union_used_cells_bbox([BackGrassLayer, GrassLayer])
	if bbox == null:
		_logical_field_center = Vector2i.ZERO
		return
	var r: Rect2i = bbox
	_logical_field_center = r.position + r.size / 2 - Vector2i(1, 1)


func _union_used_cells_bbox(layers: Array) -> Variant:
	var min_x: int = 0
	var max_x: int = 0
	var min_y: int = 0
	var max_y: int = 0
	var has_any: bool = false
	for L in layers:
		if not (L is TileMapLayer):
			continue
		var layer: TileMapLayer = L as TileMapLayer
		for cell in layer.get_used_cells():
			var c: Vector2i = cell
			if not has_any:
				min_x = c.x
				max_x = c.x
				min_y = c.y
				max_y = c.y
				has_any = true
			else:
				min_x = mini(min_x, c.x)
				max_x = maxi(max_x, c.x)
				min_y = mini(min_y, c.y)
				max_y = maxi(max_y, c.y)
	if not has_any:
		return null
	var w: int = max_x - min_x + 1
	var h: int = max_y - min_y + 1
	return Rect2i(min_x, min_y, w, h)

func place_bed_tetromino(cells_world: Array[Vector2i]) -> bool:
	if not can_place_bed_tetromino(cells_world):
		return false
	for c in cells_world:
		BedLayer.set_cell(c, BED_TILE_SOURCE_ID, Vector2i.ZERO)
		_bed_cells[c] = true
	_refresh_grass_outline_for_beds_changed(cells_world)
	_clear_ambient_near_new_beds(cells_world)
	return true


func clear_bed_tetromino_preview() -> void:
	if BedPreviewLayer:
		BedPreviewLayer.clear()
	if GrassPreviewLayer:
		GrassPreviewLayer.clear()


func update_bed_tetromino_preview(cells_world: Array[Vector2i], valid: bool) -> void:
	if BedPreviewLayer == null or GrassPreviewLayer == null:
		return
	BedPreviewLayer.clear()
	GrassPreviewLayer.clear()
	if cells_world.is_empty():
		return
	var tint: Color = Color(1.0, 1.0, 1.0, 0.42) if valid else Color(1.0, 0.38, 0.38, 0.48)
	BedPreviewLayer.modulate = tint
	GrassPreviewLayer.modulate = tint
	for c in cells_world:
		BedPreviewLayer.set_cell(c, BED_TILE_SOURCE_ID, Vector2i.ZERO)
	var extra_bed: Dictionary = {}
	for c in cells_world:
		extra_bed[c] = true
	_refresh_grass_outline_on_layer(GrassPreviewLayer, cells_world, extra_bed)


func _setup_bed_preview_layers() -> void:
	if BedPreviewLayer != null:
		return
	BedPreviewLayer = TileMapLayer.new()
	BedPreviewLayer.name = "BedPreviewLayer"
	BedPreviewLayer.tile_set = BedLayer.tile_set
	BedPreviewLayer.z_index = 500
	BedPreviewLayer.position = BedLayer.position
	BedPreviewLayer.scale = BedLayer.scale
	add_child(BedPreviewLayer)

	GrassPreviewLayer = TileMapLayer.new()
	GrassPreviewLayer.name = "GrassPreviewLayer"
	GrassPreviewLayer.tile_set = GrassLayer.tile_set
	GrassPreviewLayer.z_index = 501
	GrassPreviewLayer.position = GrassLayer.position
	GrassPreviewLayer.scale = GrassLayer.scale
	GrassPreviewLayer.use_parent_material = GrassLayer.use_parent_material
	add_child(GrassPreviewLayer)


func _is_bed_for_outline(cell: Vector2i, extra_bed: Dictionary) -> bool:
	if _bed_cells.has(cell):
		return true
	return extra_bed.has(cell)


func _packed_from_cells(cells: Array[Vector2i]) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(cells.size())
	for i in range(cells.size()):
		out[i] = Vector2(cells[i])
	return out


## Обводка повторяет форму грядки: terrain на **тех же клетках**, что и фигура (кластер),
## плюс только уже существующие тайлы Grass у 8-соседей — чтобы обновился стык с полем.
func _grass_outline_stamp_cells(
		layer: TileMapLayer,
		seed_cells: Array[Vector2i],
		extra_bed: Dictionary,
	) -> Array[Vector2i]:
	var seen: Dictionary = {}
	var out: Array[Vector2i] = []
	for c in seed_cells:
		if not _is_bed_for_outline(c, extra_bed):
			continue
		if seen.has(c):
			continue
		seen[c] = true
		out.append(c)
	for c in seed_cells:
		if not _is_bed_for_outline(c, extra_bed):
			continue
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var n: Vector2i = c + Vector2i(dx, dy)
				if _is_bed_for_outline(n, extra_bed):
					continue
				if seen.has(n):
					continue
				if layer.get_cell_tile_data(n) == null:
					continue
				seen[n] = true
				out.append(n)
	return out


func _refresh_grass_outline_on_layer(
		layer: TileMapLayer,
		seed_cells: Array[Vector2i],
		extra_bed: Dictionary,
	) -> void:
	if layer == null or seed_cells.is_empty():
		return
	var stamp: Array[Vector2i] = _grass_outline_stamp_cells(layer, seed_cells, extra_bed)
	if stamp.is_empty():
		return
	layer.set_cells_terrain_connect(
		_packed_from_cells(stamp),
		GRASS_OUTLINE_TERRAIN_SET,
		GRASS_OUTLINE_TERRAIN,
	)


func _refresh_grass_outline_for_beds_changed(changed_bed_cells: Array[Vector2i]) -> void:
	if GrassLayer == null or changed_bed_cells.is_empty():
		return
	_refresh_grass_outline_on_layer(GrassLayer, changed_bed_cells, {})


## Какие клетки карты AmbientLayer пересекают одну клетку грядки (учёт разного tile_size).
func _ambient_map_cells_under_bed_cell(bed_cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if AmbientLayer.tile_set == null or BedLayer.tile_set == null:
		out.append(bed_cell)
		return out
	var bed_sz: Vector2i = BedLayer.tile_set.tile_size
	var amb_sz: Vector2i = AmbientLayer.tile_set.tile_size
	if amb_sz.x <= 0 or amb_sz.y <= 0 or bed_sz.x <= 0 or bed_sz.y <= 0:
		out.append(bed_cell)
		return out
	var origin_global: Vector2 = BedLayer.to_global(BedLayer.map_to_local(bed_cell))
	const EPS: float = 0.02
	var tl_global: Vector2 = origin_global + Vector2(EPS, EPS)
	var br_global: Vector2 = origin_global + Vector2(bed_sz) - Vector2(EPS, EPS)
	var amb_tl: Vector2i = AmbientLayer.local_to_map(AmbientLayer.to_local(tl_global))
	var amb_br: Vector2i = AmbientLayer.local_to_map(AmbientLayer.to_local(br_global))
	var x0: int = mini(amb_tl.x, amb_br.x)
	var x1: int = maxi(amb_tl.x, amb_br.x)
	var y0: int = mini(amb_tl.y, amb_br.y)
	var y1: int = maxi(amb_tl.y, amb_br.y)
	for x in range(x0 - 1, x1):
		for y in range(y0 - 1, y1):
			out.append(Vector2i(x, y))
	return out


func _clear_ambient_near_new_beds(bed_cells: Array[Vector2i]) -> void:
	if AmbientLayer == null or bed_cells.is_empty():
		return
	var wipe: Dictionary = {}
	for v in bed_cells:
		if not (v is Vector2i):
			continue
		var bc: Vector2i = v
		for ac in _ambient_map_cells_under_bed_cell(bc):
			wipe[ac] = true
	for c in wipe:
		AmbientLayer.erase_cell(c)
		AmbientLayer.set_cell(c, -1)

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
	var local_pos: Vector2 = BedLayer.to_local(mouse_pos)
	var cell_pos: Vector2i = BedLayer.local_to_map(local_pos)

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
