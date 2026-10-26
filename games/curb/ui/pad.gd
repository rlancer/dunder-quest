class_name LegalPad
extends CanvasLayer

## Barry's yellow legal pad: the plan, in Rust, with blanks to fill. Left and
## right move between the blanks, up and down change what's in one, and Enter
## (or the Run button) plays the scene out. By mouse or touch, tap a blank to
## cycle it. The scene waits while the pad is open.

signal run_requested(plan: Plan)
signal closed

const PANEL := Rect2(14, 6, 452, 258)
const CODE_TOP := 40.0
const CODE_LEFT := 46.0
const STEP := 11.0
const PAD := 2.0

var plan: Plan
var _hint: String = ""
var _slot: int = 0
var _canvas: Control
var _run_button: Button
var _close_button: Button
var _boxes: Dictionary = {}
var _blink: float = 0.0
var _closed_ms: int = -1000
## Line to mark as the one Sharon objected to last time, or 0.
var flagged_line: int = 0


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_pad)
	_canvas.gui_input.connect(_on_canvas_input)
	add_child(_canvas)
	_run_button = Button.new()
	_run_button.text = "Run it"
	_run_button.position = Vector2(PANEL.end.x - 118, PANEL.end.y - 22)
	_run_button.size = Vector2(58, 18)
	_run_button.pressed.connect(_run)
	add_child(_run_button)
	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.position = Vector2(PANEL.end.x - 56, PANEL.end.y - 22)
	_close_button.size = Vector2(50, 18)
	_close_button.pressed.connect(close)
	add_child(_close_button)


func is_open() -> bool:
	return visible


func just_closed() -> bool:
	return Time.get_ticks_msec() - _closed_ms < 200


func open(p: Plan, hint: String) -> void:
	plan = p
	_hint = hint
	_slot = 0
	visible = true
	get_tree().paused = true
	StageAudio.play(get_tree(), preload("res://assets/audio/bump.wav"))
	_canvas.queue_redraw()


func close() -> void:
	if not visible:
		return
	visible = false
	_closed_ms = Time.get_ticks_msec()
	get_tree().paused = false
	closed.emit()


func run() -> void:
	_run()


func _run() -> void:
	if not visible:
		return
	var p := plan
	visible = false
	_closed_ms = Time.get_ticks_msec()
	get_tree().paused = false
	StageAudio.play(get_tree(), preload("res://assets/audio/goal.wav"))
	run_requested.emit(p)


func _process(delta: float) -> void:
	if visible:
		_blink += delta
		_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var order := plan.slot_order
	if event.is_action_pressed(&"pause"):
		close()
	elif event.is_action_pressed(&"run") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER)):
		_run()
	elif event.is_action_pressed(&"move_left", true) and not order.is_empty():
		_slot = posmod(_slot - 1, order.size())
		_tick()
	elif event.is_action_pressed(&"move_right", true) and not order.is_empty():
		_slot = posmod(_slot + 1, order.size())
		_tick()
	elif event.is_action_pressed(&"move_up", true) and not order.is_empty():
		plan.set_pick(order[_slot], plan.pick(order[_slot]) - 1)
		_tick()
	elif event.is_action_pressed(&"move_down", true) and not order.is_empty():
		plan.set_pick(order[_slot], plan.pick(order[_slot]) + 1)
		_tick()
	else:
		return
	get_viewport().set_input_as_handled()


func _tick() -> void:
	StageAudio.play(get_tree(), preload("res://assets/audio/bump.wav"))
	_canvas.queue_redraw()


func _on_canvas_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
	if not tap:
		return
	var at: Vector2 = event.position
	for id: String in _boxes:
		if (_boxes[id] as Rect2).grow(3).has_point(at):
			_slot = plan.slot_order.find(id)
			plan.set_pick(id, plan.pick(id) + 1)
			_tick()
			return


func _draw_pad() -> void:
	if plan == null:
		return
	var c := _canvas
	var font := Palette.mono()
	c.draw_rect(Rect2(Vector2.ZERO, Vector2(480, 270)), Color(0, 0, 0, 0.55))
	# The pad: a cardboard back, yellow paper, a binding strip, blue rules.
	c.draw_rect(PANEL.grow(3), Color(0.42, 0.3, 0.2))
	c.draw_rect(PANEL, Palette.PAD)
	c.draw_rect(Rect2(PANEL.position, Vector2(PANEL.size.x, 22)), Color(0.55, 0.18, 0.14))
	for i in 6:
		c.draw_rect(Rect2(PANEL.position + Vector2(20 + i * 74, 0), Vector2(30, 4)), Color(0.4, 0.12, 0.1))
	var y_rule := CODE_TOP + 3.0
	while y_rule < PANEL.end.y - 60:
		c.draw_line(Vector2(PANEL.position.x, y_rule), Vector2(PANEL.end.x, y_rule), Color(Palette.PAD_RULE, 0.45), 1.0)
		y_rule += STEP
	c.draw_line(Vector2(CODE_LEFT - 6, PANEL.position.y + 22), Vector2(CODE_LEFT - 6, PANEL.end.y), Color(Palette.PAD_MARGIN, 0.7), 1.0)
	var title := "%s  ·  %s" % [plan.file_name, plan.title]
	c.draw_string(font, PANEL.position + Vector2(8, 15), title, HORIZONTAL_ALIGNMENT_LEFT, -1, CodeDraw.SIZE, Palette.PAPER)
	c.draw_string(font, Vector2(PANEL.end.x - 150, PANEL.position.y + 15), "Barry's plan, in Rust", HORIZONTAL_ALIGNMENT_LEFT, -1, CodeDraw.SIZE, Palette.PAPER.darkened(0.15))

	_boxes.clear()
	var selected := plan.slot_order[_slot] if not plan.slot_order.is_empty() else ""
	var y := CODE_TOP
	var number := 1
	for line: Array in plan.lines():
		var flagged := number == flagged_line
		if flagged:
			c.draw_rect(Rect2(Vector2(PANEL.position.x + 2, y - 10), Vector2(PANEL.size.x - 4, STEP)), Color(Palette.RED, 0.14))
		c.draw_string(font, Vector2(PANEL.position.x + 8, y), str(number).lpad(2), HORIZONTAL_ALIGNMENT_LEFT, -1, CodeDraw.SIZE, Palette.RED if flagged else Palette.PAD_RULE.darkened(0.2))
		var x := CODE_LEFT
		for segment: Dictionary in line:
			var text := str(segment["t"])
			var id := str(segment["slot"])
			if id == "":
				x += CodeDraw.draw_line(c, Vector2(x, y), text)
				continue
			x += PAD + 1
			var w := maxf(CodeDraw.width(text), 12.0)
			var box := Rect2(Vector2(x - PAD - 1, y - 10), Vector2(w + PAD * 2 + 2, 12))
			_boxes[id] = box
			var on := id == selected
			c.draw_rect(box, Color(Palette.RUST, 0.22) if on else Color(1, 1, 1, 0.5))
			c.draw_rect(box, Palette.RUST if on else Palette.PAD_INK.lightened(0.4), false, 1.0)
			CodeDraw.draw_line(c, Vector2(x, y), text)
			if on and int(_blink * 3.0) % 2 == 0:
				c.draw_string(font, Vector2(box.get_center().x - 3, box.end.y + 8), "^", HORIZONTAL_ALIGNMENT_LEFT, -1, CodeDraw.SIZE, Palette.RUST)
			x += w + PAD + 1
		y += STEP
		number += 1

	var bottom := PANEL.end.y
	if selected != "":
		var options := plan.options(selected)
		var row := PackedStringArray()
		for index in options.size():
			var label := str(options[index]) if str(options[index]) != "" else "(nothing)"
			row.append("[%s]" % label if index == plan.pick(selected) else label)
		var text := "Options:  " + "   ".join(row)
		if CodeDraw.width(text) > PANEL.size.x - 16:
			# Too long to list them all: show the one that's in, and how many.
			var current := str(options[plan.pick(selected)])
			text = "Option %d of %d: %s   (Up/Down for the others)" % [plan.pick(selected) + 1, options.size(), current if current != "" else "(nothing)"]
		c.draw_string(font, Vector2(PANEL.position.x + 8, bottom - 52), text, HORIZONTAL_ALIGNMENT_LEFT, PANEL.size.x - 16, CodeDraw.SIZE, Palette.RUST.darkened(0.25))
	if _hint != "":
		var hint_lines := CodeDraw.wrap("Barry, thinking: " + _hint, PANEL.size.x - 16)
		for i in mini(hint_lines.size(), 2):
			c.draw_string(font, Vector2(PANEL.position.x + 8, bottom - 39 + i * 11), hint_lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, CodeDraw.SIZE, Palette.PAD_INK.lightened(0.25))
	var keys := "Tap a blank to change it" if TouchControls.active else "Left/Right: blank   Up/Down: change   Enter: run"
	c.draw_string(font, Vector2(PANEL.position.x + 8, bottom - 8), keys, HORIZONTAL_ALIGNMENT_LEFT, PANEL.size.x - 130, CodeDraw.SIZE, Palette.STEEL_DARK)
