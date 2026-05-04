class_name PlantData
extends Resource

enum ItemType { SEED, FERTILIZER, ARTIFACT }

@export var plant_name: String = "Неизвестное растение"
@export var type: ItemType = ItemType.SEED
@export var seed_texture: Texture2D
@export var atlas_texture: Texture2D
@export var final_stage: int = 3
@export var description: String = ""
@export var path_to_tres: String = ""
@export var path_to_script: String = ""
