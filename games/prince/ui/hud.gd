class_name Hud
extends CanvasLayer

## Everything drawn over a room: the sand trail and the hourglass along the
## top, the scroll you're reading, the last git command and its output, the
## Vizier's lines, the sepia of a death or a rewind, and the cards that open
## and close a room. Laid out at 480x270 and centred when the view is wider.

const PRINCESS := preload("res://assets/sprites/princess.png")

var room: Room
var sign_text: String = ""

var _board: Control
var _clock: float = 0.0
var _toast: Dictionary = {}
var _toast_left: float = 0.0
var _rewind: float = 0.0
var _speech: Dictionary = {}
## The card on screen: {kind, ...}. Empty when there is none.
var _card: Dictionary = {}
var _advance: bool = false
var _buttons: HBoxContainer


func _ready() -> void:
	layer = 10
	_board = Control.new()
	_board.set_anchors_preset(Control.PRESET_FULL_RECT)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.draw.connect(_paint)
	add_child(_board)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override(&"separation", 6)
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_buttons)
	_buttons.hide()


func margin() -> float:
	return floorf((_board.get_viewport_rect().size.x - Room.VIEW.x) / 2.0)


func _process(delta: float) -> void:
	_clock += delta
	_toast_left = maxf(0.0, _toast_left - delta)
	_rewind = maxf(0.0, _rewind - delta)
	_buttons.position = Vector2(margin(), 240)
	_buttons.size = Vector2(Room.VIEW.x, 22)
	_board.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if (_speech.is_empty() and _card.is_empty()) or event.is_echo() or not event.is_pressed():
		return
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton or event is InputEventScreenTouch:
		_advance = true


# --- what the room asks for --------------------------------------------------

func toast(result: Dictionary) -> void:
	_toast = result
	_toast_left = 6.0


func rewind() -> void:
	_rewind = 0.7


## Holds until a key, a tap or `seconds` (a frame, under test).
func _wait(seconds: float) -> void:
	_advance = false
	if Room.test_fast:
		await get_tree().process_frame
		return
	var left := seconds
	var held := 0.0
	while left > 0.0 and not (_advance and held > 0.35):
		await get_tree().process_frame
		var delta := get_process_delta_time()
		left -= delta
		held += delta
	_advance = false


func say(who: String, line: String) -> void:
	_speech = {"who": who, "line": line}
	await _wait(2.0 + line.length() * 0.06)
	_speech = {}


func card(title: String, text: String, seconds: float) -> void:
	_card = {"kind": "plain", "title": title, "text": text}
	await _wait(seconds)
	_card = {}


func title_card() -> void:
	_card = {"kind": "title"}
	await _wait(6.0)
	_card = {}


func clear_card() -> void:
	_card = {"kind": "clear"}
	var last := room.level_id >= Story.count()
	_fill_buttons([
		["The tower" if last else "Next room", func() -> void:
			if last:
				_ending()
			else:
				Main.play(get_tree(), room.level_id + 1)],
		["Again", func() -> void: Main.play(get_tree(), room.level_id)],
		["Title", func() -> void: Main.title(get_tree())],
	])


func _ending() -> void:
	_card = {"kind": "ending"}
	_fill_buttons([["Title", func() -> void: Main.title(get_tree())]])


func _fill_buttons(items: Array) -> void:
	for child in _buttons.get_children():
		child.queue_free()
	for item: Array in items:
		var button := Button.new()
		button.text = item[0]
		button.custom_minimum_size = Vector2(84, 20)
		button.pressed.connect(item[1])
		_buttons.add_child(button)
	_buttons.show()
	if not TouchControls.active:
		(_buttons.get_child(_buttons.get_child_count() - items.size()) as Button).grab_focus.call_deferred()


## The first button of the card on screen (the bot presses it).
func press_first() -> void:
	for child in _buttons.get_children():
		if not child.is_queued_for_deletion():
			(child as Button).pressed.emit()
			return


func card_kind() -> String:
	return _card.get("kind", "")


# --- drawing -----------------------------------------------------------------

func _text(at: Vector2, text: String, size: int, color: Color, font: Font = Palette.pixel(), width: float = -1.0,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	_board.draw_string(font, at, text, align, width, size, color)


func _wrapped(at: Vector2, text: String, size: int, color: Color, width: float, font: Font = Palette.pixel(),
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> float:
	_board.draw_multiline_string(font, at, text, align, width, size, -1, color)
	return font.get_multiline_string_size(text, align, width, size).y


func _paint() -> void:
	var full := _board.get_viewport_rect().size
	var dead := room.prince != null and not room.prince.alive
	if dead:
		_board.draw_rect(Rect2(Vector2.ZERO, full), Color(0.45, 0.3, 0.12, 0.38))
	if _rewind > 0.0:
		var t := _rewind / 0.7
		_board.draw_rect(Rect2(Vector2.ZERO, full), Color(0.93, 0.78, 0.42, 0.55 * sin(t * PI)))
		for i in 14:
			var y := fmod(i * 37.0 + _clock * 90.0, full.y)
			var x := fmod(i * 91.0 - _clock * 900.0, full.x + 120.0)
			_board.draw_rect(Rect2(x, y, 60.0 + (i % 3) * 30.0, 1.0), Color(1.0, 0.95, 0.75, 0.5 * t))
	_board.draw_set_transform(Vector2(margin(), 0))
	_board.draw_rect(Rect2(-margin(), 0, full.x, 30), Color(Palette.INK, 0.86))
	_board.draw_rect(Rect2(-margin(), 30, full.x, 1), Color(Palette.SAND, 0.5))
	Trail.paint(_board, room.repo, Rect2(2, 2, 400, 28), Palette.pixel(), false, _clock)
	_paint_hourglass()
	if room.state == "play" or room.state == "cutscene":
		if sign_text != "":
			_paint_scroll(sign_text)
		_paint_toast()
		if not TouchControls.active and room.state == "play" and room.commands_run == 0 and room.level_id == 1:
			_text(Vector2(0, 264), "Arrows run · Space jumps · %s draws the dagger" % Controls.label(&"dagger"), 10, Color(Palette.PAPER, 0.7), Palette.pixel(), 480, HORIZONTAL_ALIGNMENT_CENTER)
	if not _speech.is_empty():
		_paint_speech()
	match String(_card.get("kind", "")):
		"title":
			_paint_title()
		"plain":
			_board.draw_rect(Rect2(-margin(), 0, full.x, full.y), Color(Palette.INK, 0.86))
			_text(Vector2(0, 118), _card.title, 22, Palette.SAND, Palette.pixel(), 480, HORIZONTAL_ALIGNMENT_CENTER)
			_wrapped(Vector2(60, 142), _card.text, 11, Palette.PAPER, 360, Palette.pixel(), HORIZONTAL_ALIGNMENT_CENTER)
		"clear":
			_paint_clear()
		"ending":
			_paint_ending()
	_board.draw_set_transform(Vector2.ZERO)


func _paint_hourglass() -> void:
	var left := maxf(0.0, room.time_left)
	var low := left < 30.0
	var color := Palette.CRIMSON.lightened(0.25) if low and int(_clock * 3.0) % 2 == 0 else Palette.SAND_PALE
	var x := 440.0
	# A little hourglass: two triangles of sand.
	var fill := clampf(left / float(room.level.get("time", 180)), 0.0, 1.0)
	_board.draw_colored_polygon(PackedVector2Array([Vector2(x, 5), Vector2(x + 8, 5), Vector2(x + 4, 11)]), Color(Palette.SAND, 0.25 + 0.75 * fill))
	_board.draw_colored_polygon(PackedVector2Array([Vector2(x + 4, 11), Vector2(x + 8, 18), Vector2(x, 18)]), Color(Palette.SAND, 1.0 - 0.75 * fill))
	_board.draw_polyline(PackedVector2Array([Vector2(x, 5), Vector2(x + 8, 5), Vector2(x, 18), Vector2(x + 8, 18), Vector2(x, 5)]), Palette.SAND_PALE, 1.0)
	_text(Vector2(x + 11, 16), "%d:%02d" % [int(left) / 60, int(left) % 60], 12, color, Palette.mono())


func _paint_scroll(text: String) -> void:
	var width := 380.0
	var height := Palette.pixel().get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width - 16, 11).y
	var box := Rect2(50, 36, width, height + 8)
	_board.draw_rect(box, Color(0.93, 0.87, 0.7, 0.96))
	_board.draw_rect(box, Color(0.5, 0.36, 0.2), false, 1.0)
	_wrapped(box.position + Vector2(8, 13), text, 11, Color(0.2, 0.13, 0.08), width - 16)


func _paint_toast() -> void:
	if _toast_left <= 0.0 or _toast.is_empty():
		return
	var alpha := clampf(_toast_left, 0.0, 1.0)
	var ok := int(_toast.exit) == 0
	var out: Array = _toast.out
	var box := Rect2(112, 240, 256, 28)
	_board.draw_rect(box, Color(Palette.INK, 0.85 * alpha))
	_board.draw_rect(box, Color(Palette.SAND if ok else Palette.CRIMSON, 0.6 * alpha), false, 1.0)
	_text(box.position + Vector2(5, 11), "$ git " + Console.shown(_toast.cmd), 12, Color(Palette.SAND_PALE, alpha), Palette.mono(), box.size.x - 8)
	if not out.is_empty():
		_text(box.position + Vector2(5, 23), String(out[0]).strip_edges(), 12, Color(Palette.PAPER if ok else Palette.CRIMSON.lightened(0.4), alpha), Palette.mono(), box.size.x - 8)


func _paint_speech() -> void:
	var box := Rect2(70, 196, 340, 44)
	_board.draw_rect(box, Color(Palette.INK, 0.92))
	_board.draw_rect(box, Palette.VIOLET, false, 1.0)
	_text(box.position + Vector2(8, 13), _speech.who, 11, Palette.VIOLET.lightened(0.3))
	var line: String = _speech.line
	var is_git := line.begins_with("git ")
	_wrapped(box.position + Vector2(8, 27), ("$ " + line) if is_git else line, 13 if is_git else 11,
		Palette.SAND_PALE if is_git else Palette.PAPER, box.size.x - 16, Palette.mono() if is_git else Palette.pixel())


func _paint_title() -> void:
	var full := _board.get_viewport_rect().size
	_board.draw_rect(Rect2(-margin(), 0, full.x, full.y), Color(Palette.INK, 0.9))
	var level := room.level
	_text(Vector2(0, 74), "ROOM %d OF %d" % [room.level_id, Story.count()], 11, Color(Palette.PAPER, 0.7), Palette.pixel(), 480, HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(0, 108), level.title, 28, Palette.SAND, Palette.pixel(), 480, HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(0, 130), level.git, 16, Palette.TEAL.lightened(0.35), Palette.mono(), 480, HORIZONTAL_ALIGNMENT_CENTER)
	var y := 160.0
	for line: String in level.get("opening", []):
		y += _wrapped(Vector2(70, y), line, 11, Palette.PAPER, 340, Palette.pixel(), HORIZONTAL_ALIGNMENT_CENTER) + 4.0
	if int(_clock * 2.0) % 2 == 0:
		_text(Vector2(0, 250), "tap to begin" if TouchControls.active else "press any key", 10, Color(Palette.PAPER, 0.6), Palette.pixel(), 480, HORIZONTAL_ALIGNMENT_CENTER)


func _paint_clear() -> void:
	var full := _board.get_viewport_rect().size
	_board.draw_rect(Rect2(-margin(), 0, full.x, full.y), Color(Palette.INK, 0.9))
	var lesson: Dictionary = room.level.get("card", {})
	_text(Vector2(0, 46), "Room cleared", 11, Color(Palette.PAPER, 0.7), Palette.pixel(), 480, HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(0, 68), lesson.get("title", room.level.title), 20, Palette.SAND, Palette.pixel(), 480, HORIZONTAL_ALIGNMENT_CENTER)
	var code: Array = lesson.get("code", [])
	var box := Rect2(40, 78, 400, code.size() * 12.0 + 8.0)
	_board.draw_rect(box, Color(0.04, 0.05, 0.1))
	_board.draw_rect(box, Color(Palette.TEAL, 0.6), false, 1.0)
	var y := box.position.y + 13.0
	for line: String in code:
		var note := line.find("#")
		if note > 0:
			_text(Vector2(48, y), line.substr(0, note), 13, Palette.SAND_PALE, Palette.mono())
			_text(Vector2(48 + Palette.mono().get_string_size(line.substr(0, note), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x, y), line.substr(note), 13, Color(Palette.STEEL, 0.75), Palette.mono())
		else:
			_text(Vector2(48, y), line, 13, Color(Palette.STEEL, 0.75) if note == 0 else Palette.SAND_PALE, Palette.mono())
		y += 12.0
	var after := box.end.y + 14.0
	after += _wrapped(Vector2(44, after), lesson.get("insight", ""), 10, Palette.PAPER, 392)
	var seconds := int(room.elapsed)
	_text(Vector2(0, 234), "%d:%02d on the hourglass · %d %s · %d git commands" % [seconds / 60, seconds % 60, room.deaths, "death" if room.deaths == 1 else "deaths", room.commands_run],
		10, Color(Palette.PAPER, 0.65), Palette.pixel(), 480, HORIZONTAL_ALIGNMENT_CENTER)


func _paint_ending() -> void:
	var full := _board.get_viewport_rect().size
	_board.draw_rect(Rect2(-margin(), 0, full.x, full.y), Palette.INK)
	_board.draw_texture_rect(PRINCESS, Rect2(216, 40, 48, 72), false)
	_text(Vector2(0, 132), "Princess Shirin", 12, Palette.GREEN, Palette.pixel(), 480, HORIZONTAL_ALIGNMENT_CENTER)
	var y := 150.0
	for line in ["\"You merged two timelines to reach me. Nobody has done that since the old Sultan.\"",
			"\"The Vizier ran off muttering about a rebase. He means to rewrite the palace's history.\"",
			"Act II is on its way: stash, cherry-pick, bisect and the reflog."]:
		y += _wrapped(Vector2(60, y), line, 11, Palette.PAPER, 360, Palette.pixel(), HORIZONTAL_ALIGNMENT_CENTER) + 5.0
