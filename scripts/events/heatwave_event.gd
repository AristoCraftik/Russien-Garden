extends BaseEvent
class_name HeatwaveEvent

## Делает все клетки не политыми.
func trigger(cell: Node) -> void:
	if cell != null:
		cell.watered = false
