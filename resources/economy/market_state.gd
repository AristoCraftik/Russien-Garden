class_name Market
extends Node

signal market_changed

var day_seed: int = 0
## Сид забега: участвует во всех RNG, чтобы катки отличались при том же дне.
var run_seed: int = 0
var exchange_mult: float = 1.0
var sold_balance_by_item: Dictionary = {} # key: item.resource_path -> int

var _gameplay_rng: RandomNumberGenerator


func set_run_seed(seed: int) -> void:
	run_seed = int(seed)


func get_run_seed() -> int:
	return run_seed


func mix_seed(salt: int) -> int:
	var h: int = hash(Vector3i(run_seed, day_seed, salt))
	if h == 0:
		h = 917_513
	return h


func reset_gameplay_rng_for_run() -> void:
	if _gameplay_rng == null:
		_gameplay_rng = RandomNumberGenerator.new()
	_gameplay_rng.seed = hash(Vector2i(run_seed + 7, 5407))


func apply_gameplay_rng_state_from_save(state: Variant) -> void:
	if _gameplay_rng == null:
		_gameplay_rng = RandomNumberGenerator.new()
	if state == null:
		reset_gameplay_rng_for_run()
		return
	if state is int:
		var si: int = int(state)
		if si == 0:
			reset_gameplay_rng_for_run()
		else:
			_gameplay_rng.set_state(si)
		return
	# Старый формат (массив) или пустой массив из сейва.
	if state is Array:
		var arr: Array = state as Array
		if arr.is_empty():
			reset_gameplay_rng_for_run()
		else:
			_gameplay_rng.set_state(int(arr[0]))
		return
	reset_gameplay_rng_for_run()


func get_gameplay_rng_state_for_save() -> int:
	if _gameplay_rng == null:
		return 0
	return int(_gameplay_rng.get_state())


func roll_yield(lo: int, hi: int) -> int:
	if _gameplay_rng == null:
		reset_gameplay_rng_for_run()
	return _gameplay_rng.randi_range(lo, hi)


func set_day(day: int) -> void:
	day_seed = day
	_rebuild_exchange_mult()
	market_changed.emit()


func _rebuild_exchange_mult() -> void:
	# Биржа дня: от 0.85 до 1.20
	var rng := RandomNumberGenerator.new()
	rng.seed = mix_seed(92821)
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
