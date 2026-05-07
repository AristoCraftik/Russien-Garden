extends CanvasLayer

@onready var fade_label: Label = $Label

var color_rect: ColorRect
var _tween: Tween
var start_mode: String = "new"   # "new" | "load"


func _ready() -> void:
	color_rect = ColorRect.new()
	color_rect.color = Color(0, 0, 0, 1)
	color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color_rect.z_index = -1000
	color_rect.modulate.a = 0.0
	color_rect.visible = false
	add_child(color_rect)

	if fade_label:
		fade_label.modulate.a = 0.0
		fade_label.visible = false


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null


# Затемнение в чёрный + появление текста.
func fade_out(time: float = 0.5) -> void:
	_kill_tween()
	color_rect.visible = true
	color_rect.modulate.a = clamp(color_rect.modulate.a, 0.0, 1.0)
	if fade_label:
		fade_label.modulate.a = 0.0
		fade_label.visible = fade_label.text != ""

	_tween = create_tween()
	_tween.tween_property(color_rect, "modulate:a", 1.0, time)
	if fade_label and fade_label.visible:
		_tween.parallel().tween_property(fade_label, "modulate:a", 1.0, time)
	await _tween.finished


# Возврат: фон тушится, лейбл уходит вместе с ним.
func fade_in(time: float = 0.5) -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(color_rect, "modulate:a", 0.0, time)
	if fade_label and fade_label.visible:
		_tween.parallel().tween_property(fade_label, "modulate:a", 0.0, time)
	await _tween.finished

	color_rect.visible = false
	if fade_label:
		fade_label.visible = false
		fade_label.modulate.a = 0.0


func change_scene_with_fade(
	path: String = "",
	fade_time: float = 0.5,
	hold_time: float = 0.5,
	text: String = ""
) -> void:
	if fade_label:
		fade_label.text = text

	await fade_out(fade_time)
	await get_tree().create_timer(hold_time).timeout

	if path != "":
		get_tree().change_scene_to_file(path)
		await get_tree().process_frame

	await fade_in(fade_time)
