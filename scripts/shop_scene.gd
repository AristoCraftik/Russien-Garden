extends Control

@onready var buy_info: Label = $Panel/VBox/BuyInfo
@onready var sell_info: Label = $Panel/VBox/SellInfo

func _ready() -> void:
	_refresh()

func _refresh() -> void:
	buy_info.text = "Цены: %s" % JSON.stringify(EconomyManager.price_table)
	sell_info.text = "Продано на неделе: %s" % JSON.stringify(EconomyManager.sold_this_week)

func _on_close_pressed() -> void:
	queue_free()
