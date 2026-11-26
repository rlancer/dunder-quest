extends "res://tests/bot.gd"

## The bot's run, for the trailer's camera. Recording at 1920x1080 is slow
## (a few frames a second), so it only takes its time over what the trailer
## cuts to (`PAGES` and `WANT`) and hurries through everything else: a
## wanted line of talk is held for as long as its voice takes to read it, a
## wanted poster is written a chip at a time with the line-up lighting up
## and drawn on at the game's own speed, and its CAUGHT banner is left up
## long enough to read. The scene music is muted (the trailer has its own
## cue); the voices and the effects are recorded. A poster can be written
## wrong first, on purpose (`miss`), to get the verdicts on camera. Logs a
## MARK line, keyed by movie frame, for every moment worth cutting to:
##
##   MARK <frame> title                      the title screen
##   MARK <frame> page <n> <seconds>         a page of the prologue, and its voice's length
##   MARK <frame> say <job> <who> <seconds>| <text>   a line of talk
##   MARK <frame> card <id>                  a lesson card
##   MARK <frame> brief <poster> <seconds>   the desk, with a blank poster
##   MARK <frame> write <poster> <try>       the first chip is about to go down
##   MARK <frame> chip <poster> <try> <n> <pattern so far>
##   MARK <frame> draw <poster> <try>        the Sheriff draws
##   MARK <frame> missed <poster> <try>      every verdict is in, and it missed
##   MARK <frame> caught <poster>            the CAUGHT banner
##   MARK <frame> end-of-run
##
## Only wanted lines, cards and posters are marked.
##
## bash trailer/capture.sh   (records at 1920x1080, so the text is sharp)
## Run with `-- prologue` for the title and the prologue's pages, or
## `-- job=3` for one job.

## Frames between one chip going down and the next.
const CHIP_FRAMES := 26
## Frames a finished poster sits before the draw.
const WRITTEN_FRAMES := 45
## Frames a missed poster, and what the Kid says about it, stay up.
const MISSED_FRAMES := 150
## Frames a CAUGHT banner stays up.
const CAUGHT_FRAMES := 80
## Frames Big Backtrack's count runs for: 24 a's at three a second, and a look.
const COUNT_FRAMES := 600
## Frames the title screen is held.
const TITLE_FRAMES := 240
## The pages of the prologue the trailer uses: the band, and Dot Starr.
const PAGES := [0, 3, 4]
## What the trailer uses of each job. `say`: lines of talk, by how they
## start. `posters`: by id; `brief` waits for the brief to be read out, and
## `miss` is wrong posters to write and draw on first. `cards`: lesson cards.
const WANT := {
	1: {
		"say": ["Everybody in this town", "It keeps the stationery"],
		"posters": {"1b": {}, "1c": {}},
	},
	2: {"posters": {"2a": {}, "2d": {}}},
	3: {"posters": {"3a": {}, "3d": {}}},
	4: {
		"say": ["I don't take a little"],
		"posters": {"4a": {}, "4b": {}, "4d": {}},
	},
	5: {
		"say": ["Backtrack try every way", "You can't hold me"],
		"posters": {"5c": {}},
		"cards": ["catastrophic"],
	},
}

var _start_frame := 0
var _line: Dictionary = {}
var _card: Dictionary = {}
var _want: Dictionary = {}
var _scene: JobScene


func _init() -> void:
	linger = 1


func _ready() -> void:
	super()
	# The bot's audit draws every animation finished; the camera wants them playing.
	Fit.audit = false
	seed(7)
	JobScene.bot_frames = 3
	_start_frame = Engine.get_process_frames()
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Music"), true)


func _run() -> void:
	var tree := get_tree()
	reparent(tree.root)
	tree.current_scene = null
	var job := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("job="):
			job = int(arg.get_slice("=", 1))
	if job > 0:
		_want = WANT.get(job, {})
		Main.play_job(tree, job)
		await _until(func() -> bool: return tree.current_scene is JobScene, "job %d didn't open" % job)
		await _film(tree.current_scene as JobScene)
	else:
		tree.change_scene_to_file("res://ui/boot.tscn")
		await _frames_pass(20)
		_mark("title")
		await _frames_pass(TITLE_FRAMES)
		Main.play_intro(tree, 0)
		await _until(func() -> bool: return tree.current_scene is Intro, "the prologue didn't open")
		var intro := tree.current_scene as Intro
		intro.driven = true
		# Nobody's going to press it.
		intro._skip.visible = false
		for page: int in PAGES:
			intro._go(page)
			_mark("page %d %.3f" % [page, intro._voice])
			await _frames_pass(int((intro._done_at() + 0.8) * 60.0))
	_mark("end-of-run")
	for line in _problems:
		print("PROBLEM ", line)
	tree.quit(0 if _problems.is_empty() else 1)


func _film(scene: JobScene) -> void:
	_scene = scene
	while is_instance_valid(scene) and scene.state not in ["end", "leaving"]:
		if scene.state == "build" and not scene.builder.busy:
			await _write(scene)
		await get_tree().process_frame
	_scene = null


## Every frame, ahead of the scene's own nodes: how long the line of talk or
## the lesson card that has just come up stays. Between two of them the
## hold is left long, so the next can't turn its own page before it's seen.
func _process(_delta: float) -> void:
	var scene := _scene
	if scene == null or not is_instance_valid(scene) or scene.dialogue == null:
		return
	var talk := scene.dialogue
	if not talk.active:
		talk.auto_frames = 1 << 30
	elif not is_same(talk.line, _line):
		_line = talk.line
		var words := str(_line.get("text", ""))
		var frames := 1
		if _wanted_line(words):
			var secs := _voice_length(_line)
			frames = int(maxf(secs, words.length() / Dialogue.TYPE) * 60.0) + 30
			_mark("say %d %s %.3f| %s" % [scene.job_id, _line.get("who", "narrator"), secs, words])
		talk.auto_frames = talk._frames + frames
	var card := scene.card
	if not card.active:
		card.auto_frames = 1 << 30
	elif not is_same(card.card, _card):
		_card = card.card
		var frames := 1
		var id := str(_card.get("id", ""))
		if (_want.get("cards", []) as Array).has(id):
			frames = COUNT_FRAMES
			_mark("card %s" % id)
		card.auto_frames = card._frames + frames


func _wanted_line(words: String) -> bool:
	for start: String in _want.get("say", []):
		if words.begins_with(start):
			return true
	return false


## The desk: the brief, any wrong posters, then the solution.
func _write(scene: JobScene) -> void:
	var b := scene.builder
	var id := str(b.poster.id)
	var posters: Dictionary = _want.get("posters", {})
	if not posters.has(id):
		# Not for the camera: straight to the answer.
		Voice.hush()
		b.instant = true
		JobScene.bot_frames = 3
		b.clear()
		for chip: String in b.poster.solution:
			b.place(chip)
		b.draw_now()
		await _until(func() -> bool: return scene.state != "build", "%s: the solution didn't win" % id)
		return
	var how: Dictionary = posters[id]
	b.instant = false
	var secs := _voice_length(b.poster.brief)
	_mark("brief %s %.3f" % [id, secs])
	if bool(how.get("brief", false)):
		await _frames_pass(int(secs * 60.0) + 20)
	else:
		await _frames_pass(24)
		Voice.hush()
	var tries: Array = (how.get("miss", []) as Array).duplicate()
	tries.append(b.poster.solution)
	for t in tries.size():
		var chips: Array = tries[t]
		var last := t == tries.size() - 1
		b.clear()
		await _frames_pass(20)
		_mark("write %s %d" % [id, t])
		for n in chips.size():
			await _frames_pass(CHIP_FRAMES)
			var chip := str(chips[n])
			b.focus = (b.poster.chips as Array).find(chip)
			_expect(b.place(chip), "%s: no room on the poster for %s" % [id, chip])
			_mark("chip %s %d %d %s" % [id, t, n, Rx.text(b.tokens)])
		await _frames_pass(WRITTEN_FRAMES)
		b.focus = (b.poster.chips as Array).size() + 2
		await _frames_pass(12)
		_mark("draw %s %d" % [id, t])
		JobScene.bot_frames = CAUGHT_FRAMES
		b.draw_now()
		if last:
			await _until(func() -> bool: return scene.state != "build", "%s: the solution didn't win" % id)
			_mark("caught %s" % id)
			await _until(func() -> bool: return scene.state != "won", "%s: the banner never came down" % id)
			JobScene.bot_frames = 3
		else:
			await _until(func() -> bool: return not b.busy, "%s: the draw never finished" % id)
			_mark("missed %s %d" % [id, t])
			await _frames_pass(MISSED_FRAMES)


func _voice_length(line: Dictionary) -> float:
	var clip := Voice.stream(line)
	return clip.get_length() if clip != null else 0.0


func _mark(text: String) -> void:
	print("MARK %d %s" % [Engine.get_process_frames() - _start_frame, text])
