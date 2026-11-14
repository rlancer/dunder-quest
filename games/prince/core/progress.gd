extends Node

## Which rooms are cleared and the best time through each. Saved as JSON in
## user://, under its own name so it never touches the other games' saves.

const SAVE_PATH := "user://prince_save.json"

## Tests turn this off so a bot run never rewrites the player's save.
static var persist: bool = true
static var current: int = 1

static var _cleared: Dictionary = {}
static var _loaded: bool = false


func _ready() -> void:
	load_data()


static func is_open(id: int) -> bool:
	_ensure()
	return id == 1 or _cleared.has(id - 1) or _cleared.has(id)


static func is_cleared(id: int) -> bool:
	_ensure()
	return _cleared.has(id)


static func cleared_count() -> int:
	_ensure()
	return _cleared.size()


static func has_progress() -> bool:
	_ensure()
	return not _cleared.is_empty()


## The first room not cleared yet (or the last, once they all are).
static func next_room() -> int:
	_ensure()
	for id in range(1, Story.count() + 1):
		if not _cleared.has(id):
			return id
	return Story.count()


static func best_time(id: int) -> float:
	_ensure()
	return float(_cleared.get(id, 0.0))


static func clear(id: int, seconds: float) -> void:
	_ensure()
	var best := float(_cleared.get(id, 0.0))
	_cleared[id] = seconds if best <= 0.0 else minf(best, seconds)
	save_data()


static func reset() -> void:
	_cleared.clear()
	_loaded = true
	save_data()


static func _ensure() -> void:
	if not _loaded:
		load_data()


static func load_data() -> void:
	_loaded = true
	_cleared.clear()
	if not persist or not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if parsed is Dictionary:
		var saved: Dictionary = parsed.get("cleared", {})
		for key: String in saved:
			_cleared[int(key)] = float(saved[key])


static func save_data() -> void:
	if not persist:
		return
	var out := {}
	for id: int in _cleared:
		out[str(id)] = _cleared[id]
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"cleared": out}))
