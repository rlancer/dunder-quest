class_name Story
extends RefCounted

## The script of every job, from data/jobs.json: the cast, each job's
## dialogue, its posters (a brief, the chips on the table, the lineup and
## the pattern that solves it), the lesson cards, what each chip means in
## plain words, and the Kid's stock lines for a poster that misses.
## tests/replay.gd reads the same file, and tests/verify_regex.ts holds every
## pattern in it to JavaScript's regex engine.

const PATH := "res://data/jobs.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_data = parsed
		else:
			push_error("data/jobs.json is missing or malformed")
	return _data


static func jobs() -> Array:
	return data().get("jobs", [])


static func count() -> int:
	return jobs().size()


static func job(id: int) -> Dictionary:
	for j: Dictionary in jobs():
		if int(j.id) == id:
			return j
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


## What the Kid says about a pattern the engine would refuse.
static func error_text(problem: Dictionary) -> String:
	var key := str(problem.get("error", ""))
	if key == "empty":
		return str(stock("empty")[0])
	var template := str((data().get("errors", {}) as Dictionary).get(key, "That poster doesn't read as a pattern."))
	return template.replace("{token}", str(problem.get("token", "")))


## The fewest chips that solve a poster: its written solution's length.
## tests/replay.gd proves nothing shorter works.
static func par(poster: Dictionary) -> int:
	return (poster.get("solution", []) as Array).size()


## Every line of dialogue in the jobs that's read aloud, in order:
## {"who", "text", "say"?}. For tools/voice.py and the tests.
static func spoken_lines() -> Array:
	var out: Array = []
	for j: Dictionary in jobs():
		for line: Dictionary in j.get("intro", []):
			out.append(line)
		for p: Dictionary in j.get("posters", []):
			out.append(p.brief)
			if p.has("after"):
				out.append(p.after)
			for line: Dictionary in p.get("then", []):
				if line.has("who"):
					out.append(line)
		for line: Dictionary in j.get("outro", []):
			out.append(line)
	return out
