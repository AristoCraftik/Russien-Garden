extends Tile
class_name bed_tile

var watered = 0

func _ready() -> void:
	change_rect("res://assets/button_defoult.png")


func _on_area_2d_mouse_entered() -> void:
	if watered:
		watered = 0
		change_rect("res://assets/button_pressed.png")
		return

	watered = 1
	change_rect("res://assets/button_defoult.png")
