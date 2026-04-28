extends Control

@onready var report_label: Label = $Panel/VBox/Report
@onready var law_label: Label = $Panel/VBox/Law

func _ready() -> void:
	var law: LawData = LawManager.active_laws[0] if not LawManager.active_laws.is_empty() else null
	report_label.text = "Отчет: %d / %d" % [GameManager.quota_progress, GameManager.quota_target]
	law_label.text = "Новый закон: %s" % (law.description if law != null else "нет")

func _on_continue_pressed() -> void:
	queue_free()
