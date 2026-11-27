class_name Story
extends RefCounted

## The script of every episode, from data/episodes.json: the cast, the
## counters (each a little REST API), each episode's talk, its scenes (a
## brief, the counter and the data on it, the cards on the table, what the
## scene wants back, and the slip that gets it), Stu's lesson cards, what
## each card means in plain words, and the stock lines for a request that
## misses. tests/replay.gd reads the same file, and tests/verify_http.ts holds
## every request it can make to a real HTTP server.

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


## Why a slip can't be sent.
static func error_text(why: String) -> String:
	return str((data().get("errors", {}) as Dictionary).get(why, "That slip can't go."))


## What a card on the table means, in plain words.
static func meaning(card: String) -> String:
	var glossary: Dictionary = data().get("glossary", {})
	match Http.kind(card):
		"method":
			return str(glossary.get(card, ""))
		"path":
			return str(glossary.get("path", ""))
		"body":
			return str(glossary.get("body", ""))
	return str(glossary.get(str(Http.split_header(card)[0]), ""))


## The fewest cards a scene can be played with: its written solution's.
## tests/replay.gd proves nothing with fewer works.
static func par(scene: Dictionary) -> int:
	return (scene.get("solution", []) as Array).size()


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
