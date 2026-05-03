extends Node

signal plants_grow

var save_path := "user://garden/game_data.cfg"


func load_game():
	var config = ConfigFile.new()
	var err = config.load(save_path)
	if err == OK:
		return config.get_value("game", "plants")
	else:
		print("error")


func next_day():
	emit_signal("plants_grow")
	save_all()


func save_all():
	var config := ConfigFile.new()
	config.set_value("game", "plants", get_plants())


func get_plants():
	var plants_list = []
	var plants = get_tree().get_nodes_in_group("plants")
	for plant in plants:
		plants_list.append([plant.cell_position, plant.path_to_tres, plant.stage])
	return plants_list
