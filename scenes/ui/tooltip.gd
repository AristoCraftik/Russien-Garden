extends Control

@onready var panel: PanelContainer = $Panel
@onready var label: Label = $Panel/Label

const SCREEN_PAD: Vector2 = Vector2(2, 2)
const APPEAR_OVERSHOOT: float = 1.08
const APPEAR_PHASE1_SEC: float = 0.12
const APPEAR_PHASE2_SEC: float = 0.14
const FADE_OUT_SEC: float = 0.16

var _appear_tween: Tween
var _fade_out_tween: Tween
var _playing_fade_out: bool = false


func _enter_tree() -> void:
	# Подключаем до _ready: иначе первый `visible = true` в том же кадре после add_child
	# срабатывает раньше, чем сработает _ready, и анимация теряется.
	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed() -> void:
	if visible:
		_kill_fade_out_tween()
		_playing_fade_out = false
		modulate.a = 1.0
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


func interrupt_hide_for_show() -> void:
	_kill_fade_out_tween()
	_playing_fade_out = false
	modulate.a = 1.0


## Плавное исчезновение перед скрытием (из item.gd вместо visible = false).
func play_hide() -> void:
	if not visible:
		return
	if _playing_fade_out:
		return
	if is_equal_approx(modulate.a, 0.0):
		_finalize_hide_visuals()
		return
	_kill_appear_tween()
	scale = Vector2.ONE
	_kill_fade_out_tween()
	_playing_fade_out = true
	_fade_out_tween = create_tween()
	_fade_out_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_SEC).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_OUT
	)
	_fade_out_tween.finished.connect(_on_fade_out_finished, CONNECT_ONE_SHOT)


func _on_fade_out_finished() -> void:
	_fade_out_tween = null
	_playing_fade_out = false
	if is_instance_valid(self):
		_finalize_hide_visuals()


func _finalize_hide_visuals() -> void:
	visible = false
	modulate.a = 1.0


func _kill_fade_out_tween() -> void:
	if _fade_out_tween != null:
		_fade_out_tween.kill()
	_fade_out_tween = null


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
