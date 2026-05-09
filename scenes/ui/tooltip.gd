extends Control

@onready var panel: PanelContainer = $Panel
@onready var label: Label = $Panel/Label

const SCREEN_PAD: Vector2 = Vector2(2, 2)
const APPEAR_OVERSHOOT: float = 1.08
const APPEAR_PHASE1_SEC: float = 0.12
const APPEAR_PHASE2_SEC: float = 0.14

var _appear_tween: Tween


func _enter_tree() -> void:
	# Подключаем до _ready: иначе первый `visible = true` в том же кадре после add_child
	# срабатывает раньше, чем сработает _ready, и анимация теряется.
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed() -> void:
	if visible:
		pivot_offset = Vector2.ZERO
		scale = Vector2.ZERO
		_kill_appear_tween()
		_appear_tween = create_tween()
		_appear_tween.tween_property(self, "scale", Vector2.ONE * APPEAR_OVERSHOOT, APPEAR_PHASE1_SEC).set_trans(
			Tween.TRANS_QUAD
		).set_ease(Tween.EASE_OUT)
		_appear_tween.tween_property(self, "scale", Vector2.ONE, APPEAR_PHASE2_SEC).set_trans(Tween.TRANS_BACK).set_ease(
			Tween.EASE_OUT
		)
	else:
		_kill_appear_tween()
		scale = Vector2.ONE


func _kill_appear_tween() -> void:
	if _appear_tween != null:
		_appear_tween.kill()
	_appear_tween = null


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
