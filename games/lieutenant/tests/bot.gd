extends Node

## Plays every case to the end the way a player would: sits through the
## cold open, walks the Lieutenant with the real input actions, looks at the
## records, talks to the suspect, and writes each query in the notebook.
## At every question it first calls Records with something wrong (a blank
## page, then the solution with one chip changed) and checks the case
## doesn't move on. Then it writes the solution with real input, clicking
## the chips and the Call Records button on one question and using the
## arrow keys, Space and Enter on the next, and checks that it does.
## Prints one line per case and BOT result=ok (or the failures) at the end.
##
## godot --headless --path . res://tests/bot.tscn [-- case=N]

const FRAME_CAP := 60 * 120

var _fails: PackedStringArray = []
var scene: CaseScene
## How long lines stay up (frames, and extra frames per character). The
## trailer capture raises these so lines can be read.
var line_frames: int = 2
var per_char: float = 0.0
var pace: float = 0.05
var printout_frames: int = 2
## How long the bot looks at each page of the prologue before turning it.
var page_frames: int = 4
## Extra wrong pages to call in, by beat id, after the bot's own (the
## screenshot run uses these to catch particular errors on camera).
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
	CaseScene.test_pace = pace
	Notebook.test_auto_frames = printout_frames
	Notebook.test_pace = pace
	var only := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("case="):
			only = int(arg.get_slice("=", 1))
	if only == 0:
		await _prologue()
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


## Turns every page of the prologue and checks the query it types really
## ran, and that the last page leads into the first case.
func _prologue() -> void:
	Main.play_intro(get_tree(), 1)
	if not await wait_until(func() -> bool: return get_tree().current_scene is Intro, 300):
		_fail("the prologue didn't load")
		return
	var intro := get_tree().current_scene as Intro
	var pages := intro.beat_count()
	intro.driven = true
	_check(intro.demo.get("ok", false) and (intro.demo.rows as Array).size() == 3, "the prologue's query should return 3 rows, got %s" % [intro.demo])
	for index in pages:
		_check(intro.page() == index, "the prologue is on page %d, not %d" % [intro.page(), index])
		await _frames(page_frames)
		await moment("prologue %d" % (index + 1))
		intro.turn()
		await _frames(2)
		intro.turn()
		await _frames(2)
	if not await wait_until(func() -> bool: return get_tree().current_scene is CaseScene, 300):
		_fail("the prologue didn't lead into the first case")
		return
	print("prologue: %d pages, then case 1" % pages)
	get_tree().current_scene.queue_free()
	await _frames(2)


func _play(id: int) -> void:
	Main.play_case(get_tree(), id)
	await wait_until(func() -> bool: return get_tree().current_scene is CaseScene and (get_tree().current_scene as CaseScene).case_id == id, 300)
	scene = get_tree().current_scene as CaseScene
	if scene == null or scene.case_id != id:
		_fail("case %d didn't load" % id)
		return
	await moment("open %d" % id)
	if not await wait_until(func() -> bool: return scene.state == "free", FRAME_CAP):
		_fail("%d: never got past the opening (state %s)" % [id, scene.state])
		return
	_check(scene.hud.caption_count == (scene.data.cold_open as Array).size(), "%d: the cold open showed %d captions" % [id, scene.hud.caption_count])
	for index in scene.beats.size():
		if not await _solve(id, index):
			return
	if not await wait_until(func() -> bool: return Progress.is_cleared(id) and not (get_tree().current_scene is CaseScene), FRAME_CAP):
		_fail("%d: never closed (state %s)" % [id, scene.state if is_instance_valid(scene) else "gone"])
		return
	print("case %d \"%s\" closed in %d calls" % [id, Story.case(id).title, Progress.best_tries(id)])


func _solve(id: int, index: int) -> bool:
	var beat: Dictionary = scene.beats[index]
	var name := str(beat.id)
	var final: bool = beat.get("final", false)
	if final:
		# He walks to the door, or to the last record, by himself.
		if not await wait_until(func() -> bool: return scene.notebook.is_open() and scene.notebook.mode == "edit", FRAME_CAP):
			_fail("%s: the false exit never opened the notebook (state %s)" % [name, scene.state])
			return false
	else:
		if not await wait_until(func() -> bool: return scene.state == "free" and scene.beat_index == index, FRAME_CAP):
			_fail("%s: never came up (state %s, beat %d)" % [name, scene.state, scene.beat_index])
			return false
		for id_needed: String in beat.get("needs", []):
			if scene.found.has(id_needed):
				continue
			_check(not scene.beat_ready(), "%s: ready before %s was found" % [name, id_needed])
			var p := scene.prop(id_needed)
			await walk_to(float(p.x))
			await wait_until(func() -> bool: return not scene.notebook.just_closed(), 60)
			await press(&"edit")
			if not await wait_until(func() -> bool: return scene.found.has(id_needed) and scene.state == "free", FRAME_CAP):
				_fail("%s: couldn't look at %s (state %s)" % [name, id_needed, scene.state])
				return false
			await moment("found %s" % id_needed)
		_check(scene.beat_ready(), "%s: not ready with everything found" % name)
		await walk_to(scene.suspect.position.x - 22.0)
		# The scene ignores a press that lands as the notebook shuts.
		await wait_until(func() -> bool: return not scene.notebook.just_closed(), 60)
		await press(&"edit")
		if not await wait_until(func() -> bool: return scene.notebook.is_open() and scene.notebook.mode == "edit", FRAME_CAP):
			_fail("%s: the notebook never opened (state %s)" % [name, scene.state])
			return false
	for table: String in beat.tray.get("from", []):
		_check(scene.tables.has(table) or not (beat.solution.get("from", "") == table), "%s: the solution's table %s isn't in the notebook" % [name, table])
	await moment("notebook %s" % name)
	# Wrong first: a blank page, then the solution with one chip changed.
	for wrong: Dictionary in wrong_tries(beat) + (extra_tries.get(name, []) as Array):
		scene.notebook.set_picks(wrong)
		if not await _call(name):
			return false
		_check(scene.beat_index == index, "%s: the case moved on after %s" % [name, Query.compose(Query.from_data(wrong)).replace("\n", " ")])
		_check(scene.notebook.is_open(), "%s: the notebook shut after a wrong call" % name)
	# Then right, written the way a player writes it: by mouse on one
	# question, by keys on the next.
	var by_mouse := index % 2 == 0
	if not await write_page(name, beat.solution, by_mouse):
		return false
	await moment("solution %s" % name)
	if not await _call(name, "mouse" if by_mouse else "keys"):
		return false
	if not await wait_until(func() -> bool: return scene.beat_index > index, FRAME_CAP):
		_fail("%s: the solution wasn't accepted: %s" % [name, scene.notebook.verdict.get("says", "?")])
		return false
	return true


## The wrong pages the bot tries first: nothing at all, then the solution
## with the first chip a note is kept for.
func wrong_tries(beat: Dictionary) -> Array:
	var out: Array = [{}]
	for key: String in beat.get("notes", {}):
		var line := key.get_slice(":", 0)
		var chip := key.substr(line.length() + 1)
		var wrong: Dictionary = (beat.solution as Dictionary).duplicate(true)
		if line == "logic":
			wrong["logic"] = chip
		elif line == "select":
			wrong["select"] = (wrong.get("select", []) as Array) + [chip]
		elif Query.MULTI.has(line):
			wrong[line] = [chip]
		else:
			wrong[line] = chip
		out.append(wrong)
		break
	return out


## Clears the page and picks every chip of `picks` with real input: a click
## on each chip, or the arrow keys and Space. Checks the page then spells
## the same SQL.
func write_page(name: String, picks: Dictionary, by_mouse: bool) -> bool:
	var notebook := scene.notebook
	notebook.set_picks({})
	await _frames(3)
	var want := Query.from_data(picks)
	var chips: Array = []
	for line: String in Query.LINES:
		if Query.MULTI.has(line):
			for chip: String in want[line]:
				chips.append([line, chip])
		elif str(want[line]) != "":
			chips.append([line, str(want[line])])
	if (want.where as Array).size() > 1 and str(want.logic) != "AND":
		chips.append(["logic", str(want.logic)])
	for target: Array in chips:
		var box := {}
		for candidate: Dictionary in notebook._boxes:
			if str(candidate.line) == str(target[0]) and str(candidate.chip) == str(target[1]):
				box = candidate
		if box.is_empty():
			_fail("%s: no chip \"%s\" on the page to pick" % [name, target[1]])
			return false
		if by_mouse:
			await click((box.rect as Rect2).get_center())
		else:
			var guard := 0
			while notebook._cursor.x != int(box.row) and guard < 40:
				await press(&"move_down")
				guard += 1
			while notebook._cursor.y != int(box.index) and guard < 80:
				await press(&"move_right")
				guard += 1
			await press(&"pick")
		await _frames(2)
	if Query.compose(notebook.picks) != Query.compose(want):
		_fail("%s: picked by %s, the page says [%s], not [%s]" % [name, "mouse" if by_mouse else "keys", notebook.sql().replace("\n", " "), Query.compose(want).replace("\n", " ")])
		return false
	return true


## Calls Records with what's on the page (by the method itself, the Call
## Records button or the Enter key) and waits for the printout to be put
## down again.
func _call(name: String, how: String = "") -> bool:
	var before := scene.calls
	if how == "mouse":
		await click(scene.notebook._call_button.get_global_rect().get_center())
	elif how == "keys":
		var enter := InputEventKey.new()
		enter.keycode = KEY_ENTER
		enter.physical_keycode = KEY_ENTER
		enter.pressed = true
		Input.parse_input_event(enter)
		await _frames(2)
		enter = enter.duplicate()
		enter.pressed = false
		Input.parse_input_event(enter)
	else:
		scene.notebook.call_records()
	await moment("called %s" % name)
	if not await wait_until(func() -> bool: return scene.calls > before, FRAME_CAP):
		_fail("%s: the call never came back (mode %s)" % [name, scene.notebook.mode])
		return false
	await _frames(2)
	return true


# --- Moves -------------------------------------------------------------------

func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


func walk_to(x: float, limit: int = 900) -> void:
	var frames := 0
	while absf(scene.lt.position.x - x) > 3.0 and frames < limit:
		var right := scene.lt.position.x < x
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


## A left click at `at`, in the game's 480x270 coordinates.
func click(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		get_viewport().push_input(event, true)
		await _frames(2)


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
