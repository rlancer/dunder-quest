class_name Notebook
extends CanvasLayer

## The Lieutenant's notebook: one question for Records, the files he has
## found so far, and a page of chips to spell the query from. Under them is
## the SQL exactly as it will be read to Doris, and that text is all that
## gets run.
##
## Up and down move between the lines of the query, left and right between
## the chips on a line, Space (or E) picks a chip or puts it back, and Enter
## (or R) calls Records. By mouse or touch, tap the chips and the buttons.
## The answer comes back on green-bar paper: the rows, or the database's own
## error, and what the Lieutenant makes of it.

## Sent when the player has read a printout: the Judge's verdict on that call.
signal called(verdict: Dictionary)
signal closed

const PANEL := Rect2(8, 4, 464, 262)
const LEFT := 16.0
const CHIPS_LEFT := 76.0
const STEP := 14.0
## The strip along the foot of the page that the buttons stand in, and how
## much of its width they take.
const BUTTONS := 26.0
const BESIDE := 164.0
const OK_REMARK := "That's what I needed."
## What he says into the telephone while it dials.
const DIALING := {"who": "lt", "text": "Doris? It's Colonna."}

## Tests set these before a case starts.
static var test_auto_frames: int = 0
static var test_pace: float = 1.0

var beat: Dictionary = {}
var db: Dictionary = {}
var picks: Dictionary = Query.empty()
## The tables found so far, in the order they were found.
var tables: Array = []
var label: String = ""
## "edit", "dialing" or "printout".
var mode: String = "edit"
var verdict: Dictionary = {}
## Wrong answers on this beat so far; the hint appears after the first.
var misses: int = 0

var _canvas: Control
var _call_button: Button
var _close_button: Button
## The lines of the page: [{line, chips}], with AND/OR riding on WHERE's line.
var _rows: Array = []
var _cursor: Vector2i = Vector2i.ZERO
## [{rect, row, index, line, chip}] from the last draw, for taps and for
## moving the cursor up and down.
var _boxes: Array = []
var _clock: float = 0.0
var _dial: float = 0.0
var _wait_frames: int = 0
var _opened_ms: int = 0
var _closed_ms: int = -1000


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_page)
	_canvas.gui_input.connect(_on_canvas_input)
	add_child(_canvas)
	_call_button = Button.new()
	_call_button.text = "Call Records"
	_call_button.position = Vector2(PANEL.end.x - 156, PANEL.end.y - 22)
	_call_button.size = Vector2(92, 18)
	_call_button.focus_mode = Control.FOCUS_NONE
	_call_button.pressed.connect(call_records)
	add_child(_call_button)
	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.position = Vector2(PANEL.end.x - 58, PANEL.end.y - 22)
	_close_button.size = Vector2(50, 18)
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.pressed.connect(close)
	add_child(_close_button)


func is_open() -> bool:
	return visible


func just_closed() -> bool:
	return Time.get_ticks_msec() - _closed_ms < 200


## Opens the page for a beat. `fresh` starts it blank; otherwise it comes
## back as the player left it.
func open(for_beat: Dictionary, database: Dictionary, found_tables: Array, case_label: String, fresh: bool) -> void:
	if fresh or str(beat.get("id", "")) != str(for_beat.get("id", "")):
		picks = Query.empty()
		misses = 0
		_cursor = Vector2i.ZERO
	beat = for_beat
	db = database
	tables = found_tables
	label = case_label
	mode = "edit"
	_rows = []
	var tray: Dictionary = beat.get("tray", {})
	for line: String in Query.LINES:
		var chips: Array = (tray.get(line, []) as Array).duplicate()
		if line == "from":
			chips = chips.filter(func(t: String) -> bool: return tables.has(t))
		if chips.is_empty():
			continue
		_rows.append({"line": line, "chips": chips, "logic": tray.get("logic", []) if line == "where" else []})
	visible = true
	_opened_ms = Time.get_ticks_msec()
	_buttons()
	StageAudio.play(get_tree(), preload("res://assets/audio/page.wav"))
	if fresh:
		Voice.say({"who": "lt", "text": str(beat.get("ask", ""))})
	_canvas.queue_redraw()


func close() -> void:
	if not visible or mode != "edit":
		return
	visible = false
	_closed_ms = Time.get_ticks_msec()
	Voice.hush()
	closed.emit()


## Tests put a whole page down at once.
func set_picks(new_picks: Dictionary) -> void:
	picks = Query.from_data(new_picks)
	_canvas.queue_redraw()


func sql() -> String:
	return Query.compose(picks)


## Reads the page to Doris: the dial turns, then the printout comes back.
func call_records() -> void:
	if not visible or mode != "edit":
		return
	verdict = Judge.check(db, beat, picks)
	mode = "dialing"
	_dial = 0.9 * test_pace
	_buttons()
	StageAudio.play(get_tree(), preload("res://assets/audio/dial.wav"))
	Voice.say(DIALING)


## Puts the printout down: back to the page, or on with the case.
func dismiss() -> void:
	if mode != "printout":
		return
	var v := verdict
	Voice.hush()
	if v.verdict == "ok":
		visible = false
		_closed_ms = Time.get_ticks_msec()
	else:
		misses += 1
		mode = "edit"
		_buttons()
		# The first miss brings the hint up at the foot of the page.
		if misses == 1 and str(beat.get("hint", "")) != "":
			Voice.say(hint_line(beat))
	called.emit(v)


## What Doris says when the printout comes back: how many rows, or that the
## machine won't take it.
static func doris_text(result: Dictionary) -> String:
	var doris: Dictionary = Story.stock("doris")
	if not result.ok:
		return str(doris.strict if str(result.error.kind) == "strict" else doris.error)
	var count: int = (result.rows as Array).size()
	return str(doris.none) if count == 0 else (str(doris.row) if count == 1 else str(doris.rows) % count)


## What the Lieutenant makes of a printout.
static func remark_text(v: Dictionary) -> String:
	return OK_REMARK if v.verdict == "ok" else str(v.says)


## The two of them, as they're read aloud when the printout comes back.
static func printout_lines(v: Dictionary) -> Array:
	return [{"who": "doris", "text": doris_text(v.result)}, {"who": "lt", "text": remark_text(v), "mood": "" if v.verdict == "ok" else "think"}]


static func hint_line(b: Dictionary) -> Dictionary:
	return {"who": "lt", "text": str(b.get("hint", "")), "mood": "think"}


func _buttons() -> void:
	_call_button.visible = mode == "edit"
	_close_button.visible = mode == "edit"


func _process(delta: float) -> void:
	if not visible:
		return
	_clock += delta
	if mode == "dialing":
		_dial -= delta
		if _dial <= 0.0:
			mode = "printout"
			_wait_frames = 0
			_opened_ms = Time.get_ticks_msec()
			var good: bool = verdict.verdict == "ok"
			var bad: bool = verdict.verdict == "error"
			StageAudio.play(get_tree(), preload("res://assets/audio/ding.wav") if good else (preload("res://assets/audio/buzz.wav") if bad else preload("res://assets/audio/teletype.wav")))
			Voice.hush()
			Voice.say_after(printout_lines(verdict))
	elif mode == "printout" and test_auto_frames > 0:
		_wait_frames += 1
		if _wait_frames >= test_auto_frames:
			dismiss()
	_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if mode == "printout":
		if Time.get_ticks_msec() - _opened_ms < 250:
			return
		var tap: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		if tap or event.is_action_pressed(&"confirm") or event.is_action_pressed(&"edit") or event.is_action_pressed(&"pause"):
			get_viewport().set_input_as_handled()
			dismiss()
		return
	if mode != "edit":
		return
	var enter: bool = event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER)
	if event.is_action_pressed(&"pause"):
		close()
	elif enter or event.is_action_pressed(&"run"):
		call_records()
	elif event.is_action_pressed(&"move_left", true):
		_move(-1, 0)
	elif event.is_action_pressed(&"move_right", true):
		_move(1, 0)
	elif event.is_action_pressed(&"move_up", true):
		_move(0, -1)
	elif event.is_action_pressed(&"move_down", true):
		_move(0, 1)
	elif event.is_action_pressed(&"pick") or event.is_action_pressed(&"edit"):
		_toggle_at(_cursor)
	else:
		return
	get_viewport().set_input_as_handled()


## Every chip on a row, AND/OR included: [[line, chip], ...].
func _row_chips(row: int) -> Array:
	var out: Array = []
	if row < 0 or row >= _rows.size():
		return out
	var r: Dictionary = _rows[row]
	for chip: String in r.chips:
		out.append([r.line, chip])
	for chip: String in r.logic:
		out.append(["logic", chip])
	return out


func _move(dx: int, dy: int) -> void:
	if _rows.is_empty():
		return
	if dx != 0:
		var count := _row_chips(_cursor.x).size()
		_cursor.y = posmod(_cursor.y + dx, maxi(count, 1))
	else:
		var from := _box_of(_cursor)
		_cursor.x = posmod(_cursor.x + dy, _rows.size())
		# Land on the chip nearest to the one just left.
		var best := 0
		var best_gap := INF
		for box: Dictionary in _boxes:
			if int(box.row) != _cursor.x:
				continue
			var gap := absf((box.rect as Rect2).get_center().x - from.get_center().x)
			if gap < best_gap:
				best_gap = gap
				best = int(box.index)
		_cursor.y = best
	_tick()


func _box_of(at: Vector2i) -> Rect2:
	for box: Dictionary in _boxes:
		if int(box.row) == at.x and int(box.index) == at.y:
			return box.rect
	return Rect2(CHIPS_LEFT, 0, 10, 10)


func _toggle_at(at: Vector2i) -> void:
	var chips := _row_chips(at.x)
	if at.y < 0 or at.y >= chips.size():
		return
	Query.toggle(picks, str(chips[at.y][0]), str(chips[at.y][1]))
	_tick()


func _tick() -> void:
	StageAudio.play(get_tree(), preload("res://assets/audio/bump.wav"))
	_canvas.queue_redraw()


## A tap arrives as a touch and as an emulated click; reading both would
## flip a chip twice, so only the click counts.
func _on_canvas_input(event: InputEvent) -> void:
	if mode != "edit":
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	for box: Dictionary in _boxes:
		if (box.rect as Rect2).grow_individual(2, 2, 2, 2).has_point(event.position):
			_cursor = Vector2i(int(box.row), int(box.index))
			_toggle_at(_cursor)
			return


# --- Drawing ----------------------------------------------------------------

func _draw_page() -> void:
	if beat.is_empty():
		return
	var c := _canvas
	Fit.frame(c)
	c.draw_rect(Rect2(0, 0, 480, 270), Color(0, 0, 0, 0.6))
	if mode == "printout":
		_draw_printout(c)
		return
	var font := Palette.mono()
	# The notebook: a card cover, cream paper, a wire binding along the top.
	c.draw_rect(PANEL.grow(3), Palette.NOTE_COVER)
	c.draw_rect(PANEL, Palette.NOTE)
	Fit.begin(PANEL, "the notebook")
	c.draw_rect(Rect2(PANEL.position, Vector2(PANEL.size.x, 16)), Palette.NOTE_COVER)
	for i in 23:
		var ring := PANEL.position.x + 12 + i * 20.0
		c.draw_rect(Rect2(ring, PANEL.position.y - 3, 2, 5), Palette.STEEL)
		c.draw_rect(Rect2(ring, PANEL.position.y + 2, 2, 1), Palette.INK)
	Fit.text(c, font, PANEL.position + Vector2(8, 13), "Lt. Colonna's notebook", 16, Palette.CREAM)
	var label_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	Fit.text(c, font, Vector2(PANEL.end.x - label_w - 8, PANEL.position.y + 13), label, 16, Palette.CREAM.darkened(0.2))

	# The question, the files, the chips and the SQL all sit above the foot
	# of the page, where the buttons are.
	var body := Rect2(PANEL.position, Vector2(PANEL.size.x, PANEL.size.y - BUTTONS))
	var right := PANEL.end.x - 8
	Fit.begin(body, "the notebook page, above its buttons")
	# The question.
	var y := PANEL.position.y + 29
	var lead := "Ask Records: "
	var text_left := LEFT + SqlDraw.width(lead)
	Fit.text(c, font, Vector2(LEFT, y), lead, 16, Palette.EMBER.darkened(0.25))
	for line in SqlDraw.wrap(str(beat.get("ask", "")), right - text_left):
		Fit.text(c, font, Vector2(text_left, y), line, 16, Palette.NOTE_INK)
		y += 11
	y += 2

	# The files found so far, with their columns. They share a row while
	# they fit; one too long for a row of its own breaks between columns.
	Fit.text(c, font, Vector2(LEFT, y), "Files:", 16, Palette.EMBER.darkened(0.25))
	var x := text_left
	for name: String in tables:
		var def: Dictionary = db.get(name.to_lower(), {})
		var pieces := PackedStringArray()
		var columns: Array = def.get("columns", [])
		for i in columns.size():
			pieces.append(("(" if i == 0 else "") + str(columns[i].name) + (")" if i == columns.size() - 1 else ", "))
		var w := SqlDraw.width(name + "".join(pieces))
		if x + w > right and x > text_left:
			x = text_left
			y += 11
		Fit.text(c, font, Vector2(x, y), name, 16, Palette.SYN_FUNC)
		x += SqlDraw.width(name)
		for piece in pieces:
			if x + SqlDraw.width(piece.strip_edges(false, true)) > right:
				x = text_left + SqlDraw.width(SqlDraw.INDENT)
				y += 11
			Fit.text(c, font, Vector2(x, y), piece, 16, Palette.NOTE_INK.lightened(0.25))
			x += SqlDraw.width(piece)
		x += 12
	y += 6
	c.draw_line(Vector2(PANEL.position.x, y), Vector2(PANEL.end.x, y), Color(Palette.NOTE_RULE, 0.8), 1.0)
	y += 13

	# The chips, a line of the query to a row, and under them the SQL as it
	# will be read out: a clause to a line while there's room for that, and
	# run together when there isn't. The rows close up a little on a full page.
	var clauses := sql().split("\n")
	var by_clause := SqlDraw.wrap_clauses(clauses, PANEL.size.x - 24)
	var run_on := SqlDraw.wrap(" ".join(clauses), PANEL.size.x - 24)
	var sql_lines := by_clause
	var placed := {}
	for step: float in [STEP, STEP - 1.0]:
		placed = _place_chips(y, step)
		var room := int((body.end.y + 4.0 - float(placed.y)) / SqlDraw.LINE)
		sql_lines = by_clause if by_clause.size() <= room else run_on
		if sql_lines.size() <= room:
			break
	_boxes = placed.boxes
	for row in _rows.size():
		var on_row := row == _cursor.x and not TouchControls.active
		Fit.text(c, font, Vector2(LEFT, float(placed.rows[row])), str(Query.LABEL[_rows[row].line]), 16, Palette.SYN_KEYWORD if on_row else Palette.SYN_KEYWORD.lightened(0.3))
	for placed_chip: Dictionary in _boxes:
		var line := str(placed_chip.line)
		var chip := str(placed_chip.chip)
		var box: Rect2 = placed_chip.rect
		var picked := Query.has(picks, line, chip) or (line == "logic" and str(picks.logic) == chip)
		var dim := line == "logic" and (picks.where as Array).size() < 2
		var fill := Color(Palette.EMBER, 0.3) if picked and not dim else Color(1, 1, 1, 0.65)
		var edge := Palette.EMBER.darkened(0.15) if picked and not dim else Palette.NOTE_INK.lightened(0.5)
		c.draw_rect(box, fill)
		c.draw_rect(box, edge, false, 1.0)
		Fit.begin(box, "a chip")
		if dim:
			Fit.text(c, font, Vector2(box.position.x + 4, box.end.y - 2), chip, 16, Palette.NOTE_INK.lightened(0.45))
		else:
			SqlDraw.draw_line(c, Vector2(box.position.x + 4, box.end.y - 2), chip)
		Fit.end()
		if not TouchControls.active and int(placed_chip.row) == _cursor.x and int(placed_chip.index) == _cursor.y:
			c.draw_rect(box.grow(1), Palette.NOTE_INK, false, 1.0)
			if int(_clock * 3.0) % 2 == 0:
				c.draw_rect(Rect2(box.position.x, box.end.y + 1, box.size.x, 1), Palette.NOTE_INK)
	y = float(placed.y) + 1
	var sql_box := Rect2(LEFT - 4, y - 10, PANEL.size.x - 8, sql_lines.size() * SqlDraw.LINE + 5)
	c.draw_rect(sql_box, Color(Palette.NOTE_RULE, 0.22))
	c.draw_rect(Rect2(sql_box.position, Vector2(2, sql_box.size.y)), Palette.EMBER.darkened(0.1))
	Fit.check(sql_box, "(the SQL under the chips)")
	Fit.begin(sql_box, "the notebook's SQL")
	for line in sql_lines:
		SqlDraw.draw_line(c, Vector2(LEFT + 4, y), line)
		y += SqlDraw.LINE
	Fit.end()
	Fit.end()

	# The foot of the page, beside the buttons: how to work it, and once
	# he's missed, a thought.
	var foot := Rect2(PANEL.position.x, PANEL.end.y - BUTTONS, PANEL.size.x - BESIDE, BUTTONS)
	var hint := str(beat.get("hint", ""))
	var thinking := misses > 0 and hint != ""
	var foot_lines := PackedStringArray(["Tap the chips to write the query" if TouchControls.active else "Arrows: move   Space: pick   Enter: call"])
	if thinking:
		foot_lines = SqlDraw.wrap("Thinking: " + hint, foot.size.x - (LEFT - PANEL.position.x) - 6)
	Fit.begin(foot, "the foot of the notebook, beside its buttons")
	y = PANEL.end.y - 4 - (foot_lines.size() - 1) * SqlDraw.LINE - (5 if foot_lines.size() == 1 else 0)
	for line in foot_lines:
		Fit.text(c, font, Vector2(LEFT, y), line, 16, Palette.NOTE_INK.lightened(0.3) if thinking else Palette.STEEL_DARK)
		y += SqlDraw.LINE
	Fit.end()
	Fit.end()

	if mode == "dialing":
		_draw_dialing(c)


## Where every chip goes, starting with the first row's baseline at `y`
## and `step` room pixels to a row: {boxes, rows (each row's baseline), y
## (the baseline under the last row)}. A row too long for the page wraps.
func _place_chips(y: float, step: float) -> Dictionary:
	var boxes: Array = []
	var rows: Array = []
	for row in _rows.size():
		rows.append(y)
		var x := CHIPS_LEFT
		var chips := _row_chips(row)
		for index in chips.size():
			var line := str(chips[index][0])
			var chip := str(chips[index][1])
			var w := SqlDraw.width(chip) + 8
			# AND and OR ride at the end of WHERE's row, and stay together:
			# if the pair won't fit, both go on the next line.
			var group := w
			if line == "logic" and index > 0 and str(chips[index - 1][0]) != "logic":
				x += 8
				for later in range(index + 1, chips.size()):
					group += SqlDraw.width(str(chips[later][1])) + 12
			if x + group > PANEL.end.x - 8 and x > CHIPS_LEFT:
				x = CHIPS_LEFT
				y += step - 1
			boxes.append({"rect": Rect2(roundf(x), y - 10, w, 12), "row": row, "index": index, "line": line, "chip": chip})
			x += w + 4
		y += step
	return {"boxes": boxes, "rows": rows, "y": y}


func _draw_dialing(c: Control) -> void:
	var font := Palette.mono()
	var box := Rect2(134, 108, 212, 52)
	c.draw_rect(Rect2(0, 0, 480, 270), Color(0, 0, 0, 0.35))
	Fit.cover(box)
	c.draw_rect(box.grow(2), Palette.NOTE_COVER)
	c.draw_rect(box, Palette.INK)
	# A telephone dial, turning.
	var hub := box.position + Vector2(28, 26)
	c.draw_circle(hub, 17, Palette.STEEL_DARK)
	c.draw_circle(hub, 15, Palette.PAPER.darkened(0.1))
	for i in 10:
		var a := _clock * 5.0 + i * TAU / 12.0
		c.draw_circle(hub + Vector2(cos(a), sin(a)) * 10.5, 2.2, Palette.INK)
	c.draw_circle(hub, 5, Palette.EMBER)
	Fit.begin(box, "the Calling Records box")
	Fit.text(c, font, box.position + Vector2(56, 22), "Calling Records" + ".".repeat(int(_clock * 5.0) % 4), 16, Palette.CREAM)
	Fit.text(c, font, box.position + Vector2(56, 36), "\"%s\"" % DIALING.text, 16, Palette.STEEL)
	Fit.end()


func _draw_printout(c: Control) -> void:
	var font := Palette.mono()
	var result: Dictionary = verdict.result
	var good: bool = verdict.verdict == "ok"
	# Green-bar paper with its strips of feed holes.
	c.draw_rect(PANEL.grow(2), Palette.BAR_INK.lightened(0.2))
	c.draw_rect(PANEL, Palette.BAR_LIGHT)
	for side: float in [PANEL.position.x, PANEL.end.x - 9]:
		c.draw_rect(Rect2(side, PANEL.position.y, 9, PANEL.size.y), Palette.BAR_LIGHT.darkened(0.06))
		var hole := PANEL.position.y + 7
		while hole < PANEL.end.y - 3:
			c.draw_circle(Vector2(side + 4.5, hole), 1.8, Palette.BAR_INK.lightened(0.55))
			hole += 12
	var left := PANEL.position.x + 16
	var room := PANEL.size.x - 32
	var y := PANEL.position.y + 13
	# Between the two strips of feed holes.
	Fit.begin(Rect2(PANEL.position.x + 9, PANEL.position.y, PANEL.size.x - 18, PANEL.size.y), "the printout")
	Fit.text(c, font, Vector2(left, y), "RECORDS DIVISION", 16, Palette.BAR_INK.lightened(0.3))
	var tag_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	Fit.text(c, font, Vector2(left + room - tag_w, y), label, 16, Palette.BAR_INK.lightened(0.3))
	y += 13
	# The query he read out, a clause to a line while it fits.
	var sql_lines := str(verdict.sql).split("\n")
	var echoed := SqlDraw.wrap_clauses(sql_lines, room)
	if echoed.size() > 4:
		echoed = SqlDraw.wrap(" ".join(sql_lines), room)
	for line in echoed:
		SqlDraw.draw_line(c, Vector2(left, y), line, Palette.BAR_INK)
		y += 11
	y += 3
	# What the Lieutenant makes of it goes at the bottom; measure it first.
	var says_lines := SqlDraw.wrap(remark_text(verdict), room - 12)
	var note_lines := PackedStringArray()
	if not result.ok and result.error.kind == "strict":
		note_lines = SqlDraw.wrap(str(Story.stock("strict_note")), room)
	var foot := PANEL.end.y - 6
	var says_h := says_lines.size() * 11 + 17
	var says_top := foot - 12 - says_h
	Fit.begin(Rect2(PANEL.position.x + 9, PANEL.position.y, PANEL.size.x - 18, says_top - 1 - PANEL.position.y), "the printout, above the Lieutenant's slip")
	if result.ok:
		var count: int = (result.rows as Array).size()
		Fit.text(c, font, Vector2(left, y), "Doris: \"%s\"" % doris_text(result), 16, Palette.BAR_INK)
		y += 5
		var fit := int((says_top - y - 6) / 11.0) - 1
		var max_rows := count if count <= fit else fit - 1
		var table := Printout.layout(result, maxi(max_rows, 1), room + 8)
		var h: float = (table.lines as Array).size() * 11.0 + 4
		Fit.check(Rect2(left - 4, y, room + 8, h), "(the results table)")
		Printout.draw(c, Rect2(left - 4, y, room + 8, h), table)
	else:
		var kind := str(result.error.kind)
		Fit.text(c, font, Vector2(left, y), "Doris: \"%s\"" % doris_text(result), 16, Palette.BAR_INK)
		y += 14
		for line in SqlDraw.wrap(("ERROR: " if kind == "strict" else "Error: ") + str(result.error.msg), room - 8):
			Fit.text(c, font, Vector2(left + 8, y), line, 16, Palette.RED.darkened(0.25))
			y += 11
		y += 4
		for line in note_lines:
			Fit.text(c, font, Vector2(left, y), line, 16, Palette.BAR_INK.lightened(0.3))
			y += 11
	Fit.end()
	# The Lieutenant's own slip of notebook paper.
	var slip := Rect2(left - 4, says_top, room + 8, says_h)
	c.draw_rect(slip.grow(1), Palette.GREEN.darkened(0.2) if good else Palette.NOTE_COVER)
	c.draw_rect(slip, Palette.NOTE)
	Fit.begin(slip, "the Lieutenant's slip")
	var sy := slip.position.y + 11
	Fit.text(c, font, Vector2(slip.position.x + 6, sy), "Lt. Colonna:", 16, Palette.GREEN.darkened(0.35) if good else Palette.EMBER.darkened(0.3))
	sy += 11
	for line in says_lines:
		Fit.text(c, font, Vector2(slip.position.x + 6, sy), line, 16, Palette.NOTE_INK)
		sy += 11
	Fit.end()
	if Fit.blink(int(_clock * 3.0) % 2 == 0 or test_auto_frames > 0):
		var go := ("Tap: go on" if good else "Tap: back to the notebook") if TouchControls.active else ("Enter: go on" if good else "Enter: back to the notebook")
		var w := font.get_string_size(go, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		Fit.text(c, font, Vector2(left + room - w, foot), go, 16, Palette.EMBER.darkened(0.3))
	Fit.end()
