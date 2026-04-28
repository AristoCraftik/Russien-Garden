extends BaseEvent
class_name CrowEvent

## Удаляет растение из клетки, если оно есть.
func trigger(cell: Node) -> void:
	if cell != null and cell.has_method("uproot"):
		cell.uproot()
