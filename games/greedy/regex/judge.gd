class_name Judge
extends RefCounted

## Holds a poster up against its lineup. Each line is somebody to catch
## (`want`) or somebody to leave alone. From the fourth job on, a line to
## catch may also say how much of it to `take`: the text the pattern (or the
## poster's `group`) must match, no more and no less.


## {"error": {...}} if the chips don't make a pattern, else {"rows": [...],
## "won": bool, "pattern": String}. Each row: {"found", "start", "end" (the
## whole match), "take_start", "take_end" (what was captured), "ok", "why"}.
## `why` is "" when ok, else "walks", "innocent", "more", "less", "wrong" or
## "nogroup".
static func judge(poster: Dictionary, tokens: Array) -> Dictionary:
	if tokens.is_empty():
		return {"error": {"error": "empty"}}
	var problem := Rx.check(tokens)
	if not problem.is_empty():
		return {"error": problem}
	var pattern := Rx.text(tokens)
	var group := int(poster.get("group", 0))
	var rows: Array = []
	var won := true
	for line: Dictionary in poster.lines:
		var r := row(line, pattern, group)
		if r.has("invalid"):
			return {"error": {"error": "invalid"}}
		if not r.ok:
			won = false
		rows.append(r)
	return {"rows": rows, "won": won, "pattern": pattern}


static func row(line: Dictionary, pattern: String, group: int) -> Dictionary:
	var subject := str(line.text)
	var m := Rx.search(pattern, subject)
	if m.has("invalid"):
		return {"invalid": true, "ok": false}
	var want := bool(line.want)
	var out := {"found": bool(m.found), "start": -1, "end": -1, "take_start": -1, "take_end": -1, "ok": false, "why": ""}
	if not m.found:
		out.ok = not want
		out.why = "walks" if want else ""
		return out
	out.start = m.start
	out.end = m.end
	var groups: Array = m.groups
	if group < groups.size():
		out.take_start = groups[group][0]
		out.take_end = groups[group][1]
	if not want:
		out.why = "innocent"
		return out
	if not line.has("take"):
		out.ok = true
		return out
	if int(out.take_start) < 0:
		out.why = "nogroup"
		return out
	var captured := subject.substr(out.take_start, int(out.take_end) - int(out.take_start))
	var take := str(line.take)
	if captured == take:
		out.ok = true
	elif captured.contains(take):
		out.why = "more"
	elif take.contains(captured):
		out.why = "less"
	else:
		out.why = "wrong"
	return out


## What was captured on a row, as text.
static func got(line: Dictionary, r: Dictionary) -> String:
	var subject := str(line.text)
	if int(r.take_start) >= 0:
		return subject.substr(r.take_start, int(r.take_end) - int(r.take_start))
	if int(r.start) >= 0:
		return subject.substr(r.start, int(r.end) - int(r.start))
	return ""


## The first row that's wrong, or -1.
static func first_wrong(result: Dictionary) -> int:
	var rows: Array = result.get("rows", [])
	for i in rows.size():
		if not rows[i].ok:
			return i
	return -1
