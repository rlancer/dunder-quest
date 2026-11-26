class_name Story
extends RefCounted

## The script of every episode, from data/episodes.json: the cast, each
## episode's talk, its scenes (a brief, the locked script with its hooks,
## the cue cards on the table, the table read the lines have to air in, and
## the cues that get it there), Stu's lesson cards, what each card means in
## plain words, and the stock lines for a take that misses. tests/replay.gd
## reads the same file, and tests/verify_loop.ts holds every program it can
## make to the real JavaScript.

const PATH := "res://data/episodes.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_data = parsed
		else:
			push_error("data/episodes.json is missing or malformed")
	return _data


static func episodes() -> Array:
	return data().get("episodes", [])


static func count() -> int:
	return episodes().size()


static func episode(id: int) -> Dictionary:
	for e: Dictionary in episodes():
		if int(e.id) == id:
			return e
	return {}


static func name_of(who: String) -> String:
	return str((data().get("cast", {}) as Dictionary).get(who, {}).get("name", who.capitalize()))


static func stock(section: String) -> Array:
	return (data().get("stock", {}) as Dictionary).get(section, [])


static func card(id: String) -> Dictionary:
	var c: Dictionary = (data().get("cards", {}) as Dictionary).get(id, {})
	if c.is_empty():
		return c
	var out := c.duplicate()
	out["id"] = id
	return out


## Why a card won't go where it was put.
static func error_text(why: String) -> String:
	return str((data().get("errors", {}) as Dictionary).get(why, "That card won't go there."))


## What a cue card does, in plain words.
static func meaning(cue: String) -> String:
	var glossary: Dictionary = data().get("glossary", {})
	if glossary.has(cue):
		return str(glossary[cue])
	var parts := cue.split(":")
	var text := str(glossary.get(parts[0], ""))
	return text.replace("{ms}", parts[1] if parts.size() > 1 else "")


## The fewest cards a scene can be played with: its written solution's.
## tests/replay.gd proves nothing with fewer plays.
static func par(scene: Dictionary) -> int:
	return (scene.get("solution", {}) as Dictionary).size()


## Every line of dialogue in the episodes, in order: {"who", "text"}.
static func spoken_lines() -> Array:
	var out: Array = []
	for e: Dictionary in episodes():
		for line: Dictionary in e.get("intro", []):
			out.append(line)
		for s: Dictionary in e.get("scenes", []):
			out.append(s.brief)
			if s.has("after"):
				out.append(s.after)
		for line: Dictionary in e.get("outro", []):
			out.append(line)
	return out
