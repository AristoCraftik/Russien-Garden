extends PanelContainer
class_name VoucherRow

signal buy_requested(voucher: VoucherData)

@onready var name_label: Label = $MarginContainer/HBoxContainer/NameLabel
@onready var buy_button: Button = $MarginContainer/HBoxContainer/BuyButton
@onready var price_panel: Panel = $Panel
@onready var price_label: Label = $Panel/PriceLabel

const TOOLTIP_DELAY: float = 0.25
const TOOLTIP_SCENE: PackedScene = preload("res://scenes/ui/tooltip.tscn")

var _tooltip: Control = null
var _tooltip_layer: Node = null
var _mouse_over: bool = false
var _tooltip_timer: float = 0.0
var _tip_text: String = ""
var _voucher: VoucherData


func setup(voucher: VoucherData, can_buy: bool = true) -> void:
	_voucher = voucher

	name_label.text = voucher.title
	price_label.text = "$%d" % voucher.price
	buy_button.disabled = not can_buy

	# Tooltip с описанием ваучера
	_tip_text = voucher.description.strip_edges()
	if _tip_text.is_empty():
		_tip_text = voucher.title
		
	price_label.text = "$%d" % voucher.price

	await get_tree().process_frame
	if not is_instance_valid(price_panel) or not is_instance_valid(price_label):
		return

	var pad := Vector2(4, 1)
	var text_size: Vector2 = price_label.get_minimum_size()
	var badge_size := (text_size + pad * 2.0) * Vector2(2, 1)

	price_panel.size = badge_size
	price_label.position = pad
	price_label.size = text_size
	
	price_label.position = Vector2(
		(price_panel.size.x - text_size.x) * 0.5,
		(price_panel.size.y - text_size.y) * 0.5
	)

	price_panel.position = Vector2(
		(size.x - badge_size.x) * 0.5,
		size.y - badge_size.y * 0.5 - 5.0
	)
	
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.94, 0.68, 0.02, 0.95)
	sb.corner_radius_top_left = 5
	sb.corner_radius_top_right = 5
	sb.corner_radius_bottom_left = 5
	sb.corner_radius_bottom_right = 5
	price_panel.add_theme_stylebox_override("panel", sb)


func set_can_buy(value: bool) -> void:
	buy_button.disabled = not value


func _ready() -> void:
	buy_button.pressed.connect(_on_buy_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	tree_exiting.connect(_on_tree_exiting)


func _on_buy_pressed() -> void:
	if _voucher != null:
		buy_requested.emit(_voucher)


func get_voucher() -> VoucherData:
	return _voucher


func hide_price_badge() -> void:
	var pp: Node = get_node_or_null("Panel")
	if pp != null:
		pp.queue_free()

	
func _process(delta: float) -> void:
	if _mouse_over:
		_tooltip_timer -= delta
		if _tooltip_timer <= 0.0 and (_tooltip == null or not _tooltip.visible):
			_show_tooltip()
	else:
		if _tooltip:
			_hide_tooltip()

func _on_mouse_entered() -> void:
	_mouse_over = true
	_tooltip_timer = TOOLTIP_DELAY

func _on_mouse_exited() -> void:
	_mouse_over = false
	_tooltip_timer = 0.0
	_hide_tooltip()

func _on_tree_exiting() -> void:
	_destroy_tooltip()

func _ensure_tooltip() -> void:
	if is_instance_valid(_tooltip):
		return
	_tooltip = TOOLTIP_SCENE.instantiate() if TOOLTIP_SCENE else Control.new()
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var layer: Node = get_parent()
	while layer and not (layer is CanvasLayer):
		layer = layer.get_parent()
	if layer == null:
		layer = get_tree().root
	_tooltip_layer = layer

func _show_tooltip() -> void:
	if _tip_text.is_empty():
		return
	_ensure_tooltip()
	if _tooltip.get_parent() != _tooltip_layer:
		if _tooltip.get_parent():
			_tooltip.get_parent().remove_child(_tooltip)
		_tooltip_layer.add_child(_tooltip)
	_tooltip_layer.move_child(_tooltip, _tooltip_layer.get_child_count() - 1)

	if _tooltip.has_method("set_text"):
		_tooltip.call("set_text", _tip_text)

	var r: Rect2 = get_global_rect()
	var tip_size: Vector2 = _tooltip.size
	_tooltip.global_position = r.position + Vector2(r.size.x + 4.0, tip_size.y)

	if _tooltip.has_method("clamp_inside_viewport"):
		_tooltip.call("clamp_inside_viewport", get_viewport())

	_tooltip.visible = true

func _hide_tooltip() -> void:
	if is_instance_valid(_tooltip):
		_tooltip.visible = false

func _destroy_tooltip() -> void:
	if is_instance_valid(_tooltip):
		_tooltip.queue_free()
	_tooltip = null
