extends Tile
class_name Plant

func _ready() -> void:
	change_rect("res://assets/panel.png")
	self.scale = Vector2(0.3, 0.3)
