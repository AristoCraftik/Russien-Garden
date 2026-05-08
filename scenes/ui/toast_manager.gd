extends Control

@onready var panel: Control = $Panel
@onready var label: Label = $Panel/Label

const SHOW_TIME: float = 1.7
const FADE_TIME: float = 0.25

var _tween: Tween = null


func _ready() -> void:
	add_to_group("toast_manager")
	_hide_immediate()


func show_toast(text: String) -> void:
	if label:
		label.text = text
	if _tween and is_instance_valid(_tween):
		_tween.kill()
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_set_visible_alpha(1.0)
	visible = true
	_tween.tween_interval(SHOW_TIME)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	_tween.tween_callback(_hide_immediate)


func _set_visible_alpha(a: float) -> void:
	modulate.a = a


func _hide_immediate() -> void:
	visible = false
	modulate.a = 0.0
