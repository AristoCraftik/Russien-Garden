extends Control

@onready var day_label: Label = $Panel/VBox/Day
@onready var money_label: Label = $Panel/VBox/Money
@onready var quota_label: Label = $Panel/VBox/Quota
@onready var law_label: Label = $Panel/VBox/Law
@onready var inventory_label: Label = $Panel/VBox/Inventory
@onready var seed_menu: OptionButton = $Panel/VBox/SeedMenu

func _ready() -> void:
	GameManager.day_advanced.connect(_on_day_advanced)
	EconomyManager.money_changed.connect(_on_money_changed)
	GameManager.quota_updated.connect(_on_quota_updated)
	LawManager.law_changed.connect(_on_law_changed)
	seed_menu.item_selected.connect(_on_seed_picked)
	_on_day_advanced(GameManager.day, GameManager.week, GameManager.year)
	_on_money_changed(EconomyManager.money)
	_on_quota_updated(GameManager.quota_progress, GameManager.quota_target)

## Обновляет список доступных семян в UI.
func setup_seed_options(ids: Array) -> void:
	seed_menu.clear()
	for id: String in ids:
		seed_menu.add_item(id)

## Обновляет текст инвентаря.
func set_inventory_text(text: String) -> void:
	inventory_label.text = "Инвентарь: %s" % text

func _on_day_advanced(day: int, week: int, year: int) -> void:
	day_label.text = "День %d, Неделя %d, Год %d" % [day, week, year]

func _on_money_changed(value: int) -> void:
	money_label.text = "Деньги: %d" % value

func _on_quota_updated(progress: int, target: int) -> void:
	quota_label.text = "Квота: %d / %d" % [progress, target]

func _on_law_changed(law: LawData) -> void:
	law_label.text = "Закон: %s" % law.description

func _on_seed_picked(index: int) -> void:
	var id: String = seed_menu.get_item_text(index)
	get_tree().call_group("game_scene", "_on_seed_selected", id)
