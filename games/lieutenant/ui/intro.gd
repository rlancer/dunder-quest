class_name Intro
extends Control

## The prologue, before the first case: a city where everybody with a plan
## thinks of everything, the records that city keeps anyway, and the
## Lieutenant who reads them. It is also the game's answer to "what is SQL?"
## for someone who has never seen any: every beat pairs a line of the story
## with the database word for it.
##
## The table on screen is the first case's real guest book, and the query
## that gets typed is run by the game's own SQL engine (sql/sql.gd), so the
## rows that light up are the rows SQLite would return. Any key or tap turns
## the page, Skip (or Esc) goes straight on, and left alone it plays itself.

const VIEW := Vector2(480, 270)
const FLOOR := 188.0
const PANEL := 196.0
## Letters a second.
const TYPE := 38.0
## Seconds a finished page waits before it turns by itself.
const AFTER := 3.4
const DEMO := "SELECT name, arrived\nFROM guests\nWHERE arrived > '21:00'"
const SUSPECTS := ["voss", "bannister", "brandt", "sloane", "harrow"]
const PERSON := preload("res://world/person.gd")
const DOG := preload("res://world/dog.gd")

## The case to open afterwards; 0 goes back to the title.
static var then: int = 1

## The bot sets this and turns the pages itself.
var driven: bool = false
## What the demonstration query returned, for the bot to check.
var demo: Dictionary = {}

var _beats: Array = []
var _index: int = -1
var _t: float = 0.0
var _clock: float = 0.0
var _black: float = 1.0
var _leaving: bool = false
var _street: Sprite2D
var _desk: Sprite2D
var _lt: Person
var _dog: Dog
var _lineup: Array[Person] = []
var _canvas: Control
var _skip: Button
var _guests: Dictionary = {}
var _music: String = ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var audio := StageAudio.new()
	audio.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(audio)
	_street = Backdrop.sprite("res://assets/backgrounds/night.png")
	add_child(_street)
	_desk = Backdrop.sprite("res://assets/backgrounds/desk.png")
	add_child(_desk)
	# The backdrops are painted with the floor lower down; lift the street so
	# its kerb sits above the text.
	_street.position.y = -52.0
	for i in SUSPECTS.size():
		var suspect := PERSON.new() as Person
		suspect.who = SUSPECTS[i]
		suspect.position = Vector2(96 + i * 72, FLOOR)
		suspect.modulate = Color(0.06, 0.05, 0.1)
		add_child(suspect)
		_lineup.append(suspect)
	_dog = DOG.new() as Dog
	add_child(_dog)
	_lt = PERSON.new() as Person
	_lt.who = "lt"
	_lt.min_x = -80.0
	add_child(_lt)
	_dog.master = _lt
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_page)
	add_child(_canvas)
	_skip = Button.new()
	_skip.text = "Skip"
	_skip.position = Vector2(6, 3)
	_skip.size = Vector2(46, 16)
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.pressed.connect(_finish)
	add_child(_skip)
	_guests = Sql.run(Story.db(1), "SELECT * FROM guests")
	demo = Sql.run(Story.db(1), DEMO)
	_beats = script_beats()
	_go(0)


## The prologue's pages: where it's set, the line of story, and the
## database word for it.
static func script_beats() -> Array:
	var counts := ["No", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten"]
	var count: String = counts[Story.count()] if Story.count() < counts.size() else str(Story.count())
	return [
		{"stage": "street", "music": "cold",
			"text": "Los Angeles, 1974. Every night, somewhere in this town, somebody thinks of everything."},
		{"stage": "lineup", "sound": "sting",
			"text": "They plan it for months. The alibi. The witnesses. The one small detail nobody would ever think to check."},
		{"stage": "table", "music": "title",
			"text": "But this town writes everything down. Who signed the guest book. Who telephoned whom. Whose car went through the gate, and at what time.",
			"sql": "a database is where records are kept so they can be asked about"},
		{"stage": "table", "scan": true,
			"text": "Downtown, Doris in Records has typed all of it into the department's new machine, as tables: a row for every record, a column for every fact.",
			"sql": "a table: each row is one record, each column is one fact about it"},
		{"stage": "query",
			"text": "The machine will answer any question you like. But it only understands one language, and it takes you at your exact word.",
			"sql": "that language is SQL. A question written in it is a query"},
		{"stage": "arrive", "sound": "turn",
			"text": "Then there is Lieutenant Colonna, Homicide. He looks like he slept in that raincoat. He usually knows who did it inside five minutes."},
		{"stage": "think",
			"text": "Knowing isn't proof. Proof is one question, asked exactly right, with an answer that can only mean one thing.",
			"sql": "SELECT what to read back · FROM which table · WHERE which rows"},
		{"stage": "door", "sound": "turn",
			"text": "So he asks. He thanks them. He is almost out of the door. And then he thinks of one more.",
			"sql": "JOIN puts two tables side by side, and that's when alibis come apart"},
		{"stage": "files", "sound": "page",
			"text": "%s cases. You'll watch each of them do it. Then it's your notebook: find the query that proves it." % count,
			"sql": "write it a clause at a time · call Records · read what comes back"},
	]


func beat_count() -> int:
	return _beats.size()


func page() -> int:
	return _index


func _go(index: int) -> void:
	if index >= _beats.size():
		_finish()
		return
	_index = index
	_t = 0.0
	var beat: Dictionary = _beats[index]
	var stage := str(beat.stage)
	var outside := stage in ["street", "lineup", "arrive", "think", "door"]
	_street.visible = outside
	_desk.visible = not outside
	for suspect in _lineup:
		suspect.visible = stage == "lineup"
	var with_lt := stage in ["arrive", "think", "door"]
	_lt.visible = with_lt
	_dog.visible = with_lt
	match stage:
		"arrive":
			_lt.position = Vector2(-40, FLOOR)
			_dog.position = Vector2(-90, FLOOR)
			_lt.walk_to(250)
		"think":
			_lt.position.x = 250
			_lt.facing = 1
			_lt.strike(Person.Pose.ONE, 600.0)
		"door":
			_lt.strike(Person.Pose.IDLE, 0.0)
			_lt.walk_to(404)
	if beat.has("music") and str(beat.music) != _music:
		_music = str(beat.music)
		var path := "res://assets/audio/music_%s.ogg" % _music
		if ResourceLoader.exists(path):
			MusicDirector.play(load(path) as AudioStream)
	if beat.has("sound"):
		var path := "res://assets/audio/%s.wav" % beat.sound
		if ResourceLoader.exists(path):
			StageAudio.play(get_tree(), load(path) as AudioStream)


func _process(delta: float) -> void:
	_clock += delta
	_t += delta
	_black = maxf(_black - delta * 1.6, 0.0) if not _leaving else minf(_black + delta * 3.0, 1.0)
	var beat: Dictionary = _beats[_index]
	var stage := str(beat.stage)
	if stage == "lineup":
		# The five of them come out of the dark one at a time, and stay dark.
		for i in _lineup.size():
			var lit := clampf((_t - 0.5 - i * 0.55) * 2.0, 0.0, 1.0)
			_lineup[i].modulate = Color(0.06, 0.05, 0.1).lerp(Color(0.3, 0.26, 0.42), lit)
			_lineup[i].modulate.a = clampf((_t - i * 0.55) * 2.0, 0.0, 1.0)
			if lit >= 1.0 and _lineup[i].pose == Person.Pose.IDLE:
				_lineup[i].strike(Person.Pose.ONE, 600.0)
	elif stage == "door" and not _lt.is_walking():
		# Nearly out. Then he turns round.
		if _lt.facing > 0 and _t > 0.4:
			_lt.facing = -1
			_lt.strike(Person.Pose.TWO, 600.0)
	if not driven and _typed() >= str(beat.text).length() and _t > str(beat.text).length() / TYPE + AFTER + float(beat.get("hold", 0.0)):
		_go(_index + 1)
	_canvas.queue_redraw()


func _typed() -> int:
	return int(_t * TYPE)


func _input(event: InputEvent) -> void:
	if _leaving:
		return
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_finish()
		return
	var tap: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if tap and _skip.get_global_rect().has_point(event.position):
		return
	var key: bool = event is InputEventKey and event.pressed and not event.echo
	var pad: bool = event is InputEventJoypadButton and event.pressed
	if tap or key or pad:
		get_viewport().set_input_as_handled()
		turn()


## Jumps to the end of this page's animation (the layout test looks at
## every page as it finally stands).
func settle() -> void:
	_t = 60.0


## Finishes the page if it's still typing, otherwise turns it.
func turn() -> void:
	var text := str(_beats[_index].text)
	if _typed() < text.length():
		_t = text.length() / TYPE + 0.01
	else:
		_go(_index + 1)


func _finish() -> void:
	if _leaving:
		return
	_leaving = true
	var tree := get_tree()
	await tree.create_timer(0.35).timeout
	if then > 0:
		Main.play_case(tree, then)
	else:
		tree.change_scene_to_file(Main.TITLE)


# --- Drawing ----------------------------------------------------------------

func _draw_page() -> void:
	var c := _canvas
	var beat: Dictionary = _beats[_index]
	var stage := str(beat.stage)
	var mono := Palette.mono()
	Fit.frame(c)
	if stage in ["table", "query", "files"]:
		c.draw_rect(Rect2(0, 0, 480, PANEL), Color(0.03, 0.02, 0.03, 0.72))
	Fit.begin(Rect2(0, 0, 480, PANEL), "the prologue's picture")
	match stage:
		"table":
			_draw_table(c, Rect2(84, 8, 284, 180), bool(beat.get("scan", false)), [])
		"query":
			_draw_query(c)
		"files":
			_draw_files(c)
	Fit.end()
	# The page of story.
	Fit.begin(Rect2(0, PANEL, 480, VIEW.y - PANEL), "the prologue's page")
	c.draw_rect(Rect2(0, PANEL, 480, VIEW.y - PANEL), Color(0.04, 0.03, 0.04))
	c.draw_rect(Rect2(0, PANEL, 480, 1), Palette.EMBER.darkened(0.3))
	var text := str(beat.text).substr(0, _typed())
	var y := PANEL + 16
	for line in SqlDraw.wrap(str(beat.text), 440):
		var shown := line.substr(0, clampi(text.length(), 0, line.length()))
		text = text.substr(mini(text.length(), line.length() + 1))
		Fit.text(c, mono, Vector2(20, y), shown, 16, Palette.PAPER)
		y += 12
	var word := str(beat.get("sql", ""))
	var done := _typed() >= str(beat.text).length()
	if word != "" and done:
		var fade := clampf((_t - str(beat.text).length() / TYPE) * 2.5, 0.0, 1.0)
		c.draw_rect(Rect2(20, 250, 2, 11), Color(Palette.EMBER, fade))
		Fit.text(c, mono, Vector2(28, 259), word, 16, Color(Palette.EMBER, fade))
	if done and Fit.blink(int(_clock * 3.0) % 2 == 0):
		Fit.text(c, mono, Vector2(462, 262), "v", 16, Palette.EMBER)
	Fit.end()
	if _black > 0.0:
		c.draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0, 0, 0, _black))


## The guest book as a table. `scan` walks a marker down the rows and then
## across the columns; `lit` marks rows to pick out.
func _draw_table(c: Control, rect: Rect2, scan: bool, lit: Array) -> void:
	var mono := Palette.mono()
	var table := Printout.layout(_guests, 14, rect.size.x)
	var cell := SqlDraw.cell()
	c.draw_rect(Rect2(rect.position + Vector2(-2, -2), rect.size + Vector2(4, 4)), Palette.BAR_INK.lightened(0.2))
	c.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 13)), Palette.NOTE_COVER)
	Fit.begin(Rect2(rect.position, Vector2(rect.size.x, 13)), "the prologue's table heading")
	Fit.text(c, mono, rect.position + Vector2(6, 10), "guests", 16, Palette.CREAM)
	Fit.text(c, mono, rect.position + Vector2(rect.size.x - 96, 10), "the guest book", 16, Palette.CREAM.darkened(0.25))
	Fit.end()
	var body := Rect2(rect.position + Vector2(0, 13), Vector2(rect.size.x, (table.lines as Array).size() * 11.0 + 4))
	Fit.check(body, "(the prologue's table)")
	Printout.draw(c, body, table)
	var rows: int = (table.lines as Array).size() - 1
	if scan:
		var step := _t - 0.8
		if step >= 0.0 and step < rows * 0.22:
			# A row at a time: this is one record.
			var row := int(step / 0.22)
			var band := Rect2(body.position.x, body.position.y + 2 + (row + 1) * 11, body.size.x, 11)
			c.draw_rect(band, Color(Palette.EMBER, 0.32))
			Fit.text(c, mono, Vector2(body.end.x + 6, band.position.y + 9), "a row", 16, Palette.EMBER)
		elif step >= rows * 0.22:
			# Then a column at a time: this is one fact.
			var column := int((step - rows * 0.22) / 0.9) % (table.widths as Array).size()
			var x := body.position.x + 6
			for i in column:
				x += (int(table.widths[i]) + 2) * cell
			var band := Rect2(x - 3, body.position.y, (int(table.widths[column]) + 1) * cell + 4, body.size.y)
			c.draw_rect(band, Color(Palette.SYN_KEYWORD, 0.22))
			Fit.text(c, mono, Vector2(body.end.x + 6, body.position.y + 11), "a column", 16, Palette.DARK_KEYWORD)
	for row: int in lit:
		c.draw_rect(Rect2(body.position.x, body.position.y + 2 + (row + 1) * 11, body.size.x, 11), Color(Palette.EMBER, 0.36))


## A query typed on a page of the notebook, and the rows it picks out.
func _draw_query(c: Control) -> void:
	var mono := Palette.mono()
	var page := Rect2(6, 24, 178, 96)
	c.draw_rect(page.grow(2), Palette.NOTE_COVER)
	c.draw_rect(page, Palette.NOTE)
	c.draw_rect(Rect2(page.position, Vector2(page.size.x, 13)), Palette.NOTE_COVER)
	Fit.begin(page, "the prologue's notebook page")
	Fit.text(c, mono, page.position + Vector2(6, 10), "the question, in SQL", 16, Palette.CREAM)
	var typed := clampi(int((_t - 0.8) * 24.0), 0, DEMO.length())
	var y := page.position.y + 30
	var left := typed
	for line in DEMO.split("\n"):
		var shown := line.substr(0, clampi(left, 0, line.length()))
		left -= line.length() + 1
		var w := SqlDraw.draw_line(c, Vector2(page.position.x + 8, y), shown)
		if left < 0 and left >= -line.length() - 1 and int(_clock * 4.0) % 2 == 0 and typed < DEMO.length():
			c.draw_rect(Rect2(page.position.x + 8 + w, y - 9, 5, 10), Palette.NOTE_INK)
		y += 14
	var finished := typed >= DEMO.length()
	var lit: Array = []
	if finished and demo.get("ok", false):
		# The rows the engine really returned.
		for hit: Array in demo.rows:
			for i in (_guests.rows as Array).size():
				if str(_guests.rows[i][0]) == str(hit[0]):
					lit.append(i)
		var said := "Doris: \"%d rows.\"" % (demo.rows as Array).size()
		Fit.text(c, mono, Vector2(page.position.x + 8, page.end.y - 10), said, 16, Palette.EMBER.darkened(0.3))
	Fit.end()
	if finished and demo.get("ok", false):
		Fit.text(c, mono, Vector2(page.position.x, page.end.y + 16), "'21:00' is nine at night.", 16, Palette.STEEL)
		Fit.text(c, mono, Vector2(page.position.x, page.end.y + 28), "Three guests came later.", 16, Palette.STEEL)
	_draw_table(c, Rect2(192, 8, 284, 180), false, lit)


## The five folders, fanned on the desk.
func _draw_files(c: Control) -> void:
	var mono := Palette.mono()
	var titles := Palette.titles()
	for id in range(1, Story.count() + 1):
		var shown := clampf((_t - (id - 1) * 0.3) * 4.0, 0.0, 1.0)
		if shown <= 0.0:
			continue
		var at := Vector2(34 + (id - 1) * 84, 46 + (id % 2) * 22 + (1.0 - shown) * 30)
		var tab := Rect2(at, Vector2(78, 104))
		var paper := Color(0.86, 0.74, 0.5, shown)
		c.draw_rect(Rect2(tab.position + Vector2(3, 3), tab.size), Color(0, 0, 0, 0.4 * shown))
		c.draw_rect(Rect2(tab.position + Vector2(6, -6), Vector2(34, 7)), paper.darkened(0.08))
		c.draw_rect(tab, paper)
		# The folder and the tab that sticks up from it.
		Fit.begin(tab.grow_individual(0, 10, 0, 0), "a case folder in the prologue")
		Fit.text(c, mono, tab.position + Vector2(8, 0), "CASE %d" % id, 16, Color(Palette.INK.lightened(0.25), shown))
		var y := tab.position.y + 22
		for line in SqlDraw.wrap(str(Story.case(id).get("title", "")), 66, titles, 13):
			Fit.text(c, titles, Vector2(tab.position.x + 6, y), line, 13, Color(Palette.INK, shown))
			y += 15
		y = tab.position.y + 62
		for line in SqlDraw.wrap(str(Story.case(id).get("lesson", "")), 68):
			Fit.text(c, mono, Vector2(tab.position.x + 6, y), line, 16, Color(Palette.SYN_KEYWORD, shown))
			y += 11
		Fit.end()
