class_name Judge
extends RefCounted

## Holds a line up against its ticket. The line is run by Shell in a kitchen
## holding the ticket's files; what reaches the pass (or, for a ticket that
## wants it written down, what lands in that file) has to be the ticket's
## lines, the same ones in the same order.


## {"error": {...}} if the shell won't run the chips (see Shell.run), else
## {"line": the text that ran, "got": the lines that came out, "where": ""
## for the pass or a file's name, "rows": one {"ok"} for each line of the
## ticket, "won", "why", "at"}. `why` is "" when won, else "nothing",
## "order", "extra", "short", "wrong", "tofile" (it came out loud, the ticket
## wants a file) or "infile" (the other way round); `at` is the line of the
## ticket, or of what came out, that `why` is about.
static func judge(ticket: Dictionary, tokens: Array) -> Dictionary:
	var line := " ".join(PackedStringArray(tokens))
	var ran := Shell.run(line, Story.files(ticket.get("files", [])))
	if ran.has("error"):
		return {"error": ran, "line": line}
	var want: Array = ticket.get("want", [])
	var target := str(ticket.get("want_file", ""))
	var out := lines(str(ran.out))
	var written: Dictionary = ran.files
	var got: Array = out
	var where := ""
	var why := ""
	if target != "":
		if written.has(target):
			got = lines(str(written[target]))
			where = target
		elif not out.is_empty():
			why = "tofile"
	elif out.is_empty() and not written.is_empty():
		where = str(written.keys()[0])
		got = lines(str(written[where]))
		why = "infile"
	var rows: Array = []
	for i in want.size():
		rows.append({"ok": why == "" and i < got.size() and str(got[i]) == str(want[i])})
	var at := 0
	if why == "":
		var verdict := compare(got, want)
		why = str(verdict[0])
		at = int(verdict[1])
	return {"line": line, "got": got, "where": where, "rows": rows, "won": why == "", "why": why, "at": at}


static func lines(text: String) -> Array:
	if text == "":
		return []
	return Array((text.left(-1) if text.ends_with("\n") else text).split("\n"))


## [why, at] for what came out against what was wanted.
static func compare(got: Array, want: Array) -> Array:
	if got == want:
		return ["", 0]
	if got.is_empty():
		return ["nothing", 0]
	var first := 0
	while first < got.size() and first < want.size() and str(got[first]) == str(want[first]):
		first += 1
	var a := got.duplicate()
	var b := want.duplicate()
	a.sort()
	b.sort()
	if a == b:
		return ["order", first]
	# Something sent that nobody ordered, or something ordered that never came.
	var spare := _missing(got, want)
	var owed := _missing(want, got)
	if owed < 0 and spare >= 0:
		return ["extra", spare]
	if spare < 0 and owed >= 0:
		return ["short", owed]
	return ["wrong", mini(first, got.size() - 1)]


## The first line of `from` that `of` hasn't got a copy of, or -1.
static func _missing(from: Array, of: Array) -> int:
	var left := of.duplicate()
	for i in from.size():
		var found := left.find(from[i])
		if found < 0:
			return i
		left.remove_at(found)
	return -1


## Shell's words for a miss: the blanks {got}, {want}, {n} and {file} filled.
static func fill(template: String, ticket: Dictionary, result: Dictionary) -> String:
	var got: Array = result.get("got", [])
	var want: Array = ticket.get("want", [])
	var at := int(result.get("at", 0))
	var why := str(result.get("why", ""))
	var got_line := str(got[at]) if at < got.size() else ""
	var want_line := str(want[at]) if at < want.size() else ""
	if why == "nothing":
		want_line = str(want[0])
	elif why == "extra":
		want_line = ""
	elif why == "short":
		got_line = ""
	elif why == "wrong" and at >= want.size():
		want_line = "nothing more"
	var file := str(ticket.get("want_file", "")) if why == "tofile" else str(result.get("where", ""))
	return template.replace("{got}", got_line.strip_edges()).replace("{want}", want_line.strip_edges()).replace("{n}", str(at + 1)).replace("{file}", file)
