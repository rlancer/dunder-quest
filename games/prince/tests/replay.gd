extends SceneTree

## Runs every room's history, triggers and solution, and every probe, through
## the in-game Git (git/repo.gd) and writes what it did to
## tests/out/replay.json: each command as git argv, its exit code and output
## lines, and the branches and files after it. tests/verify_git.ts repeats the
## same commands with the real git and demands the same of it.
##
## Also checks the model against the level data: steps marked {"fails": true}
## must fail and the rest succeed, and every solution must open the exit.
##
##     godot --headless --path . --script res://tests/replay.gd    # REPLAY result=ok


func _init() -> void:
	var fails := PackedStringArray()
	var runs := []
	for level: Dictionary in Story.data().levels:
		var run := _run(level, "solution", level.solution, fails)
		if not run.exit_open:
			fails.append("%d: the solution doesn't open the exit" % level.id)
		runs.append(run)
	for probe: Dictionary in Story.data().probes:
		runs.append(_run(Story.level(int(probe.level)), probe.name, probe.steps, fails))
	DirAccess.make_dir_recursive_absolute("res://tests/out")
	var file := FileAccess.open("res://tests/out/replay.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"authors": GitRepo.AUTHORS, "date": GitRepo.DATE, "runs": runs}, " "))
	file.close()
	print("REPLAY result=%s (%d runs)" % ["ok" if fails.is_empty() else "FAIL " + "; ".join(fails), runs.size()])
	quit(0 if fails.is_empty() else 1)


func _run(level: Dictionary, name: String, steps: Array, fails: PackedStringArray) -> Dictionary:
	var repo := Steps.open_room(level)
	# Where the room's own history ends and the player's commands begin.
	var setup := repo.log.size()
	for step: Array in Steps.expand(level, steps):
		var result := Steps.run(repo, level, step)
		if result.is_empty():
			continue
		var must_fail: bool = Steps.options(step).get("fails", false)
		if name == "solution" and must_fail != (int(result.exit) != 0):
			fails.append("%d: %s exited %d (%s)" % [level.id, " ".join(result.cmd), result.exit, " / ".join(result.out)])
	return {
		"level": int(level.id), "name": name, "protect_main": repo.protect_main, "setup": setup,
		"log": repo.log, "exit_open": Steps.exit_open(repo, level),
	}
