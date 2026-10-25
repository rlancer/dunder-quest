class_name Hud
extends CanvasLayer

## Everything drawn over a stage: whose head you're in, the inner voice,
## speech bubbles, the console, the custard creams and the clock, prompts,
## an arrow toward the flatmate off screen, lesson cards, the pause menu, the
## results card and fades. It runs while the tree is paused, so cards and
## menus work over a frozen stage.

signal paused_changed(paused: bool)
signal map_requested
signal restart_requested
signal continue_requested

const VIEW := Vector2(480, 270)
const CONSOLE_LINES := 4
const CONSOLE_HOLD := 9.0
const VOICE_PER_CHAR := 0.018
const VOICE_HOLD := 2.6

var _top: Label
var _lesson: Label
var _biscuits: Label
var _time: Label
var _pov: Label
var _pov_hint: Label
var _voice_box: PanelContainer
var _voice: Label
var _voice_time: float = 0.0
var _voice_full: String = ""
var _voice_shown: float = 0.0
var _prompt: Label
var _console: Control
var _console_lines: Array[Array] = []
var _console_time: float = 0.0
var _arrow: Control
var _arrow_at: Vector2 = Vector2.ZERO
var _arrow_tint: Color = Color.WHITE
var _arrow_on: bool = false
var _bubbles: Array[Dictionary] = []
var _card: Control
var _card_open: bool = false
var _menu: Control
var _menu_buttons: Array[Button] = []
var _results: Control
var _results_open: bool = false
var _start: Label
var _fade: ColorRect
var _world: Control


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_world = Control.new()
	_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.set_anchors_preset(Control.PRESET_FULL_RECT)
	_world.draw.connect(_draw_world)
	add_child(_world)

	_top = _label(Vector2(8, 4), 13, Palette.PAPER)
	_lesson = _label(Vector2(8, 18), 11, Palette.JS)
	_biscuits = _label(Vector2(8, 31), 11, Palette.AMBER)
	_time = _label(Vector2(8, 43), 11, Palette.STEEL)
	_pov = _label(Vector2(0, 4), 13, Palette.CLIVE)
	_pov.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pov.size = Vector2(472, 16)
	_pov_hint = _label(Vector2(0, 18), 11, Palette.STEEL)
	_pov_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pov_hint.size = Vector2(472, 14)

	_voice_box = PanelContainer.new()
	_voice_box.add_theme_stylebox_override(&"panel", _box(Color(0.06, 0.05, 0.08, 0.82), Palette.CLIVE))
	_voice_box.position = Vector2(110, 34)
	_voice_box.custom_minimum_size = Vector2(260, 0)
	_voice_box.size = Vector2(260, 10)
	_voice_box.visible = false
	add_child(_voice_box)
	_voice = Label.new()
	_voice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_voice.custom_minimum_size = Vector2(248, 0)
	_voice.add_theme_font_size_override(&"font_size", 11)
	_voice_box.add_child(_voice)

	_prompt = _label(Vector2(0, 252), 11, Palette.JS)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.size = Vector2(480, 14)

	_console = Control.new()
	_console.position = Vector2(6, 196)
	_console.size = Vector2(240, 54)
	_console.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_console.draw.connect(_draw_console)
	add_child(_console)

	_fade = ColorRect.new()
	_fade.color = Color(0.04, 0.03, 0.06)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	fade(0.0, 0.35)


func _label(at: Vector2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", Palette.INK)
	label.add_theme_constant_override(&"outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


static func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.border_width_left = 3
	box.set_content_margin_all(5)
	box.anti_aliasing = false
	return box


# --- Status -----------------------------------------------------------------

func set_stage(stage_name: String, lesson: String) -> void:
	_top.text = stage_name
	_lesson.text = lesson


func set_biscuits(have: int, total: int) -> void:
	_biscuits.text = "Custard creams %d/%d" % [have, total]


func set_time(seconds: float) -> void:
	_time.text = Progress.format_time(seconds)


func set_pov(who: String) -> void:
	_pov.text = "In %s's head" % who.capitalize()
	_pov.add_theme_color_override(&"font_color", Palette.tint_of(who))
	_pov_hint.text = "%s: swap" % Controls.label(&"swap")
	(_voice_box.get_theme_stylebox(&"panel") as StyleBoxFlat).border_color = Palette.tint_of(who)


func prompt(text: String) -> void:
	_prompt.text = text


## The inner voice types itself out, then fades.
func inner_voice(who: String, line: String) -> void:
	_voice_full = "%s, thinking: %s" % [who.capitalize(), line]
	_voice_shown = 0.0
	_voice.text = ""
	_voice.add_theme_color_override(&"font_color", Palette.tint_of(who).lerp(Palette.PAPER, 0.55))
	_voice_time = VOICE_HOLD + line.length() * 0.05
	_voice_box.visible = true


func speech(mate: Node2D, text: String) -> void:
	for bubble in _bubbles:
		if bubble["who"] == mate:
			_bubbles.erase(bubble)
			break
	_bubbles.append({"who": mate, "text": text, "time": 1.4 + text.length() * 0.05})


func console(text: String, kind: StringName) -> void:
	_console_lines.append([text, kind])
	while _console_lines.size() > CONSOLE_LINES:
		_console_lines.pop_front()
	_console_time = CONSOLE_HOLD
	_console.queue_redraw()


func clear_console() -> void:
	_console_lines.clear()
	_console.queue_redraw()


## Points at the flatmate you aren't playing when he's off screen.
func track_other(other: Node2D, _camera: Camera2D) -> void:
	var screen := get_viewport().get_canvas_transform() * other.global_position
	var view := get_viewport().get_visible_rect().size
	var margin := 12.0
	_arrow_on = screen.x < -4 or screen.x > view.x + 4 or screen.y < -4 or screen.y > view.y + 4
	_arrow_at = Vector2(clampf(screen.x, margin, view.x - margin), clampf(screen.y - 10, margin + 40, view.y - margin - 20))
	_arrow_tint = Palette.tint_of(str(other.get(&"who")))


func _process(delta: float) -> void:
	if _voice_box.visible:
		if _voice_shown < _voice_full.length():
			_voice_shown += delta / VOICE_PER_CHAR
			_voice.text = _voice_full.left(int(_voice_shown))
		else:
			_voice_time -= delta
			if _voice_time <= 0.0:
				_voice_box.visible = false
	if _console_time > 0.0:
		_console_time -= delta
		if _console_time <= 0.0:
			_console_lines.clear()
			_console.queue_redraw()
	for index in range(_bubbles.size() - 1, -1, -1):
		_bubbles[index]["time"] = float(_bubbles[index]["time"]) - delta
		if float(_bubbles[index]["time"]) <= 0.0 or not is_instance_valid(_bubbles[index]["who"]):
			_bubbles.remove_at(index)
	_world.queue_redraw()


func _draw_world() -> void:
	var font := Palette.mono()
	var xform := get_viewport().get_canvas_transform()
	for bubble in _bubbles:
		var mate := bubble["who"] as Node2D
		var text := str(bubble["text"])
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.SMALL).x
		var at := (xform * mate.global_position + Vector2(0, -32)).round()
		var rect := Rect2(at + Vector2(-width * 0.5 - 4, -11), Vector2(width + 8, 14)).abs()
		rect.position.x = clampf(rect.position.x, 2, VIEW.x - rect.size.x - 2)
		_world.draw_rect(rect, Palette.PAPER)
		_world.draw_rect(rect, Palette.INK, false, 1.0)
		_world.draw_rect(Rect2(at + Vector2(-2, 3), Vector2(4, 3)), Palette.PAPER)
		_world.draw_string(font, rect.position + Vector2(4, 11), text, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.SMALL, Palette.INK)
	if _arrow_on:
		var tip := _arrow_at
		var view := get_viewport().get_visible_rect().size
		var dir := (tip - view * 0.5).normalized()
		var side := Vector2(-dir.y, dir.x)
		var points := PackedVector2Array([tip + dir * 5, tip - dir * 4 + side * 5, tip - dir * 4 - side * 5])
		_world.draw_colored_polygon(points, _arrow_tint)
		_world.draw_polyline(points + PackedVector2Array([points[0]]), Palette.INK, 1.0)


func _draw_console() -> void:
	if _console_lines.is_empty():
		return
	var height := 6 + _console_lines.size() * CodeDraw.LINE
	var rect := Rect2(Vector2(0, _console.size.y - height), Vector2(_console.size.x, height))
	_console.draw_rect(rect, Color(0.04, 0.04, 0.07, 0.86))
	_console.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1)), Palette.CODE_LINE)
	_console.draw_string(Palette.mono(), rect.position + Vector2(rect.size.x - 44, -2), "console", HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.SMALL, Palette.SYN_COMMENT)
	var y := rect.position.y + 3 + CodeDraw.LINE - 2
	for line: Array in _console_lines:
		var kind: StringName = line[1]
		var color := Palette.CODE
		if kind == &"error":
			color = Palette.RED.lightened(0.2)
		elif kind == &"cmd":
			color = Palette.SYN_COMMENT
		_console.draw_string(Palette.mono(), Vector2(5, y), str(line[0]), HORIZONTAL_ALIGNMENT_LEFT, _console.size.x - 10, CodeDraw.SIZE, color)
		y += CodeDraw.LINE


# --- Cards, menus, results --------------------------------------------------

## A lesson card from the inner voice. Holds the stage until it's read.
func open_card(card: Dictionary) -> void:
	_close_card()
	_card_open = true
	paused_changed.emit(true)
	_card = _card_panel(str(card.get("who", "clive")), str(card.get("title", "")), str(card.get("code", "")), str(card.get("text", "")))
	add_child(_card)
	move_child(_fade, -1)


func _card_panel(who: String, title: String, code: String, text: String) -> Control:
	var tint := Palette.tint_of(who)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var panel := PanelContainer.new()
	var box := _box(Color(0.08, 0.07, 0.11, 0.97), tint)
	box.set_content_margin_all(8)
	panel.add_theme_stylebox_override(&"panel", box)
	panel.position = Vector2(60, 24)
	panel.custom_minimum_size = Vector2(360, 0)
	root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 4)
	panel.add_child(column)
	var kicker := Label.new()
	kicker.text = "%s's inner voice" % who.capitalize()
	kicker.add_theme_font_size_override(&"font_size", 11)
	kicker.add_theme_color_override(&"font_color", tint)
	column.add_child(kicker)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override(&"font_size", 16)
	heading.add_theme_color_override(&"font_color", Palette.PAPER)
	column.add_child(heading)
	if code != "":
		var view := CodeBlock.new()
		view.code = code
		column.add_child(view)
	var body := Label.new()
	body.text = text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(344, 0)
	body.add_theme_font_size_override(&"font_size", 11)
	body.add_theme_color_override(&"font_color", Palette.PAPER.darkened(0.08))
	column.add_child(body)
	var footer := Label.new()
	footer.text = "Tap to carry on" if TouchControls.active else "%s to carry on" % Controls.label(&"confirm")
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_theme_font_size_override(&"font_size", 11)
	footer.add_theme_color_override(&"font_color", Palette.STEEL)
	column.add_child(footer)
	# Grow the panel to its content, centered vertically.
	panel.resized.connect(func() -> void: panel.position.y = roundf((VIEW.y - panel.size.y) * 0.5))
	return root


func _close_card() -> void:
	if _card != null:
		_card.queue_free()
		_card = null
	if _card_open:
		_card_open = false
		paused_changed.emit(false)


func is_busy() -> bool:
	return _card_open or _menu != null or _results_open


func _unhandled_input(event: InputEvent) -> void:
	if _start != null and _start.visible:
		return
	if _card_open:
		if event.is_action_pressed(&"confirm") or event.is_action_pressed(&"jump") or event.is_action_pressed(&"pause") or (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
			get_viewport().set_input_as_handled()
			_close_card()
		return
	if _results_open:
		if event.is_action_pressed(&"confirm") or event.is_action_pressed(&"jump") or (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
			get_viewport().set_input_as_handled()
			_results_open = false
			continue_requested.emit()
		return
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		if _menu != null:
			close_menu()
		elif not get_tree().paused:
			open_menu()


func open_menu() -> void:
	paused_changed.emit(true)
	_menu = Control.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(dim)
	var column := VBoxContainer.new()
	column.position = Vector2(170, 70)
	column.custom_minimum_size = Vector2(140, 0)
	column.add_theme_constant_override(&"separation", 6)
	_menu.add_child(column)
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 16)
	column.add_child(title)
	_menu_buttons.clear()
	for entry: Array in [["Carry on", close_menu], ["Start the stage again", func() -> void: restart_requested.emit()], ["Back to the line map", func() -> void: map_requested.emit()]]:
		var button := Button.new()
		button.text = str(entry[0])
		button.pressed.connect(entry[1])
		column.add_child(button)
		_menu_buttons.append(button)
	add_child(_menu)
	move_child(_fade, -1)
	_menu_buttons[0].grab_focus()


func close_menu() -> void:
	if _menu != null:
		_menu.queue_free()
		_menu = null
	paused_changed.emit(false)


func show_results(line: String, rows: Array, last: bool) -> void:
	_results = Control.new()
	_results.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_results.add_child(dim)
	var panel := PanelContainer.new()
	var box := _box(Color(0.08, 0.07, 0.11, 0.97), Palette.JS)
	box.set_content_margin_all(10)
	panel.add_theme_stylebox_override(&"panel", box)
	panel.position = Vector2(130, 56)
	panel.custom_minimum_size = Vector2(220, 0)
	_results.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 3)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "The end. For now." if last else "Stage clear"
	heading.add_theme_font_size_override(&"font_size", 18)
	heading.add_theme_color_override(&"font_color", Palette.JS)
	column.add_child(heading)
	var sub := Label.new()
	sub.text = line
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(200, 0)
	sub.add_theme_font_size_override(&"font_size", 11)
	column.add_child(sub)
	for row: Array in rows:
		var line_box := HBoxContainer.new()
		var key := Label.new()
		key.text = str(row[0])
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key.add_theme_font_size_override(&"font_size", 11)
		key.add_theme_color_override(&"font_color", Palette.STEEL)
		var value := Label.new()
		value.text = str(row[1])
		value.add_theme_font_size_override(&"font_size", 11)
		line_box.add_child(key)
		line_box.add_child(value)
		column.add_child(line_box)
	var footer := Label.new()
	footer.text = "Tap for the line map" if TouchControls.active else "%s for the line map" % Controls.label(&"confirm")
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_theme_font_size_override(&"font_size", 11)
	footer.add_theme_color_override(&"font_color", Palette.STEEL)
	column.add_child(footer)
	add_child(_results)
	move_child(_fade, -1)
	_results_open = true


func show_press_to_start() -> void:
	_start = _label(Vector2(0, 128), 13, Palette.JS)
	_start.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_start.size = Vector2(480, 16)
	_start.text = "Tap to start" if TouchControls.active else "Press any key to start"


func hide_press_to_start() -> void:
	if _start != null:
		_start.visible = false


func fade(to: float, seconds: float) -> Signal:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", to, seconds)
	return tween.finished
