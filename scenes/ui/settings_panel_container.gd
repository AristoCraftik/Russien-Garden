extends PanelContainer

@onready var menu: Control = $"../MarginContainer/MainPanelContainer"
@onready var window_mode: OptionButton = $MarginContainer/VBoxContainer/VBoxContainer/WindowContainer/WindowContainer/OptionButton
@onready var display_select: OptionButton = $MarginContainer/VBoxContainer/VBoxContainer/WindowContainer/MonitorContainer/OptionButton
@onready var language_select: OptionButton = $MarginContainer/VBoxContainer/VBoxContainer/OtherContainer/LanguageContainer/OptionButton
@onready var scale_select: OptionButton = $MarginContainer/VBoxContainer/VBoxContainer/OtherContainer/ScaleContainer/OptionButton
@onready var apply_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/ApplyButton
@onready var reset_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/ReturnToDefoultButton

const SAVE_PATH := "user://garden/display_settings.cfg"
const DEFAULT_LOCALE := "en"
const DEFAULT_SCALE := 2

var _saved_settings: Dictionary = {}
var _locales: Array[String] = ["en", "ru", "de"]


func _ready() -> void:
	apply_button.pressed.connect(_on_apply_button_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	add_to_group("i18n")
	_populate_static_options()
	_load_settings()
	_apply_i18n()


func _populate_static_options() -> void:
	window_mode.clear()
	window_mode.add_item(tr("WINDOW_FULLSCREEN"),        0)
	window_mode.add_item(tr("WINDOW_BORDERLESS"), 1)
	window_mode.add_item(tr("WINDOW_WINDOWED"),          2)
	display_select.clear()
	for i in DisplayServer.get_screen_count():
		display_select.add_item(tr("DISPLAY_FMT") % (i + 1))
	language_select.clear()
	language_select.add_item("English", 0)
	language_select.add_item("Русский", 1)
	language_select.add_item("Deutsch", 2)
	scale_select.clear()
	scale_select.add_item("1x", 1)
	scale_select.add_item("2x", 2)
	scale_select.add_item("3x", 3)


func _current_settings() -> Dictionary:
	return {
		"window_mode": window_mode.selected,
		"display":     display_select.selected,
		"locale":      _locales[clampi(language_select.selected, 0, _locales.size() - 1)],
		"scale":       int(scale_select.get_item_id(scale_select.selected)),
	}


func _default_settings() -> Dictionary:
	return {
		"window_mode": 0,
		"display":     0,
		"locale":      DEFAULT_LOCALE,
		"scale":       DEFAULT_SCALE,
	}


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	var s: Dictionary = _current_settings()
	cfg.set_value("display", "window_mode", s["window_mode"])
	cfg.set_value("display", "monitor",     s["display"])
	cfg.set_value("display", "scale",       s["scale"])
	cfg.set_value("i18n",    "locale",      s["locale"])
	DirAccess.make_dir_recursive_absolute(SAVE_PATH.get_base_dir())
	cfg.save(SAVE_PATH)
	_saved_settings = s.duplicate()


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	var defaults: Dictionary = _default_settings()
	if cfg.load(SAVE_PATH) == OK:
		_apply_settings({
			"window_mode": cfg.get_value("display", "window_mode", defaults["window_mode"]),
			"display":     cfg.get_value("display", "monitor",     defaults["display"]),
			"scale":       cfg.get_value("display", "scale",       defaults["scale"]),
			"locale":      cfg.get_value("i18n",    "locale",      defaults["locale"]),
		})
	else:
		_apply_settings(defaults)


func _apply_settings(s: Dictionary) -> void:
	# Сначала язык (чтобы остальные подписи были на нужном языке).
	var loc: String = str(s.get("locale", DEFAULT_LOCALE))
	TranslationServer.set_locale(loc)
	# Пересобираем локализуемые пункты списков.
	_populate_static_options()
	window_mode.select(  clampi(int(s["window_mode"]), 0, max(0, window_mode.item_count - 1)))
	display_select.select(clampi(int(s["display"]),    0, max(0, display_select.item_count - 1)))
	var sc: int = clampi(int(s.get("scale", DEFAULT_SCALE)), 1, 3)
	for i in range(scale_select.item_count):
		if int(scale_select.get_item_id(i)) == sc:
			scale_select.select(i)
			break
	var lang_idx: int = _locales.find(loc)
	if lang_idx < 0:
		lang_idx = 0
	language_select.select(lang_idx)
	_saved_settings = s.duplicate()
	_commit_to_window()
	# Ручное уведомление UI об изменении языка (без TranslationServer.translation_changed).
	get_tree().call_group("i18n", "_apply_i18n")


func _commit_to_window() -> void:
	var wid: int = get_window().get_window_id()
	var monitor_idx: int = display_select.selected
	if monitor_idx < 0:
		monitor_idx = 0
	DisplayServer.window_set_current_screen(monitor_idx, wid)

	match window_mode.selected:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN, wid)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN, wid)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED, wid)
			var screen_pos: Vector2i  = DisplayServer.screen_get_position(monitor_idx)
			var screen_size: Vector2i = DisplayServer.screen_get_size(monitor_idx)
			var win_size: Vector2i    = DisplayServer.window_get_size(wid)
			var offset: Vector2i = Vector2i((screen_size - win_size) / 2)
			DisplayServer.window_set_position(screen_pos + offset, wid)

	get_viewport().canvas_item_default_texture_filter = \
		Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_commit_content_scale()


func _commit_content_scale() -> void:
	# Масштабируем содержимое (CanvasItems/Viewport), НЕ меняя размер окна.
	var sc: int = clampi(int(_current_settings().get("scale", DEFAULT_SCALE)), 1, 3)
	var win: Window = get_window()
	if win == null:
		return
	# В разных сборках/версиях Godot API может отличаться, поэтому ставим через методы, если они есть.
	if win.has_method("set_content_scale_factor"):
		win.call("set_content_scale_factor", float(sc))
	elif win.has_method("set_content_scale"):
		# На случай альтернативного имени.
		win.call("set_content_scale", float(sc))


func _apply_i18n() -> void:
	# Заголовки/кнопки
	var title: Label = $MarginContainer/VBoxContainer/Label
	if title:
		title.text = tr("SETTINGS_TITLE")
	var window_lbl: Label = $MarginContainer/VBoxContainer/VBoxContainer/WindowContainer/WindowContainer/Label
	if window_lbl:
		window_lbl.text = tr("SETTINGS_WINDOW_MODE")
	var monitor_lbl: Label = $MarginContainer/VBoxContainer/VBoxContainer/WindowContainer/MonitorContainer/Label
	if monitor_lbl:
		monitor_lbl.text = tr("SETTINGS_MONITOR")
	var lang_lbl: Label = $MarginContainer/VBoxContainer/VBoxContainer/OtherContainer/LanguageContainer/Label
	if lang_lbl:
		lang_lbl.text = tr("SETTINGS_LANGUAGE")
	var scale_lbl: Label = $MarginContainer/VBoxContainer/VBoxContainer/OtherContainer/ScaleContainer/Label
	if scale_lbl:
		scale_lbl.text = tr("SETTINGS_SCALE")
	if reset_button:
		reset_button.text = tr("SETTINGS_DEFAULT")
	if apply_button:
		apply_button.text = tr("SETTINGS_APPLY")


func _on_apply_button_pressed() -> void:
	# Применяем ВСЕ текущие настройки (включая язык), затем сохраняем.
	_apply_settings(_current_settings())
	_save_settings()


func _on_reset_pressed() -> void:
	_apply_settings(_default_settings())
	_save_settings()


# Открытие панели рядом с меню, с проверкой границ окна.
func open() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var mouse_y: float = get_viewport().get_mouse_position().y
	var target_y: float = clamp(mouse_y - size.y / 2.0, 0.0, max(0.0, viewport_size.y - size.y))
	self.position.y = target_y

	var target_x: float = menu.position.x + menu.size.x
	var tween: Tween = create_tween()
	tween.tween_property(self, "position:x", target_x, 0.4) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)


func close_settings() -> void:
	# При закрытии без Apply — откатываемся на ранее сохранённое.
	_apply_settings(_saved_settings)
	var screen_width: float = get_viewport_rect().size.x
	var tween: Tween = create_tween()
	tween.tween_property(self, "position:x", screen_width, 0.4) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_IN)
