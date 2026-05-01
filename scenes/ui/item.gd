extends TextureRect

var dragging: bool = false
var drag_copy: TextureRect
var origin_position: Vector2

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	set_process_input(true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			start_drag()

func _input(event: InputEvent) -> void:
	if dragging and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			end_drag()
			get_viewport().set_input_as_handled()

func start_drag() -> void:
	dragging = true
	
	origin_position = global_position
	
	hide()
	
	drag_copy = TextureRect.new()
	drag_copy.texture = texture
	drag_copy.expand_mode = expand_mode
	drag_copy.size = size * 0.6
	drag_copy.modulate = Color(1, 1, 1, 0.9)
	drag_copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().root.add_child(drag_copy)
	drag_copy.global_position = get_global_mouse_position() - (size * 0.6) / 2

func _process(_delta: float) -> void:
	if dragging and drag_copy:
		drag_copy.global_position = get_global_mouse_position() - (size * 0.6) / 2

func end_drag() -> void:
	if not dragging: return
	dragging = false
	
	if not drag_copy: return
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(drag_copy, "global_position", origin_position, 0.3)
	
	tween.tween_callback(func():
		if drag_copy:
			drag_copy.queue_free()
			drag_copy = null
			
		show()
	)
