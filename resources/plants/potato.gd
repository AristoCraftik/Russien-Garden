extends Node
class_name PotatoBehavior

# Поведение картофеля на конце дня. Передаётся в PlantData.plant_script
# и вызывается напрямую, без сигнальных каскадов.

const NEIGHBORS: Array[Vector2i] = [
	Vector2i(-1, 0),
	Vector2i(1, 0),
	Vector2i(0, -1),
	Vector2i(0, 1),
]

# self_plant — узел Plant, у которого есть cell_position и ссылка на поле.
static func on_grew(self_plant: Node) -> void:
	if self_plant == null:
		return
	var tree: SceneTree = self_plant.get_tree() if self_plant.is_inside_tree() else null
	if tree == null:
		return
	var field: Node = tree.get_first_node_in_group("field")
	if field == null or not field.has_method("get_plant_at"):
		return
	var origin: Vector2i = self_plant.cell_position
	for dir in NEIGHBORS:
		var neighbor: Node = field.get_plant_at(origin + dir)
		if neighbor and neighbor.has_method("grow"):
			neighbor.grow()
