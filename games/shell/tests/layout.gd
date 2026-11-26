extends Node

## Looks at every screen the game can put up and checks that no text
## reaches past the panel it's drawn in, runs over other text, or has to be
## cut short. Every piece of text is drawn through Fit (ui/fit.gd), which
## writes down any that breaks out while `Fit.audit` is on.
##
## It goes further than a play-through does: the title and the rota in every
## state, each page of the prologue, every line of talk, every lesson card,
## and every ticket's pass blank, solved, full to the brim, with each chip
## under the cursor, each file on the rail, every line one or two chips can
## spell (and so everything the shell can say about them), and everything
## Shell can say about a miss; then each shift's title card, every order-up
## banner and each end card. All of it by keys and by touch.
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


# --- The title and the shift board ---------------------------------------------

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


# --- The pass ------------------------------------------------------------------

func _desks() -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	await _stage(holder)
	var b := Builder.new()
	b.instant = true
	holder.add_child(b)
	var longest_header := ""
	for j: Dictionary in Story.shifts():
		var header := "Shift %d: %s" % [j.id, j.title]
		if header.length() > longest_header.length():
			longest_header = header
	for j: Dictionary in Story.shifts():
		var tickets: Array = j.tickets
		for i in tickets.size():
			var p: Dictionary = tickets[i]
			# As briefed, with fires in three figures.
			b.setup(p, longest_header, "Ticket %d of %d" % [i + 1, tickets.size()], 188)
			await _look()
			# Every chip under the cursor, then down on the ticket alone.
			for at in (p.chips as Array).size():
				b.focus = at
				b.clear()
				b.place(str(p.chips[at]))
				b.queue_redraw()
				await _look(1)
			# Every button under the cursor.
			for at in Builder.BUTTONS.size():
				b.focus = (p.chips as Array).size() + at
				b.queue_redraw()
				await _look(1)
			# As many chips as the line will take, widest first.
			b.clear()
			var wide: Array = (p.chips as Array).duplicate()
			wide.sort_custom(func(x: String, y: String) -> bool: return Ui.chip_width(x) > Ui.chip_width(y))
			var room := true
			while room:
				room = false
				for chip: String in wide:
					if b.place(chip):
						room = true
						break
			await _look()
			# A line with no room left says so.
			b.place(str(wide[0]))
			await _look()
			# Every file the kitchen has, on the rail.
			for name: String in p.files:
				b.shown_file = name
				b.queue_redraw()
				await _look(1)
			# Every line one or two chips can spell: what it prints, or what
			# the shell says about it, on the pass.
			var rows: Array = []
			for first: String in p.chips:
				rows.append([first])
				for second: String in p.chips:
					rows.append([first, second])
			var misses := 0
			for row: Array in rows:
				b.tokens = row.duplicate()
				b.caret = row.size()
				b._judge()
				await _look(1)
				# A few of the ones that run and miss, fired, with every verdict showing.
				if not b.result.has("error") and not bool(b.result.won) and misses < 4:
					misses += 1
					b.fire_now()
					for _f in 40:
						if not b.busy:
							break
						await get_tree().process_frame
					await _look()
			# Everything Shell can say about a miss, at its longest, with the hint under it.
			var longest := "W".repeat(21)
			for why: String in ["nothing", "order", "extra", "short", "wrong", "tofile", "infile"]:
				for template: String in Story.stock(why):
					b.said = template.replace("{got}", longest).replace("{want}", longest).replace("{n}", "7").replace("{file}", "specials.txt")
					for note: String in ["", "Hint: %s" % p.hint]:
						b.note = note
						b.queue_redraw()
						await _look(1)
			# And about a line the shell won't run.
			b.note = ""
			for key: String in Story.data().errors:
				for chip: String in p.chips:
					b.said = Story.error_text({"why": key, "token": chip})
					b.queue_redraw()
					await _look(1)
			b.said = Story.error_text({"why": "something new"})
			await _look(1)
			b.fails = 2
			b.said = ""
			b.note = "Hint: %s" % p.hint
			b.queue_redraw()
			await _look()
			# And the answer, drawn on.
			b.clear()
			for chip: String in p.solution:
				b.place(chip)
			await _look()
			b.fire_now()
			await _look(6)


# --- Title cards, order-up banners, end cards --------------------------------------

func _overlays() -> void:
	ShiftScene.still = true
	for j: Dictionary in Story.shifts():
		for best: int in [0, 7]:
			_progress(0)
			if best > 0:
				Progress.mark_cleared(int(j.id), best, 1)
			var scene := ShiftScene.new()
			scene.shift_id = int(j.id)
			await _stage(scene)
			scene.state = "title"
			scene._show_overlay(true)
			await _look()
			scene._esc_armed = 2.0
			await _look()
			scene._esc_armed = 0.0
			var tickets: Array = j.tickets
			scene.builder.visible = true
			for i in tickets.size():
				scene.ticket = tickets[i]
				scene.ticket_index = i
				scene.builder.setup(tickets[i], "Shift", "Ticket", 0)
				for chip: String in tickets[i].solution:
					scene.builder.place(chip)
				for extra: int in [0, 1]:
					if extra == 1:
						scene.builder.tokens.append("ls")
					for quip: String in Story.stock("par") + Story.stock("over"):
						scene._quip = quip
						scene.state = "won"
						scene._show_overlay(true)
						await _look(1)
			scene.builder.visible = false
			scene.fires = 188
			scene.stars = tickets.size()
			scene.state = "end"
			scene._show_overlay(true)
			await _look()
	ShiftScene.still = false
	await _clear()
