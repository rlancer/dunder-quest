class_name Story
extends RefCounted

## The rooms, read once from data/levels.json.

const PATH := "res://data/levels.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _data


static func count() -> int:
	return (data().levels as Array).size()


static func level(id: int) -> Dictionary:
	for entry: Dictionary in data().levels:
		if int(entry.id) == id:
			return entry
	return {}


## Every dagger command unlocked by this room or an earlier one.
static func commands(id: int) -> PackedStringArray:
	var out := PackedStringArray()
	for entry: Dictionary in data().levels:
		if int(entry.id) <= id:
			out.append_array(PackedStringArray(entry.get("unlock", [])))
	return out
