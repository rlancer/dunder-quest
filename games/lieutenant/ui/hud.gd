class_name Hud
extends CanvasLayer

## Everything drawn over a case: speech bubbles, the cold open's letterbox
## and captions, the black title card, lesson cards (a query and what it
## returns), the "in the notebook" slip when a record is entered, the freeze
## frame and the end card.
##
## The scene drives it with coroutines: `await hud.say(...)` returns once the
## player has read the line (Enter, E, Space or a tap). Tests set
## `auto_frames` so lines move on by themselves.

signal advanced

const BUBBLE_WIDTH := 206.0
const GAME := "Just One More JOIN"

## Tests set these before a case starts; every new HUD picks them up.
static var test_auto_frames: int = 0
static var test_per_char: float = 0.0

## When above zero, every wait ends by itself after this many frames.
var auto_frames: int = test_auto_frames
## Extra frames per character of text, so longer lines stay up longer.
var auto_per_char: float = test_per_char

var _canvas: Control
var _waiting: bool = false
var _wait_started: int = 0
var _wait_frames: int = 0
var _wait_need: int = 0

# What's showing.
var bubble: Dictionary = {}
var prompt: String = ""
var place: String = ""
var _caption: Dictionary = {}
var _letterbox: float = 0.0
var _card: Dictionary = {}
var _title: Dictionary = {}
var _end: Dictionary = {}
var _slip: Dictionary = {}
var _freeze: float = 0.0
var _press_start: bool = false
var _flash: float = 0.0
var _clock: float = 0.0
var _title_serial: int = 0
## How many lesson cards and captions have been shown, for the tests.
var card_count: int = 0
var caption_count: int = 0


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)


func _process(delta: float) -> void:
	_clock += delta
	_flash = maxf(_flash - delta * 3.0, 0.0)
	if not _slip.is_empty():
		_slip.time = float(_slip.time) - delta
		if float(_slip.time) <= 0.0:
			_slip = {}
	if _waiting and auto_frames > 0:
		_wait_frames += 1
		if _wait_frames >= _wait_need:
			advance()
	_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if not _waiting:
		return
	if Time.get_ticks_msec() - _wait_started < 180:
		return
	var tap: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
	if tap or event.is_action_pressed(&"confirm") or event.is_action_pressed(&"edit"):
		get_viewport().set_input_as_handled()
		advance()


func is_waiting() -> bool:
	return _waiting


func advance() -> void:
	if not _waiting:
		return
	_waiting = false
	advanced.emit()


## Waits for the player (or `auto_frames`) to move on. `chars` lengthens the
## automatic wait for longer text.
func wait(chars: int = 0) -> void:
	_waiting = true
	_wait_started = Time.get_ticks_msec()
	_wait_frames = 0
	_wait_need = auto_frames + int(auto_per_char * chars)
	await advanced


# --- Lines ------------------------------------------------------------------

## A speech bubble over `speaker` (or a caption when null) until read.
func say(speaker: Person, text: String, mood: String = "") -> void:
	var name := speaker.display_name if speaker != null else ""
	bubble = {"who": speaker, "name": name, "text": text, "mood": mood}
	if speaker != null:
		speaker.strike_mood(mood, 60.0)
	await wait(text.length())
	if speaker != null:
		# The Lieutenant's thinking and a suspect's sweat linger a moment.
		speaker.strike(int(Person.MOODS.get(mood, Person.Pose.IDLE)), 0.5)
	bubble = {}


## One caption of the cold open: a time stamp and a sentence, under the
## letterbox.
func caption(stamp: String, text: String) -> void:
	caption_count += 1
	_caption = {"stamp": stamp, "text": text}
	await wait(text.length() + 30)
	_caption = {}


func set_letterbox(amount: float) -> void:
	_letterbox = amount


func flash() -> void:
	_flash = 1.0


## The slip that says a record has gone into the notebook.
func slip(title: String, lines: PackedStringArray, seconds: float = 4.0) -> void:
	_slip = {"title": title, "lines": lines, "time": seconds}


## A lesson card: a query, what it returns, and what that means.
func show_card(card: Dictionary) -> void:
	card_count += 1
	_card = card.duplicate()
	_card["result"] = Sql.run(card.db, str(card.sql))
	await wait(str(card.get("text", "")).length() + 60)
	_card = {}


func is_card_open() -> bool:
	return not _card.is_empty()


# --- Title cards, freeze frame, end card ------------------------------------

## A black card with the episode's name, like the top of the show.
func title_card(title: String, lines: PackedStringArray, seconds: float = 3.0) -> void:
	_title = {"title": title, "lines": lines}
	if auto_frames > 0:
		await wait(0)
	else:
		_title_serial += 1
		var mine := _title_serial
		var timer := get_tree().create_timer(seconds, true)
		_waiting = true
		_wait_started = Time.get_ticks_msec()
		_wait_need = 1 << 30
		timer.timeout.connect(func() -> void:
			if _title_serial == mine and not _title.is_empty():
				advance())
		await advanced
	_title = {}


func set_freeze(amount: float) -> void:
	_freeze = amount


func end_card(title: String, lines: PackedStringArray) -> void:
	_end = {"title": title, "lines": lines}
	await wait(80)
	_end = {}


func show_press_to_start() -> void:
	_press_start = true


func hide_press_to_start() -> void:
	_press_start = false


# --- Drawing ----------------------------------------------------------------

func _draw_hud() -> void:
	var c := _canvas
	if _freeze > 0.0:
		c.draw_rect(Rect2(0, 0, 480, 270), Color(0.95, 0.82, 0.6, 0.14 * _freeze))
		for edge in 4:
			var t := float(edge) * 5.0
			c.draw_rect(Rect2(t, t, 480 - t * 2, 270 - t * 2), Color(0, 0, 0, 0.12 * _freeze), false, 5.0)
	if _letterbox > 0.0:
		c.draw_rect(Rect2(0, 0, 480, 26 * _letterbox), Color.BLACK)
		c.draw_rect(Rect2(0, 270 - 58 * _letterbox, 480, 58 * _letterbox), Color.BLACK)
	if place != "" and _title.is_empty() and _end.is_empty() and _letterbox <= 0.0:
		_draw_label(Vector2(476, 12), place, HORIZONTAL_ALIGNMENT_RIGHT, Palette.PAPER.darkened(0.08))
	if not _caption.is_empty():
		_draw_caption(c)
	if not bubble.is_empty():
		_draw_bubble(c)
	if prompt != "" and bubble.is_empty() and _card.is_empty() and _letterbox <= 0.0:
		var w := Palette.mono().get_string_size(prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		c.draw_rect(Rect2(240 - w / 2 - 6, 251, w + 12, 16), Color(0.05, 0.04, 0.05, 0.82))
		c.draw_string(Palette.mono(), Vector2(roundf(240 - w / 2), 263), prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.CREAM)
	if not _slip.is_empty() and _card.is_empty() and _title.is_empty():
		_draw_slip(c)
	if not _card.is_empty():
		_draw_card(c)
	if _flash > 0.0:
		c.draw_rect(Rect2(0, 0, 480, 270), Color(1, 1, 1, 0.5 * _flash))
	if not _title.is_empty():
		_draw_title(c)
	if not _end.is_empty():
		_draw_end(c)
	if _press_start:
		c.draw_rect(Rect2(0, 0, 480, 270), Color(0, 0, 0, 0.88))
		_draw_centered(c, Palette.titles(), GAME, 132, 26, Palette.CREAM)
		var press := "Tap to start" if TouchControls.active else "Press any key"
		_draw_centered(c, Palette.mono(), press, 166, 16, Palette.EMBER)


func _draw_label(at: Vector2, text: String, align: HorizontalAlignment, color: Color) -> void:
	var font := Palette.mono()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var x := at.x - w if align == HORIZONTAL_ALIGNMENT_RIGHT else at.x
	_canvas.draw_string_outline(font, Vector2(x, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Palette.INK)
	_canvas.draw_string(font, Vector2(x, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)


func _draw_centered(c: Control, font: Font, text: String, y: float, size: int, color: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	c.draw_string(font, Vector2(roundf(240 - w / 2), y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _draw_bubble(c: Control) -> void:
	var font := Palette.mono()
	var speaker: Person = bubble.who
	var text: String = bubble.text
	var lines := SqlDraw.wrap(text, BUBBLE_WIDTH - 12)
	var w := 0.0
	for line in lines:
		w = maxf(w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x)
	var name: String = bubble.name
	w = maxf(w, font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x) + 12
	# Room after the last line for the blinking "v", so it never sits on the text.
	w = maxf(w, font.get_string_size(lines[-1] if not lines.is_empty() else "", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 22)
	var h := lines.size() * 12 + (14 if name != "" else 6) + 4
	var anchor := Vector2(240, 130)
	if speaker != null and is_instance_valid(speaker):
		anchor = speaker.head()
	var box := Rect2(Vector2(clampf(anchor.x - w / 2, 4, 476 - w), maxf(anchor.y - h - 10, 16)), Vector2(w, h))
	var fill := Palette.PAPER
	var border := Palette.INK
	c.draw_rect(box.grow(1), border)
	c.draw_rect(box, fill)
	if speaker != null:
		var tip := Vector2(clampf(anchor.x, box.position.x + 6, box.end.x - 6), box.end.y)
		c.draw_colored_polygon(PackedVector2Array([tip + Vector2(-4, 0), tip + Vector2(4, 0), Vector2(clampf(anchor.x, box.position.x + 2, box.end.x - 2), minf(anchor.y - 2, box.end.y + 8))]), border)
		c.draw_colored_polygon(PackedVector2Array([tip + Vector2(-3, -1), tip + Vector2(3, -1), Vector2(clampf(anchor.x, box.position.x + 3, box.end.x - 3), minf(anchor.y - 4, box.end.y + 6))]), fill)
	var y := box.position.y + 11
	if name != "":
		c.draw_string(font, Vector2(box.position.x + 6, y), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.EMBER.darkened(0.3))
		y += 12
	for line in lines:
		c.draw_string(font, Vector2(box.position.x + 6, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.INK)
		y += 12
	if _waiting and int(_clock * 3.0) % 2 == 0:
		c.draw_string(font, box.end + Vector2(-9, -2), "v", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.EMBER)


func _draw_caption(c: Control) -> void:
	var font := Palette.mono()
	var y := 226.0
	var stamp := str(_caption.stamp)
	if stamp != "":
		c.draw_string(Palette.pixel(), Vector2(24, y), stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.EMBER)
		y += 13
	for line in SqlDraw.wrap(str(_caption.text), 432):
		c.draw_string(font, Vector2(24, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.PAPER)
		y += 12
	if _waiting and int(_clock * 3.0) % 2 == 0:
		c.draw_string(font, Vector2(462, 264), "v", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.EMBER)


func _draw_slip(c: Control) -> void:
	var font := Palette.mono()
	var lines: PackedStringArray = _slip.lines
	var w := font.get_string_size(str(_slip.title), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	for line in lines:
		w = maxf(w, SqlDraw.width(line))
	var fade := clampf(float(_slip.time) * 2.0, 0.0, 1.0)
	var box := Rect2(Vector2(roundf(240 - w / 2 - 8), 22), Vector2(w + 16, 16 + lines.size() * 11))
	c.draw_rect(box.grow(1), Color(Palette.NOTE_COVER, fade))
	c.draw_rect(box, Color(Palette.NOTE, fade))
	c.draw_string(font, box.position + Vector2(8, 11), str(_slip.title), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Palette.EMBER.darkened(0.3), fade))
	var y := box.position.y + 22
	for line in lines:
		c.draw_string(font, Vector2(box.position.x + 8, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Palette.NOTE_INK, fade))
		y += 11


func _draw_card(c: Control) -> void:
	var font := Palette.mono()
	var text_lines := SqlDraw.wrap(str(_card.get("text", "")), 424)
	var sql_lines := str(_card.sql).split("\n")
	var result: Dictionary = _card.result
	var table := Printout.layout(result, 3, 420.0) if result.ok else {}
	var table_h: float = (table.lines as Array).size() * 11.0 + 4 if result.ok else 0.0
	var h := 24.0 + sql_lines.size() * 11 + 8 + table_h + 6 + text_lines.size() * 12 + 16
	var panel := Rect2(Vector2(20, maxf(roundf(135 - h / 2), 2)), Vector2(440, h))
	c.draw_rect(Rect2(0, 0, 480, 270), Color(0, 0, 0, 0.45))
	c.draw_rect(panel.grow(2), Palette.EMBER.darkened(0.25))
	c.draw_rect(panel, Color(0.09, 0.07, 0.08, 0.97))
	c.draw_string(Palette.pixel(), panel.position + Vector2(8, 15), str(_card.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.CREAM)
	var tag := "from the Lieutenant's notebook"
	var tag_w := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	c.draw_string(font, Vector2(panel.end.x - tag_w - 8, panel.position.y + 14), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.EMBER)
	# The query, on a strip of notebook paper.
	var y := panel.position.y + 22
	var strip := Rect2(panel.position.x + 8, y, 424, sql_lines.size() * 11 + 5)
	c.draw_rect(strip, Palette.NOTE)
	y += 11
	for line in sql_lines:
		SqlDraw.draw_line(c, Vector2(strip.position.x + 6, y), line)
		y += 11
	y += 3
	# What it returns, on printout paper.
	if result.ok:
		Printout.draw(c, Rect2(panel.position.x + 8, y, 424, table_h), table)
		y += table_h
	y += 15
	for line in text_lines:
		c.draw_string(font, Vector2(panel.position.x + 8, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.PAPER.darkened(0.04))
		y += 12
	if _waiting and int(_clock * 3.0) % 2 == 0:
		c.draw_string(font, Vector2(panel.end.x - 60, panel.end.y - 4), "Tap: OK" if TouchControls.active else "Enter: OK", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.EMBER)


func _draw_title(c: Control) -> void:
	c.draw_rect(Rect2(0, 0, 480, 270), Color.BLACK)
	_draw_centered(c, Palette.mono(), GAME.to_upper(), 92, 16, Palette.EMBER)
	_draw_centered(c, Palette.titles(), str(_title.title), 132, 30, Palette.CREAM)
	var y := 160.0
	for line: String in _title.lines:
		_draw_centered(c, Palette.mono(), line, y, 16, Color(0.8, 0.78, 0.72))
		y += 14


func _draw_end(c: Control) -> void:
	c.draw_rect(Rect2(0, 0, 480, 270), Color.BLACK)
	_draw_centered(c, Palette.mono(), GAME.to_upper(), 78, 16, Palette.EMBER)
	_draw_centered(c, Palette.titles(), str(_end.title), 114, 26, Palette.CREAM)
	var y := 144.0
	for line: String in _end.lines:
		_draw_centered(c, Palette.mono(), line, y, 16, Color(0.85, 0.83, 0.76))
		y += 15
	if _waiting and int(_clock * 2.0) % 2 == 0:
		_draw_centered(c, Palette.mono(), "Tap to carry on" if TouchControls.active else "Enter: carry on", 252, 16, Color(0.6, 0.6, 0.6))
