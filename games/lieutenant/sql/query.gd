class_name Query
extends RefCounted

## What's on a page of the notebook: which chips are picked on each line,
## and the SQL they spell. The SQL text is the only thing that gets run.

## The lines of a query, in the order SQL wants them written.
const LINES := ["select", "from", "join", "where", "group", "having", "order", "limit"]
## Lines that take several chips; the rest hold one.
const MULTI := ["select", "join", "where"]
const KEYWORD := {"select": "SELECT", "from": "FROM", "join": "", "where": "WHERE", "group": "GROUP BY", "having": "HAVING", "order": "ORDER BY", "limit": "LIMIT"}
## What a line is called on the page (JOIN chips carry their own keyword).
const LABEL := {"select": "SELECT", "from": "FROM", "join": "JOIN", "where": "WHERE", "group": "GROUP BY", "having": "HAVING", "order": "ORDER BY", "limit": "LIMIT"}


static func empty() -> Dictionary:
	return {"select": [], "from": "", "join": [], "where": [], "logic": "AND", "group": "", "having": "", "order": "", "limit": ""}


## Picks from a beat's JSON ("solution"), with every line present.
static func from_data(source: Dictionary) -> Dictionary:
	var picks := empty()
	for key: String in source:
		if MULTI.has(key):
			picks[key] = (source[key] as Array).duplicate()
		else:
			picks[key] = str(source[key])
	return picks


## The SQL, one clause to a line.
static func compose(picks: Dictionary) -> String:
	var lines := PackedStringArray()
	var select: Array = picks.get("select", [])
	lines.append("SELECT " + ", ".join(PackedStringArray(select)) if not select.is_empty() else "SELECT")
	if str(picks.get("from", "")) != "":
		lines.append("FROM " + str(picks.from))
	for join: String in picks.get("join", []):
		lines.append(join)
	var where: Array = picks.get("where", [])
	if not where.is_empty():
		lines.append("WHERE " + (" %s " % str(picks.get("logic", "AND"))).join(PackedStringArray(where)))
	for key: String in ["group", "having", "order", "limit"]:
		if str(picks.get(key, "")) != "":
			lines.append("%s %s" % [KEYWORD[key], picks[key]])
	return "\n".join(lines)


## Is `chip` picked on `line`?
static func has(picks: Dictionary, line: String, chip: String) -> bool:
	if line == "logic":
		return str(picks.get("logic", "AND")) == chip and (picks.get("where", []) as Array).size() > 1
	if MULTI.has(line):
		return (picks.get(line, []) as Array).has(chip)
	return str(picks.get(line, "")) == chip


## Taps a chip: multi lines add or drop it, single lines swap or clear.
static func toggle(picks: Dictionary, line: String, chip: String) -> void:
	if line == "logic":
		picks["logic"] = chip
	elif MULTI.has(line):
		var list: Array = picks[line]
		if list.has(chip):
			list.erase(chip)
		else:
			list.append(chip)
	else:
		picks[line] = "" if str(picks[line]) == chip else chip
