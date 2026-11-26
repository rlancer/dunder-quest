class_name Builder
extends Control

## The writers' room: the locked script on the left (lines can't move, but
## each line with a hook can take a cue card), the brief and the table read
## on the right (the order the lines have to air in), the event loop under
## them, and the cue cards along the foot. Roll tape and the script plays on
## the event loop (Loop, a real engine's rules), step by step: the line that
## runs lights up on the page, the queues fill and empty, and each line that
## airs is ticked or crossed against the table read.
##
## Nothing airs before the take: the script on the page is the truth, and
## working out the order it plays in is the game.
##
## Mouse and touch: tap a line with a hook to pick it, tap a card to put it
## there (or the card, then the line), tap a cued line to take its card off,
## then Roll tape. Keys: up and down pick a line, left and right pick a card,
## Enter puts it down, Backspace takes it off, R rolls tape.

signal rolled(won: bool)

const TOP := Rect2(0, 0, 480, 15)
const SCRIPT := Rect2(8, 17, 244, 194)
const BRIEF := Rect2(255, 17, 217, 56)
const TABLE := Rect2(255, 75, 217, 88)
const LOOP := Rect2(255, 165, 217, 46)
const DESK := Rect2(8, 213, 464, 54)
const CHIPS := Rect2(14, 229, 452, 37)
## The first row of code, and how many rows the page shows.
const FIRST_ROW := 41.0
const ROWS := 14
const CODE_X := 24.0
const INDENT := 9.0
## Seconds a step of the take stays up: a line airing, and anything else.
const AIR := 0.5
const STEP := 0.16
const BUTTONS := ["off", "clear", "roll"]
const BUTTON_RECTS := [Rect2(316, 215, 34, 12), Rect2(352, 215, 38, 12), Rect2(392, 215, 74, 12)]
const BUTTON_WORDS := ["Off", "Clear", "ROLL TAPE"]
## A queue's pills show this many letters of a label.
const PILL := 9

var scene: Dictionary = {}
## Slot id -> cue, and slot id -> which card on the table it is.
var cues: Dictionary = {}
var cards: Dictionary = {}
## Every hook on the page, in reading order (Loop.slots).
var slots: Array = []
## The hook picked (an index into `slots`), and the card picked to go on one
## (-1 for none).
var pick: int = 0
var armed: int = -1
## Which card (or, past the cards, which button) the keys are on.
var focus: int = 0
## The page as it stands: Loop.lines of the script with its cues on.
var page: Array = []
var scroll: int = 0
## The take: Judge.judge, and how far through its trace it has played.
var result: Dictionary = {}
var playing: bool = false
var step: int = 0
var aired: int = 0
## Takes that missed on this scene.
var fails: int = 0
## While the take plays, or once the scene's won.
var busy: bool = false
## What Stu has to say about the last take (or a card that won't go). While
## it's empty the brief shows; it clears when the cues change.
var said: String = ""
## The hint, once two takes have missed. It stays.
var note: String = ""
var header: String = ""
var index_text: String = ""
## Takes so far in the whole episode, for the top bar.
var takes: int = 0
## The bot sets this: the take plays without waiting.
var instant: bool = false

var _clock: float = 0.0
var _step_clock: float = 0.0
var _hover: Dictionary = {}
var _chip_rects: Array = []
var _row_slots: Array = []
var _won: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(s: Dictionary, episode_header: String, which: String, episode_takes: int) -> void:
	scene = s
	header = episode_header
	index_text = which
	takes = episode_takes
	cues = {}
	cards = {}
	slots = Loop.slots(s.script)
	pick = 0
	armed = -1
	focus = 0
	scroll = 0
	fails = 0
	busy = false
	playing = false
	result = {}
	step = 0
	aired = 0
	_won = false
	_hover = {}
	said = ""
	note = ""
	Voice.say(s.brief)
	_chip_rects = []
	var x := CHIPS.position.x
	var y := CHIPS.position.y
	for cue: String in s.cues:
		var w := Ui.chip_width(cue)
		if x + w > CHIPS.end.x:
			x = CHIPS.position.x
			y += 19.0
		_chip_rects.append(Rect2(x, y, w, 17))
		x += w + 5.0
	_refresh()


func par() -> int:
	return Story.par(scene)


func used(card: int) -> bool:
	return cards.values().has(card)


func picked_slot() -> String:
	return str(slots[pick].id) if pick >= 0 and pick < slots.size() else ""


# --- What the player does ----------------------------------------------------

## Puts card `card` on hook `slot`. False if it won't go.
func place(card: int, slot: String = "") -> bool:
	if busy or card < 0 or card >= (scene.cues as Array).size():
		return false
	if slot == "":
		slot = picked_slot()
	if slot == "":
		return _refuse("noslot")
	if used(card):
		# Already down somewhere: it moves here.
		for other: String in cards.keys():
			if int(cards[other]) == card:
				cues.erase(other)
				cards.erase(other)
	if cues.has(slot):
		return _refuse("taken")
	var cue := str(scene.cues[card])
	var why := Loop.refuse(scene.script, slot, cue)
	if why != "":
		return _refuse(why)
	cues[slot] = cue
	cards[slot] = card
	armed = -1
	Sfx.play(self, "card")
	_refresh()
	return true


## Takes the card off hook `slot`.
func take_off(slot: String) -> void:
	if busy or not cues.has(slot):
		return
	cues.erase(slot)
	cards.erase(slot)
	Sfx.play(self, "erase")
	_refresh()


func clear() -> void:
	if busy or cues.is_empty():
		return
	cues = {}
	cards = {}
	Sfx.play(self, "erase")
	_refresh()


func move_pick(by: int) -> void:
	if busy or slots.is_empty():
		return
	pick = (pick + by + slots.size()) % slots.size()
	_follow()
	queue_redraw()


func _refuse(why: String) -> bool:
	said = Story.error_text(why)
	Sfx.play(self, "buzz")
	queue_redraw()
	return false


## Roll tape: the script plays on the event loop, and the lines that air are
## checked against the table read as they go.
func roll() -> void:
	if busy:
		return
	result = Judge.judge(scene, cues)
	busy = true
	playing = true
	step = 0
	aired = 0
	_step_clock = 0.0
	takes += 1
	said = ""
	Sfx.play(self, "roll")
	queue_redraw()


func _refresh() -> void:
	page = Loop.lines(Loop.build(scene.script, cues))
	said = ""
	result = {}
	playing = false
	aired = 0
	_follow()
	queue_redraw()


## The first row of the page a hook's lines are on.
func slot_row(slot: String) -> int:
	for i in page.size():
		if str(page[i].slot) == slot:
			return i
	return 0


## Scrolls the page so the picked hook is on it.
func _follow() -> void:
	var row := slot_row(picked_slot())
	var last := row
	for i in range(row, page.size()):
		if str(page[i].slot) == picked_slot():
			last = i
	if row < scroll:
		scroll = row
	elif last >= scroll + ROWS:
		scroll = mini(row, last - ROWS + 1)
	scroll = clampi(scroll, 0, maxi(page.size() - ROWS, 0))


func _process(delta: float) -> void:
	_clock += delta
	if playing:
		var trace: Array = result.get("trace", [])
		_step_clock += delta
		while step < trace.size():
			var hold := AIR if str(trace[step].kind) == "log" else STEP
			if not instant and _step_clock < hold:
				break
			_step_clock -= hold if not instant else 0.0
			step += 1
			if step < trace.size() and str(trace[step].kind) == "log":
				var ok := aired < (result.rows as Array).size() and bool(result.rows[aired].ok)
				aired += 1
				Sfx.play(self, "air" if ok else "miss")
				_show_running()
		if step >= trace.size() - 1 and (instant or _step_clock >= AIR):
			step = maxi(trace.size() - 1, 0)
			playing = false
			_finish()
	queue_redraw()


## Keeps the line that's airing on the page.
func _show_running() -> void:
	var row := running_row()
	if row >= 0 and (row < scroll or row >= scroll + ROWS):
		scroll = clampi(row - ROWS / 2, 0, maxi(page.size() - ROWS, 0))


## The row of the line airing right now, or -1.
func running_row() -> int:
	var trace: Array = result.get("trace", [])
	if not playing or step >= trace.size() or str(trace[step].kind) != "log":
		return -1
	var looking := "log(%s);" % JSON.stringify(str(trace[step].log))
	for i in page.size():
		if str(page[i].text) == looking:
			return i
	return -1


func _finish() -> void:
	var won := bool(result.get("won", false))
	if won:
		_won = true
		Sfx.play(self, "applause")
	else:
		busy = false
		fails += 1
		said = feedback()
		note = "Hint: %s" % scene.hint if fails >= 2 else ""
		Sfx.play(self, "buzz")
	rolled.emit(won)


## What Stu says about a take that missed.
func feedback() -> String:
	var lines := Story.stock(str(result.get("why", "")))
	if lines.is_empty():
		return ""
	return Judge.fill(str(lines[(fails - 1) % lines.size()]), result)


# --- Input -------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var item := _item_at(event.position)
		if item != _hover:
			_hover = item
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if SCRIPT.has_point(event.position):
				scroll = clampi(scroll + (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 0, maxi(page.size() - ROWS, 0))
				queue_redraw()
				accept_event()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		var item := _item_at(event.position)
		_hover = item
		match str(item.get("kind", "")):
			"chip":
				_tap_chip(int(item.index))
			"slot":
				_tap_slot(str(item.id))
			"button":
				focus = (scene.cues as Array).size() + int(item.index)
				_press(int(item.index))
			"scroll":
				scroll = clampi(scroll + int(item.by), 0, maxi(page.size() - ROWS, 0))
				queue_redraw()
		accept_event()


func _tap_chip(card: int) -> void:
	if busy:
		return
	focus = card
	var slot := picked_slot()
	if armed == card:
		armed = -1
	elif slot != "" and not cues.has(slot) and not used(card):
		place(card, slot)
		return
	else:
		armed = card
		Sfx.play(self, "tick")
	queue_redraw()


func _tap_slot(slot: String) -> void:
	if busy:
		return
	for i in slots.size():
		if str(slots[i].id) == slot:
			pick = i
	if cues.has(slot):
		take_off(slot)
	elif armed >= 0:
		place(armed, slot)
	else:
		Sfx.play(self, "tick")
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or busy:
		return
	var count := (scene.get("cues", []) as Array).size()
	if event.is_action_pressed(&"move_right", true):
		focus = (focus + 1) % (count + BUTTONS.size())
	elif event.is_action_pressed(&"move_left", true):
		focus = (focus - 1 + count + BUTTONS.size()) % (count + BUTTONS.size())
	elif event.is_action_pressed(&"move_up", true):
		move_pick(-1)
	elif event.is_action_pressed(&"move_down", true):
		move_pick(1)
	elif event.is_action_pressed(&"confirm"):
		if focus < count:
			place(focus)
		else:
			_press(focus - count)
	elif event.is_action_pressed(&"erase", true):
		take_off(picked_slot())
	elif event.is_action_pressed(&"roll"):
		roll()
	else:
		return
	_hover = {}
	get_viewport().set_input_as_handled()
	queue_redraw()


func _press(button: int) -> void:
	match BUTTONS[button]:
		"off":
			take_off(picked_slot())
		"clear":
			clear()
		"roll":
			roll()


func _item_at(at: Vector2) -> Dictionary:
	for i in _chip_rects.size():
		if (_chip_rects[i] as Rect2).grow(2).has_point(at):
			return {"kind": "chip", "index": i}
	for i in BUTTON_RECTS.size():
		if (BUTTON_RECTS[i] as Rect2).grow(1).has_point(at):
			return {"kind": "button", "index": i}
	if SCRIPT.has_point(at):
		if page.size() > ROWS and at.x > SCRIPT.end.x - 12:
			return {"kind": "scroll", "by": -3 if at.y < SCRIPT.get_center().y else 3}
		var row := int(floor((at.y - (SCRIPT.position.y + 30)) / Ui.ROW)) + scroll
		if row >= scroll and row < page.size() and row < scroll + ROWS and str(page[row].slot) != "":
			return {"kind": "slot", "id": str(page[row].slot)}
	return {}


# --- Drawing -----------------------------------------------------------------

func _draw() -> void:
	Fit.frame(self)
	_draw_top()
	_draw_script()
	_draw_brief()
	_draw_table()
	_draw_loop()
	_draw_desk()


func _draw_top() -> void:
	var font := Palette.pixel()
	draw_rect(TOP, Color(Palette.PLUM_DARK, 0.95))
	Fit.begin(TOP, "the top bar")
	Fit.text(self, font, Vector2(8, 11), header, 10, Palette.MUSTARD_LIGHT)
	Fit.centred(self, font, 262, 11, index_text, 10, Palette.CREAM)
	var right := "Takes %d   Cards %d   Par %d" % [takes, cues.size(), par()]
	Fit.text(self, font, Vector2(472 - Fit.width(font, right, 10), 11), right, 10, Palette.CREAM)
	Fit.end()


## The script: every line as it stands, with the hooks a card can go on.
func _draw_script() -> void:
	Ui.paper(self, SCRIPT)
	Fit.begin(SCRIPT, "the script")
	Ui.head(self, SCRIPT, "SCRIPT.JS · LOCKED", Palette.BRICK, "%d LINES" % page.size() if page.size() > ROWS else "")
	var picked := picked_slot()
	var lit := running_row()
	_row_slots = []
	for r in mini(ROWS, page.size() - scroll):
		var i := r + scroll
		var line: Dictionary = page[i]
		var y := FIRST_ROW + r * Ui.ROW
		var band := Rect2(SCRIPT.position.x + 12, y - 9, SCRIPT.size.x - 16, Ui.ROW)
		var slot := str(line.slot)
		var hot: bool = _hover.get("kind", "") == "slot" and str(_hover.id) == slot
		if i == lit:
			draw_rect(band, Color(Palette.MUSTARD_LIGHT, 0.8))
		elif bool(line.cue):
			draw_rect(band, Color(Palette.TEAL_LIGHT, 0.35))
		if slot != "" and slot == picked and not busy:
			draw_rect(Rect2(band.position.x, band.position.y, 2, band.size.y), Palette.BRICK)
			draw_rect(band, Color(Palette.BRICK_LIGHT, 0.12))
		elif hot and not busy:
			draw_rect(band, Color(Palette.MUSTARD, 0.18))
		# A hook on the first line of every slot.
		if slot != "" and (i == 0 or str(page[i - 1].slot) != slot):
			_hook(Vector2(SCRIPT.position.x + 14, y - 6), cues.has(slot), slot == picked and not busy)
		var x := SCRIPT.position.x + CODE_X + int(line.indent) * INDENT
		var faded := bool(line.header)
		Ui.code(self, Vector2(x, y), str(line.text), false, 0.55 if faded else 1.0)
	# A scroll bar, if the page runs on.
	if page.size() > ROWS:
		var track := Rect2(SCRIPT.end.x - 6, SCRIPT.position.y + 16, 3, SCRIPT.size.y - 22)
		draw_rect(track, Palette.PAPER_DARK)
		var share := float(ROWS) / page.size()
		draw_rect(Rect2(track.position.x, track.position.y + track.size.y * float(scroll) / page.size(), 3, track.size.y * share), Palette.BRICK)
	Fit.end()


## A hook: where a cue card can go. Filled when one has.
func _hook(at: Vector2, full: bool, picked: bool) -> void:
	var color := Palette.BRICK if picked else (Palette.TEAL if full else Palette.PAPER_LINE)
	draw_rect(Rect2(at.x, at.y, 6, 6), color)
	draw_rect(Rect2(at.x + 1, at.y + 1, 4, 4), color if full else Palette.PAPER)


func _draw_brief() -> void:
	Ui.panel(self, BRIEF)
	var who := "stu" if said != "" else str(scene.brief.who)
	var face := Ui.portrait(who)
	if face != null:
		draw_texture_rect(face, Rect2(BRIEF.position.x + 3, BRIEF.position.y + 3, 28, 28), false)
	Fit.begin(BRIEF, "the brief")
	var font := Palette.mono()
	var at := Vector2(BRIEF.position.x + 35, BRIEF.position.y + 11)
	var wide := BRIEF.size.x - 40
	var words := said if said != "" else str(scene.brief.text)
	if playing:
		words = "Rolling..."
	# Four lines fit. If the hint won't go under the words, it goes instead.
	var hint_lines := Fit.wrap_text(font, note, 16, wide).size() if note != "" else 0
	if hint_lines > 0 and Fit.wrap_text(font, words, 16, wide).size() + hint_lines > 4:
		words = ""
	var used_lines := Fit.para(self, font, at, words, 16, Palette.CREAM, wide, 12) if words != "" else 0
	if note != "" and not playing:
		Fit.para(self, font, at + Vector2(0, used_lines * 12), note, 16, Palette.MUSTARD_LIGHT, wide, 12)
	Fit.end()


## The table read: the lines in the order they have to air.
func _draw_table() -> void:
	Ui.paper(self, TABLE)
	Fit.begin(TABLE, "the table read")
	Ui.head(self, TABLE, "TABLE READ", Palette.TEAL, "ON AIR" if playing else "")
	var want: Array = scene.get("want", [])
	var rows: Array = result.get("rows", [])
	var out: Array = result.get("out", [])
	var at := Vector2(TABLE.position.x + 6, TABLE.position.y + 24)
	var mono := Palette.mono()
	for i in want.size():
		var y := at.y + i * Ui.ROW
		var shown := i < aired and i < rows.size()
		var ok: bool = shown and bool(rows[i].ok)
		if shown:
			draw_rect(Rect2(TABLE.position.x + 1, y - 9, TABLE.size.x - 4, Ui.ROW), Color(Palette.GREEN_LIGHT if ok else Palette.BRICK_LIGHT, 0.3))
		var n := "%d" % (i + 1)
		Fit.text(self, mono, Vector2(at.x, y), n, 16, Palette.DIM)
		# What aired in this spot, if it isn't what the table read has.
		var text := str(want[i])
		var color := Palette.INK
		if shown and not ok and i < out.size():
			text = str(out[i])
			color = Palette.BRICK
		Fit.text(self, mono, Vector2(at.x + 12, y), text, 16, color)
		if shown:
			var mark := Vector2(TABLE.end.x - 15, y - 8)
			if ok:
				Ui.tick(self, mark, Palette.GREEN)
			else:
				Ui.cross(self, mark, Palette.BRICK)
	Fit.end()


## The event loop: what's running, the microtask line, the timers, the clock.
func _draw_loop() -> void:
	Ui.glass(self, LOOP)
	Fit.begin(LOOP, "the event loop")
	var trace: Array = result.get("trace", [])
	var now := {}
	if not trace.is_empty() and (playing or busy or not result.is_empty()):
		now = trace[mini(step, trace.size() - 1)]
	var clock := "t = %d ms" % int(now.get("now", 0.0)) if not now.is_empty() else "t = 0 ms"
	Ui.head(self, LOOP, "EVENT LOOP", Palette.PLUM, clock)
	var pixel := Palette.pixel()
	var lanes := [["NOW", Palette.MUSTARD], ["MICRO", Palette.TEAL_LIGHT], ["TIMERS", Palette.BRICK_LIGHT]]
	for l in lanes.size():
		var y: float = LOOP.position.y + 23 + l * 10
		Fit.text(self, pixel, Vector2(LOOP.position.x + 5, y), str(lanes[l][0]), 10, Palette.GLASS_DIM)
		var items: Array = []
		match l:
			0:
				var running := str(now.get("running", ""))
				if now.is_empty():
					running = ""
				elif running == "":
					running = "nothing"
				if running != "":
					items.append(running)
			1:
				for label: String in now.get("micro", PackedStringArray()):
					items.append(label)
			2:
				for t: Array in now.get("timers", []):
					items.append("%s @%d" % [_short(str(t[0])), int(t[1])])
		_pills(Vector2(LOOP.position.x + 44, y), items, lanes[l][1])
	Fit.end()


static func _short(label: String) -> String:
	return label if label.length() <= PILL else label.left(PILL - 1).strip_edges() + "…"


## A queue's labels in a row, as many as fit; "+N" for the rest.
func _pills(at: Vector2, items: Array, color: Color) -> void:
	var pixel := Palette.pixel()
	var x := at.x
	var end := LOOP.end.x - 6
	for i in items.size():
		var label := _short(str(items[i])) if not str(items[i]).contains("@") else str(items[i])
		var w := Fit.width(pixel, label, 10) + 6
		var rest := items.size() - i
		if x + w > end - (16 if rest > 1 else 0):
			Fit.text(self, pixel, Vector2(x, at.y), "+%d" % rest, 10, color)
			return
		draw_rect(Rect2(x, at.y - 8, w, 10), Color(color, 0.22))
		Fit.text(self, pixel, Vector2(x + 3, at.y), label, 10, color)
		x += w + 3


func _draw_desk() -> void:
	Ui.panel(self, DESK)
	Fit.begin(DESK, "the cue cards")
	Fit.text(self, Palette.titles(), Vector2(14, 226), "CUE CARDS", 11, Palette.MUSTARD_LIGHT)
	_draw_meaning()
	var count := (scene.get("cues", []) as Array).size()
	var keys := not TouchControls.active
	for i in BUTTON_RECTS.size():
		var rect: Rect2 = BUTTON_RECTS[i]
		var hot: bool = (keys and focus == count + i) or (_hover.get("kind", "") == "button" and int(_hover.index) == i)
		var ready_to_roll: bool = BUTTONS[i] == "roll" and not busy
		draw_rect(rect, Palette.MUSTARD_LIGHT if hot else Palette.PLUM_DARK)
		draw_rect(rect.grow(-1), Palette.BRICK if ready_to_roll else Palette.PLUM_DARK.lightened(0.12))
		Fit.centred(self, Palette.pixel(), rect.position.x + rect.size.x / 2.0, rect.end.y - 3, str(BUTTON_WORDS[i]), 10, Palette.CREAM if ready_to_roll or hot else Palette.PLUM_LIGHT)
	for i in _chip_rects.size():
		var hot: bool = (keys and focus == i) or (_hover.get("kind", "") == "chip" and int(_hover.index) == i) or armed == i
		Ui.chip(self, _chip_rects[i], str(scene.cues[i]), hot and not busy, used(i))
	if not _chip_rects.is_empty() and (_chip_rects[-1] as Rect2).end.y < 248:
		Fit.text(self, Palette.pixel(), Vector2(14, 262), help_text(), 10, Palette.PLUM_LIGHT)
	Fit.end()


static func help_text() -> String:
	if TouchControls.active:
		return "Tap a line with a hook, then a card. Tap a cued line to take it off."
	return "Up/down: a line. Left/right: a card. Enter puts it on. R rolls tape."


## Beside CUE CARDS: what the card under the pointer (or the keys) does.
func _draw_meaning() -> void:
	var count := (scene.get("cues", []) as Array).size()
	var card := -1
	if _hover.get("kind", "") == "chip":
		card = int(_hover.index)
	elif armed >= 0:
		card = armed
	elif not TouchControls.active and focus < count:
		card = focus
	if card < 0 or card >= count:
		return
	Fit.text(self, Palette.mono(), Vector2(82, 225), Story.meaning(str(scene.cues[card])), 16, Palette.CREAM)
