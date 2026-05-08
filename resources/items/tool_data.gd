class_name ToolData
extends ItemData

enum ToolType { WATERING_CAN }

@export var tool_type: ToolType = ToolType.WATERING_CAN


func _init() -> void:
	item_type = ItemType.TOOL
	stack_size = 1


func get_sort_category() -> String:
	return "Tool"
