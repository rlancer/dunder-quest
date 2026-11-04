class_name Season
extends RefCounted

## The season and the piece catalogue, loaded once from data/.

static var _season: Dictionary = {}
static var _pieces: Dictionary = {}


static func data() -> Dictionary:
	if _season.is_empty():
		_season = _load("res://data/season.json")
	return _season


static func pieces() -> Dictionary:
	if _pieces.is_empty():
		_pieces = _load("res://data/pieces.json")
	return _pieces


static func episodes() -> Array:
	return data().get("episodes", [])


static func episode(id: int) -> Dictionary:
	for ep in episodes():
		if int(ep["id"]) == id:
			return ep
	return {}


static func person(who: String) -> Dictionary:
	return data()["cast"].get(who, {"name": who, "look": {}})


static func _load(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Can't open " + path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		return parsed
	push_error("Bad JSON in " + path)
	return {}
