extends BasePlant
class_name NeighborBonusPlant

## Возвращает цену продажи с бонусом от соседей.
func get_sell_price() -> int:
	var base: int = plant_data.base_sell_price
	if owner_cell == null or owner_cell.grid == null:
		return base
	var bonus: int = 0
	for neighbor: GardenCell in owner_cell.grid.get_adjacent_cells(owner_cell.grid_pos):
		if neighbor.current_plant != null:
			bonus += int(base * 0.5)
	return base + bonus
