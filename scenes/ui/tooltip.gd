extends Control

@onready var panel: PanelContainer = $Panel
@onready var label: Label = $Panel/Label

const SCREEN_PAD: Vector2 = Vector2(2, 2)


func set_text(t: String) -> void:
	if label:
		label.text = t
	_update_size()


func _update_size() -> void:
	if label == null or panel == null:
		return
	label.size = label.get_minimum_size()
	panel.size = label.size + Vector2(8, 4)
	label.position = Vector2(4, 2)
	size = panel.size


func clamp_inside_viewport(vp: Viewport) -> void:
	if vp == null:
		return
	var r: Rect2 = vp.get_visible_rect()
	var gr: Rect2 = get_global_rect()
	var min_x: float = r.position.x + SCREEN_PAD.x
	var min_y: float = r.position.y + SCREEN_PAD.y
	var max_x: float = r.position.x + r.size.x - gr.size.x - SCREEN_PAD.x
	var max_y: float = r.position.y + r.size.y - gr.size.y - SCREEN_PAD.y
	global_position.x = clampf(global_position.x, min_x, max_x)
	global_position.y = clampf(global_position.y, min_y, max_y)
