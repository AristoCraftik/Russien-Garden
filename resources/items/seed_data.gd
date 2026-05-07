class_name SeedData
extends ItemData

@export var plant: PlantData


func get_sort_category() -> String:
	return plant.plant_type if plant else ""
