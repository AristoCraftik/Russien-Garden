class_name ItemData
extends Resource


enum ItemType { SEED, YIELD, FERTILIZER, ARTIFACT, TOOL, BED_TETROMINO }

@export var item_id: Vector2i = Vector2i.ZERO
@export var icon_id: Vector2i = Vector2i.ONE
@export var item_name: String = ""
@export_multiline var description: String = ""

@export var item_type: ItemType = ItemType.SEED
@export_range(1, 99999, 1) var stack_size: int = 999

## Вес в ежедневной витрине магазина (вместе с множителями типа в Shop). 0 — не попадает в пул.
@export_range(0.0, 1000.0, 0.01, "or_greater") var shop_offer_weight: float = 1.0


func get_icon() -> Texture2D:
	return Atlas.icon_from_items_atlas_v(icon_id)


func get_sort_category() -> String:
	return ""
