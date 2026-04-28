extends Node2D
class_name GardenCell

signal planted(cell: GardenCell, plant: BasePlant)
signal harvested(cell: GardenCell, items: Array[BaseShopItem])

var grid: GardenGrid
var grid_pos: Vector2i = Vector2i.ZERO
var current_plant: BasePlant
var watered: bool = false
var fertilized: bool = false
var has_artifact: bool = false

## Сажает семя в клетку после проверки законов.
func plant_seed(data: PlantData) -> bool:
	if current_plant != null:
		return false
	var validation: Dictionary = LawManager.validate_action("plant", {"cell": self, "plant_data": data})
	if not validation.get("ok", false):
		return false
	var scene: PackedScene = load(data.plant_scene)
	current_plant = scene.instantiate() as BasePlant
	add_child(current_plant)
	current_plant.position = Vector2.ZERO
	current_plant.setup(data, self)
	emit_signal("planted", self, current_plant)
	queue_redraw()
	return true

## Поливает клетку.
func water() -> void:
	watered = true
	queue_redraw()

## Удобряет клетку.
func fertilize() -> void:
	fertilized = true
	queue_redraw()

## Вырывает растение из клетки.
func uproot() -> void:
	if current_plant != null:
		current_plant.queue_free()
		current_plant = null
	queue_redraw()

## Продвигает клетку на один день роста.
func advance_day() -> void:
	if current_plant == null:
		return
	if watered:
		current_plant.grow()
	watered = false
	fertilized = false
	queue_redraw()

## Собирает урожай если растение готово.
func harvest_if_ready() -> Array[BaseShopItem]:
	if current_plant == null or not current_plant.is_ready():
		return []
	var items: Array[BaseShopItem] = current_plant.harvest()
	uproot()
	emit_signal("harvested", self, items)
	return items

func _draw() -> void:
	var color: Color = Color(0.22, 0.15, 0.1)
	if watered:
		color = Color(0.2, 0.35, 0.6)
	draw_rect(Rect2(Vector2(-8, -8), Vector2(16, 16)), color)
	draw_rect(Rect2(Vector2(-8, -8), Vector2(16, 16)), Color.WHITE, false)
