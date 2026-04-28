extends Resource
class_name PlantData

@export var id: String = ""
@export var display_name: String = ""
@export var plant_scene: String = ""
@export var days_to_grow: int = 1
@export var base_sell_price: int = 1
@export var seed_price: int = 1
@export var footprint: Vector2i = Vector2i.ONE
@export var traits: PackedStringArray = PackedStringArray()
@export var params: Dictionary = {}
