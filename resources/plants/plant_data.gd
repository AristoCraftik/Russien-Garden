class_name PlantData
extends Resource

enum PlantType { VEGETABLE, FRUIT, FLOWER, BERRY, LEGUME, GRAIN, HERB }

@export_group("Identity")
# ID из таблицы: например 1.1 -> (1, 1)
@export var plant_id: Vector2i = Vector2i.ZERO
@export var plant_name: String = ""
@export var plant_type: String = ""
@export var rarity: String = ""
@export_multiline var description: String = ""

@export_group("Visuals")
@export var plant_atlas_row_y: int = 1
@export var frame_px: Vector2i = Vector2i(32, 32)
@export var is_tall: bool = false

@export_group("Growth")
# Сколько раз растение успешно проходит grow() (дней с поливом) до созревания.
@export var grow_days: int = 3
@export var days_of_fruiting: int = 0
# Полив хотя бы раз в N дней (резерв под будущую механику)
@export var water_every_days: int = 1
# Случайное количество при сборе [min, max] включительно
@export var yield_quantity: Vector2i = Vector2i(1, 1)
@export var drain_chance: Vector2i = Vector2i(1, 3)
@export var plant_script: GDScript
@export_multiline var special_traits: String = ""


func get_save_id() -> String:
	return resource_path


func roll_yield_amount() -> int:
	var lo: int = mini(yield_quantity.x, yield_quantity.y)
	var hi: int = maxi(yield_quantity.x, yield_quantity.y)
	if is_instance_valid(MarketState):
		return MarketState.roll_yield(lo, hi)
	return randi_range(lo, hi)
