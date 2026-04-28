extends Node
class_name EventManager

signal event_triggered(event_name: String)

const EVENTS_JSON: String = "res://data/events.json"

var global_events: Array[Dictionary] = []
var cell_events: Array[Dictionary] = []

func _ready() -> void:
	var raw: Dictionary = _read_json(EVENTS_JSON)
	global_events = raw.get("global", [])
	cell_events = raw.get("cell", [])

## Разыгрывает события на день.
func roll_day_events(cells: Array[GardenCell]) -> void:
	for row: Dictionary in global_events:
		if randf() <= float(row.get("chance", 0.0)):
			_apply_event(row.get("type", ""), null)
	for cell: GardenCell in cells:
		for row: Dictionary in cell_events:
			if randf() <= float(row.get("chance", 0.0)):
				_apply_event(row.get("type", ""), cell)

func _apply_event(type: String, cell: GardenCell) -> void:
	var event: BaseEvent
	match type:
		EventTypes.CROW:
			event = CrowEvent.new()
		EventTypes.HEATWAVE:
			event = HeatwaveEvent.new()
		EventTypes.INSPECTION:
			event = InspectionEvent.new()
		_:
			return
	event.trigger(cell)
	emit_signal("event_triggered", type)

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	var p: Variant = JSON.parse_string(f.get_as_text())
	return p if p is Dictionary else {}
