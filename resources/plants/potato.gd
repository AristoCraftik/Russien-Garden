extends Node

static func script(cell_pos: Vector2i):
	var directions = [
		Vector2i(-1, 0),
		Vector2i(1, 0),
		Vector2i(0, -1),
		Vector2i(0, 1),
		]
	
	for dir in directions:
		TimeManager.plants_grow.emit(0, cell_pos + dir)
