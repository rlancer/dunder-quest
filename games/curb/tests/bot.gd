extends Node

## Plays every scene to the end the way a player would: walks Barry over
## with the real input actions, talks to whoever has the "!", fills in the
## legal pad and runs it. At every plan it runs the starting picks first and
## checks Sharon interrupts with the error the scene says (and that the scene
## doesn't move on), then runs the solution and checks the scene accepts it.
## Prints one line per scene and BOT result=ok (or the failures) at the end.
##
## godot --headless --path . res://tests/bot.tscn [-- scene=N]

const FRAME_CAP := 60 * 90

var _fails: PackedStringArray = []
var scene: CurbScene
## How long lines stay up (frames, and extra frames per character). The
## trailer capture raises these so lines can be read.
var line_frames: int = 2
var per_char: float = 0.0
var pace: float = 0.05
## Extra wrong picks to run between the start and the solution, by plan id
## (the trailer uses these to catch a panic and a wrong answer on camera).
var extra_tries: Dictionary = {}


func _ready() -> void:
	Progress.persist = false
	StageAudio.web_audio_unlocked = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	reparent(tree.root)
	tree.current_scene = null
	Hud.test_auto_frames = line_frames
	Hud.test_per_char = per_char
	CurbScene.test_pace = pace
	var only := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("scene="):
			only = int(arg.get_slice("=", 1))
	for id in range(1, Story.count() + 1):
		if only == 0 or only == id:
			await _play(id)
	print("BOT result=%s" % ("ok" if _fails.is_empty() else "FAIL " + "; ".join(_fails)))
	_finish()
	tree.quit(0 if _fails.is_empty() else 1)


func _finish() -> void:
	pass


## Hook for the screenshot and trailer runs: a named moment worth keeping.
func moment(_name: String) -> void:
	pass


func _play(id: int) -> void:
	Main.play_scene(get_tree(), id)
	await wait_until(func() -> bool: return get_tree().current_scene is CurbScene and (get_tree().current_scene as CurbScene).scene_id == id, 300)
	scene = get_tree().current_scene as CurbScene
	if scene == null or scene.scene_id != id:
		_fail("scene %d didn't load" % id)
		return
	await moment("open %d" % id)
	if not await wait_until(func() -> bool: return scene.state == "free", FRAME_CAP):
		_fail("%d: never got past the opening" % id)
		return
	for index in scene.plans.size():
		if not await _solve(id, index):
			return
	if not await wait_until(func() -> bool: return Progress.is_cleared(id) and not (get_tree().current_scene is CurbScene), FRAME_CAP):
		_fail("%d: never cleared (state %s)" % [id, scene.state if is_instance_valid(scene) else "gone"])
		return
	print("scene %d \"%s\" cleared in %d tries" % [id, Story.scene(id).title, Progress.best_tries(id)])


func _solve(id: int, index: int) -> bool:
	var plan: Plan = scene.plans[index]
	var npc := scene.npc_of(index)
	await walk_to(npc.position.x + (-20.0 if npc.position.x > scene.barry.position.x else 20.0))
	if absf(npc.position.x - scene.barry.position.x) > CurbScene.REACH:
		_fail("%s: Barry couldn't reach %s (x=%d, %s at %d)" % [plan.id, npc.who, scene.barry.position.x, npc.who, npc.position.x])
		return false
	await press(&"edit")
	if not await wait_until(func() -> bool: return scene.pad.is_open(), FRAME_CAP):
		_fail("%s: the pad never opened" % plan.id)
		return false
	await moment("pad %s" % plan.id)
	# Wrong first: the starting picks, which have to be stopped.
	plan.set_picks(plan.data.get("start", {}))
	var want := str(plan.data.get("start_error", ""))
	var verdict := plan.evaluate()
	if want != "" and (verdict.ok or verdict.error.code != want):
		_fail("%s: start picks gave %s, scene says %s" % [plan.id, "ok" if verdict.ok else verdict.error.code, want])
	var rants := scene.hud.rant_count
	await run_pad()
	if not await wait_until(func() -> bool: return scene.pad.is_open() or scene.done[index], FRAME_CAP):
		_fail("%s: stuck after the wrong run (state %s)" % [plan.id, scene.state])
		return false
	_check(not scene.done[index], "%s: the scene accepted the starting picks" % plan.id)
	_check(scene.hud.rant_count > rants or want == "", "%s: Sharon never interrupted" % plan.id)
	for picks: Dictionary in extra_tries.get(plan.id, []):
		plan.set_picks(picks)
		await run_pad()
		if not await wait_until(func() -> bool: return scene.pad.is_open() or scene.done[index], FRAME_CAP):
			_fail("%s: stuck after an extra try" % plan.id)
			return false
		_check(not scene.done[index], "%s: the scene accepted %s" % [plan.id, JSON.stringify(picks)])
	# Then right.
	plan.set_picks(plan.data.get("solution", {}))
	await run_pad()
	if not await wait_until(func() -> bool: return scene.done[index] or scene.pad.is_open(), FRAME_CAP):
		_fail("%s: stuck after the solution (state %s)" % [plan.id, scene.state])
		return false
	if not scene.done[index]:
		var r := plan.evaluate()
		_fail("%s: the solution wasn't accepted: %s" % [plan.id, r.error if not r.ok else r.run.stdout])
		return false
	return true


## Runs whatever is on the pad.
func run_pad() -> void:
	scene.pad.run()
	await _frames(3)


# --- Moves -------------------------------------------------------------------

func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


func walk_to(x: float, limit: int = 900) -> void:
	var frames := 0
	while absf(scene.barry.position.x - x) > 3.0 and frames < limit:
		var right := scene.barry.position.x < x
		Input.action_press(&"move_right" if right else &"move_left")
		Input.action_release(&"move_left" if right else &"move_right")
		await _frames(1)
		frames += 1
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	await _frames(2)


func press(action: StringName) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await _frames(2)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(1)


func wait_until(test: Callable, limit: int = 600) -> bool:
	var frames := 0
	while not test.call() and frames < limit:
		await _frames(1)
		frames += 1
	return test.call()


func _fail(text: String) -> void:
	_fails.append(text)
	print("FAIL ", text)


func _check(ok: bool, text: String) -> void:
	if not ok:
		_fail(text)
