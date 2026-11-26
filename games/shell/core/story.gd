class_name Story
extends RefCounted

## The script of every shift, from data/shifts.json: the cast, the kitchen's
## files, each shift's dialogue, its tickets (a brief, the chips on the
## table, the files in the kitchen, what should reach the pass and the line
## that sends it), the lesson cards, what each chip means in plain words,
## and Shell's stock lines for a line that misses. tests/replay.gd reads the
## same file, and tests/verify_shell.ts holds every line in it to the real
## bash.

const PATH := "res://data/shifts.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_data = parsed
		else:
			push_error("data/shifts.json is missing or malformed")
	return _data


static func shifts() -> Array:
	return data().get("shifts", [])


static func count() -> int:
	return shifts().size()


static func shift(id: int) -> Dictionary:
	for j: Dictionary in shifts():
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


## A kitchen's files as the shell wants them: name -> text, from a list of
## names in the data's "files", or a dictionary of name -> lines.
static func files(source: Variant) -> Dictionary:
	var out := {}
	if source is Dictionary:
		for name: String in source:
			out[name] = _joined(source[name])
	else:
		var all: Dictionary = data().get("files", {})
		for name: String in source:
			out[name] = _joined(all.get(name, []))
	return out


static func _joined(lines: Array) -> String:
	var text := ""
	for line: String in lines:
		text += line + "\n"
	return text


## What Shell says about a line the shell won't run.
static func error_text(problem: Dictionary) -> String:
	var key := str(problem.get("why", "empty"))
	var template := str((data().get("errors", {}) as Dictionary).get(key, "The shell won't run that, Chef. Read what it says: it usually means it."))
	return template.replace("{token}", str(problem.get("token", "")))


## What a chip means in plain words. `before` is the chips ahead of it on
## the line, which is how -c after grep differs from -c after uniq.
static func meaning(chip: String, before: Array = []) -> String:
	var glossary: Dictionary = data().get("glossary", {})
	var command := ""
	for earlier: String in before:
		for word: String in Shell.split(earlier):
			if word == "|":
				command = ""
			elif command == "" and Shell.commands().has(word):
				command = word
	if command != "" and glossary.has("%s %s" % [command, chip]):
		return str(glossary["%s %s" % [command, chip]])
	if glossary.has(chip):
		return str(glossary[chip])
	if chip.begins_with("-n "):
		return str(glossary.get("-n N", ""))
	if chip.begins_with("> "):
		return str(glossary.get("> file", ""))
	if (data().get("files", {}) as Dictionary).has(chip):
		return "a file: %d lines" % (data().files[chip] as Array).size()
	return str(glossary.get("word", ""))


## The fewest chips that solve a ticket: its written solution's length.
## tests/replay.gd proves nothing shorter works.
static func par(ticket: Dictionary) -> int:
	return (ticket.get("solution", []) as Array).size()


## Every line of dialogue in the shifts, in order: {"who", "text"}.
static func spoken_lines() -> Array:
	var out: Array = []
	for j: Dictionary in shifts():
		for line: Dictionary in j.get("intro", []):
			out.append(line)
		for p: Dictionary in j.get("tickets", []):
			out.append(p.brief)
			if p.has("after"):
				out.append(p.after)
			for line: Dictionary in p.get("then", []):
				if line.has("who"):
					out.append(line)
		for line: Dictionary in j.get("outro", []):
			out.append(line)
	return out
