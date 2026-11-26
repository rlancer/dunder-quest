class_name Judge
extends RefCounted

## Holds a take up against its scene's table read: which lines aired where
## they should, whether it plays, and what to say about it if not.


## The take a scene's cues make: the program, what it airs and how, and,
## line by line, whether each aired where the table read has it.
##   "program", "source", "out", "trace", "rows" ([{"ok"}]), "won",
##   "why" ("miss" or "nocue"), "got" and "want" (the first line out of place),
##   "photo" (true if two timers are due too close together to call).
static func judge(scene: Dictionary, cues: Dictionary) -> Dictionary:
	var program := Loop.build(scene.script, cues)
	var ran := Loop.run(program)
	var out: Array = ran.out
	var want: Array = scene.want
	var rows: Array = []
	for i in want.size():
		rows.append({"ok": i < out.size() and str(out[i]) == str(want[i])})
	var result := {
		"program": program, "source": Loop.source(program), "out": out, "trace": ran.trace,
		"rows": rows, "won": out == want, "photo": bool(ran.photo),
	}
	if ran.has("error"):
		result["error"] = ran.error
	if not result.won:
		result["why"] = "nocue" if cues.is_empty() else "miss"
		for i in want.size():
			if i >= out.size() or str(out[i]) != str(want[i]):
				result["got"] = str(out[i]) if i < out.size() else ""
				result["want"] = str(want[i])
				break
	return result


## A stock line with its blanks filled in from a take.
static func fill(template: String, result: Dictionary) -> String:
	return template.replace("{got}", str(result.get("got", ""))).replace("{want}", str(result.get("want", "")))
