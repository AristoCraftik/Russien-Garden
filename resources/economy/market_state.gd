class_name Market
extends Node

signal market_changed

var day_seed: int = 0
var exchange_mult: float = 1.0
var sold_balance_by_item: Dictionary = {} # key: item.resource_path -> int

func set_day(day: int) -> void:
	day_seed = day
	_rebuild_exchange_mult()
	market_changed.emit()

func _rebuild_exchange_mult() -> void:
	# Биржа дня: от 0.85 до 1.20
	var rng := RandomNumberGenerator.new()
	rng.seed = int(day_seed) * 92821 + 17
	exchange_mult = rng.randf_range(0.85, 1.20)

func register_sale(item_path: String, qty: int) -> void:
	if item_path.is_empty() or qty <= 0:
		return
	sold_balance_by_item[item_path] = int(sold_balance_by_item.get(item_path, 0)) + qty
	market_changed.emit()

func register_buy(item_path: String, qty: int) -> void:
	if item_path.is_empty() or qty <= 0:
		return
	sold_balance_by_item[item_path] = int(sold_balance_by_item.get(item_path, 0)) - qty
	market_changed.emit()

func get_sold_balance(item_path: String) -> int:
	return int(sold_balance_by_item.get(item_path, 0))
