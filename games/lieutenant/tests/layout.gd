extends Node

## Looks at every screen the game can put up and checks that no text
## reaches past the panel it's drawn in, runs over other text, or has to be
## cut short. Every piece of text is drawn through Fit (ui/fit.gd), which
## writes down any that breaks out while `Fit.audit` is on.
##
## It goes further than a play-through does: every line of dialogue with the
## speaker at either wall and in the middle, every notebook page blank, solved
## and with every chip picked at once (the longest query the page can spell),
## every printout those give, every card, caption, slip, prompt and end card,
## the case files in every state, and each page of the prologue, by keys and
## by touch.
##
## godot --headless --path . res://tests/layout.tscn

const PERSON := preload("res://world/person.gd")
const HUD := preload("res://ui/hud.gd")
const NOTEBOOK := preload("res://ui/notebook.gd")

var _problems: PackedStringArray = []
var _screens: int = 0


func _ready() -> void:
	Voice.muted = true
	Progress.persist = false
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
		await _files()
		await _prologue()
		for c: Dictionary in Story.cases():
			await _hud(c)
			await _notebook(c)
	TouchControls.active = false
	_tables()
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


# --- The title and the case files -------------------------------------------

func _title() -> void:
	for cleared: int in [0, 3]:
		Progress.reset()
		for id in range(1, cleared + 1):
			Progress.mark_cleared(id, 99)
		get_tree().change_scene_to_file("res://ui/boot.tscn")
		await _look(4)
		var title := get_tree().current_scene
		for button: Node in title.find_children("*", "Button", true, false):
			_button(button as Button, Fit.SCREEN, "the title")
		if cleared > 0:
			title._on_new()
			await _look(3)
			for button: Node in title.find_children("*", "Button", true, false):
				_button(button as Button, Fit.SCREEN, "the title")
		var footer: Label = title._footer
		var wide := footer.get_theme_font(&"font").get_string_size(footer.text, HORIZONTAL_ALIGNMENT_LEFT, -1, footer.get_theme_font_size(&"font_size")).x
		_expect(wide <= footer.size.x, "the title's footer \"%s\" is %d px wide in %d" % [footer.text, wide, footer.size.x])
		await _clear()
	Progress.reset()


## A button's words fit inside it, and it sits inside `panel`.
func _button(button: Button, panel: Rect2, where: String) -> void:
	if not button.is_visible_in_tree():
		return
	var font := button.get_theme_font(&"font")
	var wide := font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size(&"font_size")).x
	var rect := button.get_global_rect()
	_expect(wide <= rect.size.x - 4, "%s: the button \"%s\" is %d px of text in %d" % [where, button.text, wide, rect.size.x])
	_expect(panel.grow(0.5).encloses(rect), "%s: the button \"%s\" at %s is outside %s" % [where, button.text, rect, panel])


func _files() -> void:
	# Nothing closed, some closed, all closed (with a long count of calls).
	for cleared: int in [0, 2, Story.count()]:
		Progress.reset()
		for id in range(1, cleared + 1):
			Progress.mark_cleared(id, 99 if id % 2 == 0 else 7)
		for selected in range(1, Story.count() + 1):
			Progress.current_case = selected
			Progress.just_cleared = 0
			get_tree().change_scene_to_file("res://ui/files.tscn")
			await _look(3)
			var files := get_tree().current_scene
			# The sealed ones can only be looked at by asking.
			files._selected = selected
			await _look()
			files._say("Close \"%s\" first." % Story.case(selected).get("title", ""))
			await _look()
			files._say("Not yet. Close the one before it.")
			await _look()
			await _clear()
	Progress.reset()


func _prologue() -> void:
	Main.play_intro(get_tree(), 0)
	await _look(3)
	var intro := get_tree().current_scene as Intro
	intro.driven = true
	_button(intro._skip, Fit.SCREEN, "the prologue")
	for index in intro.beat_count():
		intro._go(index)
		# Mid-page (the marker walking the table), then as it ends up.
		for moment: float in [1.2, 2.4, 4.0, 5.5, 60.0]:
			intro._t = moment
			await _look()
	await _clear()


# --- Everything the HUD says ------------------------------------------------

func _hud(c: Dictionary) -> void:
	var id := int(c.id)
	var stage := Node2D.new()
	add_child(stage)
	var hud := HUD.new() as Hud
	hud.auto_frames = 2
	stage.add_child(hud)
	var lt := _person(stage, "lt")
	var suspect := _person(stage, str(c.killer))
	hud.place = str(c.get("place", ""))
	# The cold open and the cards that top and tail a case.
	hud.set_letterbox(1.0)
	for line: Array in c.get("cold_open", []):
		await hud.caption(str(line[0]), str(line[1]))
		_screens += 1
	hud.set_letterbox(0.0)
	await hud.title_card(str(c.get("title", "")), PackedStringArray(["Tonight's SQL: %s" % c.get("lesson", ""), str(c.get("place", ""))]))
	for calls: int in [1, 188]:
		var lines := PackedStringArray(["Tonight's SQL: %s" % c.get("lesson", ""), "%d %s to Records" % [calls, "call" if calls == 1 else "calls"]])
		lines.append("That's every case on file. More are being typed in.")
		await hud.end_card(str(c.get("title", "")), lines)
		_screens += 1
	hud.show_press_to_start()
	await _look()
	hud.hide_press_to_start()
	# Every line anybody says, wherever they might be standing to say it.
	var said: Array = (c.get("opening", []) as Array) + (c.get("ending", []) as Array)
	for p: Dictionary in c.get("props", []):
		said += p.get("lines", []) as Array
	for beat: Dictionary in c.get("beats", []):
		said += (beat.get("claim", []) as Array) + (beat.get("success", []) as Array)
	for line: Array in said:
		var speaker := lt if str(line[0]) == "lt" else suspect
		for x: float in [18.0, 240.0, 462.0]:
			speaker.position.x = x
			await hud.say(speaker, str(line[1]), str(line[2]) if line.size() > 2 else "")
			_screens += 1
	# Each record's slip, alone and with the Lieutenant talking under it at
	# that record, as he does when he stops at one on his way out.
	for p: Dictionary in c.get("props", []):
		if not p.has("table"):
			continue
		var added := PackedStringArray()
		for name: String in [str(p.table)] + (p.get("also", []) as Array):
			var columns := PackedStringArray()
			for column: Array in c.tables[name].columns:
				columns.append(str(column[0]))
			added.append("%s(%s)" % [name, ", ".join(columns)])
		hud.slip("In the notebook, as a table:" if added.size() == 1 else "In the notebook, as tables:", added, 60.0)
		await _look()
		lt.position.x = float(p.x)
		suspect.position.x = float(c.get("killer_x", 320))
		for beat: Dictionary in c.get("beats", []):
			if (beat.get("needs", []) as Array).has(str(p.id)):
				for line: Array in beat.get("claim", []):
					await hud.say(lt if str(line[0]) == "lt" else suspect, str(line[1]), "")
					_screens += 1
		hud._slip = {}
	# The lesson cards.
	for beat: Dictionary in c.get("beats", []):
		if str(beat.get("card", "")) != "":
			await hud.show_card(Story.card(str(beat.card), id))
			_screens += 1
	# The prompts along the foot of the screen.
	var prompts: Array = ["Esc again: back to the case files", "Go and talk to %s" % suspect.display_name, "%s: talk to %s" % [Controls.talk_key(), suspect.display_name]]
	for p: Dictionary in c.get("props", []):
		prompts.append("%s: look at %s" % [Controls.talk_key(), p.label])
		prompts.append("Look around: find %s" % p.label)
	for prompt: String in prompts:
		hud.prompt = prompt
		await _look()
	stage.queue_free()
	await get_tree().process_frame


func _person(stage: Node, who: String) -> Person:
	var person := PERSON.new() as Person
	person.who = who
	person.display_name = Story.name_of(who)
	person.position = Vector2(240, CaseScene.FLOOR_Y)
	stage.add_child(person)
	return person


# --- Every page of the notebook, and what comes back ------------------------

func _notebook(c: Dictionary) -> void:
	var id := int(c.id)
	var db := Story.db(id)
	var notebook := NOTEBOOK.new() as Notebook
	add_child(notebook)
	var label := "Case %d: %s" % [id, c.get("title", "")]
	var tables: Array = []
	for beat: Dictionary in c.get("beats", []):
		# The tables found by the time this question is asked.
		for needed: String in beat.get("needs", []):
			for p: Dictionary in c.get("props", []):
				if str(p.id) == needed and p.has("table"):
					for name: String in [str(p.table)] + (p.get("also", []) as Array):
						if not tables.has(name):
							tables.append(name)
		var tray: Dictionary = beat.get("tray", {})
		# Every chip on the page at once: the longest query it can spell.
		var everything := {}
		for line: String in Query.LINES:
			var chips: Array = (tray.get(line, []) as Array).filter(func(chip: String) -> bool: return line != "from" or tables.has(chip))
			if chips.is_empty():
				continue
			everything[line] = chips if Query.MULTI.has(line) else chips[-1]
		var pages: Array = [{}, beat.solution, everything]
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
			pages.append(wrong)
		for page: Dictionary in pages:
			notebook.open(beat, db, tables, label, true)
			notebook.set_picks(page)
			for misses: int in [0, 1]:
				notebook.misses = misses
				await _look()
			for button: Button in [notebook._call_button, notebook._close_button]:
				_button(button, Rect2(Notebook.PANEL.position.x, Notebook.PANEL.end.y - Notebook.BUTTONS, Notebook.PANEL.size.x, Notebook.BUTTONS), "the notebook")
			_expect(not notebook._call_button.get_global_rect().intersects(notebook._close_button.get_global_rect()), "the notebook's two buttons overlap")
			_expect(notebook._call_button.get_global_rect().position.x >= Notebook.PANEL.end.x - Notebook.BESIDE, "the notebook's buttons reach left of the space kept for them")
			notebook.verdict = Judge.check(db, beat, notebook.picks)
			notebook.mode = "dialing"
			notebook._dial = 60.0
			await _look()
			notebook.mode = "printout"
			await _look()
			notebook.mode = "edit"
		notebook.visible = false
	notebook.queue_free()
	await get_tree().process_frame


## A table with too many columns for the paper has its widest ones cut
## short, by design. That must never happen to an answer the game asks for,
## to a whole file read back with SELECT *, or to a lesson card.
func _tables() -> void:
	var paper := Notebook.PANEL.size.x - 24
	for c: Dictionary in Story.cases():
		var db := Story.db(int(c.id))
		for name: String in c.tables:
			_uncut(Sql.run(db, "SELECT * FROM %s" % name), paper, "SELECT * FROM %s" % name)
		for beat: Dictionary in c.get("beats", []):
			_uncut(Sql.run(db, Query.compose(Query.from_data(beat.solution))), paper, "%s's answer" % beat.id)
			if str(beat.get("card", "")) != "":
				var card := Story.card(str(beat.card), int(c.id))
				_uncut(Sql.run(card.db, str(card.sql)), 424.0, "the card \"%s\"" % card.title)


func _uncut(result: Dictionary, paper: float, what: String) -> void:
	_expect(result.ok and not bool(Printout.layout(result, 8, paper).cut), "%s has a column cut short on the printout" % what)


func _expect(ok: bool, text: String) -> void:
	if not ok and not _problems.has(text):
		_problems.append(text)
