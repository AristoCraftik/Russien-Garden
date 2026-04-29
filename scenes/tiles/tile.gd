extends Control
class_name Tile

@onready var rect = $MarginContainer/TextureRect

func change_rect(texture):
	rect.texture = load(texture)
