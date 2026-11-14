extends Node

## Plays every room to the end the way a player would: runs and jumps the
## Prince with the real input actions, and works the dagger by pressing the
## console's real buttons. In every room it makes that room's mistake first
## and checks what the room teaches about it:
##
##   1  dies with a torch uncommitted: the reset loses it; and the door stays
##      shut until the last torch is committed
##   2  resets to HEAD when the Vizier's commit *is* HEAD: nothing changes
##   3  resets past the Vizier and loses the Princess's bridge; ORIG_HEAD
##      brings it back; then reverts just his commit
##   4  commits on main: the guard refuses; merges the wrong door
##   5  takes the wrong side of the conflict: the gate stays barred
##
## Then it checks the git commands it ran are exactly the room's solution in
## data/levels.json, which tests/verify_git.ts holds to the real git.
## Prints one line per room and BOT result=ok (or the failures) at the end.
##
##     godot --headless --path . res://tests/bot.tscn [-- room=N]

const FRAME_CAP := 60 * 40

var _fails: PackedStringArray = []
var room: Room
var _id: int = 0


func _ready() -> void:
	Progress.persist = false
	Room.test_fast = true
	StageAudio.web_audio_unlocked = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	reparent(tree.root)
	tree.current_scene = null
	var only := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("room="):
			only = int(arg.get_slice("=", 1))
	for id in range(1, Story.count() + 1):
		if only == 0 or only == id:
			await _play(id)
	print("BOT result=%s" % ("ok" if _fails.is_empty() else "FAIL " + "; ".join(_fails)))
	_finish()
	tree.quit(0 if _fails.is_empty() else 1)


func _finish() -> void:
	pass


## Hook for the screenshot run: a named moment worth keeping.
func moment(_name: String) -> void:
	pass


func _fail(text: String) -> void:
	_fails.append("room %d: %s" % [_id, text])
	print("  FAIL room %d: %s" % [_id, text])


func _expect(ok: bool, text: String) -> void:
	if not ok:
		_fail(text)


func _play(id: int) -> void:
	_id = id
	var before := _fails.size()
	Main.play(get_tree(), id)
	await wait_until(func() -> bool: return get_tree().current_scene is Room and (get_tree().current_scene as Room).level_id == id, 300)
	room = get_tree().current_scene as Room
	if room == null or room.level_id != id:
		_fail("didn't load")
		return
	await moment("%d_title" % id)
	if not await wait_until(func() -> bool: return room.state == "play", 600):
		_fail("never got past the title card")
		return
	await call("_room_%d" % id)
	_release()
	if _fails.size() > before:
		return
	if not await wait_until(func() -> bool: return room.state == "clear", 300):
		_fail("never cleared (state %s, at %s, door: %s)" % [room.state, room.prince.pos, room.door_says()])
		return
	_expect(Progress.is_cleared(id), "cleared but not saved")
	_check_solution()
	await moment("%d_clear" % id)
	print("room %d \"%s\" cleared: %d git commands, %d deaths" % [id, room.level.title, room.commands_run, room.deaths])


## The commands the bot ran must be the solution's, in order.
func _check_solution() -> void:
	var level := room.level
	var want := Steps.open_room(level)
	var setup := want.log.size()
	for step: Array in Steps.expand(level, level.solution):
		Steps.run(want, level, step)
	var ran := _commands(room.repo.log.slice(setup))
	var expected := _commands(want.log.slice(setup))
	_expect(ran == expected, "ran %s, the solution is %s" % [ran, expected])


func _commands(entries: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for entry: Dictionary in entries:
		if entry.has("cmd"):
			out.append(Console.shown(entry.cmd))
	return out


# --- hands and feet ----------------------------------------------------------

func wait_until(test: Callable, frames: int) -> bool:
	for _i in frames:
		if test.call():
			return true
		await get_tree().physics_frame
	return test.call()


func _release() -> void:
	for action in [&"move_left", &"move_right", &"jump", &"dagger"]:
		Input.action_release(action)


## Runs until his feet pass x (in the direction it lies).
func run_to(x: float) -> void:
	var dir := signf(x - room.prince.pos.x)
	var action := &"move_right" if dir > 0.0 else &"move_left"
	Input.action_press(action)
	var arrived := await wait_until(func() -> bool:
		return room.state != "play" or (room.prince.pos.x - x) * dir >= 0.0, FRAME_CAP)
	Input.action_release(action)
	if not arrived:
		_fail("never reached x=%d (stuck at %s)" % [x, room.prince.pos])
	await get_tree().physics_frame


## Runs to x, then jumps and holds the direction until he lands (or dies).
func jump_from(x: float, dir: float) -> void:
	await run_to(x)
	var action := &"move_right" if dir > 0.0 else &"move_left"
	Input.action_press(action)
	Input.action_press(&"jump")
	await get_tree().physics_frame
	await get_tree().physics_frame
	await wait_until(func() -> bool: return room.state != "play" or room.prince.on_floor, 240)
	Input.action_release(&"jump")
	Input.action_release(action)
	await get_tree().physics_frame


## Waits for him to come to rest on a floor (after a drop).
func settle() -> void:
	await wait_until(func() -> bool: return room.state != "play" or (room.prince.on_floor and absf(room.prince.vel.x) < 1.0), 300)


## Draws the dagger (if it isn't out) and presses these buttons in order.
## Returns git's last result.
func git(acts: Array) -> Dictionary:
	if room.state == "play":
		await settle()
		Input.action_press(&"dagger")
		await get_tree().physics_frame
		await get_tree().physics_frame
		Input.action_release(&"dagger")
	if not await wait_until(func() -> bool: return room.state == "dagger" and room.console.visible, 240):
		_fail("the dagger didn't come out (state %s)" % room.state)
		return {}
	var before := room.repo.log.size()
	for act: String in acts:
		await get_tree().process_frame
		await get_tree().process_frame
		if not room.console.press(act):
			_fail("no button %s (there are: %s)" % [act, ", ".join(room.console.acts())])
			return {}
	await get_tree().process_frame
	await get_tree().process_frame
	await moment("%d_git_%d" % [_id, room.commands_run])
	var last := {}
	for entry: Dictionary in room.repo.log.slice(before):
		if entry.has("cmd"):
			last = entry
	return last


## Puts the dagger away if a failed command left it out, and waits for play.
func resume() -> void:
	await get_tree().process_frame
	if room.state == "dagger" and room.prince.alive and room.repo.merging.is_empty():
		room.console.press("close")
	if not await wait_until(func() -> bool: return room.state == "play" or room.state == "clear", 300):
		_fail("play never resumed (state %s)" % room.state)


func sha(rev: String) -> String:
	return room.repo.resolve(rev)


# --- the rooms ---------------------------------------------------------------

func _room_1() -> void:
	await run_to(104)
	_expect(room.value("torch_1") == "lit", "torch 1 didn't light")
	_expect((await git(["commit"])).get("exit", 1) == 0, "the first commit failed")
	await resume()
	await jump_from(134, 1.0)
	await jump_from(202, 1.0)
	await run_to(266)
	_expect(room.value("torch_2") == "lit", "torch 2 didn't light")
	await moment("1_uncommitted")
	# Off the edge onto the spikes, with torch 2 not committed.
	await run_to(330)
	await wait_until(func() -> bool: return room.state == "dagger", 240)
	_expect(not room.prince.alive, "the spikes didn't kill him")
	await moment("1_dead")
	_expect(not ("commit" in room.console.acts()), "a dead prince can commit")
	await git(["menu:reset", "pick:HEAD"])
	await resume()
	_expect(room.value("torch_2") == "dark", "the reset kept an uncommitted torch")
	_expect(room.value("torch_1") == "lit", "the reset lost a committed torch")
	_expect(room.prince.alive and absf(room.prince.pos.x - 104) < 12, "he didn't come back to where he committed (%s)" % room.prince.pos)
	await jump_from(134, 1.0)
	await jump_from(202, 1.0)
	await run_to(266)
	await git(["commit"])
	await resume()
	await jump_from(314, 1.0)
	await run_to(444)
	for _i in 20:
		await get_tree().physics_frame
	_expect(room.value("torch_3") == "lit", "torch 3 didn't light")
	_expect(room.state == "play", "the door opened on an uncommitted torch")
	await moment("1_door")
	await git(["commit"])
	await resume()


func _room_2() -> void:
	await run_to(90)
	_expect(room.value("bridge") == "down", "the plate didn't lower the bridge")
	await git(["commit"])
	await resume()
	await run_to(246)
	if not await wait_until(func() -> bool: return room.state == "play" and room.value("spikes") == "armed", 600):
		_fail("the Vizier never committed")
		return
	_expect(room.repo.commits[sha("HEAD")].author == "vizier", "HEAD isn't the Vizier's commit")
	await moment("2_vizier")
	await git(["menu:reset", "pick:HEAD"])
	await resume()
	_expect(room.value("spikes") == "armed" and room.value("door") == "barred", "resetting to HEAD undid the Vizier's commit")
	await git(["menu:reset", "pick:" + sha("HEAD~1")])
	await resume()
	_expect(room.value("spikes") == "sheathed" and room.value("door") == "open" and room.value("bridge") == "down", "the older commit isn't back")
	await run_to(446)


func _room_3() -> void:
	await git(["menu:reset", "pick:" + sha("msg:The room as you found it")])
	await resume()
	_expect(room.value("bridge") == "up", "the reset kept the Princess's bridge")
	await moment("3_lost")
	await git(["menu:reset", "pick:ORIG_HEAD"])
	await resume()
	_expect(room.value("bridge") == "down" and room.value("door") == "barred", "ORIG_HEAD didn't bring the history back")
	await run_to(262)
	_expect(room.value("portcullis") == "open", "the lever didn't raise the portcullis")
	await run_to(428)
	for _i in 10:
		await get_tree().physics_frame
	_expect(room.state == "play", "a barred door opened")
	await git(["menu:revert", "pick:" + sha("msg:Bar the door")])
	await resume()
	_expect(room.value("door") == "open" and room.value("bridge") == "down", "the revert didn't keep the bridge and unbar the door")
	for _i in 10:
		await get_tree().physics_frame
	_expect(room.state == "play", "the door opened with the portcullis uncommitted")
	await git(["commit"])
	await resume()
	await run_to(432)


func _room_4() -> void:
	await run_to(82)
	await settle()
	await run_to(58)
	_expect(room.value("gate") == "open", "the left lever didn't open the gate")
	var refused := await git(["commit"])
	_expect(refused.get("exit", 0) != 0 and room.repo.head == "main" and room.repo.history().size() == 1, "the guard let a commit onto main")
	await moment("4_guard")
	await git(["menu:switch_c", "pick:left"])
	await resume()
	await git(["commit"])
	await resume()
	await git(["menu:switch", "pick:main"])
	await resume()
	_expect(room.value("gate") == "shut" and room.prince.pos.y < 150, "main isn't as he left it")
	await git(["menu:switch_c", "pick:right"])
	await resume()
	await run_to(240)
	await settle()
	await run_to(392)
	_expect(room.value("spikes") == "armed", "the right lever didn't arm the spikes")
	await git(["commit"])
	await resume()
	await git(["menu:switch", "pick:main"])
	await resume()
	await git(["menu:merge", "pick:right"])
	await resume()
	_expect(room.value("spikes") == "armed" and not Steps.exit_open(room.repo, room.level), "merging the wrong door opened the exit")
	await moment("4_wrong")
	await git(["menu:reset", "pick:ORIG_HEAD"])
	await resume()
	await git(["menu:merge", "pick:left"])
	await resume()
	_expect(room.value("gate") == "open" and room.value("spikes") == "sheathed", "the left door's timeline isn't merged")
	# Over the right-hand drop on the way to the gate.
	await jump_from(214, 1.0)
	await run_to(446)


func _room_5() -> void:
	await git(["menu:switch_c", "pick:tower"])
	await resume()
	await run_to(50)
	await settle()
	await run_to(44)
	_expect(room.value("gate") == "open", "the tower lever didn't open the gate")
	await git(["commit"])
	await resume()
	await git(["menu:switch", "pick:main"])
	await resume()
	await git(["menu:switch_c", "pick:winch"])
	await resume()
	await run_to(158)
	await settle()
	await run_to(164)
	_expect(room.value("bridge") == "down" and room.value("gate") == "barred", "the winch didn't lower the bridge and bar the gate")
	await git(["commit"])
	await resume()
	await git(["menu:switch", "pick:main"])
	await resume()
	await git(["menu:merge", "pick:tower"])
	await resume()
	var conflict := await git(["menu:merge", "pick:winch"])
	_expect(conflict.get("exit", 0) != 0 and room.value("gate") == "conflict", "merging the winch didn't conflict")
	_expect(room.value("bridge") == "down", "the bridge didn't merge on its own")
	await moment("5_conflict")
	await git(["keep:gate:theirs", "commit_merge"])
	await resume()
	_expect(room.value("gate") == "barred" and not Steps.exit_open(room.repo, room.level), "the wrong side opened the gate")
	await git(["menu:reset", "pick:ORIG_HEAD"])
	await resume()
	await git(["menu:merge", "pick:winch"])
	await git(["keep:gate:ours", "commit_merge"])
	await resume()
	_expect(room.value("gate") == "open" and room.value("bridge") == "down", "the merge isn't right")
	await moment("5_merged")
	await jump_from(134, 1.0)
	await run_to(446)
	# The Vizier stops him just past the gate; then on to the door.
	await wait_until(func() -> bool: return room.state == "play" or room.state == "clear", 600)
	if room.state == "play":
		await run_to(446)
