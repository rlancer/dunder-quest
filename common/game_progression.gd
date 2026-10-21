extends Node

## Manages unlocked levels, cleared status, best emberseed counts, best times,
## the lore scrolls read so far (the Spellbook), and persistence.

const SAVE_PATH := "user://cinder_progression.json"

static var instance: Node

## Set to true when playing from the world map navigation.
static var came_from_map: bool = true

## Tests turn this off so a bot run never rewrites the player's save.
static var persist: bool = true

## ID of the currently selected stage on the world map.
static var current_stage_id: int = 1

## If non-zero, the world map plays a stage clear / unlock animation upon loading.
static var just_cleared_id: int = 0

static var _unlocked: Dictionary = {}
static var _cleared: Dictionary = {}
static var _best_seeds: Dictionary = {}
static var _best_times: Dictionary = {}
static var _total_deaths: int = 0
## Scroll id -> true for every lore scroll the player has read.
static var _scrolls: Dictionary = {}
static var _initialized: bool = false

## max_seeds counts the loose seeds, the one inside each stage's cache stone,
## and any a lesson gadget hands out (Kiln Mouth's loop forge drops four).
const STAGES: Array[Dictionary] = [
	{
		"id": 1,
		"name": "Amber Hollow",
		"subtitle": "Lesson 1: Lists & Indexing",
		"scene": "res://levels/level_01.tscn",
		"map_pos": Vector2(96.0, 155.0),
		"max_seeds": 6,
	},
	{
		"id": 2,
		"name": "Cinder Span",
		"subtitle": "Lesson 2: Dictionaries & Hashing",
		"scene": "res://levels/level_02.tscn",
		"map_pos": Vector2(240.0, 115.0),
		"max_seeds": 4,
	},
	{
		"id": 3,
		"name": "Kiln Mouth",
		"subtitle": "Lesson 3: Loops & range",
		"scene": "res://levels/level_03.tscn",
		"map_pos": Vector2(384.0, 155.0),
		"max_seeds": 8,
	},
	{
		"id": 4,
		"name": "Smelter's Fork",
		"subtitle": "Lesson 4: Booleans & Conditions",
		"scene": "res://levels/level_04.tscn",
		"map_pos": Vector2(326.0, 76.0),
		"max_seeds": 6,
	},
	{
		"id": 5,
		"name": "Bellows Bridge",
		"subtitle": "Lesson 5: Functions & return",
		"scene": "res://levels/level_05.tscn",
		"map_pos": Vector2(220.0, 58.0),
		"max_seeds": 6,
	},
	{
		"id": 6,
		"name": "Crucible Crown",
		"subtitle": "Lesson 6: Comprehensions",
		"scene": "res://levels/level_06.tscn",
		"map_pos": Vector2(112.0, 54.0),
		"max_seeds": 7,
	},
]


func _ready() -> void:
	instance = self
	_ensure_init()


static func _ensure_init() -> void:
	if _initialized:
		return
	load_data()


static func get_stage_count() -> int:
	return STAGES.size()


static func get_stage_data(stage_id: int) -> Dictionary:
	for stage in STAGES:
		if stage.id == stage_id:
			return stage
	return {}


static func is_unlocked(stage_id: int) -> bool:
	_ensure_init()
	if stage_id == 1:
		return true
	return _unlocked.get(stage_id, false)


static func is_cleared(stage_id: int) -> bool:
	_ensure_init()
	return _cleared.get(stage_id, false)


static func get_best_seeds(stage_id: int) -> int:
	_ensure_init()
	return _best_seeds.get(stage_id, 0)


## Best clear time in seconds, or 0.0 when the stage has never been cleared.
static func get_best_time(stage_id: int) -> float:
	_ensure_init()
	return _best_times.get(stage_id, 0.0)


static func get_total_deaths() -> int:
	_ensure_init()
	return _total_deaths


static func get_total_seeds_collected() -> int:
	_ensure_init()
	var total := 0
	for id in _best_seeds.keys():
		total += int(_best_seeds[id])
	return total


static func get_total_max_seeds() -> int:
	var total := 0
	for stage in STAGES:
		total += int(stage.get("max_seeds", 0))
	return total


static func learn_scroll(scroll_id: String) -> void:
	_ensure_init()
	if _scrolls.has(scroll_id):
		return
	_scrolls[scroll_id] = true
	save_data()


static func knows_scroll(scroll_id: String) -> bool:
	_ensure_init()
	return _scrolls.has(scroll_id)


## Every scroll read so far, in the order the lessons list them.
static func known_scrolls(stage_id: int = 0) -> PackedStringArray:
	_ensure_init()
	var known: PackedStringArray = []
	for stage in STAGES:
		if stage_id != 0 and stage.id != stage_id:
			continue
		for scroll_id in Lessons.scroll_ids(stage.id):
			if _scrolls.has(scroll_id):
				known.append(scroll_id)
	return known


static func note_death() -> void:
	_ensure_init()
	_total_deaths += 1


## Records a clear. Returns true when `time` beat the previous best.
static func mark_cleared(stage_id: int, seeds: int = 0, time: float = 0.0) -> bool:
	_ensure_init()
	_cleared[stage_id] = true
	if seeds > _best_seeds.get(stage_id, 0):
		_best_seeds[stage_id] = seeds
	var previous: float = _best_times.get(stage_id, 0.0)
	var new_best := time > 0.0 and (previous <= 0.0 or time < previous)
	if new_best:
		_best_times[stage_id] = time
	var next_id := stage_id + 1
	if next_id <= STAGES.size():
		_unlocked[next_id] = true
	just_cleared_id = stage_id
	save_data()
	return new_best


static func format_time(seconds: float) -> String:
	if seconds <= 0.0:
		return "--:--.-"
	var whole := int(seconds)
	return "%d:%02d.%d" % [whole / 60, whole % 60, int(fmod(seconds, 1.0) * 10.0)]


static func save_data() -> void:
	if not persist:
		return
	var unlocked := {}
	var cleared := {}
	var seeds := {}
	var times := {}
	for stage in STAGES:
		var id: int = stage.id
		var key := str(id)
		unlocked[key] = is_unlocked(id)
		cleared[key] = _cleared.get(id, false)
		seeds[key] = _best_seeds.get(id, 0)
		times[key] = _best_times.get(id, 0.0)
	var data := {
		"current_stage_id": current_stage_id,
		"unlocked": unlocked,
		"cleared": cleared,
		"best_seeds": seeds,
		"best_times": times,
		"total_deaths": _total_deaths,
		"scrolls": _scrolls.keys(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


static func _clear_memory() -> void:
	_unlocked = {1: true}
	_cleared = {}
	_best_seeds = {}
	_best_times = {}
	_total_deaths = 0
	_scrolls = {}
	current_stage_id = 1


static func load_data() -> void:
	_clear_memory()
	_initialized = true
	if not persist or not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var content := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(content)
	if not parsed is Dictionary:
		return
	var d: Dictionary = parsed
	current_stage_id = int(d.get("current_stage_id", 1))
	_total_deaths = int(d.get("total_deaths", 0))
	var unl: Dictionary = d.get("unlocked", {})
	for key in unl.keys():
		_unlocked[int(key)] = bool(unl[key])
	var clr: Dictionary = d.get("cleared", {})
	for key in clr.keys():
		_cleared[int(key)] = bool(clr[key])
	var seeds: Dictionary = d.get("best_seeds", {})
	for key in seeds.keys():
		_best_seeds[int(key)] = int(seeds[key])
	var times: Dictionary = d.get("best_times", {})
	for key in times.keys():
		_best_times[int(key)] = float(times[key])
	for scroll_id: Variant in d.get("scrolls", []):
		_scrolls[str(scroll_id)] = true
	_unlocked[1] = true


static func has_progress() -> bool:
	_ensure_init()
	return not _cleared.is_empty() or _total_deaths > 0


static func reset_progress() -> void:
	_clear_memory()
	just_cleared_id = 0
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
