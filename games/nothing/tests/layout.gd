extends Node

## Looks at every screen the game can put up and checks that no text
## reaches past the panel it's drawn in, runs over other text, or has to be
## cut short. Every piece of text is drawn through Fit (ui/fit.gd), which
## writes down any that breaks out while `Fit.audit` is on.
##
## It goes further than a play-through does: the title and the TV guide in
## every state, each page of the prologue, every line of talk, every one of
## Stu's sets, and every scene in the writers' room as briefed, with each
## card under the cursor and each hook picked, every way its cards can go on
## (at the top and the foot of the page), every step of its solution's take
## on the event loop, and everything Stu can say about a take or a card;
## then each episode's title card, every and-scene banner and each end card.
## All of it by keys and by touch.
##
## godot --headless --path . res://tests/layout.tscn

var _problems: PackedStringArray = []
var _screens: int = 0


func _ready() -> void:
	Progress.persist = false
	Voice.muted = true
	StageAudio.web_audio_unlocked = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	reparent(tree.root)
	tree.current_scene = null
	Fit.audit = true
	for touch: bool in [false, true]:
		TouchControls.active = touch
		await _title()
		await _board()
		await _prologue()
		await _talk()
		await _cards()
		await _desks()
		await _overlays()
	TouchControls.active = false
	for key: String in Fit.breaks:
		_problems.append("%s (%s)" % [key, Fit.breaks[key]])
	_problems.sort()
	for line in _problems:
		print("BREAK ", line)
	print("LAYOUT result=%s screens=%d" % ["ok" if _problems.is_empty() else "FAIL %d" % _problems.size(), _screens])
	tree.quit(0 if _problems.is_empty() else 1)


func _look(frames: int = 2) -> void:
	_screens += 1
	for _i in frames:
		await get_tree().process_frame


func _clear() -> void:
	var scene := get_tree().current_scene
	if scene != null:
		scene.queue_free()
		get_tree().current_scene = null
	await get_tree().process_frame


func _stage(node: Node) -> void:
	await _clear()
	get_tree().root.add_child(node)
	get_tree().current_scene = node


func _progress(cleared: int) -> void:
	Progress.reset()
	for id in range(1, cleared + 1):
		Progress.mark_cleared(id, 99, 0)


# --- The title and the TV guide ---------------------------------------------

func _title() -> void:
	for cleared: int in [0, 3]:
		_progress(cleared)
		await _clear()
		get_tree().change_scene_to_file("res://ui/boot.tscn")
		await _look(4)
		var title := get_tree().current_scene
		if cleared > 0:
			title._on_new()
			await _look()


func _board() -> void:
	for cleared: int in [0, 2, Story.count()]:
		_progress(cleared)
		Progress.just_cleared = cleared
		await _clear()
		get_tree().change_scene_to_file(Main.BOARD)
		await _look(4)
		var board := get_tree().current_scene
		for id in range(1, Story.count() + 1):
			board._selected = id
			if not Progress.is_open(id):
				board._take(id)
			await _look()


# --- The prologue --------------------------------------------------------------

func _prologue() -> void:
	await _clear()
	Main.play_intro(get_tree(), 0)
	for _i in 6:
		await get_tree().process_frame
		if get_tree().current_scene is Intro:
			break
	var intro := get_tree().current_scene as Intro
	if intro == null:
		_problems.append("the prologue didn't open")
		return
	intro.driven = true
	for index in intro.beat_count():
		intro._go(index)
		# Half written, then all there.
		intro._t = 1.0
		await _look()
		intro._t = 60.0
		await _look()


# --- Talk and cards --------------------------------------------------------------

func _talk() -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	await _stage(holder)
	var dialogue := Dialogue.new()
	holder.add_child(dialogue)
	var lines: Array = Story.spoken_lines()
	for who: String in Story.data().cast:
		lines.append({"who": who, "text": "A."})
	for line: Dictionary in lines:
		dialogue.say(line)
		dialogue._shown = 9999.0
		await _look()
		dialogue.advanced.emit()


func _cards() -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	await _stage(holder)
	var card := LessonCard.new()
	holder.add_child(card)
	for id: String in Story.data().cards:
		card.show_card(Story.card(id))
		await _look()
		card.settle()
		await _look()
		card._clock = 600.0
		await _look()
		card.closed.emit()


# --- The writers' room -----------------------------------------------------------

func _desks() -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	await _stage(holder)
	var b := Builder.new()
	b.instant = true
	holder.add_child(b)
	var longest_header := ""
	for e: Dictionary in Story.episodes():
		var header := "Episode %d: %s" % [e.id, e.title]
		if header.length() > longest_header.length():
			longest_header = header
	for e: Dictionary in Story.episodes():
		var scenes: Array = e.scenes
		for i in scenes.size():
			var s: Dictionary = scenes[i]
			# As briefed, with takes in three figures.
			b.setup(s, longest_header, "Scene %d of %d" % [i + 1, scenes.size()], 188)
			await _look()
			# Every card under the cursor, and every hook picked.
			for at in (s.cues as Array).size():
				b.focus = at
				b.queue_redraw()
				await _look(1)
			for at in Builder.BUTTONS.size():
				b.focus = (s.cues as Array).size() + at
				b.queue_redraw()
				await _look(1)
			for at in b.slots.size():
				b.pick = at
				b._follow()
				b.queue_redraw()
				await _look(1)
			# Every way the cards can go on, each at both ends of the page,
			# and a few of them rolled, with every line aired.
			var rolled := 0
			for cues: Dictionary in Loop.placements(s):
				b.cues = cues.duplicate()
				b.cards = {}
				var k := 0
				for slot: String in cues:
					b.cards[slot] = k
					k += 1
				b._refresh()
				for scroll: int in [0, maxi(b.page.size() - Builder.ROWS, 0)]:
					b.scroll = scroll
					b.queue_redraw()
					await _look(1)
				if rolled < 3:
					rolled += 1
					b.roll()
					for _f in 400:
						if not b.busy:
							break
						await get_tree().process_frame
					await _look()
				b.busy = false
			# Every step of the solution's take, on the event loop.
			b.cues = (s.solution as Dictionary).duplicate()
			b._refresh()
			b.result = Judge.judge(s, b.cues)
			b.playing = true
			b.busy = true
			for at in (b.result.trace as Array).size():
				b.step = at
				b.aired = 0
				for j in at + 1:
					if str(b.result.trace[j].kind) == "log":
						b.aired += 1
				b.queue_redraw()
				await _look(1)
			b.playing = false
			b.busy = false
			# Everything Stu can say about a take, at its longest, with the hint under it.
			var longest := "W".repeat(18)
			for why: String in ["miss", "nocue"]:
				for template: String in Story.stock(why):
					b.said = template.replace("{got}", longest).replace("{want}", longest)
					for note: String in ["", "Hint: %s" % s.hint]:
						b.note = note
						b.queue_redraw()
						await _look(1)
			# And about a card that won't go.
			b.note = ""
			for key: String in Story.data().errors:
				b.said = Story.error_text(key)
				b.queue_redraw()
				await _look(1)
			b.fails = 2
			b.said = ""
			b.note = "Hint: %s" % s.hint
			b.queue_redraw()
			await _look()


# --- Title cards, order-up banners, end cards --------------------------------------

func _overlays() -> void:
	EpisodeScene.still = true
	for e: Dictionary in Story.episodes():
		for best: int in [0, 7]:
			_progress(0)
			if best > 0:
				Progress.mark_cleared(int(e.id), best, 1)
			var scene := EpisodeScene.new()
			scene.episode_id = int(e.id)
			await _stage(scene)
			scene.state = "title"
			scene._show_overlay(true)
			await _look()
			scene._esc_armed = 2.0
			await _look()
			scene._esc_armed = 0.0
			var scenes: Array = e.scenes
			scene.builder.visible = true
			for i in scenes.size():
				scene.scene = scenes[i]
				scene.scene_index = i
				scene.builder.setup(scenes[i], "Episode", "Scene", 0)
				scene.builder.cues = (scenes[i].solution as Dictionary).duplicate()
				for extra: int in [0, 1]:
					if extra == 1:
						scene.builder.cues["zz"] = "then"
					for quip: String in Story.stock("par") + Story.stock("over"):
						scene._quip = quip
						scene.state = "won"
						scene._show_overlay(true)
						await _look(1)
			scene.builder.visible = false
			scene.takes = 188
			scene.stars = scenes.size()
			scene.state = "end"
			scene._show_overlay(true)
			await _look()
	EpisodeScene.still = false
	await _clear()
