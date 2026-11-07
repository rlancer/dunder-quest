extends SceneTree

## Every curriculum module, and the capstone, has an episode. Reads the
## module headings from CURRICULUM.md, so editing the curriculum flags
## anything the season leaves uncovered. Also checks each built episode
## teaches the modules the outline says it does.
##
## godot --headless --path . --script res://tests/coverage.gd   ->  COVERAGE result=ok


func _initialize() -> void:
	var fails := PackedStringArray()
	var text := FileAccess.get_file_as_string("res://CURRICULUM.md")
	var wanted := []
	var re := RegEx.create_from_string("(?m)^## Module (\\d+):")
	for m in re.search_all(text):
		wanted.append(int(m.get_string(1)))
	if text.contains("\n## Capstone"):
		wanted.append("capstone")
	if wanted.size() < 2:
		fails.append("couldn't read the modules from CURRICULUM.md")
	var covered := {}
	var outline: Array = Season.data().get("outline", [])
	for entry in outline:
		for m in entry["modules"]:
			covered[_key(m)] = true
	for m in wanted:
		if not covered.has(_key(m)):
			fails.append("module %s has no episode" % _key(m))
	# Episode 1, the Pilot, has its own data (data/pilot.json).
	var built: Array = Season.episodes().duplicate()
	if not Season.pilot().is_empty():
		built.push_front(Season.pilot())
	for ep in built:
		var match_found := false
		for entry in outline:
			if int(entry["id"]) == int(ep["id"]):
				match_found = true
				if str(entry["modules"]) != str(ep["modules"]) or entry["title"] != ep["title"]:
					fails.append("episode %d doesn't match the outline" % ep["id"])
		if not match_found:
			fails.append("episode %d isn't in the outline" % ep["id"])
	print("COVERAGE %d modules, %d episodes outlined, %d built" % [wanted.size(), outline.size(), built.size()])
	print("COVERAGE result=%s" % ("ok" if fails.is_empty() else "FAIL " + "; ".join(fails)))
	quit(0 if fails.is_empty() else 1)


## JSON numbers arrive as floats: module 7 and 7.0 are the same module.
func _key(m: Variant) -> String:
	return str(int(m)) if m is float or m is int else str(m)
