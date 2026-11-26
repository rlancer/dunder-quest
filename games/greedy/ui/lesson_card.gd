class_name LessonCard
extends Control

## A lesson, pinned up before the poster that needs it: what the new chip
## means in plain words, read aloud by the Kid, and the chip at work on a
## few lines, lit up by the real engine. The last card of the game has no
## lineup: it counts the ways Big Backtrack can split a row of a's.

signal closed

const SHEET := Rect2(56, 6, 368, 258)

var card: Dictionary = {}
var active: bool = false
## The bot sets this: the card closes by itself after so many frames.
var auto_frames: int = 0

var _clock: float = 0.0
var _frames: int = 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Shows the card, and comes back when the player has read it.
func show_card(c: Dictionary) -> void:
	card = c
	_clock = 0.0
	_frames = 0
	active = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	Sfx.play(self, "page")
	Voice.say({"who": "kid", "say": str(c.get("say", ""))})
	queue_redraw()
	await closed
	active = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func press() -> void:
	# A card can't be dismissed by the same press that opened it.
	if active and (_clock > 0.25 or auto_frames > 0):
		Voice.hush()
		closed.emit()


func _process(delta: float) -> void:
	if not active:
		return
	_clock += delta
	_frames += 1
	if auto_frames > 0 and _frames >= auto_frames:
		press()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		press()


func _unhandled_input(event: InputEvent) -> void:
	if active and is_visible_in_tree() and event.is_action_pressed(&"confirm"):
		get_viewport().set_input_as_handled()
		press()


## How far into the card's animation it's drawn: the test sets this to look
## at it finished.
func settle() -> void:
	_clock = 60.0


func _draw() -> void:
	if card.is_empty():
		return
	Fit.frame(self)
	draw_rect(Rect2(0, 0, 480, 270), Color(0.05, 0.03, 0.02, 0.6))
	Ui.paper(self, SHEET)
	Ui.nails(self, SHEET)
	Fit.begin(SHEET, "the lesson card \"%s\"" % card.get("title", ""))
	var mono := Palette.mono()
	var left := SHEET.position.x + 16
	var wide := SHEET.size.x - 34
	Fit.centred(self, Palette.pixel(), 240, SHEET.position.y + 14, "THE KID'S NOTES", 10, Palette.DIM)
	Fit.centred(self, Palette.titles(), 240, SHEET.position.y + 34, str(card.get("title", "")), 16, Palette.RED)
	var y := SHEET.position.y + 52
	y += Fit.para(self, mono, Vector2(left, y), str(card.get("text", "")), 16, Palette.INK, wide, 13) * 13 + 4
	for pair: Array in card.get("chips", []):
		var token := str(pair[0])
		var w := Ui.chip_width(token)
		Ui.chip(self, Rect2(left, y - 11, w, 18), token, false, true)
		var lines := Fit.para(self, mono, Vector2(left + w + 8, y + 2), str(pair[1]), 16, Palette.INK, wide - w - 8, 13)
		y += maxi(lines * 13, 18) + 5
	if card.has("demo"):
		y = _draw_demo(left, y + 4)
	elif card.has("count"):
		y = _draw_count(left, y + 6)
	Fit.end()
	Ui.prompt(self, "%s: got it" % Controls.go_key())


## The card's pattern on a few lines, each lighting up in turn.
func _draw_demo(left: float, top: float) -> float:
	var demo: Dictionary = card.demo
	var mono := Palette.mono()
	var pattern := str(demo.pattern)
	var group := int(demo.get("group", 0))
	var y := top
	Fit.text(self, Palette.pixel(), Vector2(left, y + 4), "ON THE POSTER", 10, Palette.DIM)
	var w := Fit.width(mono, pattern, 16) + 10
	var slot := Rect2(left + 92, y - 8, w, 17)
	draw_rect(slot, Palette.PAPER_LINE)
	draw_rect(slot.grow(-1), Palette.PAPER.lightened(0.3))
	Ui.regex(self, Vector2(slot.position.x + 5, slot.end.y - 5), pattern, Palette.RED)
	y += 22
	var lines: Array = demo.lines
	for i in lines.size():
		var words := str(lines[i])
		var m := Rx.search(pattern, words)
		var r := {}
		if bool(m.get("found", false)):
			r = {"found": true, "start": m.start, "end": m.end, "take_start": m.groups[group][0] if group < (m.groups as Array).size() else -1, "take_end": m.groups[group][1] if group < (m.groups as Array).size() else -1}
		var glow := clampf((_clock - 0.9 - i * 0.45) / 0.3, 0.0, 1.0)
		if Fit.audit:
			glow = 1.0
		Ui.lineup_text(self, Vector2(left + 12, y + 4), words, r, "", Palette.INK, glow)
		if glow >= 1.0:
			var verdict := "no match"
			if not r.is_empty():
				verdict = "match"
				if group > 0 and int(r.take_start) >= 0:
					verdict = "group %d: %s" % [group, words.substr(r.take_start, int(r.take_end) - int(r.take_start))]
			Fit.text(self, mono, Vector2(SHEET.end.x - 18 - Fit.width(mono, verdict, 16), y + 4), verdict, 16, Palette.GREEN if not r.is_empty() else Palette.DIM)
		y += 15
	return y


## Big Backtrack's telegram: every a added doubles the ways to split them.
func _draw_count(left: float, top: float) -> float:
	var mono := Palette.mono()
	var line := str(card.count)
	var most := line.length() - 1
	var n := clampi(int((_clock - 1.0) * 3.0), 1, most)
	if Fit.audit:
		n = most
	var shown := "a".repeat(n) + "b"
	Fit.text(self, Palette.pixel(), Vector2(left, top + 4), "THE TELEGRAM", 10, Palette.DIM)
	Ui.regex(self, Vector2(left + 84, top + 5), shown, Palette.INK)
	var ways := _grouped(1 << (n - 1))
	Fit.text(self, mono, Vector2(left, top + 22), "a's on the line: %d" % n, 16, Palette.INK)
	Fit.text(self, mono, Vector2(left, top + 36), "ways to split them up: %s" % ways, 16, Palette.RED)
	return top + 44


static func _grouped(n: int) -> String:
	var digits := str(n)
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return out
