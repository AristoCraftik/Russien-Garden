extends Node

signal day_advanced
signal clear_watered_tiles
signal balance_changed(new_balance: int)
signal water_supply_changed(current: int, capacity: int)
signal day_financials(day: int, earned: int, spent: int, watering_spent: int, quota_spent: int)

const SAVE_PATH := "user://garden/game_data.cfg"
const SAVE_VERSION := 5

var _coins: int = 0

const DAILY_QUOTA_COST: int = 10
const WATER_COST: int = 1
## Запас воды для полива лейкой (не путать с WATER_COST — монеты за ночь).
const WATER_TANK_CAPACITY: int = 20

var _pending_watering_count: int = 0
var _active_tool: Resource = null
var _water_units: int = WATER_TANK_CAPACITY


func set_balance(value: int) -> void:
	_coins = maxi(value, 0)
	balance_changed.emit(_coins)


func add_coins(amount: int) -> void:
	if amount == 0:
		return
	_coins += amount
	balance_changed.emit(_coins)


func get_balance() -> int:
	return _coins


func set_active_tool(tool: Resource) -> void:
	_active_tool = tool


func get_active_tool() -> Resource:
	return _active_tool


func register_watering_action() -> void:
	_pending_watering_count += 1


func get_water_tank_capacity() -> int:
	return WATER_TANK_CAPACITY


func get_water_units() -> int:
	return _water_units


func has_water_for_watering() -> bool:
	return _water_units > 0


func consume_water_unit(amount: int = 1) -> void:
	if amount <= 0:
		return
	_water_units = maxi(0, _water_units - amount)
	water_supply_changed.emit(_water_units, WATER_TANK_CAPACITY)


func refill_water_tank_for_new_day() -> void:
	_water_units = WATER_TANK_CAPACITY
	water_supply_changed.emit(_water_units, WATER_TANK_CAPACITY)


func set_water_units_from_save(value: int) -> void:
	_water_units = clampi(int(value), 0, WATER_TANK_CAPACITY)
	water_supply_changed.emit(_water_units, WATER_TANK_CAPACITY)


func _ready() -> void:
	_wipe_save_file()


func _wipe_save_file() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var err := DirAccess.remove_absolute(SAVE_PATH)
		if err != OK:
			push_warning("TimeManager: could not remove old save (%d)" % err)


## Временно: без переноса старых версий — файл сейва сбрасывается при каждом запуске (см. _ready).
func load_game() -> Dictionary:
	var config := ConfigFile.new()
	var err: int = config.load(SAVE_PATH)
	if err != OK:
		return {}
	return {
		"version":           int(config.get_value("game", "version", SAVE_VERSION)),
		"day":               int(config.get_value("game", "day", 0)),
		"plants":            config.get_value("game", "plants", []),
		"inventory":         config.get_value("game", "inventory", []),
		"coins":             int(config.get_value("game", "coins", 0)),
		"trash":             config.get_value("game", "trash", {}),
		"sell":              config.get_value("game", "sell", []),
		"field":             config.get_value("game", "field", {}),
		"run_seed":          int(config.get_value("game", "run_seed", 0)),
		"market_rng_state":  config.get_value("game", "market_rng_state", 0),
		"water_units":       int(config.get_value("game", "water_units", WATER_TANK_CAPACITY)),
	}


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func next_day(day_counter: int) -> Dictionary:
	refill_water_tank_for_new_day()
	if is_instance_valid(MarketState):
		MarketState.set_day(day_counter)
	# Доход: всё, что начислилось при day_advanced (например, продажа).
	var before: int = get_balance()
	day_advanced.emit()
	var after_income: int = get_balance()
	var earned: int = maxi(after_income - before, 0)

	# Расходы снимаем между днями.
	var watering_spent: int = _pending_watering_count * WATER_COST
	var quota_spent: int = DAILY_QUOTA_COST
	var spent: int = watering_spent + quota_spent
	set_balance(maxi(after_income - spent, 0))

	# Сбрасываем счётчик на новый день.
	_pending_watering_count = 0

	clear_watered_tiles.emit()
	save_all(day_counter, _collect_plants(), _collect_inventory())

	day_financials.emit(day_counter, earned, spent, watering_spent, quota_spent)
	return {
		"earned": earned,
		"spent": spent,
		"watering_spent": watering_spent,
		"quota_spent": quota_spent,
		"balance": get_balance(),
	}


func save_all(day_counter: int, plants_snapshot: Array = [], inventory_snapshot: Array = []) -> bool:
	if plants_snapshot.is_empty():
		plants_snapshot = _collect_plants()
	if inventory_snapshot.is_empty():
		inventory_snapshot = _collect_inventory()
	var config := ConfigFile.new()
	config.set_value("game", "version", SAVE_VERSION)
	config.set_value("game", "day", day_counter)
	config.set_value("game", "plants", plants_snapshot)
	config.set_value("game", "inventory", inventory_snapshot)
	config.set_value("game", "coins", get_balance())
	config.set_value("game", "trash", _collect_trash())
	config.set_value("game", "sell", _collect_sell())
	config.set_value("game", "field", _collect_field())
	if is_instance_valid(MarketState):
		config.set_value("game", "run_seed", MarketState.get_run_seed())
		config.set_value("game", "market_rng_state", MarketState.get_gameplay_rng_state_for_save())
	config.set_value("game", "water_units", get_water_units())
	var dir_err: int = DirAccess.make_dir_recursive_absolute(SAVE_PATH.get_base_dir())
	if dir_err != OK and dir_err != ERR_ALREADY_EXISTS:
		push_error("TimeManager: cannot create save dir (%d)" % dir_err)
		return false
	var save_err: int = config.save(SAVE_PATH)
	if save_err != OK:
		push_error("TimeManager: save error %d" % save_err)
		return false
	return true


func _collect_plants() -> Array:
	var field: Node = get_tree().get_first_node_in_group("field") if get_tree() else null
	if field and field.has_method("get_plants_save_data"):
		return field.get_plants_save_data()
	return []


func _collect_field() -> Dictionary:
	var field: Node = get_tree().get_first_node_in_group("field") if get_tree() else null
	if field and field.has_method("get_field_save_state"):
		return field.call("get_field_save_state")
	return {}


func _collect_inventory() -> Array:
	var inventory: Node = get_tree().get_first_node_in_group("inventory") if get_tree() else null
	if inventory and inventory.has_method("get_save_data"):
		return inventory.get_save_data()
	return []


func _collect_trash() -> Dictionary:
	var trash: Node = get_tree().get_first_node_in_group("trash_can") if get_tree() else null
	if trash and trash.has_method("get_save_data"):
		var d = trash.call("get_save_data")
		return d if d is Dictionary else {}
	return {}


func _collect_sell() -> Array:
	var sell_box: Node = get_tree().get_first_node_in_group("sell_box") if get_tree() else null
	if sell_box and sell_box.has_method("get_save_data"):
		var arr = sell_box.call("get_save_data")
		return arr if arr is Array else []
	return []
