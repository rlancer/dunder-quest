class_name Card
extends Control

## Full-screen cards: the episode's title card (Montserrat ExtraBold, green
## on off-white), the night's goal, lesson cards for the codex, and the cut
## to black. `await card.title_card(...)` and friends return on a tap, or
## after a hold for the title and the black.

signal advanced

static var test_auto_frames: int = 0

var _waiting: bool = false
var _frames: int = 0
var _hold: int = 0
var _shown_at: int = 0
var _content: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_content = Control.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)


func _begin(bg: Color) -> void:
	UI.clear(_content)
	var back := UI.place(UI.panel(bg), Rect2(0, 0, 480, 270))
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(back)
	visible = true


func title_card(text: String) -> void:
	_begin(Palette.PAPER)
	var top := UI.place(UI.label("MISSION SILICON", Palette.LABEL, Palette.GREEN_DARK), Rect2(0, 100, 480, 14)) as Label
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(top)
	# A long title (The Board Meeting) shrinks to keep a margin each side.
	var px := 40
	while px > 24 and Palette.titles().get_string_size(text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > 432:
		px -= 1
	var big := UI.place(UI.title(text.to_upper(), px, Palette.SLATE), Rect2(0, 114 + (40 - px) * 0.5, 480, 50)) as Label
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(big)
	var bar := UI.place(UI.panel(Palette.GREEN), Rect2(200, 168, 80, 4))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(bar)
	await _wait(150)


func goal_card(goals: Array, budget: Dictionary) -> void:
	_begin(Palette.PAPER)
	var head := UI.place(UI.title("TONIGHT", 20, Palette.GREEN_DARK), Rect2(40, 34, 400, 28))
	_content.add_child(head)
	var y := 72.0
	# More than seven goals (the finale's eleven) go in two columns.
	var rows := goals.size() if goals.size() <= 7 else ceili(goals.size() / 2.0)
	for i in goals.size():
		var col := 0 if i < rows else 1
		var at := Vector2(24 + col * 222, 72.0 + (i % rows) * 20.0) if rows < goals.size() else Vector2(48, 72.0 + i * 20.0)
		_content.add_child(UI.place(UI.label("• " + goals[i]["label"], Palette.HEAD, Palette.SLATE), Rect2(at, Vector2(220 if rows < goals.size() else 400, 18))))
	y += rows * 20.0
	# "8 hours", not "8.0 hours"; a half hour keeps its decimal.
	var t := float(budget["time"])
	var hours := str(int(t)) if is_equal_approx(t, roundf(t)) else "%.1f" % t
	var money := "Runway: %s in the bank, %s a month. Time to build: %s %s." % [
		Palette.money(budget["bank"]), Palette.money(budget["burn"]), hours,
		"hours" if budget.get("time_unit", "h") == "h" else budget["time_unit"]]
	# Lined up with the goals above it, in one column or two.
	var left := 24.0 if rows < goals.size() else 48.0
	_content.add_child(UI.place(UI.label(money, Palette.LABEL, Palette.SLATE_MID, true), Rect2(left, y + 8, 432.0 - left, 30)))
	_content.add_child(UI.place(UI.label("tap", Palette.BODY, Palette.SLATE_LIGHT), Rect2(446, 250, 24, 12)))
	await _wait(0)


func lesson_card(lesson: Dictionary) -> void:
	_begin(Palette.PAPER)
	_content.add_child(UI.place(UI.label("CODEX", Palette.LABEL, Palette.GREEN_DARK), Rect2(60, 60, 360, 14)))
	# A long term shrinks to fit the card's width rather than run off the screen.
	var px := 26
	while px > 16 and Palette.titles().get_string_size(lesson["term"], HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > 360:
		px -= 1
	_content.add_child(UI.place(UI.title(lesson["term"], px, Palette.SLATE), Rect2(60, 74 + (26 - px) * 0.5, 360, 34)))
	_content.add_child(UI.place(UI.label(lesson["plain"], Palette.HEAD, Palette.SLATE, true), Rect2(60, 114, 360, 100)))
	_content.add_child(UI.place(UI.label("tap", Palette.BODY, Palette.SLATE_LIGHT), Rect2(446, 250, 24, 12)))
	await _wait(0)


func black(text: String = "", hold: int = 90) -> void:
	_begin(Palette.BLACK)
	if text != "":
		var l := UI.place(UI.title(text, 20, Palette.WHITE), Rect2(0, 120, 480, 30)) as Label
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content.add_child(l)
	await _wait(hold)


func hide_card() -> void:
	visible = false


## hold > 0: also moves on by itself after that many frames.
func _wait(hold: int) -> void:
	_waiting = true
	_frames = 0
	_hold = hold
	_shown_at = Engine.get_process_frames()
	await advanced
	visible = false


func _process(_delta: float) -> void:
	if not _waiting:
		return
	_frames += 1
	var need := test_auto_frames if test_auto_frames > 0 else _hold
	if need > 0 and _frames >= need:
		_advance()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.pressed and (event.is_action("ui_accept") or event.is_action("ui_select")):
		_advance()
		get_viewport().set_input_as_handled()


func _advance() -> void:
	if not _waiting or Engine.get_process_frames() == _shown_at:
		return
	_waiting = false
	advanced.emit()
