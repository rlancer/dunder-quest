class_name LessonCard
extends Control

## A lesson, taped up before the ticket that needs it: what the new chips
## mean in plain words, and a line at work in a terminal, run by the game's
## own shell, so what it prints is what the real thing prints.

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
	Voice.say({"who": "shell", "say": str(c.get("say", c.get("text", "")))})
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
	draw_rect(Rect2(0, 0, 480, 270), Color(0.02, 0.03, 0.04, 0.6))
	Ui.paper(self, SHEET)
	Ui.tape(self, SHEET)
	Fit.begin(SHEET, "the lesson card \"%s\"" % card.get("title", ""))
	var mono := Palette.mono()
	var left := SHEET.position.x + 16
	var wide := SHEET.size.x - 34
	Fit.centred(self, Palette.pixel(), 240, SHEET.position.y + 14, "SHELL'S NOTES", 10, Palette.DIM)
	Fit.centred(self, Palette.titles(), 240, SHEET.position.y + 38, str(card.get("title", "")).to_upper(), 22, Palette.RED)
	var y := SHEET.position.y + 56
	y += Fit.para(self, mono, Vector2(left, y), str(card.get("text", "")), 16, Palette.INK, wide, 13) * 13 + 4
	for pair: Array in card.get("chips", []):
		var token := str(pair[0])
		var w := Ui.chip_width(token)
		Ui.chip(self, Rect2(left, y - 11, w, 18), token, false, true)
		var lines := Fit.para(self, mono, Vector2(left + w + 8, y + 2), str(pair[1]), 16, Palette.INK, wide - w - 8, 13)
		y += maxi(lines * 13, 18) + 5
	if card.has("demo"):
		_draw_demo(left, y + 2, wide)
	Fit.end()
	Ui.prompt(self, "%s: got it" % Controls.go_key())


## The card's line in a terminal, and what it prints, a row at a time.
func _draw_demo(left: float, top: float, wide: float) -> void:
	var demo: Dictionary = card.demo
	var line := str(demo.line)
	var ran := Shell.run(line, Story.files(demo.files))
	var rows: Array = Judge.lines(str(ran.get("out", "")))
	var into := ""
	for name: String in ran.get("files", {}):
		into = name
		rows = Judge.lines(str(ran.files[name]))
	var count := rows.size() + (2 if into != "" else 1)
	var glass := Rect2(left, top, wide, count * Ui.ROW + 8)
	Ui.screen(self, glass)
	var at := glass.position + Vector2(6, 14)
	Fit.text(self, Palette.mono(), at, "$", 16, Palette.GREEN_LIGHT)
	Ui.code(self, at + Vector2(12, 0), line, true)
	var row := 1
	if into != "":
		Fit.text(self, Palette.mono(), at + Vector2(0, Ui.ROW), "(nothing printed: it's in %s)" % into, 16, Palette.TERM_DIM)
		row = 2
	for i in rows.size():
		var glow := 1.0 if Fit.audit else clampf((_clock - 0.9 - i * 0.35) / 0.3, 0.0, 1.0)
		Fit.text(self, Palette.mono(), at + Vector2(0, (row + i) * Ui.ROW), str(rows[i]), 16, Color(Palette.TERM_TEXT, glow))
