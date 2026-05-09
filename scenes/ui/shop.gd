extends Control
class_name Shop

const ITEM_SCRIPT: GDScript = preload("res://scenes/ui/item.gd")
const ITEM_SIZE := Vector2(32, 32)

## Сколько разных предложений за день (не больше числа слотов в сцене и размера пула).
@export_range(1, 24, 1) var shop_size_max: int = 6
@export var max_stack_per_offer: int = 8

## Дополнительный множитель веса для всех семян (поверх shop_offer_weight у каждого .tres).
@export_range(0.0, 1000.0, 0.01, "or_greater") var seed_shop_weight_mult: float = 1.0
## Дополнительный множитель веса для кроватей-тетрамино.
@export_range(0.0, 1000.0, 0.01, "or_greater") var bed_shop_weight_mult: float = 4.0

@onready var slots_host: GridContainer = $MarginContainer/VBoxContainer/Panel/Slots

var _price_model: PriceModel


func _ready() -> void:
	add_to_group("shop")
	_price_model = PriceModel.new()
	if TimeManager:
		TimeManager.day_advanced.connect(_on_day_advanced)
	# После Game._ready успевает выставить MarketState.set_day(day_counter).
	call_deferred("_roll_daily_offers")


func _on_day_advanced() -> void:
	_roll_daily_offers()


func _roll_daily_offers() -> void:
	_clear_slots()
	var all_items := _load_all_shop_items()
	if all_items.is_empty():
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = int(MarketState.day_seed) * 100003 + 991

	var existing_slots: Array = slots_host.get_children()
	if existing_slots.is_empty():
		return

	var pool := _filter_weighted_shop_pool(all_items)
	if pool.is_empty() and not all_items.is_empty():
		push_warning("Shop: нулевые веса у всех предметов, используем полный пул без фильтра.")
		pool = all_items.duplicate()
	var slot_count: int = existing_slots.size()
	var max_offers: int = mini(pool.size(), slot_count)
	if max_offers <= 0:
		return
	# Заполняем слоты до лимита пула; shop_size_max — верхняя планка (все 6 ячеек при значении 6).
	var offers_count: int = mini(max_offers, shop_size_max)
	var picked: Array[ItemData] = _pick_weighted_without_replacement(pool, offers_count, rng)

	for i in range(existing_slots.size()):
		var clear_slot := existing_slots[i] as Panel
		_clear_slot_visual(clear_slot)

	for i in range(picked.size()):
		var slot := existing_slots[i] as Panel
		var item_data: ItemData = picked[i]

		var qty := 1
		if item_data is SeedData:
			qty = rng.randi_range(1, max_stack_per_offer)

		var unit_price := _calc_shop_price(item_data)
		_create_shop_item(slot, item_data, qty, unit_price)


func _effective_shop_pick_weight(item: ItemData) -> float:
	var w: float = maxf(0.0, item.shop_offer_weight)
	if w <= 0.0:
		return 0.0
	if item is BedTetrominoData:
		return w * bed_shop_weight_mult
	if item is SeedData:
		return w * seed_shop_weight_mult
	return w


func _filter_weighted_shop_pool(all_items: Array[ItemData]) -> Array[ItemData]:
	var out: Array[ItemData] = []
	for item in all_items:
		if _effective_shop_pick_weight(item) > 0.0:
			out.append(item)
	return out


func _pick_weighted_without_replacement(
	pool: Array[ItemData], count: int, rng: RandomNumberGenerator
) -> Array[ItemData]:
	var remaining: Array[ItemData] = pool.duplicate()
	var picks: Array[ItemData] = []
	var n: int = mini(count, remaining.size())
	for _k in range(n):
		var total: float = 0.0
		for item in remaining:
			total += _effective_shop_pick_weight(item)
		var chosen_i: int
		if total <= 0.0:
			chosen_i = rng.randi_range(0, remaining.size() - 1)
		else:
			var roll: float = rng.randf() * total
			var acc: float = 0.0
			chosen_i = remaining.size() - 1
			for i in range(remaining.size()):
				acc += _effective_shop_pick_weight(remaining[i])
				if roll < acc:
					chosen_i = i
					break
		picks.append(remaining[chosen_i])
		remaining.remove_at(chosen_i)
	return picks


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


func _calc_shop_price(item_data: ItemData) -> int:
	if item_data is SeedData:
		var seed := item_data as SeedData
		var rarity := seed.plant.rarity if seed.plant else ""
		var rarity_mult := _price_model.rarity_mult(rarity)
		var sold_balance: int = MarketState.get_sold_balance(seed.resource_path)
		var demand_mult := _price_model.demand_mult(sold_balance)
		var exch: float = MarketState.exchange_mult
		var raw: float = float(seed.base_buy_price) * rarity_mult * demand_mult * exch
		return maxi(1, int(round(raw)))

	if item_data is BedTetrominoData:
		var b := item_data as BedTetrominoData
		return maxi(1, b.base_buy_price)

	return 1


func _create_shop_item(slot: Panel, item_data: ItemData, qty: int, unit_price: int) -> void:
	var item := TextureRect.new()
	item.texture = item_data.get_icon()
	item.custom_minimum_size = ITEM_SIZE
	item.size = ITEM_SIZE
	item.mouse_filter = Control.MOUSE_FILTER_STOP
	item.stretch_mode = TextureRect.STRETCH_SCALE
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.set_script(ITEM_SCRIPT)
	item.set_item_data(item_data, qty, false)
	slot.add_child(item)

	if slot.has_method("attach_stack_label_to_item"):
		slot.call("attach_stack_label_to_item", item)
	if slot.has_method("reorder_stack_label_top"):
		slot.call("reorder_stack_label_top")

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
	price_lbl.text = "$%d" % (unit_price * qty)
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
		
func _load_all_shop_items() -> Array[ItemData]:
	var out: Array[ItemData] = []

	# Seeds
	var dir_seeds := DirAccess.open("res://resources/items/seeds/")
	if dir_seeds:
		for f in dir_seeds.get_files():
			if f.ends_with(".tres"):
				var r := load("res://resources/items/seeds/%s" % f)
				if r is ItemData:
					out.append(r)

	# Bed tetrominoes
	var dir_beds := DirAccess.open("res://resources/items/bed_tetrominoes/")
	if dir_beds:
		for f in dir_beds.get_files():
			if f.ends_with(".tres"):
				var r := load("res://resources/items/bed_tetrominoes/%s" % f)
				if r is ItemData:
					out.append(r)

	return out
