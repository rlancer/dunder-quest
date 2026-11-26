class_name Intro
extends Control

## The prologue, before the first shift: a sandwich shop that ran on
## shouting, the chef who came home with a system, and the woman on the pass
## who had been typing the orders up all along. It is also the game's
## answer to "what is the shell?" for someone who has never seen one: under
## the story runs the word for what was just said.
##
## The lines that type themselves here are run by the game's own shell
## (sh/shell.gd), so what they print is what the real thing prints. Enter
## (or any key, or a tap) turns the page, the left arrow (or a tap on the
## left edge) turns back one, Skip (or Esc) goes straight on, and left
## alone it plays itself.

const PANEL := Rect2(0, 198, 480, 72)
const SHEET_X := 244.0
## Letters a second.
const TYPE := 40.0
## Seconds a finished page waits before it turns by itself.
const AFTER := 1.4
## Seconds between one chip landing on a demonstration line and the next.
const CHIP_EVERY := 0.55

## The shift to open afterwards; 0 goes back to the title.
static var then: int = 1

## The bot sets this and turns the pages itself.
var driven: bool = false

var _beats: Array = []
var _index: int = -1
var _t: float = 0.0
var _voice: float = 0.0
var _black: float = 1.0
var _leaving: bool = false
var _old: Sprite2D
var _new: Sprite2D
var _canvas: Control
var _skip: Button
var _music: String = ""
var _sounded: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var audio := StageAudio.new()
	audio.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(audio)
	_old = Backdrop.sprite("")
	add_child(_old)
	_new = Backdrop.sprite("")
	add_child(_new)
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
	_beats = script_beats()
	_go(0)


## The prologue's pages: where it's set, who's there, the line (told by the
## narrator unless `who` says it), the shell word for it (`term`), and a
## terminal that types a line by itself (`demo`: its chips, when the first
## one lands, and the kitchen's one file).
static func script_beats() -> Array:
	var counts := ["No", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten"]
	var count: String = counts[Story.count()] if Story.count() < counts.size() else str(Story.count())
	var orders := {"orders.txt": ["beef dip hot", "turkey club", "beef combo", "veggie melt"]}
	return [
		{"bg": "city", "music": "intro",
			"text": "A city by a cold lake. Under the train tracks sits the Standard Inn: forty years of beef sandwiches, and one gas bill nobody has opened."},
		{"bg": "kitchen", "music": "service", "sound": "printer", "faces": ["awk"],
			"text": "It was Uncle Awk's kitchen. Orders were shouted. Tickets were lost. Nothing had been written down since 1987."},
		{"bg": "kitchen", "who": "awk",
			"text": "\"Two beef! No, three! Who's got table six? WHO HAS TABLE SIX?\""},
		{"bg": "title", "music": "", "sound": "sting", "faces": ["chef"],
			"text": "Then Ash Bourne came home, out of the finest kitchen in the country, with a roll of green tape, a marker, and a system."},
		{"bg": "pass", "music": "intro", "who": "chef", "faces": ["chef"],
			"text": "\"Every station does one thing. It does it well. Then it passes it down the line.\"",
			"term": "a command is a small program that does one job"},
		{"bg": "pass", "who": "shell", "faces": ["shell", "chef"],
			"demo": {"line": ["cat", "orders.txt"], "files": orders, "at": 3.2},
			"text": "\"I'm Shell. I run the pass. The orders are in a file, and a file is just lines of text. cat reads one out.\"",
			"term": "a command, then the file to work on"},
		{"bg": "pass", "who": "shell", "faces": ["shell"],
			"demo": {"line": ["grep", "beef", "orders.txt"], "files": orders, "at": 1.6},
			"text": "\"Don't want all of it? grep keeps only the lines with your word on them.\"",
			"term": "grep beef: keep the lines that say beef"},
		{"bg": "pass", "who": "shell", "faces": ["shell"],
			"demo": {"line": ["grep", "beef", "orders.txt", "|", "wc", "-l"], "files": orders, "at": 1.2},
			"text": "\"And that bar is the pass. What one command plates, the next one picks up. This one counts.\"",
			"term": "|  the pipe: one command's output is the next one's input"},
		{"bg": "walkin",
			"text": "That is all the shell is: small tools, and a line to pass things down. People who run computers have cooked this way since the nineteen-seventies.",
			"term": "the shell: where you type commands. This one is called bash"},
		{"bg": "dining", "music": "critic", "sound": "sting", "faces": ["root"],
			"text": "And on Friday, Regina Root of the Lakeside Ledger has a table for one. What Root asks for, Root gets."},
		{"bg": "title", "music": "title", "faces": ["shell", "chef"], "who": "shell",
			"text": "\"%s shifts, Chef. Read the ticket. Build the line. Then fire.\"" % count,
			"term": "put chips on the line · watch the pass · Fire!"},
	]


## Every page as it's read aloud, for tools/voice.py: {"who", "text", "say"?}.
static func lines() -> Array:
	var out: Array = []
	for beat: Dictionary in script_beats():
		var line := {"who": str(beat.get("who", "narrator")), "text": str(beat.text)}
		if beat.has("say"):
			line["say"] = beat.say
		out.append(line)
	return out


func beat_count() -> int:
	return _beats.size()


func page() -> int:
	return _index


func beat() -> Dictionary:
	return _beats[_index] if _index >= 0 and _index < _beats.size() else {}


## The chips on a page's line by now.
func demo_tokens() -> Array:
	var demo: Dictionary = beat().get("demo", {})
	var line: Array = demo.get("line", [])
	var landed := int(floor((_t - float(demo.get("at", 0.0))) / CHIP_EVERY)) + 1
	return line.slice(0, clampi(landed, 0, line.size()))


func _go(index: int) -> void:
	if index >= _beats.size():
		_finish()
		return
	_index = maxi(index, 0)
	_t = 0.0
	_sounded = false
	var b := beat()
	# The picture changes with a short fade from the one before.
	var path := "res://assets/backgrounds/%s.png" % b.get("bg", "kitchen")
	if ResourceLoader.exists(path):
		var texture := load(path) as Texture2D
		if texture != _new.texture:
			_old.texture = _new.texture
			_old.scale = _new.scale
			_new.texture = texture
			_new.scale = Vector2(480, 270) / texture.get_size()
			_new.modulate.a = 0.0 if _old.texture != null and not driven else 1.0
	if b.has("music") and str(b.music) != _music:
		_music = str(b.music)
		if _music == "":
			MusicDirector.stop()
		else:
			Sfx.music(_music)
	var line := {"who": str(b.get("who", "narrator")), "text": str(b.text)}
	if b.has("say"):
		line["say"] = b.say
	_voice = Voice.say(line)


func _typed() -> bool:
	return _t * TYPE >= str(beat().get("text", "")).length()


## When the page has said and shown everything it has.
func _done_at() -> float:
	var b := beat()
	var told := maxf(str(b.get("text", "")).length() / TYPE, _voice)
	var demo: Dictionary = b.get("demo", {})
	var shown := float(demo.get("at", 0.0)) + (demo.get("line", []) as Array).size() * CHIP_EVERY + 1.6 if not demo.is_empty() else 0.0
	return maxf(told, shown)


func _process(delta: float) -> void:
	_t += delta
	_black = maxf(_black - delta * 2.0, 0.0) if not _leaving else minf(_black + delta * 3.0, 1.0)
	_new.modulate.a = minf(_new.modulate.a + delta * 2.5, 1.0)
	var b := beat()
	if not _sounded and b.has("sound"):
		_sounded = true
		Sfx.play(self, str(b.sound))
	if not driven and not _leaving and _t > _done_at() + AFTER:
		_go(_index + 1)
	_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if _leaving or driven:
		return
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		_finish()
		return
	var forward := false
	var back := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _skip.get_global_rect().has_point(event.position):
			return
		back = event.position.x < 60.0
		forward = not back
	elif event.is_action_pressed(&"move_left"):
		back = true
	elif event is InputEventKey and event.pressed and not event.echo:
		forward = true
	elif event is InputEventJoypadButton and event.pressed:
		forward = true
	if back:
		get_viewport().set_input_as_handled()
		Voice.hush()
		_go(_index - 1)
	elif forward:
		get_viewport().set_input_as_handled()
		# The first press finishes the typing; the next turns the page.
		if not _typed():
			_t = maxf(_t, str(beat().get("text", "")).length() / TYPE + 0.01)
		else:
			Voice.hush()
			_go(_index + 1)


func _finish() -> void:
	if _leaving:
		return
	_leaving = true
	Voice.hush()
	var tree := get_tree()
	var go := func() -> void:
		if then > 0:
			Main.play_shift(tree, then)
		else:
			tree.change_scene_to_file(Main.TITLE)
	if driven:
		go.call()
	else:
		tree.create_timer(0.4).timeout.connect(go)


# --- Drawing -----------------------------------------------------------------

func _draw_page() -> void:
	var b := beat()
	if b.is_empty():
		return
	Fit.frame(_canvas)
	var mono := Palette.mono()
	var who := str(b.get("who", "narrator"))
	# Whoever's on stage: the first face on the left, the second on the right.
	var faces: Array = (b.get("faces", []) as Array).duplicate()
	if who != "narrator" and not faces.has(who):
		faces.push_front(who)
	# (A page with a terminal on it has room for one.)
	for i in mini(faces.size(), 1 if b.has("demo") else 2):
		var face := Ui.portrait(str(faces[i]))
		if face == null:
			continue
		var talking := str(faces[i]) == who and not _typed()
		var bob := roundf(sin(_t * 9.0) * 1.5) if talking else 0.0
		var slide := minf(_t / 0.25, 1.0)
		var x := 14.0 - (1.0 - slide) * 40.0 if i == 0 else 370.0 + (1.0 - slide) * 40.0
		var at := Vector2(x, PANEL.position.y - 94.0 + bob)
		_canvas.draw_texture_rect(face, Rect2(at + Vector2(3, 3), Vector2(96, 96)), false, Color(0, 0, 0, 0.35 * slide))
		_canvas.draw_texture_rect(face, Rect2(at, Vector2(96, 96)), false, Color(1, 1, 1, slide))
	if b.has("demo"):
		_draw_demo(b.demo)
	# The story, and the shell word for it.
	_canvas.draw_rect(PANEL, Color(Palette.STEEL_DARK, 0.93))
	_canvas.draw_rect(Rect2(0, PANEL.position.y, 480, 2), Palette.LAMP)
	Fit.cover(PANEL)
	Fit.begin(PANEL, "the prologue's story")
	var text := str(b.text)
	if who != "narrator":
		var name := Story.name_of(who).to_upper()
		Fit.text(_canvas, Palette.pixel(), Vector2(14, PANEL.position.y + 13), name, 10, Palette.LAMP_LIGHT)
	Fit.para(_canvas, mono, Vector2(14, PANEL.position.y + (27 if who != "narrator" else 18)), text, 16, Palette.CREAM if who != "narrator" else Palette.PAPER, 452, 13, int(_t * TYPE))
	if b.has("term") and (Fit.audit or _typed()):
		var term := str(b.term)
		var fade := 1.0 if Fit.audit else clampf((_t - text.length() / TYPE) / 0.4, 0.0, 1.0)
		Ui.star(_canvas, Vector2(20, PANEL.end.y - 12), 5, Color(Palette.LAMP, fade))
		Fit.text(_canvas, mono, Vector2(30, PANEL.end.y - 8), term, 16, Color(Palette.LAMP_LIGHT, fade))
	Fit.end()
	# Which page this is.
	for i in _beats.size():
		_canvas.draw_rect(Rect2(472 - (_beats.size() - i) * 6, 8, 4, 4), Palette.LAMP_LIGHT if i == _index else Color(Palette.PAPER, 0.4))
	if _black > 0.0:
		_canvas.draw_rect(Rect2(0, 0, 480, 270), Color(0, 0, 0, _black))


## The kitchen's file, and under it a terminal where a line types itself
## and prints what the shell makes of it.
func _draw_demo(demo: Dictionary) -> void:
	var files: Dictionary = demo.files
	var name := str(files.keys()[0])
	var lines: Array = files[name]
	var sheet := Rect2(SHEET_X, 26, 224, lines.size() * Ui.ROW + 20)
	_canvas.draw_rect(sheet.grow(2), Color(0, 0, 0, 0.35))
	Ui.paper(_canvas, sheet)
	Fit.begin(sheet, "the prologue's file")
	var strip := Rect2(sheet.position.x + 1, sheet.position.y + 1, sheet.size.x - 2, 12)
	_canvas.draw_rect(strip, Palette.GREEN)
	Fit.text(_canvas, Palette.pixel(), Vector2(strip.position.x + 4, strip.end.y - 3), name, 10, Palette.CREAM)
	Ui.listing(_canvas, sheet.position + Vector2(8, 25), lines, sheet.size.x - 14, Palette.INK, Palette.DIM)
	Fit.end()
	var tokens := demo_tokens() if not Fit.audit else (demo.line as Array)
	var typed := " ".join(PackedStringArray(tokens))
	var whole := tokens.size() == (demo.line as Array).size()
	var ran := Shell.run(typed, Story.files(files)) if whole else {}
	var rows: Array = Judge.lines(str(ran.get("out", "")))
	var glass := Rect2(SHEET_X, sheet.end.y + 4, 224, (rows.size() + 1) * Ui.ROW + 9)
	_canvas.draw_rect(glass.grow(2), Color(0, 0, 0, 0.35))
	Ui.screen(_canvas, glass)
	Fit.begin(glass, "the prologue's terminal")
	var at := glass.position + Vector2(6, 14)
	Fit.text(_canvas, Palette.mono(), at, "$", 16, Palette.GREEN_LIGHT)
	var wide := Ui.code(_canvas, at + Vector2(12, 0), typed, true) if typed != "" else 0.0
	if not whole and Fit.blink(fmod(_t, 0.7) < 0.45):
		_canvas.draw_rect(Rect2(at.x + 14 + wide, at.y - 10, 6, 12), Palette.GREEN_LIGHT)
	for i in rows.size():
		Fit.text(_canvas, Palette.mono(), at + Vector2(0, (i + 1) * Ui.ROW), str(rows[i]), 16, Palette.TERM_TEXT)
	Fit.end()
