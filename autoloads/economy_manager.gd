extends Node
class_name EconomyManager

signal money_changed(value: int)

const DEFLATION_PER_UNIT: float = 0.92

var money: int = 50
var price_table: Dictionary = {}
var sold_this_week: Dictionary = {}

## Инициализирует цену предмета.
func register_price(item_id: String, base_price: int) -> void:
	if not price_table.has(item_id):
		price_table[item_id] = base_price

## Продает предмет и возвращает выручку.
func sell(item_id: String, qty: int) -> int:
	var total: int = 0
	var current: float = float(price_table.get(item_id, 1))
	for _i: int in range(qty):
		total += int(round(current))
		current *= DEFLATION_PER_UNIT
	price_table[item_id] = max(1, int(round(current)))
	sold_this_week[item_id] = int(sold_this_week.get(item_id, 0)) + qty
	money += total
	emit_signal("money_changed", money)
	return total

## Покупает предмет и возвращает успех операции.
func buy(item_id: String, qty: int) -> bool:
	var price: int = int(price_table.get(item_id, 1)) * qty
	if money < price:
		return false
	money -= price
	emit_signal("money_changed", money)
	return true

## Сбрасывает недельную дефляцию.
func reset_weekly_prices() -> void:
	sold_this_week.clear()
