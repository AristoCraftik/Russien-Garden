extends Node2D

@onready var WateredBedLayer = $WateredBedLayer
@export var field_map = [
	Vector2i(0, 0),
	Vector2i(1, 1),
	Vector2i(0, 1),
]

# Добавь группу в _ready(), чтобы предмет мог найти поле
func _ready() -> void:
	add_to_group("field")

func plant_seed(cell_pos: Vector2i, texture: Texture2D) -> bool:
	# Проверка доступности клетки (можно добавить свои условия)
	if not cell_pos in field_map:
		field_map.append(cell_pos)   # временно разрешаем везде
	
	# Загружаем сцену растения
	var plant_scene = preload("res://plant.tscn")
	var plant = plant_scene.instantiate()
	
	# Инициализируем данными
	plant.setup(texture, "Семечко")   # название можешь менять
	
	# Позиция в центре клетки
	plant.position = WateredBedLayer.map_to_local(cell_pos)
	plant.z_index = 1
	
	# Добавляем как ребёнка слоя
	WateredBedLayer.add_child(plant)
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

func pour_cell(cell_pos:= Vector2(0, 0)):
	WateredBedLayer.set_cells_terrain_connect([cell_pos], 0, 0)

func depour_cell(cell_pos:= Vector2i(0, 0)):
	WateredBedLayer.set_cells_terrain_connect([cell_pos], 0, -1)


func replace_cell(y, x, z, cell):
	add_cell(y, x, z, cell)
	remove_cell(y, x, z)


func remove_cell(y, x, z):
	var cell = get_node("cell" + str(y) + str(x) + str(z))
	cell.queue_free()


func add_cell(y, x, z, cell):
	var cell_instantiate = load("res://scenes/tiles/" + cell + ".tscn").instantiate()
	cell_instantiate.position = Vector2(x*32, y*32)
	cell_instantiate.name = "cell" + str(y) + str(x) + str(z)
	cell_instantiate.z_index = z
	add_child(cell_instantiate)
