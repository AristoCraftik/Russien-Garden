extends Node

signal plants_grow
signal clear_watered_tiles

var save_path := "user://garden/game_data.cfg"

func load_game():
	var config = ConfigFile.new()
	var err = config.load(save_path)
	if err == OK:
		return [config.get_value("game", "plants"), config.get_value("game", "day")]
	else:
		print("Save error code: ", err)


func next_day(day_counter):
	plants_grow.emit(1, Vector2i(100000, 100000))
	emit_signal("clear_watered_tiles")
	save_all(day_counter)


func save_all(day_counter):
	var config := ConfigFile.new()
	config.set_value("game", "plants", get_plants())
	config.set_value("game", "day", day_counter)
	var dir := save_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	config.save(save_path)


func get_plants():
	var plants_list = []
	var plants = get_tree().get_nodes_in_group("plants")
	for plant in plants:
		plants_list.append([plant.cell_position, plant.path_to_tres, plant.growth_stage])
	return plants_list
