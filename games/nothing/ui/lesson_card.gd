class_name LessonCard
extends Control

## Stu's set: a lesson as a stand-up bit at the Rimshot, taped up before the
## scene that needs it. What the new cards mean in plain words, read aloud
## by Stu, and a little script with what it logs, played by the game's own
## event loop (and checked against the real one by tests/verify_loop.ts).

signal closed

const SHEET := Rect2(40, 4, 400, 262)

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


## The card as Stu reads it aloud: its `say`, or else its text.
static func spoken(c: Dictionary) -> Dictionary:
	return {"who": "stu", "say": str(c.get("say", c.get("text", "")))}


## Shows the card, and comes back when the player has read it.
func show_card(c: Dictionary) -> void:
	card = c
	_clock = 0.0
	_frames = 0
	active = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	Sfx.play(self, "page")
	Voice.say(spoken(c))
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
	draw_rect(Rect2(0, 0, 480, 270), Color(0.03, 0.02, 0.05, 0.62))
	Ui.paper(self, SHEET)
	Ui.brads(self, SHEET)
	# The club's brick along the top.
	var wall := Rect2(SHEET.position.x + 1, SHEET.position.y + 1, SHEET.size.x - 4, 20)
	draw_rect(wall, Palette.BRICK)
	for row in 3:
		var y := wall.position.y + row * 7.0
		draw_rect(Rect2(wall.position.x, y + 6, wall.size.x, 1), Palette.BRICK.darkened(0.35))
		var x := wall.position.x + (0.0 if row % 2 == 0 else 9.0)
		while x < wall.end.x:
			draw_rect(Rect2(x, y, 1, 6), Palette.BRICK.darkened(0.35))
			x += 18.0
	Fit.cover(wall)
	Fit.begin(SHEET, "Stu's set \"%s\"" % card.get("title", ""))
	var mono := Palette.mono()
	var left := SHEET.position.x + 16
	var wide := SHEET.size.x - 32
	Fit.begin(wall, "the club's sign")
	Fit.centred(self, Palette.pixel(), 240, wall.position.y + 14, "TONIGHT AT THE RIMSHOT: STU LERNER", 10, Palette.CREAM)
	Fit.end()
	Fit.centred(self, Palette.titles(), 240, SHEET.position.y + 42, str(card.get("title", "")), 19, Palette.BRICK)
	var y := SHEET.position.y + 58
	y += Fit.para(self, mono, Vector2(left, y), str(card.get("text", "")), 16, Palette.INK, wide, 12) * 12 + 3
	for pair: Array in card.get("chips", []):
		var words := str(pair[0])
		var w := Ui.tag_width(words)
		Ui.tag(self, Rect2(left, y - 10, w, 16), words)
		var lines := Fit.para(self, mono, Vector2(left + w + 8, y + 2), str(pair[1]), 16, Palette.INK, wide - w - 8, 12)
		y += maxi(lines * 12, 16) + 4
	if card.has("demo"):
		_draw_demo(left, y, wide)
	Fit.end()
	Ui.prompt(self, "%s: got it" % Controls.go_key())


## The card's script, and beside it what it logs, a line at a time.
func _draw_demo(left: float, top: float, wide: float) -> void:
	var program: Array = card.demo
	var code := Loop.lines(program, false)
	var ran := Loop.run(program)
	var out: Array = ran.out
	var rows := maxi(code.size(), out.size() + 1)
	var split := wide - 104
	var page := Rect2(left, top, split - 4, rows * Ui.ROW + 8)
	draw_rect(page, Palette.PAPER_DARK)
	Fit.cover(page)
	Fit.begin(page, "the set's script")
	for i in code.size():
		var line: Dictionary = code[i]
		Ui.code(self, Vector2(page.position.x + 5 + int(line.indent) * 9, page.position.y + 13 + i * Ui.ROW), str(line.text), false)
	Fit.end()
	var screen := Rect2(left + split, top, wide - split, rows * Ui.ROW + 8)
	Ui.glass(self, screen)
	Fit.begin(screen, "what the set's script logs")
	Fit.text(self, Palette.pixel(), Vector2(screen.position.x + 5, screen.position.y + 11), "LOGS", 10, Palette.GLASS_DIM)
	for i in out.size():
		var glow := 1.0 if Fit.audit else clampf((_clock - 1.2 - i * 0.6) / 0.3, 0.0, 1.0)
		Fit.text(self, Palette.mono(), Vector2(screen.position.x + 5, screen.position.y + 13 + (i + 1) * Ui.ROW), str(out[i]), 16, Color(Palette.GLASS_TEXT, glow))
	Fit.end()
