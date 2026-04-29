extends Node2D


@export var filed_matrix = [
	["bed_tile", "bed_tile", "bed_tile"],
	["bed_tile", "bed_tile", "bed_tile"],
	["bed_tile", "bed_tile", "bed_tile"]
]
 

func _ready() -> void:
	var z = 0
	var y = 0 
	for row in filed_matrix:
		var x = 0
		for cell in row:
			add_cell(y, x, z, cell)
			x += 1
		y += 1
	
	add_cell(1, 1, 1, "plant")


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
