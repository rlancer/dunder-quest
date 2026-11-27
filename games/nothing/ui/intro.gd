class_name Intro
extends Control

## The prologue, before the first episode: four friends on the Upper West
## Side, a comedian who notices things, and a pilot due Friday. It is also
## the game's answer to "what is HTTP?" for someone who has never looked
## under a website: under the story runs the word for what was just said.
##
## The requests that write themselves out here are answered by the game's
## own HTTP (http/http.gd), so what comes back is what a real server sends.
## Enter (or any key, or a tap) turns the page, the left arrow (or a tap on
## the left edge) turns back one, Skip (or Esc) goes straight on, and left
## alone it plays itself.

const PANEL := Rect2(0, 198, 480, 72)
const SHEET_X := 236.0
## Letters a second.
const TYPE := 40.0
## Seconds a finished page waits before it turns by itself.
const AFTER := 1.4
## Seconds between one line of a demonstration landing and the next.
const LINE_EVERY := 0.45

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
## narrator unless `who` says it), the word for it (`term`), and a request
## that writes itself out and is answered (`demo`: the counter, its data,
## the cards, and when the first line lands).
static func script_beats() -> Array:
	var counts := ["No", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten"]
	var count: String = counts[Story.count()] if Story.count() < counts.size() else str(Story.count())
	var diner := {"menu": ["coffee", "toast", "tuna on rye"], "orders": [{"id": 7, "item": "toast", "table": 4}]}
	return [
		{"bg": "street", "music": "intro",
			"text": "New York. The Upper West Side. Four friends, one coffee shop, nothing to do, and all day to do it in."},
		{"bg": "apartment", "faces": ["stu"],
			"text": "Stu Lerner is a stand-up comedian. He notices things. He once broke up with a woman because she said \"gif\" with a J."},
		{"bg": "apartment", "faces": ["dana", "zelnick"], "sound": "door",
			"text": "Dana Wexler, his ex, still his friend, mostly out of spite. Zelnick, from across the hall, who has never once knocked, and twice come in through the window."},
		{"bg": "club", "who": "stu", "faces": ["stu"],
			"demo": {"counter": "vics", "data": diner, "request": ["GET", "/menu"], "at": 2.4},
			"text": "\"You ever notice the whole internet is just people asking for things? Give me the menu. Give me the weather. Nobody goes on to offer.\"",
			"term": "a request: a method and a path. GET means give me"},
		{"bg": "club", "who": "stu", "faces": ["stu"],
			"demo": {"counter": "vics", "data": diner, "request": ["GET", "/orders/9"], "at": 1.4},
			"text": "\"And it always answers with a number. 200, it's OK. 404, there's nothing there. Like my refrigerator.\"",
			"term": "a response: a status code, headers, then the body"},
		{"bg": "diner", "who": "lenny", "faces": ["lenny", "stu"],
			"text": "\"A number? I don't want a number! I want the soup!\"",
			"say": "[exasperated] A number? I don't want a number! I want the soup!"},
		{"bg": "diner", "who": "stu", "faces": ["stu"],
			"demo": {"counter": "vics", "data": diner, "request": ["POST", "/orders", "Content-Type: application/json", "{\"item\":\"soup\",\"table\":4}"], "at": 1.4},
			"text": "\"Then you POST an order, and say what it is. 201, Created. That's HTTP. Every app on your phone is this, with a logo on it.\"",
			"term": "HTTP: how every website and app asks a server for things"},
		{"bg": "network", "music": "network", "sound": "sting", "faces": ["pratt"],
			"text": "On Friday, Stu and Lenny pitch the network a show where four friends run errands and nothing happens. Mr. Pratt, who runs it, has never laughed. Doctors have looked into it."},
		{"bg": "apartment", "music": "apartment", "who": "lenny", "faces": ["lenny"],
			"text": "\"We need material! Go run errands! Have petty arguments with strangers! I'll be here. Supervising.\"",
			"say": "[excited] We need material! Go run errands! Have petty arguments with strangers! [settling into the couch] I'll be here. Supervising."},
		{"bg": "title", "music": "title", "who": "stu", "faces": ["stu", "lenny"],
			"text": "\"%s counters, kid. Read what the scene wants. Make the slip. Send it.\"" % count,
			"term": "put cards on the slip · send it · get what the scene wants"},
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


## A page's demonstration: its request's lines and the response's.
static func demo_take(demo: Dictionary) -> Dictionary:
	return Judge.judge({"counter": demo.counter, "data": demo.data, "goal": {"status": 0}}, demo.request)


## How many lines of a page's demonstration (the request's, then the
## response's) have landed by now.
func demo_lines() -> int:
	var demo: Dictionary = beat().get("demo", {})
	if demo.is_empty():
		return 0
	var take := demo_take(demo)
	var total: int = (take.request as Array).size() + (take.get("lines", []) as Array).size()
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
	var shown := float(demo.get("at", 0.0)) + 8 * LINE_EVERY + 1.6 if not demo.is_empty() else 0.0
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


## The page's request on a slip, a line landing at a time, and under it the
## response as it comes back.
func _draw_demo(demo: Dictionary) -> void:
	var take := demo_take(demo)
	var asked: Array = take.request
	var answered: Array = take.get("lines", [])
	var shown := demo_lines() if not Fit.audit else asked.size() + answered.size()
	var sheet := Rect2(SHEET_X, 22, 232, _rows(asked).size() * Ui.ROW + 22)
	_canvas.draw_rect(sheet.grow(2), Color(0, 0, 0, 0.35))
	Ui.paper(_canvas, sheet)
	Fit.begin(sheet, "the prologue's request")
	Ui.head(_canvas, sheet, "REQUEST", Palette.BRICK)
	var rows := _rows(asked.slice(0, mini(shown, asked.size())))
	for i in rows.size():
		Fit.text(_canvas, Palette.mono(), Vector2(sheet.position.x + 6, sheet.position.y + 25 + i * Ui.ROW), str(rows[i]), 16, Palette.BRICK if i == 0 else Palette.INK)
	Fit.end()
	if shown <= asked.size():
		return
	var back := _rows(answered.slice(0, shown - asked.size()))
	var glass := Rect2(SHEET_X, sheet.end.y + 4, 232, _rows(answered).size() * Ui.ROW + 22)
	_canvas.draw_rect(glass.grow(2), Color(0, 0, 0, 0.35))
	Ui.glass(_canvas, glass)
	Fit.begin(glass, "the prologue's response")
	Ui.head(_canvas, glass, "RESPONSE", Palette.TEAL)
	for i in back.size():
		Fit.text(_canvas, Palette.mono(), Vector2(glass.position.x + 6, glass.position.y + 25 + i * Ui.ROW), str(back[i]), 16, Palette.MUSTARD_LIGHT if i == 0 else Palette.GLASS_TEXT)
	Fit.end()


## Lines broken to fit the demonstration's width.
func _rows(lines: Array) -> Array:
	var font := Palette.mono()
	var out: Array = []
	for line: String in lines:
		var rest := line
		if rest == "":
			out.append("")
		while rest != "":
			var cut := rest.length()
			while cut > 1 and Fit.width(font, rest.left(cut), 16) > 220:
				cut -= 1
			out.append(rest.left(cut))
			rest = rest.substr(cut)
	return out
