extends Node

signal plants_grow

var save_path := "user://garden/game_data.cfg"


func load_game():
	var config = ConfigFile.new()
	var err = config.load(save_path)
	if err == OK:
		return config.get_value("game", "plants")
	else:
		print("Save error code: ", err)


func next_day():
	plants_grow.emit(1, Vector2i(100000, 100000))
	save_all()


func save_all():
	var config := ConfigFile.new()
	config.set_value("game", "plants", get_plants())
	var dir := save_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var err = config.save(save_path)


func get_plants():
	var plants_list = []
	var plants = get_tree().get_nodes_in_group("plants")
	for plant in plants:
		plants_list.append([plant.cell_position, plant.path_to_tres, plant.growth_stage])
	return plants_list
