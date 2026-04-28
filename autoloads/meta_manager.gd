extends Node
class_name MetaManager

const META_PATH: String = "user://meta.json"

var unlocked: PackedStringArray = PackedStringArray()

func _ready() -> void:
	load_meta()

## Сохраняет мета-прогресс между забегами.
func save_meta() -> void:
	var data: Dictionary = {"unlocked": unlocked}
	var f: FileAccess = FileAccess.open(META_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))

## Загружает мета-прогресс между забегами.
func load_meta() -> void:
	if not FileAccess.file_exists(META_PATH):
		unlocked = PackedStringArray()
		return
	var f: FileAccess = FileAccess.open(META_PATH, FileAccess.READ)
	var p: Variant = JSON.parse_string(f.get_as_text())
	if p is Dictionary:
		unlocked = PackedStringArray(p.get("unlocked", []))

## Разблокирует достижение если его еще нет.
func unlock(id: String) -> void:
	if not unlocked.has(id):
		unlocked.append(id)
		save_meta()
