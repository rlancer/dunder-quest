extends SceneTree

## Runs every plan in every combination of its blanks through the in-game
## checker (and, when it compiles, the runner), and writes the verdicts to
## tests/out/cases.json for tests/verify_rust.py to hold up against rustc.
## Also checks each plan's starting picks fail the way the scene says and its
## solution prints exactly what the scene needs.
##
##   godot --headless --path . --script res://tests/cases.gd   ->  CASES result=ok

func _init() -> void:
	var fails: PackedStringArray = []
	var cases: Array = []
	for scene: Dictionary in Story.scenes():
		for d: Dictionary in scene.plans:
			var plan := Plan.from_data(d)
			for combo: Dictionary in plan.combinations():
				plan.set_picks(combo)
				var result := plan.evaluate()
				var entry := {
					"plan": plan.id,
					"picks": plan.picks(),
					"source": plan.source(),
					"ok": result.ok,
					"codes": [],
					"stdout": [],
					"panic": "",
				}
				for e: Dictionary in result.errors:
					(entry.codes as Array).append(e.code)
				if result.ok:
					entry.stdout = result.run.stdout
					entry.panic = result.run.panic
				else:
					entry["first"] = "%s line %d: %s" % [result.error.code, result.error.line, result.error.msg]
				cases.append(entry)
				if OS.get_cmdline_user_args().has("verbose"):
					print("%s %s -> %s" % [plan.id, JSON.stringify(plan.picks()), entry.get("first", "ok " + JSON.stringify(entry.stdout) + (" PANIC " + entry.panic if entry.panic != "" else ""))])
			plan.set_picks(d.get("start", {}))
			var start := plan.evaluate()
			var want := str(d.get("start_error", ""))
			if want != "" and (start.ok or start.error.code != want):
				fails.append("%s: start picks gave %s, scene says %s" % [plan.id, "ok" if start.ok else start.error.code, want])
			plan.set_picks(d.get("solution", {}))
			var solved := plan.evaluate()
			if not solved.passed:
				fails.append("%s: solution %s" % [plan.id, ("printed " + JSON.stringify(solved.run.stdout)) if solved.ok else (solved.error.code + " " + solved.error.msg)])
	var dir := ProjectSettings.globalize_path("res://tests/out/")
	DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(dir + "cases.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(cases, "\t"))
	file.close()
	for f in fails:
		print("FAIL ", f)
	print("CASES %d combinations, result=%s" % [cases.size(), "ok" if fails.is_empty() else "FAIL"])
	quit(0 if fails.is_empty() else 1)
