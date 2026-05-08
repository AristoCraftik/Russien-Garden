class_name PriceModel
extends Resource

@export var rarity_multipliers: Dictionary = {
	"common": 1.0,
	"uncommon": 1.2,
	"rare": 1.5,
	"epic": 2.0,
	"legendary": 3.0
}

@export var demand_step: float = 0.05
@export var min_demand_mult: float = 0.7
@export var max_demand_mult: float = 1.8

func rarity_mult(rarity: String) -> float:
	var key := rarity.strip_edges().to_lower()
	return float(rarity_multipliers.get(key, 1.0))

func demand_mult(net_sold: int) -> float:
	# net_sold > 0 => много продали, цена падает
	# net_sold < 0 => дефицит, цена растет
	var mult := 1.0 - float(net_sold) * demand_step
	return clampf(mult, min_demand_mult, max_demand_mult)
