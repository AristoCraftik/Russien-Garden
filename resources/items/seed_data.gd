class_name SeedData
extends ItemData

@export var plant: PlantData
@export var base_buy_price: int = 5

func get_sort_category() -> String:
	return plant.plant_type if plant else ""
