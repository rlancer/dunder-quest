extends "res://tests/bot.gd"

## The bot's run, for the trailer's camera. Recording at 1920x1080 is slow
## (a few frames a second), so it only takes its time over what the trailer
## cuts to (`PAGES` and `WANT`) and hurries through everything else: a
## wanted line of talk is held for as long as its voice takes to read it, a
## wanted scene's slip is made a card at a time and sent at the game's own
## speed, and its AND SCENE banner is left up long enough to read. A slip
## can be sent wrong first, on purpose (`miss`), to get the counter's 4xx
## and what Stu says about it on camera. The music and the voices are muted
## (the trailer has its own cue, and lays the voice clips in itself); the
## effects are recorded. Logs a MARK line, keyed by movie frame, for every
## moment worth cutting to:
##
##   MARK <frame> title                      the title screen
##   MARK <frame> page <n> <seconds>         a page of the prologue, and its voice's length
##   MARK <frame> titlecard <episode>        an episode's title card
##   MARK <frame> say <episode> <who> <seconds>| <text>   a line of talk
##   MARK <frame> card <id> <seconds>        one of Stu's sets
##   MARK <frame> brief <scene>              the counter, with an empty slip
##   MARK <frame> write <scene> <try>        the first card is about to go on
##   MARK <frame> chip <scene> <try> <n> <card>
##   MARK <frame> send <scene> <try>         the slip goes over the counter
##   MARK <frame> missed <scene> <try> <status>   the response is in, and it isn't what the scene wants
##   MARK <frame> won <scene> <status>       the AND SCENE banner
##   MARK <frame> end <episode>              the episode's end card
##   MARK <frame> end-of-run
##
## Only wanted lines, sets and scenes are marked.
##
## bash trailer/capture.sh   (records at 1920x1080, so the text is sharp)
## Run with `-- prologue` for the title and the prologue's pages, or
## `-- episode=3` for one episode.

## Frames between one card going on the slip and the next.
const CARD_FRAMES := 24
## Frames a finished slip sits before it's sent.
const WRITTEN_FRAMES := 40
## Frames a missed take, and what Stu says about it, stay up.
const MISSED_FRAMES := 170
## Frames an AND SCENE banner stays up.
const WON_FRAMES := 120
## Frames an episode's title card, and its end card, stay up.
const CARD_HOLD := 110
## Frames the title screen is held.
const TITLE_FRAMES := 120
## The pages of the prologue the trailer uses: Stu at the Rimshot, twice, and Lenny.
const PAGES := [3, 4, 5]
## What the trailer uses of each episode. `say`: lines of talk, by how they
## start. `scenes`: by id; `miss` is wrong slips to send first. `cards`:
## Stu's sets, by id. `end`: hold the end card.
const WANT := {
	1: {"scenes": {"1a": {}, "1c": {}}},
	2: {
		"say": ["Know what you want", "Next!"],
		"scenes": {"2b": {"miss": [["POST", "/orders", "Content-Type: text/plain", "{\"broth\":\"mulligatawny\",\"size\":\"cup\"}"]]}},
	},
	3: {
		"say": ["And did you see what DELETE", "Finally, a status code"],
		"cards": ["delete"],
		"scenes": {"3c": {}},
	},
	4: {
		"say": ["Every parcel has a version"],
		"scenes": {
			"4a": {},
			"4b": {},
			"4c": {"miss": [["PATCH", "/mail/12", "Content-Type: application/json", "If-Match: \"v1\"", "{\"to\":\"Stu Lerner\"}"]]},
		},
	},
	5: {
		"say": ["Our pilots are behind", "Ha.", "Six episodes!"],
		"scenes": {"5d": {}},
		"end": true,
	},
}

var _start_frame := 0
var _line: Dictionary = {}
var _card: Dictionary = {}
var _want: Dictionary = {}
var _scene: EpisodeScene


func _ready() -> void:
	super()
	# The bot's audit draws every animation finished; the camera wants them playing.
	Fit.audit = false
	_start_frame = Engine.get_process_frames()
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Music"), true)


func _run() -> void:
	var tree := get_tree()
	reparent(tree.root)
	tree.current_scene = null
	var episode := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("episode="):
			episode = int(arg.get_slice("=", 1))
	if episode > 0:
		_want = WANT.get(episode, {})
		EpisodeScene.bot_frames = CARD_HOLD
		Main.play_episode(tree, episode)
		await _until(func() -> bool: return tree.current_scene is EpisodeScene, "episode %d didn't open" % episode)
		await _film(tree.current_scene as EpisodeScene)
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
			var b := intro.beat()
			var line := {"who": str(b.get("who", "narrator")), "text": str(b.text)}
			if b.has("say"):
				line["say"] = b.say
			var secs := _voice_length(line)
			_mark("page %d %.3f" % [page, secs])
			await _frames_pass(int((maxf(intro._done_at(), secs) + 0.8) * 60.0))
	_mark("end-of-run")
	for line in _problems:
		print("PROBLEM ", line)
	tree.quit(0 if _problems.is_empty() else 1)


func _film(scene: EpisodeScene) -> void:
	_scene = scene
	var seen := ""
	while is_instance_valid(scene) and scene.state != "leaving":
		if scene.state != seen:
			seen = scene.state
			if seen == "title":
				_mark("titlecard %d" % scene.episode_id)
			elif seen == "talk":
				EpisodeScene.bot_frames = 3
			elif seen == "end":
				_mark("end %d" % scene.episode_id)
		if scene.state == "build" and not scene.builder.busy:
			await _write(scene)
		await get_tree().process_frame
	_scene = null


## Every frame, ahead of the scene's own nodes: how long the line of talk or
## the set that has just come up stays. Between two of them the hold is
## left long, so the next can't turn its own page before it's seen.
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
			_mark("say %d %s %.3f| %s" % [scene.episode_id, _line.get("who", "narrator"), secs, words])
		talk.auto_frames = talk._frames + frames
	var card := scene.card
	if not card.active:
		card.auto_frames = 1 << 30
	elif not is_same(card.card, _card):
		_card = card.card
		var frames := 1
		var id := str(_card.get("id", ""))
		if (_want.get("cards", []) as Array).has(id):
			var secs := _voice_length(LessonCard.spoken(_card))
			frames = int(secs * 60.0) + 60
			_mark("card %s %.3f" % [id, secs])
		card.auto_frames = card._frames + frames


func _wanted_line(words: String) -> bool:
	for start: String in _want.get("say", []):
		if words.begins_with(start):
			return true
	return false


## The counter: any wrong slips, then the solution.
func _write(scene: EpisodeScene) -> void:
	var b := scene.builder
	var id := str(b.scene.id)
	var scenes: Dictionary = _want.get("scenes", {})
	var is_last := scene.scene_index == (scene.episode.scenes as Array).size() - 1
	var after := CARD_HOLD if is_last and bool(_want.get("end", false)) else 3
	if not scenes.has(id):
		# Not for the camera: straight to the answer.
		b.instant = true
		EpisodeScene.bot_frames = 3
		b.clear()
		for card: String in b.scene.solution:
			b.toggle(card)
		b.send()
		await _until(func() -> bool: return scene.state != "build", "%s: the solution didn't win" % id)
		await _until(func() -> bool: return scene.state != "won", "%s: the banner never came down" % id)
		EpisodeScene.bot_frames = after
		return
	var how: Dictionary = scenes[id]
	b.instant = false
	_mark("brief %s" % id)
	await _frames_pass(30)
	var tries: Array = (how.get("miss", []) as Array).duplicate()
	tries.append(b.scene.solution)
	for t in tries.size():
		var cards: Array = tries[t]
		var last := t == tries.size() - 1
		b.clear()
		await _frames_pass(20)
		_mark("write %s %d" % [id, t])
		for n in cards.size():
			await _frames_pass(CARD_FRAMES)
			var card := str(cards[n])
			b.focus = (b.scene.cards as Array).find(card)
			b.toggle(card)
			_expect(b.cards.has(card), "%s: %s didn't go on the slip" % [id, card])
			_mark("chip %s %d %d %s" % [id, t, n, card])
		await _frames_pass(WRITTEN_FRAMES)
		b.focus = (b.scene.cards as Array).size() + 2
		await _frames_pass(12)
		_mark("send %s %d" % [id, t])
		EpisodeScene.bot_frames = WON_FRAMES
		b.send()
		if last:
			await _until(func() -> bool: return scene.state != "build", "%s: the solution didn't win" % id)
			_mark("won %s %d" % [id, int(b.result.response.status)])
			await _until(func() -> bool: return scene.state != "won", "%s: the banner never came down" % id)
			EpisodeScene.bot_frames = after
		else:
			await _until(func() -> bool: return not b.busy, "%s: the take never finished" % id)
			_expect(not bool(b.result.get("won", false)), "%s: a slip meant to miss didn't" % id)
			_mark("missed %s %d %d" % [id, t, int(b.result.response.status)])
			await _frames_pass(MISSED_FRAMES)


func _voice_length(line: Dictionary) -> float:
	var clip := Voice.stream(line)
	return clip.get_length() if clip != null else 0.0


func _mark(text: String) -> void:
	print("MARK %d %s" % [Engine.get_process_frames() - _start_frame, text])
