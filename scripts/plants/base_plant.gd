extends Node2D
class_name BasePlant

signal grew(plant: BasePlant)
signal ready_to_harvest(plant: BasePlant)
signal harvested(plant: BasePlant)

var plant_data: PlantData
var days_to_grow: int = 1
var days_grown: int = 0
var owner_cell: GardenCell

## Инициализирует растение данными.
func setup(data: PlantData, cell: GardenCell) -> void:
	plant_data = data
	days_to_grow = data.days_to_grow
	owner_cell = cell
	queue_redraw()

## Увеличивает стадию роста на день.
func grow() -> void:
	days_grown += 1
	emit_signal("grew", self)
	if is_ready():
		emit_signal("ready_to_harvest", self)
	queue_redraw()

## Проверяет готовность к сбору.
func is_ready() -> bool:
	return days_grown >= days_to_grow

## Проверяет можно ли посадить растение в клетке.
func can_plant_here(_cell: GardenCell) -> bool:
	return true

## Возвращает цену продажи с учетом модификаторов.
func get_sell_price() -> int:
	return plant_data.base_sell_price

## Возвращает отображаемое имя растения.
func get_display_name() -> String:
	return plant_data.display_name

## Собирает урожай и возвращает элементы магазина.
func harvest() -> Array[BaseShopItem]:
	var crop: BaseShopItem = BaseShopItem.new()
	crop.id = "crop_%s" % plant_data.id
	crop.display_name = plant_data.display_name
	crop.base_price = get_sell_price()
	crop.quantity = 1
	emit_signal("harvested", self)
	return [crop]

func _draw() -> void:
	if plant_data == null:
		return
	var ratio: float = float(days_grown) / float(max(1, days_to_grow))
	draw_rect(Rect2(Vector2(-6, -6), Vector2(12, 12)), Color(0.2 + ratio * 0.6, 0.8 - ratio * 0.3, 0.2))
