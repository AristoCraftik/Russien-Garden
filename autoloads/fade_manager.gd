extends CanvasLayer

@onready var fade_label = $Label

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
	fade_label.visible = false


func fade_out(time := 0.5):
	if tween:
		tween.kill()

	tween = create_tween()
	color_rect.visible = true
	fade_label.visible = true

	tween.tween_property(color_rect, "modulate:a", 1.0, time)
	tween.parallel().tween_property(fade_label, "modulate:a", 1.0, time)

	await tween.finished


func fade_in(time := 0.5, text_delay := 0.4):
	if tween:
		tween.kill()

	tween = create_tween()

	# фон появляется сразу
	tween.tween_property(color_rect, "modulate:a", 0.0, time)

	# текст сначала ждёт, потом появляется
	tween.parallel().tween_callback(func():
		await get_tree().create_timer(text_delay).timeout
		if fade_label:
			fade_label.modulate.a = 0.0
			fade_label.visible = true

			var t = create_tween()
			t.tween_property(fade_label, "modulate:a", 1.0, time - text_delay)
	)

	await tween.finished

	color_rect.visible = false


func change_scene_with_fade(
	path: String = "",
	fade_time := 0.5,
	hold_time := 0.5,
	text: String = ""
):
	color_rect.visible = true

	# показать текст (если есть Label и текст задан)
	if fade_label:
		if text != "":
			fade_label.text = text
			fade_label.visible = true
		else:
			fade_label.visible = false

	# затемнение
	await fade_out(fade_time)

	# пауза на чёрном экране
	await get_tree().create_timer(hold_time).timeout

	# смена сцены (если путь есть)
	if path != "":
		get_tree().change_scene_to_file(path)
		await get_tree().process_frame

	# если сцена не менялась — просто держим экран

	# возврат
	await fade_in(fade_time)

	if fade_label:
		fade_label.visible = false
