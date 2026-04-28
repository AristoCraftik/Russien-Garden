extends Node

## Переключает сцену поверх корневого узла.
func change_scene(path: String) -> void:
	for child: Node in get_children():
		child.queue_free()
	var scene: PackedScene = load(path)
	add_child(scene.instantiate())
