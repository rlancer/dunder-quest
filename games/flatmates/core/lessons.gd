class_name Lessons
extends RefCounted

## The inner-voice lesson cards, from data/lessons.json: per stage, the
## lesson's name and its cards. A card is {id, who, title, code, text}: who
## is thinking it, a short snippet, and what it means. tests/verify_lessons.mjs
## runs every snippet under Node and checks the // comments it prints.

const PATH := "res://data/lessons.json"

static var _bank: Dictionary = {}
static var _cards: Dictionary = {}


static func lesson(stage: int) -> String:
	_load()
	return str((_bank.get(str(stage), {}) as Dictionary).get("lesson", ""))


static func card(id: String) -> Dictionary:
	_load()
	return _cards.get(id, {})


static func cards(stage: int) -> Array:
	_load()
	return (_bank.get(str(stage), {}) as Dictionary).get("cards", [])


static func _load() -> void:
	if not _bank.is_empty():
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary:
		push_error("Lesson bank is missing or malformed")
		return
	_bank = parsed
	for key: String in _bank:
		for entry: Dictionary in (_bank[key] as Dictionary).get("cards", []):
			var card := entry.duplicate()
			card["code"] = "\n".join(PackedStringArray(entry.get("code", [])))
			card["stage"] = int(key)
			_cards[str(entry["id"])] = card
