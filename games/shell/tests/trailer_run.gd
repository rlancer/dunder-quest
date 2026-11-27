extends "res://tests/bot.gd"

## The bot's run, for the trailer's camera. Recording at 1920x1080 is slow
## (a few frames a second), so it only takes its time over what the trailer
## cuts to (`PAGES` and `WANT`) and hurries through everything else: a
## wanted line of talk is held for as long as its voice takes to read it, a
## wanted ticket's line is written a chip at a time with the pass printing
## as it goes and fired at the game's own speed, and its ORDER UP banner is
## left up long enough to read. The scene music is muted (the trailer has
## its own cue); the voices and the effects are recorded. A line can be
## written wrong first, on purpose (`miss`), to get the shell's own error or
## Shell's verdict on camera: one the shell refuses is held, then fired
## (which costs nothing), one that runs is fired and its misses read.
## Logs a MARK line, keyed by movie frame, for every moment worth cutting to:
##
##   MARK <frame> title                      the title screen
##   MARK <frame> page <n> <seconds>         a page of the prologue, and its voice's length
##   MARK <frame> say <shift> <who> <seconds>| <text>   a line of talk
##   MARK <frame> card <id>                  a lesson card
##   MARK <frame> brief <ticket> <seconds>   the pass, with an empty line
##   MARK <frame> write <ticket> <try>       the first chip is about to go down
##   MARK <frame> chip <ticket> <try> <n> <line so far>
##   MARK <frame> refused <ticket> <try>     a line the shell won't run, fired
##   MARK <frame> fire <ticket> <try>        the Chef fires
##   MARK <frame> missed <ticket> <try>      every verdict is in, and it missed
##   MARK <frame> sent <ticket>              the ORDER UP banner
##   MARK <frame> end-of-run
##
## Only wanted lines, cards and tickets are marked.
##
## bash trailer/capture.sh   (records at 1920x1080, so the text is sharp)
## Run with `-- prologue` for the title and the prologue's pages, or
## `-- shift=3` for one shift.

## Frames between one chip going down and the next.
const CHIP_FRAMES := 26
## Frames a finished line sits before it's fired.
const WRITTEN_FRAMES := 45
## Frames a refused line stays up before it's fired, and after.
const REFUSED_FRAMES := 120
## Frames a missed line, and what Shell says about it, stay up.
const MISSED_FRAMES := 150
## Frames an ORDER UP banner stays up.
const SENT_FRAMES := 100
## Frames the title screen is held.
const TITLE_FRAMES := 240
## The pages of the prologue the trailer uses: Uncle Awk's kitchen, the
## Chef coming home with his system, and the pipe.
const PAGES := [1, 2, 3, 4, 7]
## What the trailer uses of each shift. `say`: lines of talk, by how they
## start. `tickets`: by id; `brief` waits for the brief to be read out, and
## `miss` is wrong lines to write and fire first. `cards`: lesson cards.
const WANT := {
	1: {
		"say": ["Yes, Shell."],
		"tickets": {"1c": {}},
	},
	2: {
		"say": ["The word first"],
		"tickets": {
			"2a": {"miss": [["grep", "orders.txt", "beef"], ["cat", "orders.txt"]]},
			"2d": {},
		},
	},
	3: {"tickets": {"3a": {}, "3b": {}}},
	4: {"tickets": {"4a": {}, "4d": {}}},
	5: {
		"say": ["The machine!", "Twelve tickets", "One question, Chef", "Fries."],
		"tickets": {"5b": {}, "5d": {}},
	},
}

var _start_frame := 0
var _line: Dictionary = {}
var _card: Dictionary = {}
var _want: Dictionary = {}
var _scene: ShiftScene


func _init() -> void:
	linger = 1


func _ready() -> void:
	super()
	# The bot's audit draws every animation finished; the camera wants them playing.
	Fit.audit = false
	Voice.muted = false
	seed(7)
	ShiftScene.bot_frames = 3
	_start_frame = Engine.get_process_frames()
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Music"), true)


func _run() -> void:
	var tree := get_tree()
	reparent(tree.root)
	tree.current_scene = null
	var shift := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("shift="):
			shift = int(arg.get_slice("=", 1))
	if shift > 0:
		_want = WANT.get(shift, {})
		Main.play_shift(tree, shift)
		await _until(func() -> bool: return tree.current_scene is ShiftScene, "shift %d didn't open" % shift)
		await _film(tree.current_scene as ShiftScene)
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


func _film(scene: ShiftScene) -> void:
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
			_mark("say %d %s %.3f| %s" % [scene.shift_id, _line.get("who", "narrator"), secs, words])
		talk.auto_frames = talk._frames + frames
	var card := scene.card
	if not card.active:
		card.auto_frames = 1 << 30
	elif not is_same(card.card, _card):
		_card = card.card
		var frames := 1
		var id := str(_card.get("id", ""))
		if (_want.get("cards", []) as Array).has(id):
			frames = int((_voice_length(LessonCard.spoken(_card)) + 1.0) * 60.0)
			_mark("card %s" % id)
		card.auto_frames = card._frames + frames


func _wanted_line(words: String) -> bool:
	for start: String in _want.get("say", []):
		if words.begins_with(start):
			return true
	return false


## The pass: the brief, any wrong lines, then the solution.
func _write(scene: ShiftScene) -> void:
	var b := scene.builder
	var id := str(b.ticket.id)
	var tickets: Dictionary = _want.get("tickets", {})
	if not tickets.has(id):
		# Not for the camera: straight to the answer.
		Voice.hush()
		b.instant = true
		ShiftScene.bot_frames = 3
		b.clear()
		for chip: String in b.ticket.solution:
			b.place(chip)
		b.fire_now()
		await _until(func() -> bool: return scene.state != "build", "%s: the solution didn't win" % id)
		return
	var how: Dictionary = tickets[id]
	b.instant = false
	var secs := _voice_length(b.ticket.brief)
	_mark("brief %s %.3f" % [id, secs])
	if bool(how.get("brief", false)):
		await _frames_pass(int(secs * 60.0) + 20)
	else:
		await _frames_pass(24)
		Voice.hush()
	var tries: Array = (how.get("miss", []) as Array).duplicate()
	tries.append(b.ticket.solution)
	for t in tries.size():
		var chips: Array = tries[t]
		var last := t == tries.size() - 1
		b.clear()
		await _frames_pass(20)
		_mark("write %s %d" % [id, t])
		for n in chips.size():
			await _frames_pass(CHIP_FRAMES)
			var chip := str(chips[n])
			b.focus = (b.ticket.chips as Array).find(chip)
			_expect(b.place(chip), "%s: no room on the line for %s" % [id, chip])
			_mark("chip %s %d %d %s" % [id, t, n, " ".join(PackedStringArray(b.tokens))])
		await _frames_pass(WRITTEN_FRAMES)
		# The keys move onto FIRE!.
		b.focus = (b.ticket.chips as Array).size() + 2
		await _frames_pass(12)
		if b.result.has("error"):
			_expect(not last, "%s: the solution is refused" % id)
			await _frames_pass(REFUSED_FRAMES)
			_mark("refused %s %d" % [id, t])
			b.fire_now()
			await _frames_pass(REFUSED_FRAMES)
			continue
		_mark("fire %s %d" % [id, t])
		ShiftScene.bot_frames = SENT_FRAMES
		b.fire_now()
		if last:
			await _until(func() -> bool: return scene.state != "build", "%s: the solution didn't win" % id)
			_mark("sent %s" % id)
			await _until(func() -> bool: return scene.state != "won", "%s: the banner never came down" % id)
			ShiftScene.bot_frames = 3
		else:
			await _until(func() -> bool: return not b.busy, "%s: the fire never finished" % id)
			ShiftScene.bot_frames = 3
			_mark("missed %s %d" % [id, t])
			await _frames_pass(MISSED_FRAMES)


func _voice_length(line: Dictionary) -> float:
	var clip := Voice.stream(line)
	return clip.get_length() if clip != null else 0.0


func _mark(text: String) -> void:
	print("MARK %d %s" % [Engine.get_process_frames() - _start_frame, text])
