class_name Lessons
extends RefCounted

## The Python lesson each stage teaches, from `data/lessons.json`: its topic,
## the wizard's taunt, the lore scrolls laid along the route, and the quiz.
## `trial` is how many questions the wizard wants answered right before he goes.
## `tools/verify_quiz.py` runs every snippet in it against real Python.

const BANK_PATH := "res://data/lessons.json"
const DEFAULT_TRIAL := 3

static var _bank: Dictionary = {}
static var _scrolls: Dictionary = {}
static var _loaded: bool = false


## {topic, taunt, trial, scrolls: Array[Dictionary], questions: Array[Dictionary]}
static func stage(stage_id: int) -> Dictionary:
	_ensure_loaded()
	return _bank.get(stage_id, {"topic": "", "taunt": "", "trial": DEFAULT_TRIAL, "scrolls": [], "questions": []})


static func topic(stage_id: int) -> String:
	return str(stage(stage_id).get("topic", ""))


static func trial(stage_id: int) -> int:
	return int(stage(stage_id).get("trial", DEFAULT_TRIAL))


## {id, title, code, insight, stage}, or {} for an unknown id.
static func scroll(scroll_id: String) -> Dictionary:
	_ensure_loaded()
	return _scrolls.get(scroll_id, {})


static func scroll_ids(stage_id: int) -> PackedStringArray:
	var ids: PackedStringArray = []
	for entry: Dictionary in stage(stage_id).get("scrolls", []):
		ids.append(str(entry["id"]))
	return ids


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BANK_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Lesson bank is missing or malformed")
		return
	for key: Variant in (parsed as Dictionary).keys():
		var raw: Variant = parsed[key]
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var stage_id := int(str(key))
		var scrolls: Array[Dictionary] = []
		for entry: Variant in (raw as Dictionary).get("scrolls", []):
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var card := {
				"id": str(entry.get("id", "")),
				"title": str(entry.get("title", "Scroll")),
				"code": _joined(entry.get("code", [])),
				"insight": str(entry.get("insight", "")),
				"stage": stage_id,
			}
			scrolls.append(card)
			_scrolls[card["id"]] = card
		var questions: Array[Dictionary] = []
		for entry: Variant in (raw as Dictionary).get("questions", []):
			if typeof(entry) == TYPE_DICTIONARY:
				questions.append(_question(entry as Dictionary))
		_bank[stage_id] = {
			"topic": str(raw.get("topic", "")),
			"taunt": str(raw.get("taunt", "")),
			"trial": maxi(int(raw.get("trial", DEFAULT_TRIAL)), 1),
			"scrolls": scrolls,
			"questions": questions,
		}


static func _question(entry: Dictionary) -> Dictionary:
	var options: PackedStringArray = []
	for option: Variant in entry.get("options", []):
		options.append(str(option))
	return {
		"code": _joined(entry.get("code", [])),
		"prompt": str(entry.get("prompt", "What does this print?")),
		"options": options,
		"answer": int(entry.get("answer", 0)),
		"explanation": str(entry.get("explanation", "")),
		"scroll": str(entry.get("scroll", "")),
		"hint": str(entry.get("hint", "")),
	}


static func _joined(lines: Variant) -> String:
	var out: PackedStringArray = []
	if typeof(lines) == TYPE_ARRAY:
		for line: Variant in lines:
			out.append(str(line))
	return "\n".join(out)
