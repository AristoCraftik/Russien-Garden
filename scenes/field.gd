extends Node2D

@onready var WateredBedLayer = $WateredBedLayer
@onready var BedLayer = $BedLayer
@export var field_map = [
	Vector2i(0, 0),
	Vector2i(1, 1),
	Vector2i(0, 1),
]

func _ready() -> void:
	add_to_group("field")
	
	field_map.clear()
	for cell in BedLayer.get_used_cells():
		field_map.append(cell)

func plant_seed(cell_pos: Vector2i, plant_data: PlantData, growth_stage: int = 0) -> bool:
	if not is_bed(cell_pos):
		return false
	
	var plant_scene = preload("res://resources/plants/plant.tscn")
	var plant = plant_scene.instantiate()
	
	WateredBedLayer.add_child(plant)
	plant.setup_from_data(plant_data)
	plant.set_cell(cell_pos)
	plant.growth_stage = growth_stage
	plant._update_frame()
	
	plant.position = WateredBedLayer.map_to_local(cell_pos)
	plant.z_index = 1
	
	return true



func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		var mouse_pos = get_global_mouse_position()
		var local_pos = WateredBedLayer.to_local(mouse_pos)
		var cell_pos = WateredBedLayer.local_to_map(local_pos)
		if event.button_index == MOUSE_BUTTON_LEFT:
			pour_cell(cell_pos)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			depour_cell(cell_pos)

func pour_cell(cell_pos:= Vector2i(0, 0)):
	if not is_bed(cell_pos):
		return
	WateredBedLayer.set_cells_terrain_connect([cell_pos], 0, 0)

func depour_cell(cell_pos:= Vector2i(0, 0)):
	if not is_bed(cell_pos):
		return
	WateredBedLayer.set_cells_terrain_connect([cell_pos], 0, -1)
	
func is_bed(cell_pos: Vector2i) -> bool:
	return cell_pos in field_map
	
func is_cell_occupied(cell_pos: Vector2i) -> bool:
	for plant in get_tree().get_nodes_in_group("plants"):
		var pos = plant.get("cell_position")
		if pos != null and pos == cell_pos:
			return true
	return false
