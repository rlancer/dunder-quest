class_name Hud
extends CanvasLayer

## Everything drawn over a scene: speech bubbles, the close-up inset, the
## code strip that follows the plan line by line, Sharon's interruption (her
## face, the rustc error and the offending line), panics, lesson cards, the
## black title cards in plain serif, the freeze frame and the end card.
##
## The scene drives it with coroutines: `await hud.say(...)` returns once the
## player has read the line (Enter, E, Space or a tap). Tests set
## `auto_frames` so lines move on by themselves.

signal advanced

const BUBBLE_WIDTH := 190.0
const CODE_RECT := Rect2(8, 6, 464, 70)

## Tests set these before a scene starts; every new HUD picks them up.
static var test_auto_frames: int = 0
static var test_per_char: float = 0.0

## When above zero, every wait ends by itself after this many frames.
var auto_frames: int = test_auto_frames
## Extra frames per character of text, so longer lines stay up longer.
var auto_per_char: float = test_per_char

var _canvas: Control
var _waiting: bool = false
var _wait_started: int = 0
var _wait_frames: int = 0
var _wait_need: int = 0

# What's showing.
var bubble: Dictionary = {}
var prompt: String = ""
var place: String = ""
var _code_plan: Plan
var _code_line: int = 0
var _code_sepia: bool = false
var _code_error_line: int = 0
var _closeup: Dictionary = {}
var _rant: Dictionary = {}
var _panic: Dictionary = {}
var _card: Dictionary = {}
var _card_block: CodeBlock
var _title: Dictionary = {}
var _end: Dictionary = {}
var _freeze: float = 0.0
var _sepia: float = 0.0
var _press_start: bool = false
var _flash: float = 0.0
var _clock: float = 0.0
var _faces: Dictionary = {}
## How many times Sharon has interrupted, and panics shown, for the tests.
var rant_count: int = 0
var panic_count: int = 0
var _title_serial: int = 0


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)
	_card_block = CodeBlock.new()
	_card_block.visible = false
	add_child(_card_block)


func _process(delta: float) -> void:
	_clock += delta
	_flash = maxf(_flash - delta * 3.0, 0.0)
	if _waiting and auto_frames > 0:
		_wait_frames += 1
		if _wait_frames >= _wait_need:
			advance()
	_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if not _waiting:
		return
	if Time.get_ticks_msec() - _wait_started < 180:
		return
	var tap: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
	if tap or event.is_action_pressed(&"confirm") or event.is_action_pressed(&"edit"):
		get_viewport().set_input_as_handled()
		advance()


func is_waiting() -> bool:
	return _waiting


func advance() -> void:
	if not _waiting:
		return
	_waiting = false
	advanced.emit()


## Waits for the player (or `auto_frames`) to move on. `chars` lengthens the
## automatic wait for longer text.
func wait(chars: int = 0) -> void:
	_waiting = true
	_wait_started = Time.get_ticks_msec()
	_wait_frames = 0
	_wait_need = auto_frames + int(auto_per_char * chars)
	await advanced


func face_texture(who: String) -> Texture2D:
	if not _faces.has(who):
		var path := "res://assets/sprites/%s_face.png" % who
		_faces[who] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _faces[who]


# --- Lines ------------------------------------------------------------------

## A speech bubble over `speaker` (or a caption when null) until read.
func say(speaker: Person, text: String, mood: String = "") -> void:
	var name := speaker.display_name if speaker != null else ""
	bubble = {"who": speaker, "name": name, "text": text, "mood": mood, "shown": 0.0}
	if speaker != null:
		match mood:
			"squint":
				speaker.strike(Person.Pose.SQUINT, 60.0)
				_closeup = {"who": speaker.who, "frame": 2, "side": 1 if speaker.position.x < 240 else -1}
			"yell":
				speaker.strike(Person.Pose.YELL, 60.0)
			_:
				speaker.strike(Person.Pose.TALK, 60.0)
	await wait(text.length())
	if speaker != null:
		speaker.strike(Person.Pose.SQUINT if mood == "squint" else Person.Pose.IDLE, 0.6)
	bubble = {}
	_closeup = {}


## Shows a line without waiting, for the run of a plan (println! output).
func show_line(speaker: Person, text: String) -> void:
	bubble = {"who": speaker, "name": speaker.display_name if speaker != null else "", "text": text, "mood": "", "shown": 0.0}
	if speaker != null:
		speaker.strike(Person.Pose.TALK, 1.0)


func clear_line() -> void:
	bubble = {}


func closeup(who: String, frame: int, side: int = 1) -> void:
	_closeup = {"who": who, "frame": frame, "side": side} if who != "" else {}


# --- The code strip ---------------------------------------------------------

func show_code(plan: Plan, sepia: bool) -> void:
	_code_plan = plan
	_code_line = 0
	_code_sepia = sepia
	_code_error_line = 0


func highlight(line: int) -> void:
	_code_line = line


func mark_error_line(line: int) -> void:
	_code_error_line = line
	_code_line = line


func hide_code() -> void:
	_code_plan = null


func set_sepia(amount: float) -> void:
	_sepia = amount


func flash() -> void:
	_flash = 1.0


# --- Interruptions ----------------------------------------------------------

## Sharon bursts in: her face, her line, and the rustc error it stands for.
func rant(checker: String, line_text: String, error: Dictionary, plan: Plan) -> void:
	var name := Story.name_of(checker)
	rant_count += 1
	_rant = {"who": checker, "name": name, "text": line_text, "error": error, "file": plan.file_name, "code": _source_line(plan, int(error.get("line", 0)))}
	await wait(line_text.length() + 60)
	_rant = {}


func panic(speaker: String, line_text: String, message: String, plan: Plan, line: int) -> void:
	panic_count += 1
	_panic = {"who": speaker, "name": Story.name_of(speaker), "text": line_text, "message": message, "file": plan.file_name, "line": line}
	await wait(line_text.length() + 40)
	_panic = {}


static func _source_line(plan: Plan, line: int) -> String:
	var src := plan.source().split("\n")
	return src[line - 1] if line >= 1 and line <= src.size() else ""


func show_card(card: Dictionary) -> void:
	_card = card
	_card_block.code = str(card.get("code_text", ""))
	_card_block.visible = true
	await wait(str(card.get("text", "")).length() + 40)
	_card = {}
	_card_block.visible = false


# --- Title cards, freeze frame, end card ------------------------------------

## A black card with plain serif text, like the opening of an episode.
func title_card(title: String, small: String = "", seconds: float = 2.4) -> void:
	_title = {"title": title, "small": small, "alpha": 1.0}
	if auto_frames > 0:
		await wait(0)
	else:
		_title_serial += 1
		var mine := _title_serial
		var timer := get_tree().create_timer(seconds, true)
		_waiting = true
		_wait_started = Time.get_ticks_msec()
		_wait_need = 1 << 30
		timer.timeout.connect(func() -> void:
			if _title_serial == mine and not _title.is_empty():
				advance())
		await advanced
	_title = {}


func set_freeze(amount: float) -> void:
	_freeze = amount


func end_card(lines: Array) -> void:
	_end = {"lines": lines}
	await wait(80)
	_end = {}


func show_press_to_start() -> void:
	_press_start = true


func hide_press_to_start() -> void:
	_press_start = false


func is_card_open() -> bool:
	return not _card.is_empty()


# --- Drawing ----------------------------------------------------------------

func _draw_hud() -> void:
	var c := _canvas
	if _sepia > 0.0:
		c.draw_rect(Rect2(0, 0, 480, 270), Color(Palette.SEPIA, 0.38 * _sepia))
		c.draw_rect(Rect2(0, 0, 480, 270), Color(0.2, 0.12, 0.05, 0.18 * _sepia))
	if _freeze > 0.0:
		c.draw_rect(Rect2(0, 0, 480, 270), Color(0.95, 0.9, 0.8, 0.12 * _freeze))
		for edge in 4:
			var t := float(edge) * 5.0
			c.draw_rect(Rect2(t, t, 480 - t * 2, 270 - t * 2), Color(0, 0, 0, 0.12 * _freeze), false, 5.0)
	if place != "" and _title.is_empty() and _end.is_empty():
		_draw_label(Vector2(476, 264), place, HORIZONTAL_ALIGNMENT_RIGHT, Palette.PAPER.darkened(0.08))
	if _code_plan != null:
		_draw_code(c)
	if not _closeup.is_empty():
		_draw_closeup(c)
	if not bubble.is_empty():
		_draw_bubble(c)
	if prompt != "" and bubble.is_empty() and _rant.is_empty():
		var w := Palette.mono().get_string_size(prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		c.draw_rect(Rect2(240 - w / 2 - 6, 247, w + 12, 16), Color(0.05, 0.04, 0.07, 0.8))
		c.draw_string(Palette.mono(), Vector2(240 - w / 2, 259), prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.AMBER)
	if not _rant.is_empty():
		_draw_rant(c)
	if not _panic.is_empty():
		_draw_panic(c)
	if not _card.is_empty():
		_draw_card(c)
	if _flash > 0.0:
		c.draw_rect(Rect2(0, 0, 480, 270), Color(1, 1, 1, 0.5 * _flash))
	if not _title.is_empty():
		_draw_title(c)
	if not _end.is_empty():
		_draw_end(c)
	if _press_start:
		c.draw_rect(Rect2(0, 0, 480, 270), Color(0, 0, 0, 0.85))
		_draw_centered(c, Palette.serif(), "Curb Your Oxidation", 135, 22, Palette.PAPER)
		var press := "Tap to start" if TouchControls.active else "Press any key"
		_draw_centered(c, Palette.mono(), press, 168, 16, Palette.AMBER)


func _draw_label(at: Vector2, text: String, align: HorizontalAlignment, color: Color) -> void:
	var font := Palette.mono()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var x := at.x - w if align == HORIZONTAL_ALIGNMENT_RIGHT else at.x
	_canvas.draw_string_outline(font, Vector2(x, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Palette.INK)
	_canvas.draw_string(font, Vector2(x, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)


func _draw_centered(c: Control, font: Font, text: String, y: float, size: int, color: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	c.draw_string(font, Vector2(roundf(240 - w / 2), y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _draw_bubble(c: Control) -> void:
	var font := Palette.mono()
	var speaker: Person = bubble.who
	var text: String = bubble.text
	var lines := CodeDraw.wrap(text, BUBBLE_WIDTH - 12)
	var w := 0.0
	for line in lines:
		w = maxf(w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x)
	var name: String = bubble.name
	w = maxf(w, font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x) + 12
	# Room after the last line for the blinking "v", so it never sits on the text.
	w = maxf(w, font.get_string_size(lines[-1] if not lines.is_empty() else "", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 22)
	var h := lines.size() * 12 + (14 if name != "" else 6) + 4
	var anchor := Vector2(240, 120)
	if speaker != null and is_instance_valid(speaker):
		anchor = speaker.head()
	var box := Rect2(Vector2(clampf(anchor.x - w / 2, 4, 476 - w), maxf(anchor.y - h - 10, CODE_RECT.end.y + 4 if _code_plan != null else 4)), Vector2(w, h))
	var fill := Palette.PAPER
	var border := Palette.INK
	if bubble.mood == "squint":
		fill = Palette.PAPER.lerp(Palette.SEPIA, 0.25)
	c.draw_rect(box.grow(1), border)
	c.draw_rect(box, fill)
	if speaker != null:
		var tip := Vector2(clampf(anchor.x, box.position.x + 6, box.end.x - 6), box.end.y)
		c.draw_colored_polygon(PackedVector2Array([tip + Vector2(-4, 0), tip + Vector2(4, 0), Vector2(clampf(anchor.x, box.position.x + 2, box.end.x - 2), minf(anchor.y - 2, box.end.y + 8))]), border)
		c.draw_colored_polygon(PackedVector2Array([tip + Vector2(-3, -1), tip + Vector2(3, -1), Vector2(clampf(anchor.x, box.position.x + 3, box.end.x - 3), minf(anchor.y - 4, box.end.y + 6))]), fill)
	var y := box.position.y + 11
	if name != "":
		c.draw_string(font, Vector2(box.position.x + 6, y), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.RUST.darkened(0.2))
		y += 12
	for line in lines:
		c.draw_string(font, Vector2(box.position.x + 6, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.INK)
		y += 12
	if _waiting and int(_clock * 3.0) % 2 == 0:
		c.draw_string(font, box.end + Vector2(-9, -2), "v", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.RUST)


func _draw_closeup(c: Control) -> void:
	var tex := face_texture(str(_closeup.who))
	if tex == null:
		return
	var side: int = _closeup.side
	var rect := Rect2(Vector2(372 if side > 0 else 12, 92), Vector2(96, 96))
	c.draw_rect(rect.grow(3), Palette.INK)
	c.draw_rect(rect.grow(1), Palette.PAPER)
	c.draw_texture_rect_region(tex, rect, Rect2(48 * int(_closeup.frame), 0, 48, 48))


func _draw_code(c: Control) -> void:
	var font := Palette.mono()
	var plan := _code_plan
	var rect := CODE_RECT
	var bg := Palette.PAD.lerp(Palette.SEPIA, 0.55 if _code_sepia else 0.0)
	c.draw_rect(rect.grow(2), Color(0.42, 0.3, 0.2))
	c.draw_rect(rect, bg)
	var header := plan.file_name + ("   (Barry, rehearsing it in his head)" if _code_sepia else "   (it's happening)")
	c.draw_string(font, rect.position + Vector2(5, 10), header, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 8, 16, Palette.PAD_INK.lightened(0.3))
	var src := plan.source().split("\n")
	var total := src.size()
	var first := clampi(_code_line - 3, 0, maxi(total - 5, 0))
	for row in 5:
		var index := first + row
		if index >= total:
			break
		var y := rect.position.y + 22 + row * 11
		var number := index + 1
		if number == _code_line:
			var shade := Color(Palette.RED, 0.3) if number == _code_error_line else Color(Palette.RUST, 0.2)
			c.draw_rect(Rect2(Vector2(rect.position.x + 1, y - 9), Vector2(rect.size.x - 2, 11)), shade)
			c.draw_string(font, Vector2(rect.position.x + 2, y), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.RED if number == _code_error_line else Palette.RUST)
		c.draw_string(font, Vector2(rect.position.x + 9, y), str(number).lpad(2), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.PAD_RULE.darkened(0.3))
		var text := str(src[index])
		if CodeDraw.width(text) > rect.size.x - 30:
			while CodeDraw.width(text + "..") > rect.size.x - 30 and text.length() > 4:
				text = text.substr(0, text.length() - 1)
			text += ".."
		CodeDraw.draw_line(c, Vector2(rect.position.x + 25, y), text, Palette.PAD_INK, 0.35 if _code_sepia else 0.0)


func _draw_rant(c: Control) -> void:
	var font := Palette.mono()
	var panel := Rect2(6, 140, 468, 124)
	c.draw_rect(panel.grow(1), Palette.RED.darkened(0.3))
	c.draw_rect(panel, Color(0.08, 0.05, 0.07, 0.96))
	var tex := face_texture(str(_rant.who))
	var face_rect := Rect2(panel.position + Vector2(6, 9), Vector2(96, 96))
	if tex != null:
		var frame := 3 if int(_clock * 6.0) % 2 == 0 else 1
		c.draw_rect(face_rect.grow(1), Palette.PAPER)
		c.draw_texture_rect_region(tex, face_rect, Rect2(48 * frame, 0, 48, 48))
	var x := face_rect.end.x + 8
	var limit := panel.end.x - x - 6
	var err: Dictionary = _rant.error
	var code := str(err.get("code", ""))
	var head := ("error[%s]: " % code) if code != "" else "error: "
	var msg := str(err.get("msg", ""))
	var y := panel.position.y + 13
	var err_lines := CodeDraw.wrap(head + msg, limit)
	for i in mini(err_lines.size(), 2):
		c.draw_string(font, Vector2(x, y), err_lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.RED.lightened(0.25))
		y += 12
	var line_no := int(err.get("line", 0))
	if line_no > 0:
		c.draw_string(font, Vector2(x, y), "--> %s:%d" % [_rant.file, line_no], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.POOL)
		y += 12
		var code_line := str(_rant.code).strip_edges()
		if CodeDraw.width(code_line) > limit - 22:
			while CodeDraw.width(code_line + "..") > limit - 22 and code_line.length() > 4:
				code_line = code_line.substr(0, code_line.length() - 1)
			code_line += ".."
		c.draw_string(font, Vector2(x, y), "%d |" % line_no, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.POOL)
		var cx := x + CodeDraw.width("%d | " % line_no)
		c.draw_string(font, Vector2(cx, y), code_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.PAPER)
		y += 9
		c.draw_string(font, Vector2(cx, y), "^".repeat(clampi(code_line.length(), 1, 40)), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.RED)
		y += 12
	c.draw_string(font, Vector2(x, y), "%s:" % _rant.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.AMBER)
	y += 12
	for line in CodeDraw.wrap("\"%s\"" % _rant.text, limit):
		if y > panel.end.y - 4:
			break
		c.draw_string(font, Vector2(x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.PAPER)
		y += 12


func _draw_panic(c: Control) -> void:
	var font := Palette.mono()
	var panel := Rect2(6, 140, 468, 124)
	c.draw_rect(panel.grow(1), Palette.AMBER.darkened(0.3))
	c.draw_rect(panel, Color(0.08, 0.05, 0.07, 0.96))
	var tex := face_texture(str(_panic.who))
	var face_rect := Rect2(panel.position + Vector2(6, 9), Vector2(96, 96))
	if tex != null:
		c.draw_rect(face_rect.grow(1), Palette.PAPER)
		c.draw_texture_rect_region(tex, face_rect, Rect2(48 * 3, 0, 48, 48))
	var x := face_rect.end.x + 8
	var limit := panel.end.x - x - 6
	var y := panel.position.y + 13
	var head := "thread 'main' panicked at %s:%d:" % [_panic.file, _panic.line]
	c.draw_string(font, Vector2(x, y), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.AMBER)
	y += 12
	for line in CodeDraw.wrap(str(_panic.message), limit):
		c.draw_string(font, Vector2(x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.AMBER.lightened(0.3))
		y += 12
	y += 6
	c.draw_string(font, Vector2(x, y), "%s:" % _panic.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.AMBER)
	y += 12
	for line in CodeDraw.wrap("\"%s\"" % _panic.text, limit):
		c.draw_string(font, Vector2(x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.PAPER)
		y += 12


func _draw_card(c: Control) -> void:
	var font := Palette.mono()
	var lines := CodeDraw.wrap(str(_card.get("text", "")), 424)
	var code_h := _card_block.custom_minimum_size.y
	var h := 30.0 + code_h + 8 + lines.size() * 12 + 18
	var panel := Rect2(Vector2(20, maxf(135 - h / 2, 4)), Vector2(440, h))
	c.draw_rect(panel.grow(2), Palette.RUST.darkened(0.2))
	c.draw_rect(panel, Color(0.08, 0.06, 0.08, 0.97))
	var who := str(_card.get("who", "barry"))
	c.draw_string(Palette.pixel(), panel.position + Vector2(8, 15), str(_card.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.PAPER)
	var tag := "won't compile: %s" % _card.error if _card.has("error") else "%s's note" % Story.name_of(who)
	var tag_w := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	c.draw_string(font, Vector2(panel.end.x - tag_w - 8, panel.position.y + 14), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.RED.lightened(0.2) if _card.has("error") else Palette.AMBER)
	_card_block.position = panel.position + Vector2(8, 24)
	var y := panel.position.y + 24 + code_h + 14
	for line in lines:
		c.draw_string(font, Vector2(panel.position.x + 8, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.PAPER.darkened(0.05))
		y += 12
	if _waiting and int(_clock * 3.0) % 2 == 0:
		c.draw_string(font, Vector2(panel.end.x - 60, panel.end.y - 5), "Enter: OK", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.AMBER)


func _draw_title(c: Control) -> void:
	c.draw_rect(Rect2(0, 0, 480, 270), Color.BLACK)
	_draw_centered(c, Palette.serif(), str(_title.title), 142, 22, Color.WHITE)
	if str(_title.small) != "":
		_draw_centered(c, Palette.serif(), str(_title.small), 170, 11, Color(0.8, 0.8, 0.8))


func _draw_end(c: Control) -> void:
	c.draw_rect(Rect2(0, 0, 480, 270), Color.BLACK)
	_draw_centered(c, Palette.serif(), "Curb Your Oxidation", 96, 22, Palette.YELLOW)
	var y := 132.0
	for line: String in _end.lines:
		_draw_centered(c, Palette.serif(), line, y, 11, Color(0.85, 0.85, 0.85))
		y += 18
	if _waiting and int(_clock * 2.0) % 2 == 0:
		_draw_centered(c, Palette.mono(), "Tap to carry on" if TouchControls.active else "Enter: carry on", 252, 16, Color(0.6, 0.6, 0.6))
