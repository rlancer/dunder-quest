extends Node

## Plays the whole game the way a player does, without a window: the title,
## every page of the prologue (checking that each request it writes out
## gets an answer), then every episode from the TV guide. On each scene it
## first sends a slip that the counter answers but that isn't what the scene
## wants, and checks that Stu has something to say about it; then tries one
## with no method, which can't go and must cost nothing; then puts the
## solution's cards on and sends. At the end every episode must have aired,
## with a star for every scene, and no text anywhere may have left its
## panel (Fit).
##
## godot --headless --path . res://tests/bot.tscn

## Frames a talking page and a won banner stay up; tests/shots.gd slows these.
var linger: int = 0

var _problems: PackedStringArray = []
var _scenes: int = 0


func _ready() -> void:
	Progress.persist = false
	Progress.reset()
	Voice.muted = true
	StageAudio.web_audio_unlocked = true
	EpisodeScene.bot = true
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
		await _until(func() -> bool: return tree.current_scene is EpisodeScene and (tree.current_scene as EpisodeScene).episode_id == id, "episode %d didn't open" % id)
		await _episode(tree.current_scene as EpisodeScene)
		await _until(func() -> bool: return tree.current_scene != null and tree.current_scene.has_method("_take"), "the TV guide didn't come back after episode %d" % id)
		await _frames_pass(4)
		await moment("board_%d" % id)
		_expect(Progress.is_cleared(id), "episode %d isn't marked aired" % id)
		var scenes := (Story.episode(id).scenes as Array).size()
		_expect(Progress.stars(id) == scenes, "episode %d: %d stars for %d scenes played at par" % [id, Progress.stars(id), scenes])
		_expect(Progress.best_tries(id) == scenes * 2, "episode %d: %d takes counted, not %d" % [id, Progress.best_tries(id), scenes * 2])
		if id < Story.count():
			_expect(Progress.is_open(id + 1), "episode %d didn't open after episode %d" % [id + 1, id])
			tree.current_scene._take(id + 1)
	_expect(Progress.cleared_count() == Story.count(), "%d of %d episodes aired" % [Progress.cleared_count(), Story.count()])
	for key: String in Fit.breaks:
		_problems.append("%s (%s)" % [key, Fit.breaks[key]])
	for line in _problems:
		print("PROBLEM ", line)
	print("BOT result=%s episodes=%d scenes=%d" % ["ok" if _problems.is_empty() else "FAIL %d" % _problems.size(), Progress.cleared_count(), _scenes])
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
			var take := Intro.demo_take(demo)
			_expect(take.has("lines"), "prologue page %d: its request can't be sent" % index)
			_expect(intro.demo_lines() == (take.request as Array).size() + (take.get("lines", []) as Array).size(), "prologue page %d: its request didn't finish" % index)
	intro._go(intro.beat_count())


func _episode(scene: EpisodeScene) -> void:
	var seen := ""
	var tried_wrong := false
	var guard := 0
	while is_instance_valid(scene) and scene.state != "leaving":
		guard += 1
		if guard > 20000:
			_expect(false, "episode %d never finished (stuck in \"%s\")" % [scene.episode_id, scene.state])
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
						await _wrong_take(scene)
					else:
						_scenes += 1
						var id := str(b.scene.id)
						b.clear()
						for card: String in b.scene.solution:
							b.toggle(card)
						_expect(b.cards == b.scene.solution, "%s: its own solution didn't go on the slip as written" % id)
						await _frames_pass(1 + linger)
						await moment("%s_slip" % id)
						b.send()
						if linger > 0:
							await _until(func() -> bool: return b.arrived * 2 >= (b.result.get("lines", []) as Array).size(), "%s: no response came" % id)
							await moment("%s_sending" % id)
						await _until(func() -> bool: return scene.state != "build", "%s: the solution didn't get what the scene wants" % id)
						await _frames_pass(linger)
						await moment("%s_aired" % id)
			"talk":
				if linger > 0 and scene.dialogue._frames >= linger:
					await moment("%d_say_%s" % [scene.episode_id, Voice.key_of(scene.dialogue.line)])
			"card":
				if linger > 0:
					scene.card.settle()
					await _frames_pass(2)
					await moment("card_%s" % scene.card.card.get("id", ""))
			"title":
				await moment("%d_title" % scene.episode_id)
			"end":
				await moment("%d_end" % scene.episode_id)
		await get_tree().process_frame


## A slip the counter answers that isn't what the scene wants: the first
## the cards can make. Stu must say what went wrong. Then one with no
## method, which can't go and costs no take.
func _wrong_take(scene: EpisodeScene) -> void:
	var b := scene.builder
	var id := str(b.scene.id)
	await moment("%s_brief" % id)
	for cards: Array in Http.slips(b.scene.cards):
		var take := Judge.judge(b.scene, cards)
		if take.has("refused") or bool(take.won):
			continue
		for card: String in cards:
			b.toggle(card)
		var before := b.takes
		b.send()
		await _until(func() -> bool: return not b.busy, "%s: sending %s never finished" % [id, cards])
		_expect(b.takes == before + 1, "%s: a missed take wasn't counted" % id)
		_expect(b.fails == 1 and b.said != "", "%s: Stu said nothing about %s" % [id, cards])
		_expect(not b.said.contains("{"), "%s: an unfilled blank in \"%s\"" % [id, b.said])
		await _frames_pass(1 + linger)
		await moment("%s_missed" % id)
		# Twice wrong brings the hint; look at that too.
		b.fails = 2
		b.note = "Hint: %s" % b.scene.hint
		await _frames_pass(2)
		b.fails = 1
		b.note = ""
		# The board, turned back to.
		b.turn()
		await _frames_pass(1 + linger)
		await moment("%s_board" % id)
		# A slip with no method can't go, and costs nothing.
		b.clear()
		for card: String in b.scene.cards:
			if Http.kind(card) == "path":
				b.toggle(card)
				break
		b.send()
		_expect(b.takes == before + 1 and not b.busy and b.said != "", "%s: a slip with no method cost a take" % id)
		await _frames_pass(2)
		await moment("%s_refused" % id)
		b.clear()
		return
	_expect(false, "%s: every slip the cards make either can't go or wins" % id)


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
