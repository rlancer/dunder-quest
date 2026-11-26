extends Node

## Plays the whole game the way a player does, without a window: the title,
## every page of the prologue (checking that each line it types runs and
## prints something), then every shift from the rota. On each ticket it
## first fires a line that runs but sends the wrong thing, and checks that
## Shell has something to say about it; then tries one the shell refuses,
## which must cost nothing; then writes the solution and fires. At the end
## every shift must be done, with a star for every ticket, and no text
## anywhere may have left its panel (Fit).
##
## godot --headless --path . res://tests/bot.tscn

## Frames a talking page and a won banner stay up; tests/shots.gd slows these.
var linger: int = 0

var _problems: PackedStringArray = []
var _tickets: int = 0
var _frames: int = 0


func _ready() -> void:
	Progress.persist = false
	Progress.reset()
	Voice.muted = true
	StageAudio.web_audio_unlocked = true
	ShiftScene.bot = true
	Fit.audit = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	reparent(tree.root)
	tree.current_scene = null
	tree.change_scene_to_file("res://ui/boot.tscn")
	await _frames_pass(6 + linger * 6)
	await moment("title")
	var title := tree.current_scene
	_expect(title != null and title.has_method("_on_start"), "the title didn't open")
	title._on_start()
	await _until(func() -> bool: return tree.current_scene is Intro, "the prologue didn't open")
	await _prologue(tree.current_scene as Intro)
	for id in range(1, Story.count() + 1):
		await _until(func() -> bool: return tree.current_scene is ShiftScene and (tree.current_scene as ShiftScene).shift_id == id, "shift %d didn't open" % id)
		await _shift(tree.current_scene as ShiftScene)
		await _until(func() -> bool: return tree.current_scene != null and tree.current_scene.has_method("_take"), "the shift board didn't come back after shift %d" % id)
		await _frames_pass(4)
		await moment("board_%d" % id)
		_expect(Progress.is_cleared(id), "shift %d isn't marked done" % id)
		var tickets := (Story.shift(id).tickets as Array).size()
		_expect(Progress.stars(id) == tickets, "shift %d: %d stars for %d tickets written at par" % [id, Progress.stars(id), tickets])
		_expect(Progress.best_tries(id) == tickets * 2, "shift %d: %d fires counted, not %d" % [id, Progress.best_tries(id), tickets * 2])
		if id < Story.count():
			_expect(Progress.is_open(id + 1), "shift %d didn't open after shift %d" % [id + 1, id])
			tree.current_scene._take(id + 1)
	_expect(Progress.cleared_count() == Story.count(), "%d of %d shifts done" % [Progress.cleared_count(), Story.count()])
	for key: String in Fit.breaks:
		_problems.append("%s (%s)" % [key, Fit.breaks[key]])
	for line in _problems:
		print("PROBLEM ", line)
	print("BOT result=%s shifts=%d tickets=%d" % ["ok" if _problems.is_empty() else "FAIL %d" % _problems.size(), Progress.cleared_count(), _tickets])
	tree.quit(0 if _problems.is_empty() else 1)


func _prologue(intro: Intro) -> void:
	intro.driven = true
	for index in intro.beat_count():
		intro._go(index)
		intro._t = 60.0
		await _frames_pass(2 + linger)
		await moment("prologue_%d" % index)
		var demo: Dictionary = intro.beat().get("demo", {})
		if not demo.is_empty():
			_expect(intro.demo_tokens() == demo.line, "prologue page %d: its line didn't finish typing" % index)
			var ran := Shell.run(" ".join(PackedStringArray(demo.line)), Story.files(demo.files))
			_expect(not ran.has("error") and str(ran.get("out", "")) != "", "prologue page %d: its line prints nothing" % index)
	intro._go(intro.beat_count())


func _shift(scene: ShiftScene) -> void:
	var seen := ""
	var tried_wrong := false
	var guard := 0
	while is_instance_valid(scene) and scene.state != "leaving":
		guard += 1
		if guard > 20000:
			_expect(false, "shift %d never finished (stuck in \"%s\")" % [scene.shift_id, scene.state])
			return
		if scene.state != seen:
			seen = scene.state
			if seen == "build":
				tried_wrong = false
		match scene.state:
			"build":
				var b := scene.builder
				if not b.busy:
					if not tried_wrong:
						tried_wrong = true
						await _wrong_try(scene)
					else:
						_tickets += 1
						b.clear()
						for chip: String in b.ticket.solution:
							_expect(b.place(chip), "%s: no room on the line for its own solution" % b.ticket.id)
						await _frames_pass(1 + linger)
						await moment("%s_written" % b.ticket.id)
						b.fire_now()
						await _until(func() -> bool: return scene.state != "build", "%s: the solution didn't win" % b.ticket.id)
						await _frames_pass(linger)
						await moment("%s_sent" % b.ticket.id)
			"talk":
				if linger > 0 and scene.dialogue._frames >= linger:
					await moment("%d_say_%s" % [scene.shift_id, Voice.key_of(scene.dialogue.line)])
			"card":
				if linger > 0:
					scene.card.settle()
					await _frames_pass(2)
					await moment("card_%s" % scene.card.card.get("id", ""))
			"title":
				await moment("%d_title" % scene.shift_id)
			"end":
				await moment("%d_end" % scene.shift_id)
		await get_tree().process_frame


## A line that runs and sends the wrong thing: the first row of up to
## three chips that does. Shell must say what was wrong with it.
func _wrong_try(scene: ShiftScene) -> void:
	var b := scene.builder
	var id := str(b.ticket.id)
	await moment("%s_brief" % id)
	var rows: Array = []
	for chip: String in b.ticket.chips:
		rows.append([chip])
	for first: String in b.ticket.chips:
		for second: String in b.ticket.chips:
			rows.append([first, second])
	for first: String in b.ticket.chips:
		for second: String in b.ticket.chips:
			for third: String in b.ticket.chips:
				rows.append([first, second, third])
	for row: Array in rows:
		var result := Judge.judge(b.ticket, row)
		if result.has("error") or bool(result.won):
			continue
		for chip: String in row:
			_expect(b.place(chip), "%s: couldn't put down %s" % [id, chip])
		var before := b.fires
		b.fire_now()
		await _until(func() -> bool: return not b.busy, "%s: firing %s never finished" % [id, result.line])
		_expect(b.fires == before + 1, "%s: a missed fire wasn't counted" % id)
		_expect(b.fails == 1 and b.said != "", "%s: Shell said nothing about firing %s" % [id, result.line])
		_expect(not b.said.contains("{"), "%s: an unfilled blank in \"%s\"" % [id, b.said])
		await _frames_pass(1 + linger)
		await moment("%s_missed" % id)
		# Twice wrong brings the hint; look at that too.
		b.fails = 2
		b.note = "Hint: %s" % b.ticket.hint
		await _frames_pass(2)
		b.fails = 1
		b.note = ""
		# And a line the shell won't run, which costs no fire.
		b.clear()
		b.tokens = [str(b.ticket.files[0])]
		b.caret = 1
		b._judge()
		_expect(b.result.has("error") and str(b.result.error.error).contains("command not found"), "%s: a file's name alone isn't refused as a command" % id)
		b.fire_now()
		_expect(b.fires == before + 1 and not b.busy and b.said != "", "%s: a line the shell won't run cost a fire" % id)
		await _frames_pass(2)
		await moment("%s_refused" % id)
		return
	_expect(false, "%s: no row of up to three chips runs and misses" % id)


## A named moment, for tests/shots.gd to photograph.
func moment(_name: String) -> void:
	pass


func _expect(ok: bool, what: String) -> void:
	if not ok and not _problems.has(what):
		_problems.append(what)


func _frames_pass(count: int) -> void:
	for _i in maxi(count, 1):
		await get_tree().process_frame


func _until(test: Callable, what: String) -> void:
	for _i in 3000:
		if test.call():
			return
		await get_tree().process_frame
	_expect(false, what)
