extends Node

## Plays the whole game the way a player does, without a window: the title,
## every page of the prologue (checking that each poster it writes lights up
## the lines the engine says it should), then every job from the board. On
## each poster it first draws on a pattern that misses and checks that the
## Kid has something to say about it, then writes the solution and draws.
## At the end every job must be done, with a star for every poster, and no
## text anywhere may have left its panel (Fit).
##
## godot --headless --path . res://tests/bot.tscn

## Frames a talking page and a won banner stay up; tests/shots.gd slows these.
var linger: int = 0

var _problems: PackedStringArray = []
var _posters: int = 0
var _frames: int = 0


func _ready() -> void:
	Progress.persist = false
	Progress.reset()
	Voice.muted = linger == 0
	StageAudio.web_audio_unlocked = true
	JobScene.bot = true
	Fit.audit = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	reparent(tree.root)
	tree.current_scene = null
	tree.change_scene_to_file("res://ui/boot.tscn")
	await _frames_pass(6)
	await moment("title")
	var title := tree.current_scene
	_expect(title != null and title.has_method("_on_start"), "the title didn't open")
	title._on_start()
	await _until(func() -> bool: return tree.current_scene is Intro, "the prologue didn't open")
	await _prologue(tree.current_scene as Intro)
	for id in range(1, Story.count() + 1):
		await _until(func() -> bool: return tree.current_scene is JobScene and (tree.current_scene as JobScene).job_id == id, "job %d didn't open" % id)
		await _job(tree.current_scene as JobScene)
		await _until(func() -> bool: return tree.current_scene != null and tree.current_scene.has_method("_take"), "the job board didn't come back after job %d" % id)
		await _frames_pass(4)
		await moment("board_%d" % id)
		_expect(Progress.is_cleared(id), "job %d isn't marked done" % id)
		var posters := (Story.job(id).posters as Array).size()
		_expect(Progress.stars(id) == posters, "job %d: %d stars for %d posters written at par" % [id, Progress.stars(id), posters])
		_expect(Progress.best_tries(id) == posters * 2, "job %d: %d draws counted, not %d" % [id, Progress.best_tries(id), posters * 2])
		if id < Story.count():
			_expect(Progress.is_open(id + 1), "job %d didn't open after job %d" % [id + 1, id])
			tree.current_scene._take(id + 1)
	_expect(Progress.cleared_count() == Story.count(), "%d of %d jobs done" % [Progress.cleared_count(), Story.count()])
	for key: String in Fit.breaks:
		_problems.append("%s (%s)" % [key, Fit.breaks[key]])
	for line in _problems:
		print("PROBLEM ", line)
	print("BOT result=%s jobs=%d posters=%d" % ["ok" if _problems.is_empty() else "FAIL %d" % _problems.size(), Progress.cleared_count(), _posters])
	tree.quit(0 if _problems.is_empty() else 1)


func _prologue(intro: Intro) -> void:
	intro.driven = true
	for index in intro.beat_count():
		intro._go(index)
		intro._t = 60.0
		await _frames_pass(2 + linger)
		await moment("prologue_%d" % index)
		var demo: Dictionary = intro.beat().get("demo", {})
		var pattern: Array = demo.get("pattern", [])
		if not pattern.is_empty():
			_expect(intro.demo_tokens() == pattern, "prologue page %d: its poster didn't finish writing" % index)
			_expect(Rx.check(pattern).is_empty(), "prologue page %d: its poster isn't a pattern" % index)
			var lit := 0
			for line: String in demo.lines:
				lit += 1 if bool(Rx.search(Rx.text(pattern), line).found) else 0
			_expect(lit > 0 and lit < (demo.lines as Array).size(), "prologue page %d: its poster lights %d of %d lines" % [index, lit, (demo.lines as Array).size()])
	intro._go(intro.beat_count())


func _job(scene: JobScene) -> void:
	var seen := ""
	var tried_wrong := false
	var guard := 0
	while is_instance_valid(scene) and scene.state != "leaving":
		guard += 1
		if guard > 20000:
			_expect(false, "job %d never finished (stuck in \"%s\")" % [scene.job_id, scene.state])
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
						_posters += 1
						b.clear()
						for chip: String in b.poster.solution:
							_expect(b.place(chip), "%s: no room on the poster for its own solution" % b.poster.id)
						await _frames_pass(1 + linger)
						await moment("%s_written" % b.poster.id)
						b.draw_now()
						await _until(func() -> bool: return scene.state != "build", "%s: the solution didn't win" % b.poster.id)
						await _frames_pass(linger)
						await moment("%s_caught" % b.poster.id)
			"talk":
				if linger > 0 and scene.dialogue._frames >= linger:
					await moment("%d_say_%s" % [scene.job_id, Voice.key_of(scene.dialogue.line)])
			"card":
				if linger > 0:
					scene.card.settle()
					await _frames_pass(2)
					await moment("card_%s" % scene.card.card.get("id", ""))
			"title":
				await moment("%d_title" % scene.job_id)
			"end":
				await moment("%d_end" % scene.job_id)
		await get_tree().process_frame


## A poster that misses: the first single chip that neither wins nor is
## refused. The Kid must say which line it got wrong.
func _wrong_try(scene: JobScene) -> void:
	var b := scene.builder
	var id := str(b.poster.id)
	await moment("%s_brief" % id)
	for chip: String in b.poster.chips:
		var result := Judge.judge(b.poster, [chip])
		if result.has("error") or bool(result.won):
			continue
		_expect(b.place(chip), "%s: couldn't put down %s" % [id, chip])
		var before := b.draws
		b.draw_now()
		await _until(func() -> bool: return not b.busy, "%s: the draw on %s never finished" % [id, chip])
		_expect(b.draws == before + 1, "%s: a missed draw wasn't counted" % id)
		_expect(b.fails == 1 and b.said != "", "%s: the Kid said nothing about a miss with %s" % [id, chip])
		_expect(not b.said.contains("{"), "%s: an unfilled blank in \"%s\"" % [id, b.said])
		await _frames_pass(1 + linger)
		await moment("%s_missed" % id)
		# Twice wrong brings the hint; look at that too.
		b.fails = 2
		b.note = "Hint: %s" % b.poster.hint
		await _frames_pass(2)
		b.fails = 1
		b.note = ""
		# And a poster the engine would refuse, which costs no draw.
		b.clear()
		b.tokens = ["*"]
		b.caret = 1
		b._judge()
		b.draw_now()
		_expect(b.draws == before + 1 and not b.busy, "%s: a poster that isn't a pattern cost a draw" % id)
		await _frames_pass(2)
		return
	_expect(false, "%s: every single chip wins or is refused" % id)


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
