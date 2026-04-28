extends Control

@onready var unlocks: Label = $Panel/VBox/Unlocks

func _ready() -> void:
	unlocks.text = "Открыто: %s" % ", ".join(MetaManager.unlocked)

func _on_unlock_spring_pressed() -> void:
	MetaManager.unlock("survived_spring")
	unlocks.text = "Открыто: %s" % ", ".join(MetaManager.unlocked)
