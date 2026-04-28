extends Node
class_name BreedingSystem

signal plant_bred(result: PlantData)

## Создает гибрид двух растений.
func breed(cell_a: GardenCell, cell_b: GardenCell) -> PlantData:
	if cell_a.current_plant == null or cell_b.current_plant == null:
		return null
	var pa: PlantData = cell_a.current_plant.plant_data
	var pb: PlantData = cell_b.current_plant.plant_data
	var hybrid: PlantData = PlantData.new()
	hybrid.id = "%s_%s_hybrid" % [pa.id, pb.id]
	hybrid.display_name = "%s-%s" % [pa.display_name, pb.display_name]
	hybrid.plant_scene = "res://entities/plants/simple_grow_plant.tscn"
	hybrid.days_to_grow = int(round((pa.days_to_grow + pb.days_to_grow) / 2.0))
	hybrid.base_sell_price = int(round((pa.base_sell_price + pb.base_sell_price) / 2.0))
	hybrid.seed_price = hybrid.base_sell_price
	hybrid.traits = PackedStringArray(pa.traits + pb.traits)
	PlantRegistry.register_generated_plant(hybrid)
	emit_signal("plant_bred", hybrid)
	return hybrid
