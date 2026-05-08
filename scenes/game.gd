extends Control

@onready var camera: Camera2D = $Camera2D
@onready var field: Node2D = $Field
@onready var inventory: Node = $CanvasLayer/MarginContainer/VBoxContainer/Inventory
@onready var money_label: Label = $CanvasLayer/MarginContainer3/BottomRow/PanelContainer/MoneyLabel
@onready var day_label: Label = $CanvasLayer/MarginContainer3/BottomRow/DayContainer/DayLabel
@onready var next_day_button: Button = $CanvasLayer/MarginContainer2/HBoxContainer/NextDayButton
@onready var quit_button: Button = $CanvasLayer/MarginContainer2/HBoxContainer/QuitToMenuButton

const STARTER_STACK: int = 1
const NIGHT_SCENE: String = "res://scenes/ui/night.tscn"

var day_counter: int = 0
var _is_transitioning: bool = false


func _ready() -> void:
	# Общая зона локальных координат для drag-copy предметов (инвентарь, мусорка, продажи).
	var ui_drag_root: Control = $CanvasLayer/DragOverlay
	ui_drag_root.add_to_group("ui_drag_root")
	TimeManager.balance_changed.connect(_on_economy_balance_changed)
	_on_economy_balance_changed(TimeManager.get_balance())
	_update_day_label()
	add_to_group("i18n")
	_apply_i18n()
	# Иначе MarginContainer перехватывает клики по всему экрану, и поле не получает сбор/полив.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if FadeManager.start_mode == "load":
		await _load_game()
	else:
		TimeManager.set_balance(0)
		await get_tree().process_frame
		_spawn_starter_inventory()
	# Сбрасываем режим, чтобы повторный вход в эту сцену не падал в "load".
	FadeManager.start_mode = "new"


func _on_economy_balance_changed(balance: int) -> void:
	if is_instance_valid(money_label):
		money_label.text = tr("MONEY_FMT") % balance


func _apply_i18n() -> void:
	if is_instance_valid(next_day_button):
		next_day_button.text = tr("GAME_NEXT_DAY")
	if is_instance_valid(quit_button):
		quit_button.text = tr("GAME_QUIT_TO_MENU")
	_on_economy_balance_changed(TimeManager.get_balance())
	_update_day_label()


func _update_day_label() -> void:
	if is_instance_valid(day_label):
		day_label.text = "Day: %d" % day_counter


func _spawn_starter_inventory() -> void:
	if inventory == null:
		return
	if not inventory.has_method("try_add_items"):
		return
	# Стартовый инструмент: лейка.
	var wc: Resource = load("res://resources/items/tools/watering_can.tres")
	if wc is ItemData:
		inventory.try_add_items(wc as ItemData, 1, Vector2.INF)
	var dir := DirAccess.open("res://resources/items/seeds/")
	if dir == null:
		return
	var names: Array = Array(dir.get_files())
	names.sort()
	for f in names:
		if not f.ends_with(".tres"):
			continue
		var path: String = "res://resources/items/seeds/%s" % f
		var res: Resource = load(path)
		if res is SeedData:
			var seed_data: SeedData = res
			var n: int = mini(STARTER_STACK, seed_data.stack_size)
			if not inventory.try_add_items(seed_data as ItemData, n, Vector2.INF):
				break


func _load_game() -> void:
	var save: Dictionary = TimeManager.load_game()
	if save.is_empty():
		# Сейва нет — играем как новая игра.
		TimeManager.set_balance(0)
		await get_tree().process_frame
		_spawn_starter_inventory()
		return

	day_counter = int(save.get("day", 0))
	TimeManager.set_balance(int(save.get("coins", 0)))
	_update_day_label()

	for plant_entry in save.get("plants", []):
		if typeof(plant_entry) != TYPE_DICTIONARY:
			continue
		var id_path: String = str(plant_entry.get("id", ""))
		if id_path.is_empty():
			continue
		var data: Resource = load(id_path)
		if not (data is PlantData):
			continue
		var cell: Vector2i = plant_entry.get("cell", Vector2i.ZERO)
		var stage: int = int(plant_entry.get("stage", 0))
		# Старые сейвы: зрелость записывали как stage == grow_days; теперь последний кадр — grow_days - 1.
		var cap: int = maxi(data.grow_days, 1) - 1
		if stage > cap:
			stage = cap
		var watered: bool = bool(plant_entry.get("watered", false))
		field.plant_seed(cell, data, stage, watered, plant_entry)

	if inventory:
		await get_tree().process_frame
		inventory.load_save_data(save.get("inventory", []))
	var trash_can: Node = get_tree().get_first_node_in_group("trash_can")
	if trash_can and trash_can.has_method("load_save_data"):
		trash_can.call("load_save_data", save.get("trash", {}))
	var sell_box: Node = get_tree().get_first_node_in_group("sell_box")
	if sell_box and sell_box.has_method("load_save_data"):
		sell_box.call("load_save_data", save.get("sell", []))


func _on_quit_to_menu_button_button_up() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	# Сохраняем перед выходом, чтобы не терять прогресс.
	TimeManager.save_all(day_counter)
	FadeManager.change_scene_with_fade("res://scenes/main.tscn", 0.5, 0.5, "Main menu")


func _on_next_day_button_button_up() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_set_buttons_enabled(false)

	day_counter += 1
	_update_day_label()
	TimeManager.next_day(day_counter)
	# Переходим на экран ночи (там покажем заработок/траты).
	FadeManager.change_scene_with_fade(NIGHT_SCENE, 0.5, 0.0, "")
	_set_buttons_enabled(true)
	_is_transitioning = false


func _set_buttons_enabled(enabled: bool) -> void:
	if is_instance_valid(next_day_button):
		next_day_button.disabled = not enabled
	if is_instance_valid(quit_button):
		quit_button.disabled = not enabled
