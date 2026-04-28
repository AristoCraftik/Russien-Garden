extends BasePlant
class_name RequiresSameTypePlant

## Проверяет что рядом есть растение того же типа.
func can_plant_here(cell: GardenCell) -> bool:
	if cell.grid == null:
		return true
	for neighbor: GardenCell in cell.grid.get_adjacent_cells(cell.grid_pos):
		if neighbor.current_plant != null and neighbor.current_plant.plant_data.id == plant_data.id:
			return true
	return false
