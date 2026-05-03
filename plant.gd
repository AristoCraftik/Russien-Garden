extends Node2D

var sprite: Sprite2D
var growth_stage: int = 0
var final_stage: int = 2
var watered: bool = false
var plant_name: String = ""

var atlas_texture: Texture2D = null
var frame_width: int = 32
var frame_height: int = 32

func _ready() -> void:
	sprite = get_node_or_null("Sprite")
	if not sprite:
		sprite = Sprite2D.new()
		sprite.name = "Sprite"
		add_child(sprite)

func setup_from_data(data: PlantData) -> void:
	plant_name = data.plant_name
	final_stage = data.final_stage
	atlas_texture = data.atlas_texture
	
	if atlas_texture:
		sprite.texture = atlas_texture
		sprite.region_enabled = true
		frame_width = atlas_texture.get_width() / final_stage
		frame_height = atlas_texture.get_height()
		_update_frame()
	else:
		sprite.texture = null

func _update_frame() -> void:
	var col = growth_stage % final_stage
	var row = growth_stage / final_stage
	sprite.region_rect = Rect2(col * frame_width, row * frame_height, frame_width, frame_height)

func water() -> void:
	watered = true
	
func advance_day() -> void:
	if growth_stage < final_stage:
		growth_stage += 1
		_update_frame()
