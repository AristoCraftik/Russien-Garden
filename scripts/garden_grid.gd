extends Node2D
class_name GardenGrid

signal cell_created(cell: GardenCell)

@export var cell_scene: PackedScene
@export var cell_size: int = 18
@export var grid_size: Vector2i = Vector2i(2, 2)

var cells: Dictionary = {}

func _ready() -> void:
	build_grid()

## Создает и размещает клетки сада.
func build_grid() -> void:
	for y: int in range(grid_size.y):
		for x: int in range(grid_size.x):
			var pos: Vector2i = Vector2i(x, y)
			var cell: GardenCell = cell_scene.instantiate() as GardenCell
			cell.grid = self
			cell.grid_pos = pos
			cell.position = Vector2(pos.x * cell_size, pos.y * cell_size)
			add_child(cell)
			cells[pos] = cell
			emit_signal("cell_created", cell)

## Возвращает клетку по координате.
func get_cell(pos: Vector2i) -> GardenCell:
	return cells.get(pos)

## Возвращает соседние клетки по четырем направлениям.
func get_adjacent_cells(pos: Vector2i) -> Array[GardenCell]:
	var result: Array[GardenCell] = []
	for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var c: GardenCell = get_cell(pos + d)
		if c != null:
			result.append(c)
	return result

## Возвращает все клетки сада.
func get_all_cells() -> Array[GardenCell]:
	var out: Array[GardenCell] = []
	for cell: GardenCell in cells.values():
		out.append(cell)
	return out
