class_name Judge
extends RefCounted

## Holds a request up against its scene: what the counter answered, whether
## that's what the scene wanted, and what to say about it if not.


## The counter a scene is at: its name in the data's counters (or, for the
## tests' probes, the counter itself).
static func counter(scene: Dictionary) -> Dictionary:
	var c: Variant = scene.get("counter", "")
	if c is Dictionary:
		return c
	return (Story.data().get("counters", {}) as Dictionary).get(str(c), {})


## The counter's data as the scene sets it out.
static func start(scene: Dictionary) -> Dictionary:
	return Http.state(scene.get("data", {}), scene.get("versions", {}))


## What the cards on a slip make of the scene: "slip", "request" (its lines),
## and, if it can be sent, "response" (Http.answer) and "lines" (the
## response's), "won", and if it missed, "why" (a status like "404", "wrong"
## for a 2xx that isn't what was wanted, or "miss"), "got" and "want" (the two
## status lines). If it can't be sent, "refused" says why.
static func judge(scene: Dictionary, cards: Array) -> Dictionary:
	var s := Http.slip(cards)
	var c := counter(scene)
	var result := {"slip": s, "request": Http.request_lines(s, str(c.get("host", "")))}
	var why := Http.refuse(s)
	if why != "":
		result["refused"] = why
		return result
	var r := Http.answer(c, start(scene), s)
	result["response"] = r
	result["lines"] = Http.response_lines(r)
	result["won"] = wins(scene, s, r)
	if not result.won:
		var goal: Dictionary = scene.goal
		result["got"] = "%d %s" % [int(r.status), r.reason]
		result["want"] = "%d %s" % [int(goal.status), Http.REASONS.get(int(goal.status), "")]
		var code := str(int(r.status))
		if int(r.status) == int(goal.status) or int(r.status) < 300:
			result["why"] = "wrong"
		elif not Story.stock(code).is_empty():
			result["why"] = code
		else:
			result["why"] = "miss"
	return result


## Whether response `r` to slip `s` is what the scene's goal asks for: the
## status, and where it says so, the method, the path and the data left.
static func wins(scene: Dictionary, s: Dictionary, r: Dictionary) -> bool:
	var goal: Dictionary = scene.goal
	if int(r.status) != int(goal.status):
		return false
	if goal.has("method") and str(s.method) != str(goal.method):
		return false
	if goal.has("path") and str(s.path) != str(goal.path):
		return false
	for route: String in goal.get("state", {}):
		var now: Variant = (r.state.items as Dictionary).get(route, [])
		if Wire.write(now) != Wire.write(goal.state[route]):
			return false
	return true


## A stock line with its blanks filled in.
static func fill(template: String, result: Dictionary) -> String:
	return template.replace("{got}", str(result.get("got", ""))).replace("{want}", str(result.get("want", "")))
