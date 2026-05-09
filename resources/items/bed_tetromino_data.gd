class_name BedTetrominoData
extends ItemData

@export var base_buy_price: int = 100
@export var cells: Array[Vector2i] = [Vector2i.ZERO]

func _init() -> void:
	item_type = ItemType.BED_TETROMINO
	stack_size = 1


func get_icon() -> Texture2D:
	return Atlas.icon_from_bed_tetromino_atlas_v(icon_id)


func get_sort_category() -> String:
	return "Bed"
