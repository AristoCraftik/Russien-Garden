extends Node
class_name PlantRegistry

signal plants_loaded(total: int)

const PLANTS_JSON: String = "res://data/plants.json"

var plants: Dictionary = {}

func _ready() -> void:
	load_plants()

## Загружает все растения из JSON.
func load_plants() -> void:
	plants.clear()
	var raw: Dictionary = _read_json(PLANTS_JSON)
	for row: Dictionary in raw.get("plants", []):
		var data: PlantData = PlantData.new()
		data.id = row.get("id", "")
		data.display_name = row.get("display_name", "")
		data.plant_scene = row.get("plant_scene", "res://entities/plants/simple_grow_plant.tscn")
		data.days_to_grow = row.get("days_to_grow", 1)
		data.base_sell_price = row.get("base_sell_price", 1)
		data.seed_price = row.get("seed_price", 1)
		data.footprint = Vector2i(row.get("footprint", [1, 1])[0], row.get("footprint", [1, 1])[1])
		data.traits = PackedStringArray(row.get("traits", []))
		data.params = row.get("params", {})
		plants[data.id] = data
	emit_signal("plants_loaded", plants.size())

## Возвращает данные растения по id.
func get_plant(id: String) -> PlantData:
	return plants.get(id)

## Регистрирует гибридное растение во время рантайма.
func register_generated_plant(data: PlantData) -> void:
	plants[data.id] = data

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
