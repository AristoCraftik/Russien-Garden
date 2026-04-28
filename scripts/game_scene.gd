extends Node2D

@onready var grid: GardenGrid = $GardenGrid
@onready var hud: Control = $CanvasLayer/HUD

var inventory: Dictionary = {}
var selected_plant_id: String = "tomato"

func _ready() -> void:
	add_to_group("game_scene")
	GameManager.set_game_scene(self)
	GameManager.week_ended.connect(_on_week_ended)
	_connect_cells()
	_refresh_seed_buttons()
	hud.get_node("Panel/VBox/EndDay").pressed.connect(_on_end_day_pressed)
	hud.get_node("Panel/VBox/SellAll").pressed.connect(_on_sell_all_pressed)

func _connect_cells() -> void:
	for cell: GardenCell in grid.get_all_cells():
		cell.planted.connect(_on_cell_planted)
		cell.harvested.connect(_on_cell_harvested)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell: GardenCell = _cell_from_mouse()
		if cell != null:
			var plant_data: PlantData = PlantRegistry.get_plant(selected_plant_id)
			if plant_data != null:
				cell.plant_seed(plant_data)
	if event.is_action_pressed("water_cell"):
		var target: GardenCell = _cell_from_mouse()
		if target != null:
			target.water()
	if event.is_action_pressed("harvest_cell"):
		var harvest_cell: GardenCell = _cell_from_mouse()
		if harvest_cell != null:
			harvest_cell.harvest_if_ready()

## Продвигает все клетки на сутки.
func advance_all_cells() -> void:
	for cell: GardenCell in grid.get_all_cells():
		cell.advance_day()

## Возвращает все клетки для внешних менеджеров.
func get_all_cells() -> Array[GardenCell]:
	return grid.get_all_cells()

func _cell_from_mouse() -> GardenCell:
	var local: Vector2 = grid.to_local(get_global_mouse_position())
	var x: int = int(round(local.x / grid.cell_size))
	var y: int = int(round(local.y / grid.cell_size))
	return grid.get_cell(Vector2i(x, y))

func _on_cell_planted(_cell: GardenCell, plant: BasePlant) -> void:
	EconomyManager.register_price("crop_%s" % plant.plant_data.id, plant.get_sell_price())

func _on_cell_harvested(_cell: GardenCell, items: Array[BaseShopItem]) -> void:
	for item: BaseShopItem in items:
		inventory[item.id] = int(inventory.get(item.id, 0)) + item.quantity
	hud.call("set_inventory_text", JSON.stringify(inventory))

func _on_end_day_pressed() -> void:
	GameManager.end_day()

func _on_sell_all_pressed() -> void:
	for item_id: String in inventory.keys():
		var qty: int = int(inventory[item_id])
		if qty > 0:
			var gained: int = EconomyManager.sell(item_id, qty)
			GameManager.add_quota(gained)
			inventory[item_id] = 0
	hud.call("set_inventory_text", JSON.stringify(inventory))

func _refresh_seed_buttons() -> void:
	hud.call("setup_seed_options", PlantRegistry.plants.keys())

func _on_seed_selected(id: String) -> void:
	selected_plant_id = id


func _on_week_ended(_week: int) -> void:
	var report: PackedScene = load("res://scenes/quota_report.tscn")
	add_child(report.instantiate())
