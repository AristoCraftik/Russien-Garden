extends CanvasLayer

var color_rect: ColorRect
var tween: Tween
var start_mode = "new" # или "load"

func _ready():
	color_rect = ColorRect.new()
	color_rect.color = Color(0, 0, 0, 1)
	color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color_rect.z_index = -1000
	color_rect.visible = false
	add_child(color_rect)
	color_rect.modulate.a = 0.0


func fade_out(time := 0.5):
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(color_rect, "modulate:a", 1.0, time)
	await tween.finished


func fade_in(time := 0.5):
	
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(color_rect, "modulate:a", 0.0, time)
	await tween.finished
	
	color_rect.visible = false


func change_scene_with_fade(path: String, time := 0.5):
	color_rect.visible = true
	await fade_out(time)
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await fade_in(time)
