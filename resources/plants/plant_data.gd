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
# plant_id кодирует визуал:
# - plant_id.x: 1 -> short atlas (32px), 2 -> tall atlas (48px)
# - plant_id.y: row_y в атласе (1-based)
const SHORT_FRAME_PX := Vector2i(32, 32)
const TALL_FRAME_PX := Vector2i(32, 48)

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


func get_atlas_row_y() -> int:
	return maxi(plant_id.y, 1)


func is_tall() -> bool:
	return plant_id.x == 2


func get_frame_px() -> Vector2i:
	return TALL_FRAME_PX if is_tall() else SHORT_FRAME_PX


func roll_yield_amount() -> int:
	var lo: int = mini(yield_quantity.x, yield_quantity.y)
	var hi: int = maxi(yield_quantity.x, yield_quantity.y)
	return randi_range(lo, hi)
