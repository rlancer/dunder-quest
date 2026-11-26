class_name Intro
extends Control

## The prologue, before the first episode: four friends on the Upper West
## Side, a comedian who notices things, a pilot due Friday, and a script
## nobody is allowed to change. It is also the game's answer to "what is
## the event loop?" for someone who has never written JavaScript: under the
## story runs the word for what was just said.
##
## The scripts that type themselves here are played by the game's own event
## loop (loop/engine.gd), so what they log is what JavaScript logs. Enter
## (or any key, or a tap) turns the page, the left arrow (or a tap on the
## left edge) turns back one, Skip (or Esc) goes straight on, and left alone
## it plays itself.

const PANEL := Rect2(0, 198, 480, 72)
const SHEET_X := 236.0
## Letters a second.
const TYPE := 40.0
## Seconds a finished page waits before it turns by itself.
const AFTER := 1.4
## Seconds between one line of a demonstration landing and the next.
const LINE_EVERY := 0.5

## The episode to open afterwards; 0 goes back to the title.
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
## narrator unless `who` says it), the word for it (`term`), and a script
## that types itself and plays (`demo`: its statements, when the first line
## lands).
static func script_beats() -> Array:
	var counts := ["No", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten"]
	var count: String = counts[Story.count()] if Story.count() < counts.size() else str(Story.count())
	return [
		{"bg": "street", "music": "intro",
			"text": "New York. The Upper West Side. Four friends, one coffee shop, and absolutely nothing going on."},
		{"bg": "apartment", "faces": ["stu"],
			"text": "Stu Lerner is a stand-up comedian. He notices things. Small things. Things nobody else bothers to notice."},
		{"bg": "apartment", "faces": ["dana", "zelnick"], "sound": "door",
			"text": "Dana Wexler, his ex, still his friend, mostly out of spite. Zelnick, from across the hall, who has never once knocked."},
		{"bg": "club", "who": "stu", "faces": ["stu"],
			"demo": {"program": [{"log": "first"}, {"log": "second"}], "at": 2.6},
			"text": "\"You ever notice JavaScript only does one thing at a time? One! I've dated people like that.\"",
			"term": "a script runs one line at a time, top to bottom"},
		{"bg": "club", "who": "stu", "faces": ["stu"],
			"demo": {"program": [{"timeout": 0, "body": [{"log": "later"}]}, {"log": "now"}], "at": 1.6},
			"text": "\"So how does it wait for anything? It doesn't! It hands the job a function to call back later, and keeps going.\"",
			"term": "a callback: a function handed over, to be called later"},
		{"bg": "diner", "who": "lenny", "faces": ["lenny", "stu"],
			"text": "\"Later? When's later? Who decides later? I need a time!\"",
			"say": "[panicking] Later? When's later? Who decides later? I need a time!"},
		{"bg": "diner", "who": "stu", "faces": ["stu", "lenny"],
			"text": "\"Later is when nothing else is running. Nothing! The whole thing runs on nothing.\"",
			"term": "the event loop: when nothing's running, it runs what's waiting"},
		{"bg": "network", "music": "network", "sound": "sting", "faces": ["pratt"],
			"text": "And the network wants their pilot by Friday. Mr. Pratt, who runs the network, has never been seen to laugh."},
		{"bg": "apartment", "music": "apartment", "who": "lenny", "faces": ["lenny"],
			"text": "\"And legal locked the pages! We can't move a single line!\"",
			"say": "[panicking] And legal locked the pages! We can't move a single line!"},
		{"bg": "title", "music": "title", "who": "stu", "faces": ["stu", "lenny"],
			"text": "\"Then we don't move them. We cue them. %s episodes, kid. Read the table read, cue the lines, roll tape.\"" % count,
			"term": "put cue cards on lines · roll tape · match the table read"},
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


## How many lines of a page's script have landed by now.
func demo_lines() -> int:
	var demo: Dictionary = beat().get("demo", {})
	if demo.is_empty():
		return 0
	var total := Loop.lines(demo.program, false).size()
	var landed := int(floor((_t - float(demo.get("at", 0.0))) / LINE_EVERY)) + 1
	return clampi(landed, 0, total)


func _go(index: int) -> void:
	if index >= _beats.size():
		_finish()
		return
	_index = maxi(index, 0)
	_t = 0.0
	_sounded = false
	var b := beat()
	# The picture changes with a short fade from the one before.
	var path := "res://assets/backgrounds/%s.png" % b.get("bg", "apartment")
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
	var shown := float(demo.get("at", 0.0)) + Loop.lines(demo.program, false).size() * LINE_EVERY + 2.4 if not demo.is_empty() else 0.0
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
			Main.play_episode(tree, then)
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
	# The story, and the word for it.
	_canvas.draw_rect(PANEL, Color(Palette.PLUM_DARK, 0.93))
	_canvas.draw_rect(Rect2(0, PANEL.position.y, 480, 2), Palette.MUSTARD)
	Fit.cover(PANEL)
	Fit.begin(PANEL, "the prologue's story")
	var text := str(b.text)
	if who != "narrator":
		var name := Story.name_of(who).to_upper()
		Fit.text(_canvas, Palette.pixel(), Vector2(14, PANEL.position.y + 13), name, 10, Palette.MUSTARD_LIGHT)
	Fit.para(_canvas, mono, Vector2(14, PANEL.position.y + (27 if who != "narrator" else 18)), text, 16, Palette.CREAM if who != "narrator" else Palette.PAPER, 452, 13, int(_t * TYPE))
	if b.has("term") and (Fit.audit or _typed()):
		var term := str(b.term)
		var fade := 1.0 if Fit.audit else clampf((_t - text.length() / TYPE) / 0.4, 0.0, 1.0)
		Ui.star(_canvas, Vector2(20, PANEL.end.y - 12), 5, Color(Palette.MUSTARD, fade))
		Fit.text(_canvas, mono, Vector2(30, PANEL.end.y - 8), term, 16, Color(Palette.MUSTARD_LIGHT, fade))
	Fit.end()
	# Which page this is.
	for i in _beats.size():
		_canvas.draw_rect(Rect2(472 - (_beats.size() - i) * 6, 8, 4, 4), Palette.MUSTARD_LIGHT if i == _index else Color(Palette.PAPER, 0.4))
	if _black > 0.0:
		_canvas.draw_rect(Rect2(0, 0, 480, 270), Color(0, 0, 0, _black))


## The page's script on a sheet, a line landing at a time, and under it
## what it logs once it's all there.
func _draw_demo(demo: Dictionary) -> void:
	var code := Loop.lines(demo.program, false)
	var shown := demo_lines() if not Fit.audit else code.size()
	var sheet := Rect2(SHEET_X, 24, 232, code.size() * Ui.ROW + 22)
	_canvas.draw_rect(sheet.grow(2), Color(0, 0, 0, 0.35))
	Ui.paper(_canvas, sheet)
	Fit.begin(sheet, "the prologue's script")
	Ui.head(_canvas, sheet, "SCRIPT.JS", Palette.BRICK)
	for i in shown:
		var line: Dictionary = code[i]
		Ui.code(_canvas, Vector2(sheet.position.x + 8 + int(line.indent) * 9, sheet.position.y + 25 + i * Ui.ROW), str(line.text), false)
	if shown < code.size() and Fit.blink(fmod(_t, 0.7) < 0.45):
		_canvas.draw_rect(Rect2(sheet.position.x + 8, sheet.position.y + 16 + shown * Ui.ROW, 6, 11), Palette.BRICK)
	Fit.end()
	var whole := shown == code.size()
	var out: Array = Loop.run(demo.program).out if whole else []
	var glass := Rect2(SHEET_X, sheet.end.y + 4, 232, (maxi(out.size(), 1) + 1) * Ui.ROW + 8)
	_canvas.draw_rect(glass.grow(2), Color(0, 0, 0, 0.35))
	Ui.glass(_canvas, glass)
	Fit.begin(glass, "what the prologue's script logs")
	Fit.text(_canvas, Palette.pixel(), Vector2(glass.position.x + 6, glass.position.y + 11), "LOGS", 10, Palette.GLASS_DIM)
	for i in out.size():
		Fit.text(_canvas, Palette.mono(), Vector2(glass.position.x + 6, glass.position.y + 13 + (i + 1) * Ui.ROW), str(out[i]), 16, Palette.GLASS_TEXT)
	Fit.end()
