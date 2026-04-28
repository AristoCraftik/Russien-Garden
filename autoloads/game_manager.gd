extends Node
class_name GameManager

signal day_advanced(day: int, week: int, year: int)
signal week_ended(week: int)
signal quota_updated(progress: int, target: int)

var day: int = 1
var week: int = 1
var year: int = 1
var quota_target: int = 40
var quota_progress: int = 0
var game_scene: Node

## Привязывает игровую сцену к менеджеру.
func set_game_scene(scene: Node) -> void:
	game_scene = scene

## Добавляет прогресс выполнения квоты.
func add_quota(value: int) -> void:
	quota_progress += value
	emit_signal("quota_updated", quota_progress, quota_target)

## Завершает текущий день.
func end_day() -> void:
	if game_scene != null and game_scene.has_method("advance_all_cells"):
		game_scene.advance_all_cells()
	if game_scene != null and game_scene.has_method("get_all_cells"):
		EventManager.roll_day_events(game_scene.get_all_cells())
	day += 1
	if day > 7:
		end_week()
	emit_signal("day_advanced", day, week, year)

## Завершает неделю и открывает отчет.
func end_week() -> void:
	day = 1
	week += 1
	EconomyManager.reset_weekly_prices()
	LawManager.draw_new_law()
	emit_signal("week_ended", week)
	if week > 52:
		year += 1
		week = 1
