class_name YieldData
extends ItemData

@export var plant: PlantData
@export var base_price: int = 1


func get_sort_category() -> String:
	return plant.plant_type if plant else ""
