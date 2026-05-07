extends Node2D
class_name Plant

var data: PlantData = null
var growth_stage: int = 0
var watered: bool = false
var can_harvest: bool = false
var cell_position: Vector2i = Vector2i.ZERO

@onready var sprite: Sprite2D = _ensure_sprite()


func _ensure_sprite() -> Sprite2D:
	var s: Sprite2D = get_node_or_null("Sprite") as Sprite2D
	if s == null:
		s = Sprite2D.new()
		s.name = "Sprite"
		add_child(s)
	return s


func _ready() -> void:
	add_to_group("plants")
	if TimeManager and not TimeManager.day_advanced.is_connected(_on_day_advanced):
		TimeManager.day_advanced.connect(_on_day_advanced)


func setup_from_data(plant_data: PlantData) -> void:
	data = plant_data
	if data == null:
		return
	sprite.texture = Atlas.PLANTS_TALL_ATLAS if data.is_tall else Atlas.PLANTS_SHORT_ATLAS
	sprite.region_enabled = true
	sprite.centered = true
	var fh: float = float(max(1, data.frame_px.y))
	if data.is_tall:
		sprite.offset.y = (32.0 - fh) / 2.0
	else:
		sprite.offset.y = 0.0
	_update_frame()


func set_cell(pos: Vector2i) -> void:
	cell_position = pos


func water() -> void:
	watered = true


## Индекс последней колонки в атласе: кадры 0..last включая семя как колонку 0.
func _last_atlas_stage_index() -> int:
	if data == null:
		return 0
	var g: int = maxi(data.grow_days, 1)
	return g - 1


func grow() -> void:
	if data == null:
		return
	var cap: int = _last_atlas_stage_index()
	if growth_stage < cap:
		growth_stage += 1
		_update_frame()
	if growth_stage >= cap:
		can_harvest = true


func _update_frame() -> void:
	if data == null or sprite == null:
		return
	var atlas: Texture2D = sprite.texture
	if atlas == null:
		return
	var fp: Vector2i = data.frame_px
	var fw: int = max(1, fp.x)
	var fh: int = max(1, fp.y)
	var atlas_stages_x: int = max(1, atlas.get_width() / fw)
	var atlas_rows: int = max(1, atlas.get_height() / fh)
	var cap_x: int = _last_atlas_stage_index()
	var stage_vis: int = maxi(growth_stage, 0)
	var stage_x: int = clampi(stage_vis, 0, cap_x)
	stage_x = clampi(stage_x, 0, atlas_stages_x - 1)
	var row_y: int = clamp(data.plant_atlas_row_y, 1, atlas_rows)
	sprite.region_rect = Atlas.frame_from_plants_atlas(row_y, stage_x, fp)


func _on_day_advanced() -> void:
	if not watered:
		queue_free()
		return
	grow()
	watered = false
	if data and data.plant_script and data.plant_script.has_method("on_grew"):
		data.plant_script.on_grew(self)


func get_save_dict() -> Dictionary:
	return {
		"cell": cell_position,
		"id": data.get_save_id() if data else "",
		"stage": growth_stage,
		"watered": watered,
	}
