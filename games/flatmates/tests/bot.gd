extends Node

## Plays every stage to the end with real physics and real input actions,
## the way a player would: walks, jumps, swaps heads, fills in each laptop's
## blanks and runs it. Also runs a wrong answer at every laptop first and
## checks the stage still isn't passable that way. Prints one line per stage
## and BOT result=ok (or the failures) at the end.
##
## godot --headless --path . res://tests/bot.tscn [-- stage=N]

const FRAME_CAP := 60 * 120

var _fails: PackedStringArray = []
var _stage: Stage


func _ready() -> void:
	Progress.persist = false
	StageAudio.web_audio_unlocked = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	reparent(tree.root)
	tree.current_scene = null
	var only := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("stage="):
			only = int(arg.get_slice("=", 1))
	var id := 1
	while ResourceLoader.exists("res://stages/stage_%d.gd" % id):
		if only == 0 or only == id:
			await _play(id)
		id += 1
	print("BOT result=%s" % ("ok" if _fails.is_empty() else "FAIL " + "; ".join(_fails)))
	tree.quit(0 if _fails.is_empty() else 1)


func _play(id: int) -> void:
	Main.play_stage(get_tree(), id)
	while not get_tree().current_scene is Stage or (_stage != null and get_tree().current_scene == _stage):
		await get_tree().process_frame
	_stage = get_tree().current_scene as Stage
	await _frames(5)
	_check(_stage._biscuit_total == int(Progress.stage(id).biscuits), "%d: %d custard creams, the map says %d" % [id, _stage._biscuit_total, Progress.stage(id).biscuits])
	var solver := "_solve_%d" % id
	if not has_method(solver):
		_fail("stage %d has no solver" % id)
		return
	await call(solver)
	var start := Engine.get_physics_frames()
	while not _stage._cleared and Engine.get_physics_frames() - start < 60 * 6:
		await _frames(1)
	_dump_sources(id)
	if _stage._cleared:
		print("stage %d cleared in %.1fs, %d runs, %d falls, %d/%d biscuits" % [id, _stage._elapsed, _stage._runs, _stage._falls, _stage._biscuits, _stage._biscuit_total])
	else:
		_fail("stage %d not cleared (clive x=%d, jazz x=%d)" % [id, _tile(_stage.clive), _tile(_stage.jazz)])
	_release_all()
	_stage.hud._results_open = false
	get_tree().paused = false


## Writes each laptop's script, as solved, to tests/out/ for
## tests/check_sources.mjs to parse with Node: the code the player sees has to
## be real JavaScript.
func _dump_sources(id: int) -> void:
	var dir := ProjectSettings.globalize_path("res://tests/out/")
	DirAccess.make_dir_recursive_absolute(dir)
	for index in _stage._laptops.size():
		var program: JsProgram = _stage._laptops[index].program
		var file := FileAccess.open(dir + "stage%d_%d_%s.mjs" % [id, index, program.file_name.get_basename()], FileAccess.WRITE)
		file.store_string(program.source() + "
")


# --- Moves -------------------------------------------------------------------

func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame
		_dismiss()


## Cards pop up as the player walks; read them and carry on.
func _dismiss() -> void:
	if _stage != null and is_instance_valid(_stage) and _stage.hud._card_open:
		_stage.hud._close_card()


func _tile(mate: Flatmate) -> int:
	return int(floor(mate.global_position.x / 16.0))


func _be(who: String) -> void:
	if _stage.active.who != who:
		_stage.swap()
	await _frames(2)


## Walks the active flatmate until his tile is `x`, jumping when `hop` says.
func walk_to(x: int, jump_at: Array = [], limit: int = 600) -> bool:
	var mate := _stage.active
	var frames := 0
	var jumped: Dictionary = {}
	while _tile(mate) != x and frames < limit:
		var right := _tile(mate) < x
		Input.action_press(&"move_right" if right else &"move_left")
		Input.action_release(&"move_left" if right else &"move_right")
		for spot: int in jump_at:
			if _tile(mate) == spot and not jumped.has(spot) and mate.is_on_floor():
				jumped[spot] = true
				await jump()
		await _frames(1)
		frames += 1
	_release_all()
	if _tile(mate) != x and OS.get_cmdline_user_args().has("verbose"):
		print("  walk_to(%d) by %s stopped at %d y %d" % [x, mate.who, _tile(mate), mate.global_position.y])
	# Let him come to a stop on the tile, and land if he walked off an edge.
	for _i in 60:
		if absf(mate.velocity.x) < 1.0 and mate.is_on_floor():
			break
		await _frames(1)
	return _tile(mate) == x


## Jumps toward tile `x` and steers onto it: holds jump, moves until over
## the tile, then lets go of the direction and waits to land.
func jump_to(x: int, hold: int = 26) -> bool:
	var mate := _stage.active
	var right := x > _tile(mate)
	Input.action_press(&"jump")
	var frames := 0
	while frames < 90:
		var over := _tile(mate) == x and absf(mate.global_position.x - (x * 16 + 8)) < 5.0
		if over:
			_release_moves()
			# Stop drifting: tap the other way for a frame if still sliding.
			if absf(mate.velocity.x) > 30.0:
				Input.action_press(&"move_left" if right else &"move_right")
				await _frames(1)
				_release_moves()
		elif mate.global_position.x < x * 16 + 8:
			Input.action_press(&"move_right")
			Input.action_release(&"move_left")
		else:
			Input.action_press(&"move_left")
			Input.action_release(&"move_right")
		if frames == hold:
			Input.action_release(&"jump")
		await _frames(1)
		frames += 1
		if frames > 6 and mate.is_on_floor():
			break
	_release_all()
	await _frames(4)
	if _tile(mate) != x and OS.get_cmdline_user_args().has("verbose"):
		print("  jump_to(%d) by %s landed on %d at y %d" % [x, mate.who, _tile(mate), mate.global_position.y])
	return _tile(mate) == x


func _release_moves() -> void:
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")


func jump(hold: int = 22) -> void:
	Input.action_press(&"jump")
	await _frames(hold)
	Input.action_release(&"jump")


func _release_all() -> void:
	for action in [&"move_left", &"move_right", &"jump"]:
		Input.action_release(action)


## Runs the laptop at `index` with `picks`, then waits `wait` frames.
func run_laptop(index: int, picks: Dictionary, wait: int = 0) -> Laptop:
	var laptop: Laptop = _stage._laptops[index]
	laptop.program.set_picks(picks)
	_stage._run_laptop(laptop)
	await _frames(wait)
	return laptop


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


# --- Solutions ----------------------------------------------------------------

func _solve_1() -> void:
	var door: Slab = _stage.js_lookup("door")
	var boards: Slab = _stage.js_lookup("boards")
	await walk_to(14)
	# Wrong first: walk(5) leaves Jazz short of the mat.
	await run_laptop(0, {"steps": 5}, 150)
	_check(door.on, "1: door opened with walk(5)")
	await run_laptop(0, {"steps": 7}, 150)
	_check(not door.on, "1: door shut with walk(7)")
	await walk_to(17)
	_check(await jump_to(19), "1: clive can't get on the counter")
	await jump_to(21)
	_check(_stage.clive.global_position.y > 190.0, "1: clive got up to the hatch")
	await walk_to(24)
	_check(_tile(_stage.clive) == 24, "1: clive not through the door")
	await _be("jazz")
	await walk_to(17)
	await jump_to(19)
	_check(_stage.jazz.global_position.y < 200.0, "1: jazz can't get on the counter")
	_check(await jump_to(21), "1: jazz can't reach the sill")
	await walk_to(28)
	_check(_tile(_stage.jazz) == 28, "1: jazz didn't get through the hatch")
	await _be("clive")
	await walk_to(32)
	await run_laptop(1, {"verb": "strum", "steps": 4}, 120)
	_check(not boards.on, "1: boards out after a strum")
	await run_laptop(1, {"verb": "jump", "steps": 1}, 200)
	print("  1: jazz landed on tile ", _tile(_stage.jazz))
	_check(boards.on, "1: boards not out after jump")
	await walk_to(58)
	await _be("jazz")
	await walk_to(58)


func _solve_2() -> void:
	var door: Slab = _stage.js_lookup("door")
	var lift: Lift = _stage.js_lookup("lift")
	await walk_to(12)
	await run_laptop(0, {"first": 0, "second": 0}, 30)
	_check(door.on, "2: door opened for \"desk\"\"ext\"")
	await run_laptop(0, {"first": 2, "second": 2}, 30)
	_check(not door.on, "2: door shut for ${desk}${ext}")
	await walk_to(20)
	await run_laptop(1, {"floor": "2"}, 120)
	_check(lift.level == 0, "2: lift moved for the string \"2\"")
	await _ride(lift, 2)
	_check(_stage.jazz.global_position.y < 140.0, "2: jazz not on Big Ron's floor")
	await _be("clive")
	await wait_until(func() -> bool: return lift.level == 0 and lift._body.position.y > -1.0, 600)
	await walk_to(20)
	await _ride(lift, 2)
	_check(_stage.clive.global_position.y < 140.0, "2: clive not on Big Ron's floor")
	await walk_to(55)
	await _be("jazz")
	await walk_to(55)


## Runs the lift laptop for `floor`, steps in before the doors close, rides
## up and steps off to the right.
func _ride(lift: Lift, floor_number: int) -> void:
	await run_laptop(1, {"floor": floor_number})
	await walk_to(22)
	await wait_until(func() -> bool: return lift.level == floor_number and is_equal_approx(lift._body.position.y, lift.target_y()), 400)
	await _frames(10)
	await walk_to(27)


func _solve_3() -> void:
	var stack: Lift = _stage._gadgets.filter(func(g: Gadget) -> bool: return g is Lift and (g as Lift).rises_on_strum)[0]
	await _be("clive")
	await walk_to(10)
	await run_laptop(0, {"op": "<="}, 240)
	_check(stack.level == 0, "3: stack didn't topple at five strums")
	await run_laptop(0, {"op": "<"})
	await jump_to(12)
	await jump_to(13)
	await wait_until(func() -> bool: return stack.level == 4 and is_equal_approx(stack._body.position.y, stack.target_y()) and not _stage.jazz.is_busy(), 400)
	await jump_to(16)
	_check(_stage.clive.global_position.y < 150.0, "3: clive not on the band's floor")
	await walk_to(30)
	await run_laptop(1, {"list": 0}, 30)
	_check(not (_stage.js_lookup("amp1") as Amp).lit, "3: amps[0] switched something on")
	await run_laptop(1, {"list": 1}, 60)
	_check(not (_stage.js_lookup("amp1") as Amp).lit and (_stage.js_lookup("amp3") as Amp).lit, "3: slice(1) wrong")
	await run_laptop(1, {"list": 2}, 120)
	await _climb_stair()
	_check(_stage.clive.global_position.y < 60.0, "3: clive didn't reach the stage")
	await _be("jazz")
	await walk_to(11)
	await jump_to(12)
	await jump_to(13)
	await jump_to(16)
	await walk_to(30)
	await _climb_stair()


func _climb_stair() -> void:
	await jump_to(32)
	await jump_to(34)
	await jump_to(36)
	await walk_to(46)


func _solve_4() -> void:
	var gate_1: Slab = _stage.js_lookup("gate1")
	var gate_2: Slab = _stage.js_lookup("gate2")
	await walk_to(7)
	await run_laptop(0, {"event": "click", "steps": 4}, 90)
	_check(not gate_1.on, "4: gate 1 shut with jazz on plate 1")
	await walk_to(24)
	_stage.use()
	await _frames(90)
	_check(gate_2.on, "4: gate 2 opened for a \"click\" listener")
	await walk_to(7)
	await run_laptop(0, {"event": "ring", "steps": 4}, 90)
	await walk_to(24)
	_stage.use()
	await wait_until(func() -> bool: return not gate_2.on, 200)
	_check(gate_1.on, "4: gate 1 still open after the bell")
	await walk_to(32)
	_check(_tile(_stage.clive) == 32, "4: clive not through gate 2")
	await _be("jazz")
	await walk_to(18)
	await jump_to(21)
	await walk_to(26)
	await jump_to(29)
	await _pond()
	await _be("clive")
	await _pond()


func _pond() -> void:
	await walk_to(40)
	await jump_to(44)
	await walk_to(53)


func _solve_5() -> void:
	var doors: Slab = _stage.js_lookup("doors")
	await walk_to(9)
	await run_laptop(0, {"ms": 500})
	await walk_to(30, [], 300)
	_check(_tile(_stage.clive) < 26, "5: clive got through with 500ms")
	await walk_to(9)
	await run_laptop(0, {"ms": 2500})
	await walk_to(30, [], 400)
	_check(_tile(_stage.clive) == 30, "5: clive didn't get through with 2500ms")
	await _be("jazz")
	await walk_to(25)
	await jump_to(27)
	await walk_to(41)
	await run_laptop(1, {"first": "gap!", "second": "the"}, 30)
	_check(doors.on, "5: doors opened for the wrong order")
	await run_laptop(1, {"first": "mind", "second": "the"}, 30)
	_check(not doors.on, "5: doors shut for mind, the, gap!")
	await walk_to(52)
	await _be("clive")
	await walk_to(52)


func _solve_6() -> void:
	var vestry: Slab = _stage.js_lookup("vestry")
	await walk_to(6)
	await run_laptop(0, {"wait": ""}, 60)
	await walk_to(24)
	await _frames(60)
	_check(vestry.on, "6: vestry opened without await")
	await walk_to(6)
	await run_laptop(0, {"wait": "await"}, 30)
	await walk_to(24)
	await wait_until(func() -> bool: return not vestry.on, 120)
	_check(not vestry.on, "6: vestry shut with await")
	await walk_to(36)
	await run_laptop(1, {"wait": ""}, 60)
	_check(not _stage._cleared, "6: car left with both without await")
	await run_laptop(1, {"wait": "await"})
	await walk_to(50)
