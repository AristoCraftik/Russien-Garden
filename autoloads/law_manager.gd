extends Node
class_name LawManager

signal law_changed(law: LawData)

const LAWS_JSON: String = "res://data/laws.json"

var laws_pool: Array[LawData] = []
var active_laws: Array[LawData] = []

func _ready() -> void:
	_load_laws()

## Проверяет возможность действия по активным законам.
func validate_action(action: String, payload: Dictionary) -> Dictionary:
	for law: LawData in active_laws:
		if action == "plant" and not _validate_plant_law(law, payload):
			return {"ok": false, "reason": law.description}
	return {"ok": true, "reason": ""}

## Выдает новый закон на неделю.
func draw_new_law() -> LawData:
	if laws_pool.is_empty():
		return null
	var law: LawData = laws_pool[randi() % laws_pool.size()]
	active_laws = [law]
	emit_signal("law_changed", law)
	return law

func _validate_plant_law(law: LawData, payload: Dictionary) -> bool:
	var cell: GardenCell = payload.get("cell")
	var plant: PlantData = payload.get("plant_data")
	match law.condition_type:
		LawTypes.NO_PLANT_ID:
			return plant.id != str(law.params.get("plant_id", ""))
		LawTypes.NO_ADJACENT:
			var a: String = str(law.params.get("a", ""))
			var b: String = str(law.params.get("b", ""))
			if plant.id != a and plant.id != b:
				return true
			for n: GardenCell in cell.grid.get_adjacent_cells(cell.grid_pos):
				if n.current_plant != null:
					var id: String = n.current_plant.plant_data.id
					if (id == a and plant.id == b) or (id == b and plant.id == a):
						return false
			return true
		_:
			return true

func _load_laws() -> void:
	laws_pool.clear()
	var raw: Dictionary = _read_json(LAWS_JSON)
	for row: Dictionary in raw.get("laws", []):
		var law: LawData = LawData.new()
		law.id = row.get("id", "")
		law.description = row.get("description", "")
		law.condition_type = row.get("condition_type", "")
		law.params = row.get("params", {})
		laws_pool.append(law)

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	var p: Variant = JSON.parse_string(f.get_as_text())
	return p if p is Dictionary else {}
