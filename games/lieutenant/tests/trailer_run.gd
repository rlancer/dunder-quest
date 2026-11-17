extends "res://tests/bot.gd"

## The bot's run, paced for the trailer: lines held long enough to read, the
## Lieutenant walking at his own speed, each query spelled a chip at a time,
## the printout left on the desk a few seconds, and the scene music muted
## (the trailer has its own cue). It calls Records with the right answer
## only, except for the few wrong pages in `extra_tries`, which are there to
## get the database's own errors on camera. Logs a MARK line, keyed by movie
## frame, for every moment worth cutting to:
##
##   MARK <frame> title | files               the title screen, the case files
##   MARK <frame> page <n>                    a page of the prologue
##   MARK <frame> open <case>                 a case starts (its cold open)
##   MARK <frame> caption <case> <n>          a caption of the cold open
##   MARK <frame> titlecard <case>            the black title card
##   MARK <frame> arrive <case>               the Lieutenant walks in
##   MARK <frame> state <case> <state>        free, busy, notebook, ending, cleared
##   MARK <frame> say <case> <who> <mood>| <text>   a speech bubble
##   MARK <frame> slip <case> <tables>        a record goes into the notebook
##   MARK <frame> card <case> <id>            a lesson card
##   MARK <frame> notebook <beat>             the notebook opens on a question
##   MARK <frame> sql <beat> <text>           the page spells this (after each chip)
##   MARK <frame> dial <beat>                 Records is called
##   MARK <frame> printout <beat> <verdict> <rows or the error>
##   MARK <frame> exit <case>                 he makes for the door
##   MARK <frame> freeze <case> | end <case>  the freeze frame, the end card
##   MARK <frame> end-of-run
##
## bash trailer/capture.sh   (records at 1920x1080, so the text is sharp)
## Add `-- case=3` for one case, or `-- prologue` for the title screen, the
## case files and the prologue playing itself.

var _start_frame := 0
var _seen := {}
var _only_prologue := false


func _init() -> void:
	line_frames = 80
	per_char = 1.7
	pace = 1.0
	printout_frames = 240
	chip_frames = 16
	# The database's own words, on camera: a count with no GROUP BY (the one
	# rule stricter than SQLite), a column two tables share, and a column from
	# a table that was never joined.
	extra_tries = {
		"4b": [{"select": ["patient", "COUNT(*)"], "from": "prescriptions"}],
		"5a": [{"select": ["seat", "orders.dish"], "from": "seating", "join": ["JOIN orders ON seating.seat = orders.seat"]}],
		"3b": [{"select": ["phones.owner", "calls.at"], "from": "calls", "where": ["calls.receiver = '555-0142'"]}],
	}


func _ready() -> void:
	_only_prologue = OS.get_cmdline_user_args().has("prologue")
	super()
	seed(7)
	_start_frame = Engine.get_process_frames()
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Music"), true)


func _run() -> void:
	if not _only_prologue:
		await super()
		return
	var tree := get_tree()
	reparent(tree.root)
	tree.current_scene = null
	tree.change_scene_to_file("res://ui/boot.tscn")
	await tree.create_timer(0.4).timeout
	_mark("title")
	await tree.create_timer(6.0).timeout
	tree.change_scene_to_file("res://ui/files.tscn")
	await tree.create_timer(0.4).timeout
	_mark("files")
	await tree.create_timer(3.0).timeout
	# The prologue, turning its own pages.
	Main.play_intro(tree, 1)
	await wait_until(func() -> bool: return tree.current_scene is Intro, 300)
	var page := -1
	while tree.current_scene is Intro:
		var intro := tree.current_scene as Intro
		if intro.page() != page:
			page = intro.page()
			_mark("page %d" % (page + 1))
		await tree.process_frame
	_finish()
	tree.quit(0)


func _finish() -> void:
	_mark("end-of-run")


## Only the wrong pages chosen for the camera.
func wrong_tries(_beat: Dictionary) -> Array:
	return []


func moment(name: String) -> void:
	if name.begins_with("open "):
		_mark(name)
	elif name.begins_with("notebook "):
		# The blank page and its question, before the first chip.
		_mark(name)
		await _frames(70)
	elif name.begins_with("solution "):
		# The whole query, before Records is called.
		await _frames(70)
	elif name.begins_with("called "):
		_mark("dial %s" % name.get_slice(" ", 1))


func _physics_process(_delta: float) -> void:
	if scene == null or not is_instance_valid(scene) or scene.hud == null:
		return
	var id := scene.case_id
	var hud := scene.hud
	var book := scene.notebook
	var beat_id := str(scene.current_beat().get("id", ""))
	_flag("state", "%d %s" % [id, scene.state])
	_flag("caption", "%d %d" % [id, hud.caption_count] if not hud._caption.is_empty() else "")
	_flag("titlecard", str(id) if not hud._title.is_empty() else "")
	_flag("arrive", str(id) if scene.state == "intro" and scene.lt.visible else "")
	var bubble := hud.bubble
	if bubble.is_empty():
		_flag("say", "")
	else:
		var who: Person = bubble.who
		_flag("say", "%d %s %s| %s" % [id, who.who if who != null else "-", bubble.mood, bubble.text])
	_flag("slip", "%d %s" % [id, " ".join(hud._slip.lines)] if not hud._slip.is_empty() else "")
	_flag("card", "%d %s" % [id, hud._card.get("id", "?")] if not hud._card.is_empty() else "")
	_flag("freeze", str(id) if hud._freeze > 0.0 and hud._end.is_empty() else "")
	_flag("end", str(id) if not hud._end.is_empty() else "")
	# He says goodnight and walks off by himself: the false exit.
	_flag("exit", str(id) if scene.state == "busy" and scene.lt.is_walking() and bool(scene.current_beat().get("final", false)) else "")
	if book.is_open():
		if book.mode == "edit":
			_flag("sql", "%s %s" % [beat_id, book.sql().replace("\n", " ")])
		elif book.mode == "printout":
			var result: Dictionary = book.verdict.result
			var what := "%d rows" % (result.rows as Array).size() if result.ok else str(result.error.msg)
			_flag("printout", "%s %s %s" % [beat_id, book.verdict.verdict, what])
	else:
		_seen.erase("sql")
		_seen.erase("printout")


## Prints a marker each time `key`'s value changes to something non-empty.
func _flag(key: String, value: String) -> void:
	if _seen.get(key, "") == value:
		return
	_seen[key] = value
	if value != "":
		_mark("%s %s" % [key, value])


func _mark(text: String) -> void:
	print("MARK %d %s" % [_frame(), text])


func _frame() -> int:
	return Engine.get_process_frames() - _start_frame
