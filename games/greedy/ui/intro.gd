class_name Intro
extends Control

## The prologue, before the first job: a town where everybody has the same
## name, the outlaw who takes everything on the line, and a sheriff whose
## only weapon is a wanted poster. It is also the game's answer to "what is
## a regular expression?" for someone who has never seen one: the story is
## told aloud (core/voice.gd), and under it runs the regex word for what
## was just said.
##
## The posters that write themselves here are run by the game's own engine
## (regex/rx.gd), so the lines that light up are the lines a real regex
## would match. Enter (or any key, or a tap) turns the page, the left arrow
## (or a tap on the left edge) turns back one, Skip (or Esc) goes straight
## on, and left alone it plays itself.

const PANEL := Rect2(0, 198, 480, 72)
const SHEET_X := 244.0
## Letters a second.
const TYPE := 40.0
## Seconds a finished page waits before it turns by itself.
const AFTER := 1.4
## Seconds between one chip landing on a demonstration poster and the next.
const CHIP_EVERY := 0.55

## The job to open afterwards; 0 goes back to the title.
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
## old-timer unless `who` says it), the regex word for it (`term`), and a
## poster that writes itself (`demo`: its chips, the lineup, when the first
## chip lands, and a line to point at).
static func script_beats() -> Array:
	var counts := ["No", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten"]
	var count: String = counts[Story.count()] if Story.count() < counts.size() else str(Story.count())
	var slims := ["Slim Hobson", "Howard Hobson", "Old Slim", "Slimy Pete Hobson"]
	return [
		{"bg": "band", "music": "intro",
			"text": "The West, eighteen seventy-something. That's the band. They go wherever the story goes, and nobody is sure who's paying them."},
		{"bg": "title",
			"text": "Out past the edge of the map sits Backslash Ridge: a peaceable little town where every last soul is named Hobson.",
			"term": "a line of text, like a name, is called a string"},
		{"bg": "street", "faces": ["mayor"],
			"demo": {"pattern": [], "lines": ["Howard Hobson", "Olsen Hobson", "Doc Hobson", "The Widow Hobson", "Hobson Hobson"]},
			"text": "Howard Hobson. Olsen Hobson. Doc Hobson. The Widow Hobson. It kept the stationery simple, and nobody minded."},
		{"bg": "saloon", "music": "showdown", "sound": "sting", "faces": ["dot"],
			"text": "Then Dot Starr rode in. Dot, as in anything at all. Star, as in as much of it as she pleases."},
		{"bg": "saloon", "who": "dot",
			"text": "\"I'll take the bank. And the feed store. And everything else on the line.\""},
		{"bg": "street", "music": "title", "faces": ["mayor"],
			"text": "The town wired the Governor for a sheriff, and hired a band for the welcome."},
		{"bg": "street", "music": "", "sound": "scratch", "faces": ["mayor", "sheriff"],
			"text": "The Governor sent the only one he had left. The band stopped playing. They had been expecting somebody louder."},
		{"bg": "street", "music": "intro", "faces": ["sheriff"],
			"demo": {"pattern": ["Slim"], "lines": slims, "at": 6.5},
			"text": "Because in Backslash Ridge, nobody shoots anybody. The law is a wanted poster, and a poster catches exactly what is written on it.",
			"term": "what's written on the poster is a pattern"},
		{"bg": "street", "who": "kid",
			"demo": {"pattern": ["Slim"], "lines": slims, "at": 0.0, "mark": 3},
			"text": "\"Write Slim, and it hauls in every Slim in the county. Including Slimy Pete, the preacher.\"",
			"term": "a pattern matches anywhere it fits, letter for letter"},
		{"bg": "street", "who": "kid",
			"demo": {"pattern": ["H", ".", "nk"], "lines": ["Hank Hobson", "Honk Hobson", "Hunk Hobson", "Howard Hobson"], "at": 2.6},
			"text": "\"So you learn to say more with less. A dot is any one character. A star is as many as you like.\"",
			"term": ".  any one character      *  as many as you like"},
		{"bg": "sunset",
			"text": "That is all a regular expression is: a wanted poster for text. Folks who write code use them to find text, check it, and pull it apart.",
			"term": "regular expression: regex, to its friends"},
		{"bg": "title", "music": "title", "faces": ["kid", "sheriff"], "who": "kid",
			"text": "\"%s jobs, Sheriff. Read the lineup. Write the poster. Then draw.\"" % count,
			"term": "put chips on the poster · watch the lines light up · Draw!"},
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


## The chips on a page's poster by now.
func demo_tokens() -> Array:
	var demo: Dictionary = beat().get("demo", {})
	var pattern: Array = demo.get("pattern", [])
	var landed := int(floor((_t - float(demo.get("at", 0.0))) / CHIP_EVERY)) + 1
	return pattern.slice(0, clampi(landed, 0, pattern.size()))


func _go(index: int) -> void:
	if index >= _beats.size():
		_finish()
		return
	_index = maxi(index, 0)
	_t = 0.0
	_sounded = false
	var b := beat()
	# The picture changes with a short fade from the one before.
	var path := "res://assets/backgrounds/%s.png" % b.get("bg", "street")
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
	var shown := float(demo.get("at", 0.0)) + (demo.get("pattern", []) as Array).size() * CHIP_EVERY + 1.2 if not demo.is_empty() else 0.0
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
			Main.play_job(tree, then)
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
	for i in mini(faces.size(), 2):
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
	# The story, and the regex word for it.
	_canvas.draw_rect(PANEL, Color(Palette.WOOD_DARK, 0.93))
	_canvas.draw_rect(Rect2(0, PANEL.position.y, 480, 2), Palette.GOLD)
	Fit.cover(PANEL)
	Fit.begin(PANEL, "the prologue's story")
	var text := str(b.text)
	if who != "narrator":
		var name := Story.name_of(who).to_upper()
		Fit.text(_canvas, Palette.pixel(), Vector2(14, PANEL.position.y + 13), name, 10, Palette.GOLD_LIGHT)
	Fit.para(_canvas, mono, Vector2(14, PANEL.position.y + (27 if who != "narrator" else 18)), text, 16, Palette.CREAM if who != "narrator" else Palette.PAPER, 452, 13, int(_t * TYPE))
	if b.has("term") and (Fit.audit or _typed()):
		var term := str(b.term)
		var fade := 1.0 if Fit.audit else clampf((_t - text.length() / TYPE) / 0.4, 0.0, 1.0)
		Ui.star(_canvas, Vector2(20, PANEL.end.y - 12), 5, Color(Palette.GOLD, fade))
		Fit.text(_canvas, mono, Vector2(30, PANEL.end.y - 8), term, 16, Color(Palette.GOLD_LIGHT, fade))
	Fit.end()
	# Which page this is.
	for i in _beats.size():
		_canvas.draw_rect(Rect2(472 - (_beats.size() - i) * 6, 8, 4, 4), Palette.GOLD_LIGHT if i == _index else Color(Palette.PAPER, 0.4))
	if _black > 0.0:
		_canvas.draw_rect(Rect2(0, 0, 480, 270), Color(0, 0, 0, _black))


## A poster that writes itself, on a lineup that lights up as it does.
func _draw_demo(demo: Dictionary) -> void:
	var lines: Array = demo.lines
	var pattern: Array = demo.get("pattern", [])
	var has_poster := not pattern.is_empty()
	var sheet := Rect2(SHEET_X, 30, 224, lines.size() * 15 + (34 if has_poster else 12))
	_canvas.draw_rect(sheet.grow(2), Color(0, 0, 0, 0.35))
	Ui.paper(_canvas, sheet)
	Ui.nails(_canvas, sheet)
	Fit.begin(sheet, "the prologue's poster")
	var y := sheet.position.y + 8
	var tokens := demo_tokens() if not Fit.audit else pattern
	if has_poster:
		Fit.text(_canvas, Palette.titles(), Vector2(sheet.position.x + 10, y + 12), "WANTED", 11, Palette.RED)
		var slot := Rect2(sheet.position.x + 74, y, 140, 18)
		_canvas.draw_rect(slot, Palette.PAPER_LINE)
		_canvas.draw_rect(slot.grow(-1), Palette.PAPER.lightened(0.3))
		var x := slot.position.x + 4
		for token: String in tokens:
			var w := Fit.width(Palette.mono(), token, 16) + 6
			_canvas.draw_rect(Rect2(x, slot.position.y + 2, w, 14), Palette.PAPER_DARK)
			Ui.regex(_canvas, Vector2(x + 3, slot.end.y - 5), token, Ui.kind_color(token))
			x += w + 1
		y += 24
	var text := Rx.text(tokens)
	for i in lines.size():
		var words := str(lines[i])
		var r := {}
		if not tokens.is_empty():
			var m := Rx.search(text, words)
			if bool(m.get("found", false)):
				r = {"found": true, "start": m.start, "end": m.end}
		var marked := int(demo.get("mark", -1)) == i and not r.is_empty()
		if marked and Fit.blink(fmod(_t, 0.7) < 0.45):
			_canvas.draw_rect(Rect2(sheet.position.x + 4, y - 1, sheet.size.x - 10, 14), Color(Palette.RED_LIGHT, 0.4))
		Ui.lineup_text(_canvas, Vector2(sheet.position.x + 12, y + 10), words, r, "", Palette.INK)
		y += 15
	Fit.end()
