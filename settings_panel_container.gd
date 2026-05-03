extends PanelContainer

@onready var menu = $"../MarginContainer/MainPanelContainer"
@onready var window_mode: OptionButton = $MarginContainer/VBoxContainer/VBoxContainer/WindowContainer/WindowContainer/OptionButton
@onready var display_select: OptionButton = $MarginContainer/VBoxContainer/VBoxContainer/WindowContainer/MonitorContainer/OptionButton
@onready var apply_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/ApplyButton
@onready var reset_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/ReturnToDefoultButton

const SAVE_PATH := "user://display_settings.cfg"

# Снимок последних сохранённых настроек — используется для отката при закрытии
var _saved_settings := {}

func _ready() -> void:
	apply_button.pressed.connect(_on_apply_button_pressed)
	reset_button.pressed.connect(_on_reset_pressed)

	_populate_static_options()
	_load_settings()

	# Применяем изменения сразу при взаимодействии
	window_mode.item_selected.connect(_on_window_mode_changed)
	display_select.item_selected.connect(_on_display_changed)


# ---------------------------------------------------------------------------
# Заполнение списков
# ---------------------------------------------------------------------------

func _populate_static_options() -> void:
	window_mode.clear()
	window_mode.add_item("Fullscreen",        0)
	window_mode.add_item("Borderless Window", 1)
	window_mode.add_item("Windowed",          2)

	display_select.clear()
	for i in DisplayServer.get_screen_count():
		display_select.add_item("Display %d" % (i + 1))


# ---------------------------------------------------------------------------
# Сохранение / загрузка
# ---------------------------------------------------------------------------

func _current_settings() -> Dictionary:
	return {
		"window_mode": window_mode.selected,
		"display":     display_select.selected,
	}

func _default_settings() -> Dictionary:
	return {
		"window_mode": 0,  # Fullscreen
		"display":     0,
	}

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	var s := _current_settings()
	cfg.set_value("display", "window_mode", s["window_mode"])
	cfg.set_value("display", "monitor",     s["display"])
	cfg.save(SAVE_PATH)
	_saved_settings = s.duplicate()

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	var defaults := _default_settings()

	if cfg.load(SAVE_PATH) == OK:
		_apply_settings({
			"window_mode": cfg.get_value("display", "window_mode", defaults["window_mode"]),
			"display":     cfg.get_value("display", "monitor",     defaults["display"]),
		})
	else:
		_apply_settings(defaults)


# ---------------------------------------------------------------------------
# Применение
# ---------------------------------------------------------------------------

func _apply_settings(s: Dictionary) -> void:
	window_mode.select(  clampi(s["window_mode"], 0, window_mode.item_count - 1))
	display_select.select(clampi(s["display"],    0, display_select.item_count - 1))

	_saved_settings = s.duplicate()
	_commit_to_window()

func _commit_to_window() -> void:
	var monitor_idx: int = display_select.selected
	DisplayServer.window_set_current_screen(monitor_idx)

	if OS.has_feature("editor"):
		# Запущено из редактора — только оконный режим
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		match window_mode.selected:
			0:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			1:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			2:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				var screen_pos  := DisplayServer.screen_get_position(monitor_idx)
				var screen_size := DisplayServer.screen_get_size(monitor_idx)
				var win_size    := DisplayServer.window_get_size()
				DisplayServer.window_set_position(screen_pos + (screen_size - win_size) / 2)

	get_viewport().canvas_item_default_texture_filter = \
		Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST


# ---------------------------------------------------------------------------
# Обработчики сигналов — живой предпросмотр
# ---------------------------------------------------------------------------

func _on_window_mode_changed(_idx: int) -> void:
	_commit_to_window()

func _on_display_changed(_idx: int) -> void:
	_commit_to_window()


# ---------------------------------------------------------------------------
# Кнопки
# ---------------------------------------------------------------------------

func _on_apply_button_pressed() -> void:
	_save_settings()

func _on_reset_pressed() -> void:
	_apply_settings(_default_settings())
	_save_settings()


# ---------------------------------------------------------------------------
# Анимация панели
# ---------------------------------------------------------------------------

func open() -> void:
	self.position.y = get_viewport().get_mouse_position().y - size.y / 2
	var target_x: float = menu.position.x + menu.size.x
	var tween := create_tween()
	tween.tween_property(self, "position:x", target_x, 0.4) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)

func close_settings() -> void:
	# Откатываем несохранённые изменения
	_apply_settings(_saved_settings)

	var screen_width: float = get_viewport_rect().size.x
	var tween := create_tween()
	tween.tween_property(self, "position:x", screen_width, 0.4) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_IN)
