class_name Atlas
extends Object

const TILE_SIZE: int = 32

const ITEMS_ATLAS: Texture2D = preload("res://assets/items/items_atlas.png")
const PLANTS_SHORT_ATLAS: Texture2D = preload("res://assets/plants/short_plants_atlas.png")
const PLANTS_TALL_ATLAS: Texture2D = preload("res://assets/plants/tall_plants_atlas.png")


static func icon_from_items_atlas(id_y_1based: int, id_x_1based: int) -> Texture2D:
	# В данных (PlantData) координаты храним 1-based: (Y, X),
	# чтобы "1 1" означало самую первую клетку атласа.
	var y: int = max(0, id_y_1based - 1)
	var x: int = max(0, id_x_1based - 1)
	return _atlas_texture(ITEMS_ATLAS, x, y)


static func icon_from_items_atlas_v(id_xy_1based: Vector2i) -> Texture2D:
	# (x, y) 1-based
	var x: int = max(0, id_xy_1based.x - 1)
	var y: int = max(0, id_xy_1based.y - 1)
	return _atlas_texture(ITEMS_ATLAS, x, y)


static func frame_from_plants_atlas(row_y_1based: int, stage_x_0based: int, frame_px: Vector2i) -> Rect2:
	var row: int = max(0, row_y_1based - 1)
	var w: int = max(1, frame_px.x)
	var h: int = max(1, frame_px.y)
	# Стадии идут по X с шагом w; строки по Y с шагом h.
	return Rect2(stage_x_0based * w, row * h, w, h)


static func _atlas_texture(atlas: Texture2D, x: int, y: int) -> Texture2D:
	var t := AtlasTexture.new()
	t.atlas = atlas
	t.region = Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
	return t
