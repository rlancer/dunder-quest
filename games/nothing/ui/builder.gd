class_name Builder
extends Control

## The counter: the brief and what the scene wants along the top, the
## request slip on the left (made from the cards along the foot), and on the
## right the counter's board (the data on it, as it stands) or, once a slip
## has gone over, its response, exactly as it comes back over the wire.
##
## Every take starts from the same counter, so a request that missed changes
## nothing. Whether the response is what the scene wanted is the judge's to
## say (Judge): the right status, and where it matters, the right path and
## the right data left behind.
##
## Mouse and touch: tap a card to put it on the slip (a second method, path,
## body or header of the same name takes the place of the first), tap a line
## on the slip to take it off, tap Send. Tap the right-hand panel's tab to
## turn between the board and the response. Keys: arrows pick a card, Enter
## puts it on or takes it off, Backspace takes the last one off, S sends,
## Tab turns the panel.

signal sent(won: bool)

const TOP := Rect2(0, 0, 480, 15)
const BRIEF := Rect2(8, 16, 464, 40)
const WANT := Rect2(370, 19, 99, 34)
const SLIP := Rect2(8, 58, 230, 140)
const RIGHT := Rect2(241, 58, 231, 140)
const DESK := Rect2(8, 200, 464, 67)
const CARDS := Rect2(14, 216, 452, 50)
const FIRST_ROW := 81.0
const ROWS := 10
## Seconds between one line of a response arriving and the next.
const LINE := 0.07
const BUTTONS := ["back", "clear", "send"]
const BUTTON_RECTS := [Rect2(316, 202, 34, 12), Rect2(352, 202, 38, 12), Rect2(392, 202, 74, 12)]
const BUTTON_WORDS := ["Back", "Clear", "SEND"]

var scene: Dictionary = {}
## The cards on the slip, in the order they went on.
var cards: Array = []
## Which card (or, past the cards, which button) the keys are on.
var focus: int = 0
## The last take: Judge.judge, and how many of its response lines are in.
var result: Dictionary = {}
var arrived: int = 0
## True while the response is coming in, or once the scene's won.
var busy: bool = false
## "board" or "response": what the right-hand panel shows.
var page: String = "board"
## Takes that missed on this scene.
var fails: int = 0
## What Stu has to say about the last take (or a slip that can't go). While
## it's empty the brief shows; it clears when the slip changes.
var said: String = ""
## The hint, once two takes have missed. It stays.
var note: String = ""
var header: String = ""
var index_text: String = ""
## Takes so far in the whole episode, for the top bar.
var takes: int = 0
## The bot sets this: responses arrive at once.
var instant: bool = false

var _clock: float = 0.0
var _line_clock: float = 0.0
var _hover: Dictionary = {}
var _card_rects: Array = []
var _slip_rows: Array = []
var _won: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(s: Dictionary, episode_header: String, which: String, episode_takes: int) -> void:
	scene = s
	header = episode_header
	index_text = which
	takes = episode_takes
	cards = []
	focus = 0
	fails = 0
	busy = false
	result = {}
	arrived = 0
	page = "board"
	_won = false
	_hover = {}
	said = ""
	note = ""
	Voice.say(s.brief)
	_card_rects = []
	var x := CARDS.position.x
	var y := CARDS.position.y
	for card: String in s.cards:
		var w := Ui.chip_width(card)
		if x + w > CARDS.end.x:
			x = CARDS.position.x
			y += 17.0
		_card_rects.append(Rect2(x, y, w, 16))
		x += w + 4.0
	queue_redraw()


func par() -> int:
	return Story.par(scene)


func counter() -> Dictionary:
	return Judge.counter(scene)


## The slip the cards on it make.
func slip() -> Dictionary:
	return Http.slip(cards)


# --- What the player does ----------------------------------------------------

## Puts `card` on the slip, or takes it off if it's there. A second method,
## path or body, or a second header of the same name, takes the first's place.
func toggle(card: String) -> void:
	if busy:
		return
	if cards.has(card):
		cards.erase(card)
		Sfx.play(self, "erase")
	else:
		var kind := Http.kind(card)
		for other: String in cards.duplicate():
			var same: bool = Http.kind(other) == kind and (kind != "header" or str(Http.split_header(other)[0]) == str(Http.split_header(card)[0]))
			if same:
				cards.erase(other)
		cards.append(card)
		Sfx.play(self, "card")
	_changed()


## Takes the last card put on back off.
func back() -> void:
	if busy or cards.is_empty():
		return
	cards.pop_back()
	Sfx.play(self, "erase")
	_changed()


func clear() -> void:
	if busy or cards.is_empty():
		return
	cards = []
	Sfx.play(self, "erase")
	_changed()


func turn() -> void:
	if busy:
		return
	page = "board" if page == "response" or result.is_empty() else "response"
	Sfx.play(self, "page")
	queue_redraw()


func _changed() -> void:
	said = ""
	queue_redraw()


## Send: the slip goes over the counter, and the response comes back a line at
## a time. A slip that can't go costs nothing; Stu says why.
func send() -> void:
	if busy:
		return
	var take := Judge.judge(scene, cards)
	if take.has("refused"):
		said = Story.error_text(str(take.refused))
		Sfx.play(self, "buzz")
		queue_redraw()
		return
	result = take
	busy = true
	arrived = 0
	_line_clock = 0.0
	page = "response"
	takes += 1
	said = ""
	Sfx.play(self, "roll")
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	if busy and not _won and not result.is_empty():
		var lines: Array = result.get("lines", [])
		_line_clock += delta
		while arrived < lines.size() and (instant or _line_clock >= LINE):
			_line_clock -= 0.0 if instant else LINE
			arrived += 1
		if arrived >= lines.size() and (instant or _line_clock >= LINE * 4):
			_finish()
	queue_redraw()


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
		Sfx.play(self, "miss")
	sent.emit(won)


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
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var item := _item_at(event.position)
		_hover = item
		match str(item.get("kind", "")):
			"card":
				focus = int(item.index)
				toggle(str(scene.cards[int(item.index)]))
			"line":
				if not busy:
					cards.erase(str(item.card))
					Sfx.play(self, "erase")
					_changed()
			"button":
				focus = (scene.cards as Array).size() + int(item.index)
				_press(int(item.index))
			"turn":
				turn()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or busy:
		return
	var count := (scene.get("cards", []) as Array).size()
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
			toggle(str(scene.cards[focus]))
		else:
			_press(focus - count)
	elif event.is_action_pressed(&"erase", true):
		back()
	elif event.is_action_pressed(&"send"):
		send()
	elif event.is_action_pressed(&"turn"):
		turn()
	else:
		return
	_hover = {}
	get_viewport().set_input_as_handled()
	queue_redraw()


func _press(button: int) -> void:
	match BUTTONS[button]:
		"back":
			back()
		"clear":
			clear()
		"send":
			send()


func _item_at(at: Vector2) -> Dictionary:
	for i in _card_rects.size():
		if (_card_rects[i] as Rect2).grow(2).has_point(at):
			return {"kind": "card", "index": i}
	for i in BUTTON_RECTS.size():
		if (BUTTON_RECTS[i] as Rect2).grow(1).has_point(at):
			return {"kind": "button", "index": i}
	for row: Array in _slip_rows:
		if (row[0] as Rect2).has_point(at) and str(row[1]) != "":
			return {"kind": "line", "card": str(row[1])}
	if Rect2(RIGHT.position, Vector2(RIGHT.size.x, 14)).has_point(at):
		return {"kind": "turn"}
	return {}


# --- Drawing -----------------------------------------------------------------

func _draw() -> void:
	Fit.frame(self)
	_draw_top()
	_draw_brief()
	_draw_slip()
	_draw_right()
	_draw_desk()


func _draw_top() -> void:
	var font := Palette.pixel()
	draw_rect(TOP, Color(Palette.PLUM_DARK, 0.95))
	Fit.begin(TOP, "the top bar")
	Fit.text(self, font, Vector2(8, 11), header, 10, Palette.MUSTARD_LIGHT)
	Fit.centred(self, font, 262, 11, index_text, 10, Palette.CREAM)
	var right := "Takes %d   Cards %d   Par %d" % [takes, cards.size(), par()]
	Fit.text(self, font, Vector2(472 - Fit.width(font, right, 10), 11), right, 10, Palette.CREAM)
	Fit.end()


func _draw_brief() -> void:
	Ui.panel(self, BRIEF)
	var who := "stu" if said != "" else str(scene.brief.who)
	var face := Ui.portrait(who)
	if face != null:
		draw_texture_rect(face, Rect2(BRIEF.position.x + 3, BRIEF.position.y + 3, 34, 34), false)
	Fit.begin(BRIEF, "the brief")
	var font := Palette.mono()
	var at := Vector2(BRIEF.position.x + 42, BRIEF.position.y + 11)
	var wide := WANT.position.x - at.x - 6
	var words := said if said != "" else str(scene.brief.text)
	if busy and not _won:
		words = "Over the counter it goes..."
	# Three lines fit. If the hint won't go under the words, it goes instead.
	var hint_lines := Fit.wrap_text(font, note, 16, wide).size() if note != "" else 0
	if hint_lines > 0 and Fit.wrap_text(font, words, 16, wide).size() + hint_lines > 3:
		words = ""
	var used := Fit.para(self, font, at, words, 16, Palette.CREAM, wide, 12) if words != "" else 0
	if note != "" and not busy:
		Fit.para(self, font, at + Vector2(0, used * 12), note, 16, Palette.MUSTARD_LIGHT, wide, 12)
	Fit.end()
	# What the scene wants back.
	draw_rect(WANT, Palette.PLUM_DARK)
	draw_rect(WANT.grow(-1), Palette.TEAL)
	Fit.cover(WANT)
	Fit.begin(WANT, "what the scene wants")
	var goal: Dictionary = scene.goal
	Fit.centred(self, Palette.pixel(), WANT.get_center().x, WANT.position.y + 11, "THE SCENE WANTS", 10, Palette.CREAM)
	var status := str(int(goal.status))
	var reason := str(Http.REASONS.get(int(goal.status), ""))
	Fit.centred(self, Palette.mono(), WANT.get_center().x, WANT.position.y + 23, status, 16, Palette.MUSTARD_LIGHT)
	Fit.centred(self, Palette.pixel(), WANT.get_center().x, WANT.position.y + 32, reason, 10, Palette.CREAM)
	Fit.end()


## A panel's lines, wrapped to its width, from the first row down: [text,
## colour, card it belongs to]. Returns the rows as drawn.
func _rows(rect: Rect2, lines: Array, shown: int = -1) -> Array:
	var font := Palette.mono()
	var wide := rect.size.x - 12
	var rows: Array = []
	for line: Array in lines:
		var rest := str(line[0])
		if rest == "":
			rows.append(["", line[1], line[2]])
			continue
		while rest != "":
			var cut := rest.length()
			while cut > 1 and Fit.width(font, rest.left(cut), 16) > wide:
				cut -= 1
			rows.append([rest.left(cut), line[1], line[2]])
			rest = rest.substr(cut)
	if shown >= 0:
		rows = rows.slice(0, shown)
	var drawn: Array = []
	for i in rows.size():
		if i == ROWS - 1 and rows.size() > ROWS:
			Fit.text(self, font, Vector2(rect.position.x + 6, FIRST_ROW + i * Ui.ROW), "+ %d more lines" % (rows.size() - i), 16, Palette.DIM)
			break
		var y := FIRST_ROW + i * Ui.ROW
		Fit.text(self, font, Vector2(rect.position.x + 6, y), str(rows[i][0]), 16, rows[i][1])
		drawn.append([Rect2(rect.position.x + 2, y - 9, rect.size.x - 4, Ui.ROW), str(rows[i][2])])
	return drawn


## The request slip: what goes over the counter, as it goes.
func _draw_slip() -> void:
	Ui.paper(self, SLIP)
	Fit.begin(SLIP, "the request slip")
	Ui.head(self, SLIP, "REQUEST SLIP", Palette.BRICK, "tap a line to take it off" if TouchControls.active and not cards.is_empty() else "")
	var s := slip()
	var c := counter()
	if cards.is_empty():
		Fit.para(self, Palette.mono(), Vector2(SLIP.position.x + 6, FIRST_ROW), "Put cards on: a method, a path, and whatever else the counter needs.", 16, Palette.DIM, SLIP.size.x - 12, Ui.ROW)
		_slip_rows = []
		Fit.end()
		return
	var lines: Array = []
	var first := "%s %s HTTP/1.1" % [s.method if s.method != "" else "___", s.path if s.path != "" else "___"]
	var last_of_two := ""
	for card: String in cards:
		if Http.kind(card) in ["method", "path"]:
			last_of_two = card
	lines.append([first, Palette.INK, last_of_two])
	lines.append(["Host: %s" % c.get("host", ""), Palette.PAPER_LINE, ""])
	for card: String in s.headers:
		lines.append([card, Palette.BLUE, card])
	if str(s.body) != "":
		lines.append(["", Palette.INK, ""])
		lines.append([str(s.body), Palette.BRICK, str(s.body)])
	_slip_rows = _rows(SLIP, lines)
	Fit.end()


## The right-hand panel: the counter's board, or its last response.
func _draw_right() -> void:
	Ui.glass(self, RIGHT)
	Fit.begin(RIGHT, "the counter")
	var c := counter()
	var showing := page if not result.is_empty() else "board"
	var other := "" if result.is_empty() else ("board" if showing == "response" else "response")
	var tab := ("%s: %s" % ["Tab" if not TouchControls.active else "tap", other]) if other != "" and not busy else ""
	Ui.head(self, RIGHT, "RESPONSE" if showing == "response" else "THE BOARD: %s" % c.get("host", ""), Palette.PLUM if showing == "board" else Palette.TEAL, tab)
	if showing == "response":
		var lines: Array = []
		var all: Array = result.get("lines", [])
		var status := int(result.response.status)
		var won := bool(result.get("won", false))
		for i in all.size():
			var text := str(all[i])
			var color := Palette.GLASS_TEXT
			if i == 0:
				color = Palette.GREEN_LIGHT if status < 300 else (Palette.MUSTARD_LIGHT if status < 400 else Palette.BRICK_LIGHT)
			elif text.contains(": ") and not text.begins_with("{") and not text.begins_with("["):
				color = Palette.TEAL_LIGHT
			lines.append([text, color, ""])
		_rows(RIGHT, lines, -1 if not busy or _won else arrived)
		if not busy and not won and fails > 0:
			pass
	else:
		_rows(RIGHT, board_lines(), -1)
	Fit.end()


## What's on the counter, as the scene sets it out: each document and each
## item at its own path (with its ETag, if the counter keeps them), and what
## it holds.
func board_lines() -> Array:
	var c := counter()
	var st := Judge.start(scene)
	var tagged := bool(c.get("etag", false))
	var out: Array = []
	for name: String in (c.routes as Dictionary):
		var route: Dictionary = c.routes[name]
		var value: Variant = (st.items as Dictionary).get(name, [])
		if str(route.type) == "doc":
			out.append(["/%s" % name, Palette.MUSTARD_LIGHT, ""])
			out.append([Wire.write(value), Palette.GLASS_TEXT, ""])
			continue
		out.append(["/%s%s" % [name, "  ETag: %s" % Http.etag(st, name) if tagged else ""], Palette.MUSTARD_LIGHT, ""])
		for item: Dictionary in value:
			var key := "%s/%d" % [name, int(item.id)]
			out.append([" /%s%s" % [key, "  ETag: %s" % Http.etag(st, key) if tagged else ""], Palette.TEAL_LIGHT, ""])
			out.append([" " + Wire.write(item), Palette.GLASS_TEXT, ""])
	return out


func _draw_desk() -> void:
	Ui.panel(self, DESK)
	Fit.begin(DESK, "the cards")
	Fit.text(self, Palette.titles(), Vector2(14, 213), "CARDS", 11, Palette.MUSTARD_LIGHT)
	_draw_meaning()
	var count := (scene.get("cards", []) as Array).size()
	var keys := not TouchControls.active
	for i in BUTTON_RECTS.size():
		var rect: Rect2 = BUTTON_RECTS[i]
		var hot: bool = (keys and focus == count + i) or (_hover.get("kind", "") == "button" and int(_hover.index) == i)
		var ready: bool = BUTTONS[i] == "send" and not busy and Http.refuse(slip()) == ""
		draw_rect(rect, Palette.MUSTARD_LIGHT if hot else Palette.PLUM_DARK)
		draw_rect(rect.grow(-1), Palette.BRICK if ready else Palette.PLUM_DARK.lightened(0.12))
		Fit.centred(self, Palette.pixel(), rect.position.x + rect.size.x / 2.0, rect.end.y - 3, str(BUTTON_WORDS[i]), 10, Palette.CREAM if ready or hot else Palette.PLUM_LIGHT)
	for i in _card_rects.size():
		var card := str(scene.cards[i])
		var hot: bool = (keys and focus == i) or (_hover.get("kind", "") == "card" and int(_hover.index) == i)
		Ui.chip(self, _card_rects[i], card, hot and not busy, cards.has(card))
	if not _card_rects.is_empty() and (_card_rects[-1] as Rect2).end.y < 250:
		Fit.text(self, Palette.pixel(), Vector2(14, 262), help_text(), 10, Palette.PLUM_LIGHT)
	Fit.end()


static func help_text() -> String:
	if TouchControls.active:
		return "Tap a card to put it on the slip, a line to take it off. Then Send."
	return "Arrows pick a card. Enter puts it on. Backspace: back. S sends."


## Beside CARDS: what the card under the pointer (or the keys) means.
func _draw_meaning() -> void:
	var count := (scene.get("cards", []) as Array).size()
	var card := -1
	if _hover.get("kind", "") == "card":
		card = int(_hover.index)
	elif not TouchControls.active and focus < count:
		card = focus
	if card < 0 or card >= count:
		return
	Fit.text(self, Palette.mono(), Vector2(56, 212), Story.meaning(str(scene.cards[card])), 16, Palette.CREAM)
