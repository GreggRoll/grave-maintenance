class_name Catalog
extends RefCounted

static var equipment: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/equipment.json"))
static var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/contract.json"))

static func tool(kind: String) -> Dictionary:
	return equipment.get(kind, {})

static func clock(elapsed: float) -> String:
	var total := 22 * 60 + int(minf(elapsed, 300.0))
	var hour := (total / 60) % 24
	var minute := total % 60
	return "%d:%02d %s" % [12 if hour % 12 == 0 else hour % 12, minute, "AM" if hour < 12 else "PM"]
