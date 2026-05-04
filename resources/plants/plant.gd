extends Node2D

var sprite: Sprite2D
var growth_stage: int = 0
var final_stage: int = 2
var watered: bool = false
var plant_name: String = ""
var cell_position: Vector2i = Vector2i.ZERO
var path_to_tres: String = ""
var path_to_script: String = ""

var atlas_texture: Texture2D = null
var frame_width: int = 32
var frame_height: int = 32

func _ready() -> void:
	TimeManager.plants_grow.connect(_plants_grow)
	add_to_group("plants")

	sprite = get_node_or_null("Sprite")
	if not sprite:
		sprite = Sprite2D.new()
		sprite.name = "Sprite"
		add_child(sprite)

func setup_from_data(data: PlantData) -> void:
	plant_name = data.plant_name
	final_stage = data.final_stage
	atlas_texture = data.atlas_texture
	path_to_tres = data.path_to_tres
	path_to_script = data.path_to_script
	
	if atlas_texture:
		sprite.texture = atlas_texture
		sprite.region_enabled = true
		
		frame_height = atlas_texture.get_height()
		_update_frame()
	else:
		sprite.texture = null

func set_cell(pos: Vector2i) -> void:
	cell_position = pos

func _update_frame() -> void:
	var count_of_stages_in_atlas = float(atlas_texture.get_width()) / frame_width
	var t := float(growth_stage) / float(final_stage - 1)
	var frame_index := int(round(t * (count_of_stages_in_atlas - 1)))
	sprite.region_rect = Rect2(frame_index * frame_width, 0, frame_width, frame_height)

func water() -> void:
	watered = true


func _plants_grow(mode, pos: Vector2i):
	if mode:
		grow()
		if path_to_script:
			load(path_to_script).script(cell_position)
	if !mode and pos == cell_position:
		grow()


func grow():
	if growth_stage < final_stage - 1:
		growth_stage += 1
		_update_frame()
	else:
		print('2')
