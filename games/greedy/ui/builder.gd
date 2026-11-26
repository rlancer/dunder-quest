class_name Builder
extends Control

## The Sheriff's desk: the brief, the lineup, and the wanted poster being
## written. Chips go onto the poster at the caret; every line of the lineup
## lights up at once with what the pattern matches (Rx, a real regex
## engine). Who that catches is for the player to read off: the verdicts
## only come when they draw.
##
## Mouse and touch: tap a chip to put it down, tap one on the poster to take
## it back, tap Draw. Keys: arrows pick a chip, Enter puts it down,
## Backspace takes one back, comma and full stop move the caret, D draws.

signal drew(won: bool)

const TOP := Rect2(0, 0, 480, 15)
const BRIEF := Rect2(8, 16, 464, 50)
const LINEUP := Rect2(8, 68, 464, 108)
const POSTER := Rect2(8, 178, 464, 88)
const SLOTS := Rect2(16, 196, 330, 20)
const CHIPS := Rect2(16, 221, 448, 42)
const ROW := 15.0
## Seconds between one line's verdict and the next when the Sheriff draws.
const REVEAL := 0.17
const BUTTONS := ["erase", "clear", "draw"]
const BUTTON_RECTS := [Rect2(350, 196, 34, 20), Rect2(386, 196, 36, 20), Rect2(424, 196, 40, 20)]
const BUTTON_WORDS := ["Back", "Clear", "DRAW!"]
const VERDICTS := {
	"": "", "walks": "got away", "innocent": "arrested!", "more": "too much", "less": "too little",
	"wrong": "wrong part", "nogroup": "no group",
}

var poster: Dictionary = {}
var tokens: Array = []
var caret: int = 0
## Which chip (or, past the chips, which button) the keys are on.
var focus: int = 0
## What the pattern makes of the lineup right now (Judge.judge), or {}.
var result: Dictionary = {}
## True once the Sheriff has drawn on this pattern: the verdicts show.
var judged: bool = false
var revealed: int = 0
## Draws that missed on this poster.
var fails: int = 0
## While the verdicts are coming in, or once the poster is won.
var busy: bool = false
## What the Kid has to say about the last draw (or a poster that can't be
## drawn on). While it's empty the brief shows; it clears when the poster
## is changed.
var said: String = ""
## The hint, once two draws have missed. It stays.
var note: String = ""
var header: String = ""
var index_text: String = ""
## Draws so far in the whole job, for the top bar.
var draws: int = 0
## The bot sets this: no waiting between verdicts.
var instant: bool = false

var _clock: float = 0.0
var _reveal_clock: float = 0.0
var _hover: Dictionary = {}
var _chip_rects: Array = []
var _token_rects: Array = []
var _won: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(p: Dictionary, job_header: String, which: String, job_draws: int) -> void:
	poster = p
	header = job_header
	index_text = which
	draws = job_draws
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
	return Story.par(poster)


# --- What the player does ----------------------------------------------------

## Puts `chip` on the poster at the caret. False if there's no room.
func place(chip: String) -> bool:
	if busy:
		return false
	if _slots_width(tokens) + _token_width(chip) + 1.0 > SLOTS.size.x - 8.0:
		said = "That poster's full, Sheriff. Take something off it first."
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


## The Sheriff draws: the poster is tried on every line, one at a time.
func draw_now() -> void:
	if busy:
		return
	if tokens.is_empty() or result.has("error"):
		said = Story.error_text(result.get("error", {"error": "empty"}))
		Sfx.play(self, "buzz")
		queue_redraw()
		return
	busy = true
	judged = true
	revealed = 0
	_reveal_clock = 0.0
	draws += 1
	Sfx.play(self, "draw")
	queue_redraw()


func _judge() -> void:
	result = Judge.judge(poster, tokens) if not tokens.is_empty() else {}
	judged = false
	revealed = 0
	said = ""
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	if busy and judged and not _won:
		_reveal_clock += delta
		var rows: Array = result.get("rows", [])
		while revealed < rows.size() and (instant or _reveal_clock >= REVEAL):
			_reveal_clock -= REVEAL
			var r: Dictionary = rows[revealed]
			var want := bool(poster.lines[revealed].want)
			Sfx.play(self, ("shot" if want else "tip") if r.ok else "miss")
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
		note = "Hint: %s" % poster.hint if fails >= 2 else ""
		Sfx.play(self, "buzz")
	drew.emit(won)


## What the Kid says about the first line the poster got wrong.
func feedback() -> String:
	var i := Judge.first_wrong(result)
	if i < 0:
		return ""
	var line: Dictionary = poster.lines[i]
	var r: Dictionary = result.rows[i]
	var lines := Story.stock(str(r.why))
	if lines.is_empty():
		return ""
	var template := str(lines[(fails - 1) % lines.size()])
	return template.replace("{text}", str(line.text)).replace("{got}", Judge.got(line, r)).replace("{take}", str(line.get("take", "")))


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
				place(str(poster.chips[int(item.index)]))
			"token":
				take_back(int(item.index))
			"button":
				focus = (poster.chips as Array).size() + int(item.index)
				_press(int(item.index))
			"slots":
				caret = int(item.index)
				queue_redraw()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or busy:
		return
	var count := (poster.get("chips", []) as Array).size()
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
			place(str(poster.chips[focus]))
		else:
			_press(focus - count)
	elif event.is_action_pressed(&"erase", true):
		erase()
	elif event.is_action_pressed(&"caret_left", true):
		move_caret(-1)
	elif event.is_action_pressed(&"caret_right", true):
		move_caret(1)
	elif event.is_action_pressed(&"draw"):
		draw_now()
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
		"draw":
			draw_now()


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
	_draw_lineup()
	_draw_poster()


func _draw_top() -> void:
	var font := Palette.pixel()
	draw_rect(TOP, Color(Palette.WOOD_DARK, 0.94))
	Fit.begin(TOP, "the top bar")
	Fit.text(self, font, Vector2(8, 11), header, 10, Palette.GOLD_LIGHT)
	Fit.centred(self, font, 250, 11, index_text, 10, Palette.CREAM)
	var right := "Draws %d   Chips %d   Par %d" % [draws, tokens.size(), par()]
	Fit.text(self, font, Vector2(472 - Fit.width(font, right, 10), 11), right, 10, Palette.CREAM)
	Fit.end()


func _draw_brief() -> void:
	Ui.wood(self, BRIEF)
	var face := Ui.portrait("kid" if said != "" else str(poster.brief.who))
	if face != null:
		draw_texture_rect(face, Rect2(BRIEF.position.x + 2, BRIEF.position.y + 1, 48, 48), false)
	Fit.begin(BRIEF, "the brief")
	var font := Palette.mono()
	var at := Vector2(BRIEF.position.x + 56, BRIEF.position.y + 11)
	var wide := BRIEF.size.x - 62
	var words := said if said != "" else str(poster.brief.text)
	# Four lines fit. If the hint won't go under the words, it goes instead of
	# them: the line-up already shows which line went wrong.
	var hint_lines := Fit.wrap_text(font, note, 16, wide).size() if note != "" else 0
	if hint_lines > 0 and Fit.wrap_text(font, words, 16, wide).size() + hint_lines > 4:
		words = ""
	var used := Fit.para(self, font, at, words, 16, Palette.CREAM, wide, 12) if words != "" else 0
	if note != "":
		Fit.para(self, font, at + Vector2(0, used * 12), note, 16, Palette.GOLD_LIGHT, wide, 12)
	Fit.end()


func _draw_lineup() -> void:
	Ui.paper(self, LINEUP)
	Fit.begin(LINEUP, "the lineup")
	var rows: Array = result.get("rows", [])
	var lines: Array = poster.get("lines", [])
	for i in lines.size():
		var line: Dictionary = lines[i]
		var y := LINEUP.position.y + 2 + i * ROW
		var r: Dictionary = rows[i] if i < rows.size() else {}
		var shown := judged and i < revealed
		if shown and not r.ok:
			draw_rect(Rect2(LINEUP.position.x + 1, y, LINEUP.size.x - 4, ROW - 1), Color(Palette.RED_LIGHT, 0.28))
		elif i % 2 == 1:
			draw_rect(Rect2(LINEUP.position.x + 1, y, LINEUP.size.x - 4, ROW - 1), Color(Palette.PAPER_DARK, 0.35))
		var want := bool(line.want)
		Ui.tab(self, Rect2(LINEUP.position.x + 4, y + 1, 36, 12), "CATCH" if want else "FREE", Palette.RED if want else Palette.GREEN, Palette.CREAM)
		Ui.lineup_text(self, Vector2(LINEUP.position.x + 46, y + 12), str(line.text), r, str(line.get("take", "")), Palette.INK)
		if shown:
			var word := str(VERDICTS[str(r.why)])
			if word == "":
				word = "caught" if want else "rides on"
			var color := Palette.GREEN if r.ok else Palette.RED
			if r.ok:
				Ui.tick(self, Vector2(LINEUP.end.x - 88, y + 3), color)
			else:
				Ui.cross(self, Vector2(LINEUP.end.x - 88, y + 3), color)
			Fit.text(self, Palette.mono(), Vector2(LINEUP.end.x - 74, y + 12), word, 16, color)
	Fit.end()


func _draw_poster() -> void:
	Ui.paper(self, POSTER)
	Ui.nails(self, POSTER)
	Fit.begin(POSTER, "the poster")
	Fit.text(self, Palette.titles(), Vector2(18, 192), "WANTED", 11, Palette.RED)
	_draw_meaning()
	# The pattern.
	draw_rect(SLOTS, Palette.PAPER_LINE)
	draw_rect(SLOTS.grow(-1), Palette.PAPER.lightened(0.3))
	var bad := int(result.error.get("at", -1)) if result.has("error") else -1
	_token_rects = []
	var x := SLOTS.position.x + 4
	var caret_x := x
	if tokens.is_empty():
		Fit.text(self, Palette.mono(), Vector2(x + 6, SLOTS.end.y - 6), "put chips here to write the poster", 16, Palette.DIM)
	for i in tokens.size():
		var token := str(tokens[i])
		var w := _token_width(token)
		var rect := Rect2(x, SLOTS.position.y + 2, w, 16)
		_token_rects.append(rect)
		var hot: bool = _hover.get("kind", "") == "token" and int(_hover.index) == i
		draw_rect(rect, Palette.RED_LIGHT if i == bad else (Palette.GOLD_LIGHT if hot else Palette.PAPER_DARK))
		Ui.regex(self, Vector2(x + 3, rect.end.y - 4), token, Ui.kind_color(token))
		x += w + 1.0
		if i + 1 == caret:
			caret_x = x
	if not busy and Fit.blink(fmod(_clock, 0.9) < 0.55):
		draw_rect(Rect2(caret_x - 1, SLOTS.position.y + 2, 2, 16), Palette.RED)
	# Back, Clear, Draw.
	var count := (poster.get("chips", []) as Array).size()
	var keys := not TouchControls.active
	for i in BUTTON_RECTS.size():
		var rect: Rect2 = BUTTON_RECTS[i]
		var hot: bool = (keys and focus == count + i) or (_hover.get("kind", "") == "button" and int(_hover.index) == i)
		var ready_to_draw: bool = BUTTONS[i] == "draw" and not tokens.is_empty() and not result.has("error")
		draw_rect(rect, Palette.GOLD_LIGHT if hot else Palette.WOOD_DARK)
		draw_rect(rect.grow(-1), Palette.RED if ready_to_draw else Palette.WOOD)
		Fit.centred(self, Palette.pixel(), rect.position.x + rect.size.x / 2.0, rect.end.y - 6, str(BUTTON_WORDS[i]), 10, Palette.CREAM if ready_to_draw or hot else Palette.PAPER_DARK)
	# The chips on the table.
	for i in _chip_rects.size():
		var hot: bool = (keys and focus == i) or (_hover.get("kind", "") == "chip" and int(_hover.index) == i)
		Ui.chip(self, _chip_rects[i], str(poster.chips[i]), hot and not busy)
	# How to work the desk, if the chips left room for it.
	if not _chip_rects.is_empty() and (_chip_rects[-1] as Rect2).end.y < 244:
		Fit.text(self, Palette.pixel(), Vector2(18, 260), help_text(), 10, Palette.DIM)
	Fit.end()


static func help_text() -> String:
	if TouchControls.active:
		return "Tap a chip to put it on the poster. Tap it there to take it back. Then Draw."
	return "Enter puts a chip down. Backspace takes one back. , and . move the caret. D draws."


## The line beside WANTED: what's wrong with the pattern, or what the chip
## under the pointer (or the keys) means in plain words.
func _draw_meaning() -> void:
	var font := Palette.mono()
	var at := Vector2(74, 191)
	if result.has("error"):
		Fit.text(self, font, at, Story.error_text(result.error), 16, Palette.RED)
		return
	var token := ""
	var meaning := ""
	var count := (poster.get("chips", []) as Array).size()
	if _hover.get("kind", "") == "token" and int(_hover.index) < tokens.size():
		token = str(tokens[int(_hover.index)])
		meaning = Rx.meaning(tokens, int(_hover.index))
	elif _hover.get("kind", "") == "chip":
		token = str(poster.chips[int(_hover.index)])
		meaning = Rx.meaning_of(token)
	elif not TouchControls.active and focus < count:
		token = str(poster.chips[focus])
		meaning = Rx.meaning_of(token)
	elif not tokens.is_empty() and caret > 0:
		token = str(tokens[caret - 1])
		meaning = Rx.meaning(tokens, caret - 1)
	if token == "":
		return
	var wide := Ui.regex(self, at, token, Palette.RED)
	Fit.text(self, font, at + Vector2(wide + 8, 0), meaning, 16, Palette.INK)
