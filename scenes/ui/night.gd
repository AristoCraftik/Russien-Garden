extends CanvasLayer

@onready var day_label: Label = $PanelContainer/VBoxContainer/DayCount

@onready var earned_section: VBoxContainer = $PanelContainer/VBoxContainer/EarnedContainer
@onready var spent_section: VBoxContainer = $PanelContainer/VBoxContainer/SpentContainer
@onready var summary: VBoxContainer = $PanelContainer/VBoxContainer/SummaryContainer

@onready var earned_template: HBoxContainer = $PanelContainer/VBoxContainer/EarnedContainer/HBoxContainer
@onready var spent_template: HBoxContainer = $PanelContainer/VBoxContainer/SpentContainer/HBoxContainer

@onready var total_earned_value: Label = $PanelContainer/VBoxContainer/SummaryContainer/HBoxContainer/MoneyCount
@onready var total_spent_value: Label = $PanelContainer/VBoxContainer/SummaryContainer/HBoxContainer2/MoneyCount
@onready var total_balance_value: Label = $PanelContainer/VBoxContainer/SummaryContainer/HBoxContainer3/MoneyCount

@onready var main_container: PanelContainer = $PanelContainer
@onready var documents_container: PanelContainer = $DocumentsContainer
@onready var texture_rect: TextureRect = $DocumentsContainer/VBoxContainer/HBoxContainer/VBoxContainer/TextureRect


func _ready() -> void:
	var screen_size = get_viewport().get_visible_rect().size
	documents_container.position = Vector2(
		(screen_size.x - documents_container.size.x) / 2,
		screen_size.y + 200)
	documents_container.modulate.a = 0.0
	texture_rect.gui_input.connect(_on_gui_input)


	_populate_from_report(TimeManager.get_last_night_report() if TimeManager and TimeManager.has_method("get_last_night_report") else {})


func _on_save_and_quit_button_button_up() -> void:
	# На всякий случай сохраняем и выходим в меню.
	var day: int = int(TimeManager.get_last_night_report().get("day", 0)) if TimeManager else 0
	TimeManager.save_all(day)
	FadeManager.change_scene_with_fade("res://scenes/main.tscn", 0.5, 0.0, "")


func _on_continue_button_button_up() -> void:
	# Возвращаемся в игру через загрузку сохранения (чтобы восстановить day_counter и состояние мира).
	show_main()


func _clear_dynamic_rows(section: VBoxContainer) -> void:
	# Оставляем заголовок (Label) и template-HBox, удаляем все остальные HBox строки.
	var keep: Array = []
	for c in section.get_children():
		if c is Label:
			keep.append(c)
		elif c is HBoxContainer and (c == earned_template or c == spent_template):
			keep.append(c)
	for c in section.get_children():
		if keep.has(c):
			continue
		if c is HBoxContainer:
			c.queue_free()


func _set_row_text(row: HBoxContainer, left_text: String, right_text: String) -> void:
	var left: Label = row.get_child(0) as Label
	var right: Label = row.get_child(1) as Label
	if left:
		left.text = left_text
	if right:
		right.text = right_text


func _populate_section(section: VBoxContainer, template: HBoxContainer, lines: Array) -> void:
	_clear_dynamic_rows(section)
	template.visible = false
	for line in lines:
		if typeof(line) != TYPE_DICTIONARY:
			continue
		var left: String = str(line.get("left", ""))
		var right: String = str(line.get("right", ""))
		var row: HBoxContainer = template.duplicate() as HBoxContainer
		row.visible = true
		_set_row_text(row, left, right)
		section.add_child(row)


func _populate_from_report(report: Dictionary) -> void:
	var day: int = int(report.get("day", 0))
	if day_label:
		day_label.text = "Day %d" % day

	var earned_lines: Array = report.get("earned_lines", [])
	var spent_lines: Array = report.get("spent_lines", [])
	_populate_section(earned_section, earned_template, earned_lines)
	_populate_section(spent_section, spent_template, spent_lines)

	var earned_total: int = int(report.get("earned_total", 0))
	var spent_total: int = int(report.get("spent_total", 0))
	var balance: int = int(report.get("balance", 0))
	if total_earned_value:
		total_earned_value.text = "+%d$" % earned_total
	if total_spent_value:
		total_spent_value.text = "-%d$" % spent_total
	if total_balance_value:
		total_balance_value.text = "%d$" % balance


func show_main() -> void:
	var screen_size = get_viewport().get_visible_rect().size

	# Центр экрана
	var target_position = Vector2(
		(screen_size.x - documents_container.size.x) / 2,
		(screen_size.y - documents_container.size.y) / 2
	)

	var tween = create_tween()

	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	# Анимация позиции
	tween.tween_property(
		documents_container,
		"position",
		target_position,
		1.4
	)

	# Анимация прозрачности
	tween.parallel().tween_property(
		documents_container,
		"modulate:a",
		1.0,
		1.5
	)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			texture_rect.modulate.a = 1
			await get_tree().create_timer(1.0).timeout
			FadeManager.start_mode = "load"
			FadeManager.change_scene_with_fade("res://scenes/game.tscn", 0.5, 0.0, "")
	
	
