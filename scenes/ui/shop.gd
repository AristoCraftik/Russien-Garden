extends Control
class_name Shop

const ITEM_SCRIPT: GDScript = preload("res://scenes/ui/item.gd")
const ITEM_SIZE := Vector2(32, 32)

@export var shop_size_min: int = 3
@export var shop_size_max: int = 6
@export var max_stack_per_offer: int = 8

@onready var slots_host: GridContainer = $MarginContainer/VBoxContainer/Panel/Slots

var _price_model: PriceModel


func _ready() -> void:
	add_to_group("shop")
	_price_model = PriceModel.new()
	if TimeManager:
		TimeManager.day_advanced.connect(_on_day_advanced)
	_roll_daily_offers()


func _on_day_advanced() -> void:
	_roll_daily_offers()


func _roll_daily_offers() -> void:
	_clear_slots()
	var all_seeds := _load_all_seed_data()
	if all_seeds.is_empty():
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = int(MarketState.day_seed) * 100003 + 991

	var existing_slots: Array = slots_host.get_children()
	if existing_slots.is_empty():
		return

	var offers_count := rng.randi_range(
		shop_size_min,
		min(shop_size_max, min(all_seeds.size(), existing_slots.size()))
	)
	all_seeds.shuffle()

	for i in range(existing_slots.size()):
		var slot := existing_slots[i] as Panel
		_clear_slot_visual(slot)

	for i in range(offers_count):
		var seed: SeedData = all_seeds[i]
		var slot := existing_slots[i] as Panel
		var qty := rng.randi_range(1, max_stack_per_offer)
		var unit_price := _calc_seed_price(seed)
		_create_shop_item(slot, seed, qty, unit_price)


func _load_all_seed_data() -> Array:
	var result: Array = []
	var dir := DirAccess.open("res://resources/items/seeds/")
	if dir == null:
		return result
	for f in dir.get_files():
		if not f.ends_with(".tres"):
			continue
		var res := load("res://resources/items/seeds/%s" % f)
		if res is SeedData:
			result.append(res)
	return result


func _calc_seed_price(seed: SeedData) -> int:
	if seed == null:
		return 1
	var rarity := ""
	if seed.plant:
		rarity = seed.plant.rarity
	var rarity_mult := _price_model.rarity_mult(rarity)
	var sold_balance := MarketState.get_sold_balance(seed.resource_path)
	var demand_mult := _price_model.demand_mult(sold_balance)
	var exch := MarketState.exchange_mult
	var raw := float(seed.base_buy_price) * rarity_mult * demand_mult * exch
	return maxi(1, int(round(raw)))


func _create_shop_item(slot: Panel, seed: SeedData, qty: int, unit_price: int) -> void:
	var item := TextureRect.new()
	item.texture = seed.get_icon()
	item.custom_minimum_size = ITEM_SIZE
	item.size = ITEM_SIZE
	item.mouse_filter = Control.MOUSE_FILTER_STOP
	item.stretch_mode = TextureRect.STRETCH_SCALE
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.set_script(ITEM_SCRIPT)
	slot.add_child(item)

	if slot.has_method("attach_stack_label_to_item"):
		slot.call("attach_stack_label_to_item", item)
	if slot.has_method("reorder_stack_label_top"):
		slot.call("reorder_stack_label_top")

	item.set_item_data(seed, qty, false)
	if item.has_method("setup_shop_item"):
		item.setup_shop_item(unit_price)

	# Компактный ценник по центру снизу
	var price_panel := Panel.new()
	price_panel.name = "PricePanel"
	price_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_panel.anchor_left = 0.0
	price_panel.anchor_top = 0.0
	price_panel.anchor_right = 0.0
	price_panel.anchor_bottom = 0.0

	# Кастомный фон, чтобы не зависеть от большой темы PanelContainer
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.94, 0.68, 0.02, 0.95)
	sb.corner_radius_top_left = 5
	sb.corner_radius_top_right = 5
	sb.corner_radius_bottom_left = 5
	sb.corner_radius_bottom_right = 5
	price_panel.add_theme_stylebox_override("panel", sb)

	slot.add_child(price_panel)

	var price_lbl := Label.new()
	price_lbl.name = "PriceLabel"
	price_lbl.text = "$%d" % unit_price
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_panel.add_child(price_lbl)

	await get_tree().process_frame

	var pad := Vector2(4, 1)
	var text_size: Vector2 = price_lbl.get_minimum_size()
	var badge_size := text_size + pad * 2.0

	price_panel.size = badge_size
	price_lbl.position = pad
	price_lbl.size = text_size

	price_panel.position = Vector2(
		(slot.size.x - badge_size.x) * 0.5,
		slot.size.y - badge_size.y / 2.0
	)

	item.position = (slot.size - item.size) / 2.0


func _clear_slots() -> void:
	for c in slots_host.get_children():
		_clear_slot_visual(c as Panel)


func _clear_slot_visual(slot: Panel) -> void:
	if slot == null:
		return
	for child in slot.get_children():
		if child.name == "StackLabel":
			continue
		child.queue_free()
	var stack_lbl := slot.get_node_or_null("StackLabel")
	if stack_lbl is Label:
		(stack_lbl as Label).visible = false
		(stack_lbl as Label).text = ""
