extends Node

## Which scenes are open and cleared, how many tries each took, and which
## lesson cards Barry has read. Saved as JSON in user://, under its own name
## so it never touches the other games' saves.

const SAVE_PATH := "user://curb_save.json"

## Tests turn this off so a bot run never rewrites the player's save.
static var persist: bool = true
## The scene picked on the map, and one just cleared (the map celebrates it).
static var current_scene: int = 1
static var just_cleared: int = 0

static var _cleared: Dictionary = {}
static var _tries: Dictionary = {}
static var _cards: Dictionary = {}
static var _loaded: bool = false


func _ready() -> void:
	load_data()


static func count() -> int:
	return Story.count()


static func is_open(id: int) -> bool:
	_ensure()
	return id == 1 or _cleared.has(id - 1) or _cleared.has(id)


static func is_cleared(id: int) -> bool:
	_ensure()
	return _cleared.has(id)


static func cleared_count() -> int:
	_ensure()
	return _cleared.size()


static func best_tries(id: int) -> int:
	_ensure()
	return int(_tries.get(id, 0))


static func read_card(id: String) -> void:
	_ensure()
	if not _cards.has(id):
		_cards[id] = true
		save_data()


static func has_read(id: String) -> bool:
	_ensure()
	return _cards.has(id)


static func has_progress() -> bool:
	_ensure()
	return not _cleared.is_empty()


static func mark_cleared(id: int, tries: int) -> void:
	_ensure()
	_cleared[id] = true
	var best := int(_tries.get(id, 0))
	_tries[id] = tries if best == 0 else mini(best, tries)
	just_cleared = id
	current_scene = mini(id + 1, count())
	save_data()


static func save_data() -> void:
	if not persist:
		return
	var data := {"current_scene": current_scene, "cleared": _cleared.keys(), "tries": _keyed(_tries), "cards": _cards.keys()}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))


static func load_data() -> void:
	if not persist and _loaded:
		# Tests keep their progress in memory only.
		return
	_loaded = true
	_cleared = {}
	_tries = {}
	_cards = {}
	current_scene = 1
	if not persist or not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not parsed is Dictionary:
		return
	var d: Dictionary = parsed
	current_scene = clampi(int(d.get("current_scene", 1)), 1, maxi(count(), 1))
	for id: Variant in d.get("cleared", []):
		_cleared[int(id)] = true
	for key: Variant in (d.get("tries", {}) as Dictionary):
		_tries[int(key)] = int(d.tries[key])
	for id: Variant in d.get("cards", []):
		_cards[str(id)] = true


static func reset() -> void:
	_cleared = {}
	_tries = {}
	_cards = {}
	current_scene = 1
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
