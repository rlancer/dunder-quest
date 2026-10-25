class_name LaptopScreen
extends CanvasLayer

## The laptop screen: one flatmate's script, with blanks to fill. Left and
## right move between the blanks, up and down change what's in one, and Run
## sends the script to whoever it's for. The stage waits while it's open.
## By mouse or touch, tap a blank to change it.

signal run_requested(laptop: Laptop)

const PANEL := Rect2(24, 18, 432, 234)
const CODE_TOP := 46.0
const CODE_LEFT := 40.0
## Gap a blank's box leaves around its text.
const PAD := 2.0

var _laptop: Laptop
var _program: JsProgram
var _player: String = ""
var _slot: int = 0
var _canvas: Control
var _run_button: Button
var _close_button: Button
## Slot id -> its box on screen, for taps.
var _boxes: Dictionary = {}
var _blink: float = 0.0
var _closed_ms: int = -1000


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_editor)
	_canvas.gui_input.connect(_on_canvas_input)
	add_child(_canvas)
	_run_button = Button.new()
	_run_button.text = "Run"
	_run_button.position = Vector2(PANEL.end.x - 104, PANEL.end.y - 24)
	_run_button.size = Vector2(46, 18)
	_run_button.pressed.connect(_run)
	add_child(_run_button)
	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.position = Vector2(PANEL.end.x - 54, PANEL.end.y - 24)
	_close_button.size = Vector2(46, 18)
	_close_button.pressed.connect(close)
	add_child(_close_button)


func is_open() -> bool:
	return visible


## True for a moment after closing, so the key that closed it can't reopen it.
func just_closed() -> bool:
	return Time.get_ticks_msec() - _closed_ms < 200


func open(laptop: Laptop, player: String) -> void:
	_laptop = laptop
	_program = laptop.program
	_player = player
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


func _run() -> void:
	var laptop := _laptop
	close()
	StageAudio.play(get_tree(), preload("res://assets/audio/goal.wav"))
	run_requested.emit(laptop)


func _process(delta: float) -> void:
	if visible:
		_blink += delta
		_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var order := _program.slot_order
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"edit"):
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
		_program.set_pick(order[_slot], _program.pick(order[_slot]) - 1)
		_tick()
	elif event.is_action_pressed(&"move_down", true) and not order.is_empty():
		_program.set_pick(order[_slot], _program.pick(order[_slot]) + 1)
		_tick()
	elif event.is_action_pressed(&"jump") and event is InputEventJoypadButton:
		_run()
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
			_slot = _program.slot_order.find(id)
			_program.set_pick(id, _program.pick(id) + 1)
			_tick()
			return


func _draw_editor() -> void:
	if _program == null:
		return
	var c := _canvas
	var font := Palette.mono()
	c.draw_rect(Rect2(Vector2.ZERO, Vector2(480, 270)), Color(0, 0, 0, 0.5))
	# The laptop: a bezel, a title bar like a code editor's tab.
	c.draw_rect(PANEL.grow(3), Palette.INK.lightened(0.14))
	c.draw_rect(PANEL, Palette.CODE_BG)
	c.draw_rect(Rect2(PANEL.position, Vector2(PANEL.size.x, 18)), Palette.INK.lightened(0.08))
	var tint := Palette.tint_of(_program.runs_on) if _program.runs_on != "" else Palette.JS
	var tab := Rect2(PANEL.position + Vector2(6, 3), Vector2(CodeDraw.width(_program.file_name) + 14, 15))
	c.draw_rect(tab, Palette.CODE_BG)
	c.draw_rect(Rect2(tab.position, Vector2(tab.size.x, 1)), tint)
	c.draw_string(font, tab.position + Vector2(7, 11), _program.file_name, HORIZONTAL_ALIGNMENT_LEFT, -1, CodeDraw.SIZE, Palette.PAPER)
	var whose := "%s runs this." % _program.runs_on.capitalize() if _program.runs_on != "" else "The building runs this."
	if _program.runs_on == _player:
		whose += " You'll swap out when it starts."
	c.draw_string(font, Vector2(tab.end.x + 10, PANEL.position.y + 13), whose, HORIZONTAL_ALIGNMENT_LEFT, -1, CodeDraw.SIZE, tint.lerp(Palette.PAPER, 0.4))

	_boxes.clear()
	var selected := _program.slot_order[_slot] if not _program.slot_order.is_empty() else ""
	var y := CODE_TOP
	var number := 1
	for line: Array in _program.lines():
		c.draw_string(font, Vector2(PANEL.position.x + 6, y), str(number).lpad(2), HORIZONTAL_ALIGNMENT_LEFT, -1, CodeDraw.SIZE, Palette.CODE_LINE)
		var x := CODE_LEFT
		for segment: Dictionary in line:
			var text := str(segment["t"])
			var id := str(segment["slot"])
			if id == "":
				x += CodeDraw.draw_line(c, Vector2(x, y), text)
				continue
			x += PAD + 1
			var w := maxf(CodeDraw.width(text), 10.0)
			var box := Rect2(Vector2(x - PAD - 1, y - 10), Vector2(w + PAD * 2 + 2, 13))
			_boxes[id] = box
			var on := id == selected
			c.draw_rect(box, Color(0.97, 0.87, 0.12, 0.16) if on else Color(1, 1, 1, 0.06))
			c.draw_rect(box, Palette.JS if on else Palette.CODE_LINE.lightened(0.2), false, 1.0)
			CodeDraw.draw_line(c, Vector2(x, y), text)
			if on and int(_blink * 3.0) % 2 == 0:
				c.draw_string(font, Vector2(box.get_center().x - 3, box.position.y - 1), "^", HORIZONTAL_ALIGNMENT_LEFT, -1, CodeDraw.SIZE, Palette.JS)
			x += w + PAD + 1
		y += CodeDraw.LINE + 2
		number += 1

	# The open blank's options, listed under the code.
	if selected != "":
		var options := _program.options(selected)
		var row := PackedStringArray()
		for index in options.size():
			var label := _program.option_text(selected, options[index])
			row.append("[%s]" % label if index == _program.pick(selected) else label)
		c.draw_string(font, Vector2(CODE_LEFT, PANEL.end.y - 62), "Options:  " + "   ".join(row), HORIZONTAL_ALIGNMENT_LEFT, PANEL.size.x - 30, CodeDraw.SIZE, Palette.SYN_COMMENT.lightened(0.2))

	# The inner voice, wrapped to two lines, and the keys.
	if _laptop.hint != "":
		var hint_lines := _wrap("%s, thinking: %s" % [_player.capitalize(), _laptop.hint], PANEL.size.x - 20)
		for index in mini(hint_lines.size(), 2):
			c.draw_string(font, Vector2(PANEL.position.x + 10, PANEL.end.y - 46 + index * CodeDraw.LINE), hint_lines[index], HORIZONTAL_ALIGNMENT_LEFT, -1, CodeDraw.SIZE, Palette.tint_of(_player).lerp(Palette.PAPER, 0.5))
	var keys := "Tap a blank to change it" if TouchControls.active else "Left/Right: pick a blank   Up/Down: change it   Enter: run   Esc: close"
	c.draw_string(font, Vector2(PANEL.position.x + 10, PANEL.end.y - 10), keys, HORIZONTAL_ALIGNMENT_LEFT, PANEL.size.x - 120, CodeDraw.SIZE, Palette.STEEL)


## Breaks `text` into lines no wider than `width` in the code font.
static func _wrap(text: String, width: float) -> PackedStringArray:
	var lines := PackedStringArray()
	var line := ""
	for word in text.split(" "):
		var next := word if line == "" else line + " " + word
		if CodeDraw.width(next) > width and line != "":
			lines.append(line)
			line = word
		else:
			line = next
	if line != "":
		lines.append(line)
	return lines
