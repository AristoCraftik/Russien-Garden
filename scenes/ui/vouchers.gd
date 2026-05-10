extends Control
class_name Vouchers

signal voucher_purchased(voucher: VoucherData)

const ROW_SCENE: PackedScene = preload("res://scenes/ui/voucher_row.tscn")

@export var min_offers_per_day: int = 1
@export var max_offers_per_day: int = 4

@onready var list: VBoxContainer = $MarginContainer/VBoxContainer/PanelContainer/VBoxContainer

var _daily_offers: Array[VoucherData] = []
var _bought_one_time_ids: Dictionary = {} # id -> true

func _ready() -> void:
	add_to_group("vouchers")
	TimeManager.day_advanced.connect(_on_day_advanced)
	TimeManager.balance_changed.connect(_on_balance_changed)

func _on_day_advanced() -> void:
	_roll_daily_vouchers()

func _on_balance_changed(_new_balance: int) -> void:
	_refresh_buy_buttons()

func _roll_daily_vouchers() -> void:
	_clear_rows()
	_daily_offers.clear()

	var all := _load_all_vouchers()
	if all.is_empty():
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = MarketState.mix_seed(200_003)
	_shuffle_array_with_rng(all, rng)

	var count := rng.randi_range(min_offers_per_day, min(max_offers_per_day, all.size()))
	for i in range(count):
		var v: VoucherData = all[i]
		if v.one_time and _bought_one_time_ids.has(v.voucher_id):
			continue
		_daily_offers.append(v)

	for v in _daily_offers:
		var row := ROW_SCENE.instantiate() as VoucherRow
		list.add_child(row)
		var can_buy := TimeManager.get_balance() >= v.price
		row.setup(v, can_buy)
		row.buy_requested.connect(_on_buy_requested)

func _shuffle_array_with_rng(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _load_all_vouchers() -> Array[VoucherData]:
	var out: Array[VoucherData] = []
	var dir := DirAccess.open("res://resources/vouchers/vouchers")
	if dir == null:
		return out
	for f in dir.get_files():
		if not f.ends_with(".tres"):
			continue
		var path := "res://resources/vouchers/vouchers/%s" % f
		var res := load(path)
		if res is VoucherData:
			out.append(res)
	return out

func _clear_rows() -> void:
	for c in list.get_children():
		c.queue_free()

func _refresh_buy_buttons() -> void:
	var money := TimeManager.get_balance()
	for c in list.get_children():
		if c is VoucherRow:
			var row := c as VoucherRow
			var voucher: VoucherData = row.get_voucher()
			if voucher != null:
				row.set_can_buy(money >= voucher.price)

func _on_buy_requested(voucher: VoucherData) -> void:
	if voucher == null:
		return
	if TimeManager.get_balance() < voucher.price:
		return

	TimeManager.add_coins(-voucher.price)

	if voucher.one_time:
		_bought_one_time_ids[voucher.voucher_id] = true

	for c in list.get_children():
		if c is VoucherRow and (c as VoucherRow).get_voucher() == voucher:
			(c as VoucherRow).hide_price_badge()
			break

	voucher_purchased.emit(voucher)

	# Удаляем купленный из текущего списка и перерисовываем
	for i in range(_daily_offers.size()):
		if _daily_offers[i].voucher_id == voucher.voucher_id:
			_daily_offers.remove_at(i)
			break
	_rebuild_rows_from_current_offers()

func _rebuild_rows_from_current_offers() -> void:
	_clear_rows()
	for v in _daily_offers:
		var row := ROW_SCENE.instantiate() as VoucherRow
		list.add_child(row)
		row.setup(v, TimeManager.get_balance() >= v.price)
		row.buy_requested.connect(_on_buy_requested)
