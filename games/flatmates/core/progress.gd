extends Node

## Which stages are open and cleared, best biscuit counts and times, and the
## inner-voice thoughts heard so far (the Diary). Saved as JSON in user://,
## under its own name so it never touches the Python game's save.

const SAVE_PATH := "user://flatmates_save.json"

## Tests turn this off so a bot run never rewrites the player's save.
static var persist: bool = true
## The stage picked on the line map, and one just cleared (the map
## celebrates it on arrival).
static var current_stage: int = 1
static var just_cleared: int = 0

## Stage scripts live at res://stages/stage_N.gd. `stop` is the name on the
## tram-line map, `lesson` the JavaScript it teaches.
const STAGES: Array[Dictionary] = [
	{"id": 1, "name": "Flat 5B", "stop": "Hermes House", "lesson": "Calling methods", "biscuits": 6},
	{"id": 2, "name": "Croydon Credit", "stop": "Croydon Credit", "lesson": "Variables & strings", "biscuits": 6},
	{"id": 3, "name": "Band Practice", "stop": "The Cellar Bar", "lesson": "Loops", "biscuits": 6},
	{"id": 4, "name": "The Stag Do", "stop": "Wet Bottom Farm", "lesson": "Events & callbacks", "biscuits": 6},
	{"id": 5, "name": "East Croydon", "stop": "East Croydon", "lesson": "Timers & the event loop", "biscuits": 6},
	{"id": 6, "name": "The Wedding", "stop": "St Agatha's", "lesson": "async & await", "biscuits": 6},
]

static var _cleared: Dictionary = {}
static var _biscuits: Dictionary = {}
static var _times: Dictionary = {}
static var _thoughts: Dictionary = {}
static var _falls: int = 0
static var _loaded: bool = false


func _ready() -> void:
	load_data()


static func stage(id: int) -> Dictionary:
	for entry in STAGES:
		if entry.id == id:
			return entry
	return {}


static func count() -> int:
	return STAGES.size()


static func is_open(id: int) -> bool:
	_ensure()
	return id == 1 or _cleared.has(id - 1) or _cleared.has(id)


static func is_cleared(id: int) -> bool:
	_ensure()
	return _cleared.has(id)


static func cleared_count() -> int:
	_ensure()
	return _cleared.size()


static func best_biscuits(id: int) -> int:
	_ensure()
	return int(_biscuits.get(id, 0))


static func best_time(id: int) -> float:
	_ensure()
	return float(_times.get(id, 0.0))


static func total_biscuits() -> int:
	_ensure()
	var total := 0
	for id: int in _biscuits:
		total += int(_biscuits[id])
	return total


static func max_biscuits() -> int:
	var total := 0
	for entry in STAGES:
		total += int(entry.biscuits)
	return total


static func falls() -> int:
	_ensure()
	return _falls


static func note_fall() -> void:
	_ensure()
	_falls += 1


static func hear_thought(id: String) -> void:
	_ensure()
	if _thoughts.has(id):
		return
	_thoughts[id] = true
	save_data()


static func knows_thought(id: String) -> bool:
	_ensure()
	return _thoughts.has(id)


static func has_progress() -> bool:
	_ensure()
	return not _cleared.is_empty() or not _thoughts.is_empty()


## Records a clear. Returns true when `time` beats the previous best.
static func mark_cleared(id: int, biscuits: int, time: float) -> bool:
	_ensure()
	_cleared[id] = true
	_biscuits[id] = maxi(int(_biscuits.get(id, 0)), biscuits)
	var previous := float(_times.get(id, 0.0))
	var best := time > 0.0 and (previous <= 0.0 or time < previous)
	if best:
		_times[id] = time
	just_cleared = id
	current_stage = mini(id + 1, STAGES.size())
	save_data()
	return best


static func format_time(seconds: float) -> String:
	if seconds <= 0.0:
		return "--:--"
	var whole := int(seconds)
	return "%d:%02d" % [whole / 60, whole % 60]


static func save_data() -> void:
	if not persist:
		return
	var data := {
		"current_stage": current_stage,
		"cleared": _cleared.keys(),
		"biscuits": _keyed(_biscuits),
		"times": _keyed(_times),
		"thoughts": _thoughts.keys(),
		"falls": _falls,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))


static func load_data() -> void:
	_loaded = true
	_cleared = {}
	_biscuits = {}
	_times = {}
	_thoughts = {}
	_falls = 0
	current_stage = 1
	if not persist or not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not parsed is Dictionary:
		return
	var d: Dictionary = parsed
	current_stage = clampi(int(d.get("current_stage", 1)), 1, STAGES.size())
	_falls = int(d.get("falls", 0))
	for id: Variant in d.get("cleared", []):
		_cleared[int(id)] = true
	for key: Variant in (d.get("biscuits", {}) as Dictionary):
		_biscuits[int(key)] = int(d.biscuits[key])
	for key: Variant in (d.get("times", {}) as Dictionary):
		_times[int(key)] = float(d.times[key])
	for id: Variant in d.get("thoughts", []):
		_thoughts[str(id)] = true


static func reset() -> void:
	_cleared = {}
	_biscuits = {}
	_times = {}
	_thoughts = {}
	_falls = 0
	current_stage = 1
	just_cleared = 0
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


static func _ensure() -> void:
	if not _loaded:
		load_data()


static func _keyed(source: Dictionary) -> Dictionary:
	var out := {}
	for key: Variant in source:
		out[str(key)] = source[key]
	return out
