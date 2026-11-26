class_name Builder
extends Control

## The pass: the brief, the kitchen's files on the left (the rail), the
## ticket on the right (what has to come out), and between them whatever
## the line being written prints right now. Chips go onto the line at the
## caret, and the line is run as they do (Shell, a real shell's rules), so
## the middle of the screen is always the truth. Whether that's what the
## ticket asked for is for the player to read off: the verdict only comes
## when they fire.
##
## Mouse and touch: tap a chip to put it down, tap one on the line to take
## it back, tap Fire. Keys: arrows pick a chip, Enter puts it down,
## Backspace takes one back, comma and full stop move the caret, Tab turns
## to the next file, F fires.

signal fired(won: bool)

const TOP := Rect2(0, 0, 480, 15)
const BRIEF := Rect2(8, 16, 464, 50)
const RAIL := Rect2(8, 68, 148, 108)
const PASS := Rect2(159, 68, 162, 108)
const WANT := Rect2(324, 68, 148, 108)
const LINE := Rect2(8, 178, 464, 88)
const SLOTS := Rect2(16, 196, 448, 20)
const CHIPS := Rect2(16, 221, 448, 42)
## Seconds between one line's verdict and the next when the line is fired.
const REVEAL := 0.17
const BUTTONS := ["erase", "clear", "fire"]
const BUTTON_RECTS := [Rect2(346, 181, 34, 13), Rect2(382, 181, 36, 13), Rect2(420, 181, 44, 13)]
const BUTTON_WORDS := ["Back", "Clear", "FIRE!"]
## What the pass shows for a line the game won't run for its own reasons.
const HOUSE := {
	"waiting": "(standing by: nothing is coming down the line)",
	"unsupported": "(not on the cards in this kitchen)",
	"clobber": "(it would read the file it's writing)",
	"empty": "",
}

var ticket: Dictionary = {}
var tokens: Array = []
var caret: int = 0
## Which chip (or, past the chips, which button) the keys are on.
var focus: int = 0
## What the line makes of the kitchen right now (Judge.judge), or {}.
var result: Dictionary = {}
## True once the line has been fired: the verdicts show.
var judged: bool = false
var revealed: int = 0
## Fires that missed on this ticket.
var fails: int = 0
## While the verdicts are coming in, or once the ticket is won.
var busy: bool = false
## What Shell has to say about the last fire (or a line that can't be
## fired). While it's empty the brief shows; it clears when the line is
## changed.
var said: String = ""
## The hint, once two fires have missed. It stays.
var note: String = ""
var header: String = ""
var index_text: String = ""
## Fires so far in the whole shift, for the top bar.
var fires: int = 0
## The bot sets this: no waiting between verdicts.
var instant: bool = false
## The file showing on the rail.
var shown_file: String = ""

var _clock: float = 0.0
var _reveal_clock: float = 0.0
var _hover: Dictionary = {}
var _chip_rects: Array = []
var _token_rects: Array = []
var _won: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(p: Dictionary, shift_header: String, which: String, shift_fires: int) -> void:
	ticket = p
	header = shift_header
	index_text = which
	fires = shift_fires
	tokens = []
	caret = 0
	focus = 0
	fails = 0
	busy = false
	judged = false
	revealed = 0
	_won = false
	_hover = {}
	said = ""
	note = ""
	shown_file = str((p.files as Array)[0])
	Voice.say(p.brief)
	_chip_rects = []
	var x := CHIPS.position.x
	var y := CHIPS.position.y
	for chip: String in p.chips:
		var w := Ui.chip_width(chip)
		if x + w > CHIPS.end.x:
			x = CHIPS.position.x
			y += 22.0
		_chip_rects.append(Rect2(x, y, w, 19))
		x += w + 5.0
	_judge()


func par() -> int:
	return Story.par(ticket)


# --- What the player does ----------------------------------------------------

## Puts `chip` on the line at the caret. False if there's no room.
func place(chip: String) -> bool:
	if busy:
		return false
	if _slots_width(tokens) + _token_width(chip) + 1.0 > SLOTS.size.x - 20.0:
		said = "That line's full, Chef. Take something off it first."
		Sfx.play(self, "buzz")
		queue_redraw()
		return false
	tokens.insert(caret, chip)
	caret += 1
	Sfx.play(self, "chip")
	_judge()
	return true


## Takes back the chip before the caret.
func erase() -> void:
	if busy or caret <= 0:
		return
	tokens.remove_at(caret - 1)
	caret -= 1
	Sfx.play(self, "erase")
	_judge()


func take_back(index: int) -> void:
	if busy or index < 0 or index >= tokens.size():
		return
	tokens.remove_at(index)
	caret = index
	Sfx.play(self, "erase")
	_judge()


func clear() -> void:
	if busy or tokens.is_empty():
		return
	tokens = []
	caret = 0
	Sfx.play(self, "erase")
	_judge()


func move_caret(by: int) -> void:
	if busy:
		return
	caret = clampi(caret + by, 0, tokens.size())
	queue_redraw()


## Turns the rail to the kitchen's next file.
func next_file() -> void:
	var files: Array = ticket.get("files", [])
	if files.size() < 2:
		return
	shown_file = str(files[(files.find(shown_file) + 1) % files.size()])
	Sfx.play(self, "page")
	queue_redraw()


## Fire: the line goes out, and the pass is checked against the ticket, a
## line at a time. A line the shell won't run costs nothing; Shell says why.
func fire_now() -> void:
	if busy:
		return
	if tokens.is_empty() or result.has("error"):
		said = Story.error_text(result.get("error", {"why": "empty"}))
		Sfx.play(self, "buzz")
		queue_redraw()
		return
	busy = true
	judged = true
	revealed = 0
	_reveal_clock = 0.0
	fires += 1
	Sfx.play(self, "fire")
	queue_redraw()


func _judge() -> void:
	result = Judge.judge(ticket, tokens) if not tokens.is_empty() else {}
	judged = false
	revealed = 0
	said = ""
	# The rail turns to the last file the line names.
	var files: Array = ticket.get("files", [])
	for i in range(tokens.size() - 1, -1, -1):
		var found := ""
		for word: String in Shell.split(str(tokens[i])):
			if files.has(word):
				found = word
		if found != "":
			shown_file = found
			break
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	if busy and judged and not _won:
		_reveal_clock += delta
		var rows: Array = result.get("rows", [])
		while revealed < rows.size() and (instant or _reveal_clock >= REVEAL):
			_reveal_clock -= REVEAL
			Sfx.play(self, "plate" if rows[revealed].ok else "miss")
			revealed += 1
		if revealed >= rows.size() and (instant or _reveal_clock >= REVEAL * 2.0):
			_finish()
	queue_redraw()


func _finish() -> void:
	var won := bool(result.get("won", false))
	if won:
		_won = true
		Sfx.play(self, "win")
	else:
		busy = false
		fails += 1
		said = feedback()
		note = "Hint: %s" % ticket.hint if fails >= 2 else ""
		Sfx.play(self, "buzz")
	fired.emit(won)


## What Shell says about a line that ran and sent the wrong thing.
func feedback() -> String:
	var lines := Story.stock(str(result.get("why", "")))
	if lines.is_empty():
		return ""
	return Judge.fill(str(lines[(fails - 1) % lines.size()]), ticket, result)


# --- Input -------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var item := _item_at(event.position)
		if item != _hover:
			_hover = item
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var item := _item_at(event.position)
		_hover = item
		match str(item.get("kind", "")):
			"chip":
				focus = int(item.index)
				place(str(ticket.chips[int(item.index)]))
			"token":
				take_back(int(item.index))
			"button":
				focus = (ticket.chips as Array).size() + int(item.index)
				_press(int(item.index))
			"slots":
				caret = int(item.index)
				queue_redraw()
			"rail":
				next_file()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or busy:
		return
	var count := (ticket.get("chips", []) as Array).size()
	if event.is_action_pressed(&"move_right", true):
		focus = (focus + 1) % (count + BUTTONS.size())
	elif event.is_action_pressed(&"move_left", true):
		focus = (focus - 1 + count + BUTTONS.size()) % (count + BUTTONS.size())
	elif event.is_action_pressed(&"move_up"):
		focus = count + 2 if focus < count else focus
	elif event.is_action_pressed(&"move_down"):
		focus = 0 if focus >= count else focus
	elif event.is_action_pressed(&"confirm"):
		if focus < count:
			place(str(ticket.chips[focus]))
		else:
			_press(focus - count)
	elif event.is_action_pressed(&"erase", true):
		erase()
	elif event.is_action_pressed(&"caret_left", true):
		move_caret(-1)
	elif event.is_action_pressed(&"caret_right", true):
		move_caret(1)
	elif event.is_action_pressed(&"next_file"):
		next_file()
	elif event.is_action_pressed(&"fire"):
		fire_now()
	else:
		return
	_hover = {}
	get_viewport().set_input_as_handled()
	queue_redraw()


func _press(button: int) -> void:
	match BUTTONS[button]:
		"erase":
			erase()
		"clear":
			clear()
		"fire":
			fire_now()


func _item_at(at: Vector2) -> Dictionary:
	for i in _chip_rects.size():
		if (_chip_rects[i] as Rect2).grow(2).has_point(at):
			return {"kind": "chip", "index": i}
	for i in BUTTON_RECTS.size():
		if (BUTTON_RECTS[i] as Rect2).grow(1).has_point(at):
			return {"kind": "button", "index": i}
	for i in _token_rects.size():
		if (_token_rects[i] as Rect2).has_point(at):
			return {"kind": "token", "index": i}
	if SLOTS.grow(2).has_point(at):
		# A tap between two chips, or past the last, moves the caret there.
		var index := tokens.size()
		for i in _token_rects.size():
			if at.x < (_token_rects[i] as Rect2).position.x:
				index = i
				break
		return {"kind": "slots", "index": index}
	if RAIL.has_point(at):
		return {"kind": "rail"}
	return {}


# --- Drawing -----------------------------------------------------------------

static func _token_width(token: String) -> float:
	return Fit.width(Palette.mono(), token, 16) + 6.0


static func _slots_width(row: Array) -> float:
	var wide := 0.0
	for token: String in row:
		wide += _token_width(token) + 1.0
	return wide


func _draw() -> void:
	Fit.frame(self)
	_draw_top()
	_draw_brief()
	_draw_rail()
	_draw_pass()
	_draw_want()
	_draw_line()


func _draw_top() -> void:
	var font := Palette.pixel()
	draw_rect(TOP, Color(Palette.STEEL_DARK, 0.94))
	Fit.begin(TOP, "the top bar")
	Fit.text(self, font, Vector2(8, 11), header, 10, Palette.LAMP_LIGHT)
	Fit.centred(self, font, 250, 11, index_text, 10, Palette.CREAM)
	var right := "Fires %d   Chips %d   Par %d" % [fires, tokens.size(), par()]
	Fit.text(self, font, Vector2(472 - Fit.width(font, right, 10), 11), right, 10, Palette.CREAM)
	Fit.end()


func _draw_brief() -> void:
	Ui.steel(self, BRIEF)
	var face := Ui.portrait("shell" if said != "" else str(ticket.brief.who))
	if face != null:
		draw_texture_rect(face, Rect2(BRIEF.position.x + 2, BRIEF.position.y + 1, 48, 48), false)
	Fit.begin(BRIEF, "the brief")
	var font := Palette.mono()
	var at := Vector2(BRIEF.position.x + 56, BRIEF.position.y + 11)
	var wide := BRIEF.size.x - 64
	var words := said if said != "" else str(ticket.brief.text)
	# Four lines fit. If the hint won't go under the words, it goes instead of
	# them: the pass already shows what went wrong.
	var hint_lines := Fit.wrap_text(font, note, 16, wide).size() if note != "" else 0
	if hint_lines > 0 and Fit.wrap_text(font, words, 16, wide).size() + hint_lines > 4:
		words = ""
	var used := Fit.para(self, font, at, words, 16, Palette.CREAM, wide, 12) if words != "" else 0
	if note != "":
		Fit.para(self, font, at + Vector2(0, used * 12), note, 16, Palette.LAMP_LIGHT, wide, 12)
	Fit.end()


## A panel's name on a strip along its top.
func _head(rect: Rect2, words: String, fill: Color, right: String = "") -> void:
	var strip := Rect2(rect.position.x + 1, rect.position.y + 1, rect.size.x - 2, 12)
	draw_rect(strip, fill)
	Fit.text(self, Palette.pixel(), Vector2(strip.position.x + 4, strip.end.y - 3), words, 10, Palette.CREAM)
	if right != "":
		Fit.text(self, Palette.pixel(), Vector2(strip.end.x - 4 - Fit.width(Palette.pixel(), right, 10), strip.end.y - 3), right, 10, Palette.CREAM)


## The rail: one of the kitchen's files, as it is.
func _draw_rail() -> void:
	Ui.paper(self, RAIL)
	Fit.begin(RAIL, "the rail")
	var files: Array = ticket.get("files", [])
	var turn := ""
	if files.size() > 1:
		turn = "%d/%d %s" % [files.find(shown_file) + 1, files.size(), "tap" if TouchControls.active else "Tab"]
	_head(RAIL, shown_file, Palette.GREEN, turn)
	var lines: Array = (Story.data().files as Dictionary).get(shown_file, [])
	Ui.listing(self, RAIL.position + Vector2(6, 24), lines, RAIL.size.x - 10, Palette.INK, Palette.DIM)
	Fit.end()


## The pass: what the line prints right now, or the shell's complaint.
func _draw_pass() -> void:
	Ui.screen(self, PASS)
	Fit.begin(PASS, "the pass")
	var where := str(result.get("where", ""))
	_head(PASS, "THE PASS" if where == "" else "INTO %s" % where, Palette.STEEL if where == "" else Palette.GREEN)
	var at := PASS.position + Vector2(6, 24)
	var wide := PASS.size.x - 10
	var mono := Palette.mono()
	if tokens.is_empty():
		Fit.para(self, mono, at, "Nothing fired yet. What the line prints shows up here.", 16, Palette.TERM_DIM, wide, Ui.ROW)
	elif result.has("error"):
		var problem: Dictionary = result.error
		var shell_says := str(problem.error).split("\n")[0]
		if shell_says != "":
			Fit.para(self, mono, at, shell_says, 16, Palette.RED_LIGHT, wide, Ui.ROW)
		else:
			Fit.para(self, mono, at, str(HOUSE.get(str(problem.kind), "")), 16, Palette.TERM_DIM, wide, Ui.ROW)
	else:
		var got: Array = result.get("got", [])
		if got.is_empty():
			Fit.para(self, mono, at, "(it ran, and printed nothing)", 16, Palette.TERM_DIM, wide, Ui.ROW)
		else:
			var missed: bool = judged and revealed >= (result.rows as Array).size() and not bool(result.won)
			Ui.listing(self, at, got, wide, Palette.RED_LIGHT if missed else Palette.TERM_TEXT, Palette.TERM_DIM)
	Fit.end()


## The ticket: the lines that have to reach the pass, in this order.
func _draw_want() -> void:
	Ui.paper(self, WANT)
	Fit.begin(WANT, "the ticket")
	var file := str(ticket.get("want_file", ""))
	_head(WANT, "THE TICKET" if file == "" else "IN %s" % file, Palette.RED)
	var want: Array = ticket.get("want", [])
	var rows: Array = result.get("rows", [])
	var at := WANT.position + Vector2(6, 24)
	for i in want.size():
		var shown := judged and i < revealed and i < rows.size()
		var ok: bool = shown and bool(rows[i].ok)
		if shown:
			draw_rect(Rect2(WANT.position.x + 1, at.y - 10 + i * Ui.ROW, WANT.size.x - 4, Ui.ROW), Color(Palette.GREEN_LIGHT if ok else Palette.RED_LIGHT, 0.3))
		Fit.text(self, Palette.mono(), at + Vector2(0, i * Ui.ROW), str(want[i]), 16, Palette.INK)
		if shown:
			var mark := Vector2(WANT.end.x - 15, at.y - 9 + i * Ui.ROW)
			if ok:
				Ui.tick(self, mark, Palette.GREEN)
			else:
				Ui.cross(self, mark, Palette.RED)
	Fit.end()


func _draw_line() -> void:
	Ui.steel(self, LINE)
	Fit.begin(LINE, "the line")
	Fit.text(self, Palette.titles(), Vector2(18, 193), "THE LINE", 13, Palette.LAMP_LIGHT)
	_draw_meaning()
	# The command line.
	Ui.screen(self, SLOTS)
	var bad := result.has("error") and str(result.error.kind) != "empty"
	_token_rects = []
	var x := SLOTS.position.x + 4
	Fit.text(self, Palette.mono(), Vector2(x, SLOTS.end.y - 6), "$", 16, Palette.GREEN_LIGHT)
	x += 12
	var caret_x := x
	if tokens.is_empty():
		Fit.text(self, Palette.mono(), Vector2(x + 6, SLOTS.end.y - 6), "put chips here to write the line", 16, Palette.TERM_DIM)
	for i in tokens.size():
		var token := str(tokens[i])
		var w := _token_width(token)
		var rect := Rect2(x, SLOTS.position.y + 2, w, 16)
		_token_rects.append(rect)
		var hot: bool = _hover.get("kind", "") == "token" and int(_hover.index) == i
		if hot:
			draw_rect(rect, Color(Palette.LAMP, 0.45))
		Ui.code(self, Vector2(x + 3, rect.end.y - 4), token, true)
		x += w + 1.0
		if i + 1 == caret:
			caret_x = x
	if bad:
		draw_rect(Rect2(SLOTS.position.x + 16, SLOTS.end.y - 3, x - SLOTS.position.x - 17, 1), Palette.RED_LIGHT)
	if not busy and Fit.blink(fmod(_clock, 0.9) < 0.55):
		draw_rect(Rect2(caret_x - 1, SLOTS.position.y + 3, 2, 14), Palette.GREEN_LIGHT)
	# Back, Clear, Fire.
	var count := (ticket.get("chips", []) as Array).size()
	var keys := not TouchControls.active
	for i in BUTTON_RECTS.size():
		var rect: Rect2 = BUTTON_RECTS[i]
		var hot: bool = (keys and focus == count + i) or (_hover.get("kind", "") == "button" and int(_hover.index) == i)
		var ready_to_fire: bool = BUTTONS[i] == "fire" and not tokens.is_empty() and not result.has("error")
		draw_rect(rect, Palette.LAMP_LIGHT if hot else Palette.STEEL_DARK)
		draw_rect(rect.grow(-1), Palette.RED if ready_to_fire else Palette.STEEL_DARK.lightened(0.12))
		Fit.centred(self, Palette.pixel(), rect.position.x + rect.size.x / 2.0, rect.end.y - 3, str(BUTTON_WORDS[i]), 10, Palette.CREAM if ready_to_fire or hot else Palette.STEEL_LIGHT)
	# The chips on the table.
	for i in _chip_rects.size():
		var hot: bool = (keys and focus == i) or (_hover.get("kind", "") == "chip" and int(_hover.index) == i)
		Ui.chip(self, _chip_rects[i], str(ticket.chips[i]), hot and not busy)
	# How to work the pass, if the chips left room for it.
	if not _chip_rects.is_empty() and (_chip_rects[-1] as Rect2).end.y < 244:
		Fit.text(self, Palette.pixel(), Vector2(18, 260), help_text(), 10, Palette.STEEL_LIGHT)
	Fit.end()


static func help_text() -> String:
	if TouchControls.active:
		return "Tap a chip to put it on the line. Tap it there to take it back. Then Fire."
	return "Enter puts a chip down. Backspace takes one back. , and . move the caret. F fires."


## Beside THE LINE: what the chip under the pointer (or the keys) means in
## plain words.
func _draw_meaning() -> void:
	var font := Palette.mono()
	var at := Vector2(68, 192)
	var token := ""
	var meaning := ""
	var count := (ticket.get("chips", []) as Array).size()
	if _hover.get("kind", "") == "token" and int(_hover.index) < tokens.size():
		token = str(tokens[int(_hover.index)])
		meaning = Story.meaning(token, tokens.slice(0, int(_hover.index)))
	elif _hover.get("kind", "") == "chip":
		token = str(ticket.chips[int(_hover.index)])
		meaning = Story.meaning(token, tokens.slice(0, caret))
	elif not TouchControls.active and focus < count:
		token = str(ticket.chips[focus])
		meaning = Story.meaning(token, tokens.slice(0, caret))
	elif not tokens.is_empty() and caret > 0:
		token = str(tokens[caret - 1])
		meaning = Story.meaning(token, tokens.slice(0, caret - 1))
	if token == "":
		return
	# A chip of one word is shown beside what it means; a longer one is on
	# the table to be read, so only its meaning goes here.
	var wide := 0.0
	if not token.contains(" "):
		wide = Ui.code(self, at, token, true) + 8
	Fit.text(self, font, at + Vector2(wide, 0), meaning, 16, Palette.CREAM)
