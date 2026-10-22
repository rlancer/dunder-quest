extends CanvasLayer

## On-screen pad for phones and tablets: move left and right, jump, and ask
## the wizard for a hint mid-duel. It turns on with the first touch (or from
## the start on a mobile browser) and off again when a key or gamepad button
## is pressed. Presses go in as actions, so the player, cards and menus read
## them exactly like keys. Menus, the map and cards need no pad: taps on their
## buttons arrive as mouse clicks.

const FONT := preload("res://assets/fonts/PixelifySans.ttf")
## Drawn buttons, in the 480x270 viewport. Hit zones are wider than these.
const LEFT_CENTER := Vector2(34.0, 232.0)
const RIGHT_CENTER := Vector2(92.0, 232.0)
const JUMP_CENTER := Vector2(440.0, 226.0)
const HINT_CENTER := Vector2(440.0, 168.0)
const MOVE_RADIUS := 22.0
const JUMP_RADIUS := 28.0
const HINT_RADIUS := 15.0
## Touches below this line in the outer columns drive the pad.
const PAD_TOP := 150.0
const MOVE_ZONE_RIGHT := 150.0
const JUMP_ZONE_LEFT := 370.0
const FILL := Color(0.08, 0.06, 0.16, 0.38)
const RIM := Color(1.0, 0.86, 0.55, 0.55)
const LIT := Color(1.0, 0.72, 0.3, 0.55)
const GLYPH := Color(1.0, 0.94, 0.8, 0.8)

## True while the player is playing by touch. Prompts read this to say "tap".
var active: bool = OS.has_feature("web_android") or OS.has_feature("web_ios")

## Touch index to the action that finger holds.
var _held: Dictionary = {}
## How many fingers hold each action, so two on one button release once.
var _counts: Dictionary = {}
var _pad: Node2D
var _shown: bool = false


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pad = Node2D.new()
	_pad.draw.connect(_draw_pad)
	add_child(_pad)
	get_window().size_changed.connect(_pad.queue_redraw)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_release_all()


func _process(_delta: float) -> void:
	var shown := active and _pad_wanted()
	if shown != _shown:
		_shown = shown
		if not shown:
			_release_all()
	_pad.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		active = true
	elif event is InputEventKey or event is InputEventJoypadButton:
		if event.is_pressed() and active:
			active = false
			_release_all()
		return
	else:
		return
	# The touch that turns the pad on counts as a press too.
	_shown = _pad_wanted()
	if not _shown:
		return

	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			var action := _action_at(touch.position)
			if action != &"":
				_held[touch.index] = action
				_press(action)
		elif _held.has(touch.index):
			_release(_held[touch.index])
			_held.erase(touch.index)
		return

	# A finger sliding across the move buttons switches direction without lifting.
	var drag := event as InputEventScreenDrag
	if not _held.has(drag.index):
		return
	var was: StringName = _held[drag.index]
	if was != &"move_left" and was != &"move_right":
		return
	var now := _action_at(drag.position)
	if now == &"move_left" or now == &"move_right":
		if now != was:
			_release(was)
			_held[drag.index] = now
			_press(now)


## The pad shows in stages, while play runs. Pause menus and cards are tapped.
func _pad_wanted() -> bool:
	if not get_tree().current_scene is StageLevel or get_tree().paused:
		return false
	var hud := _hud()
	return hud == null or not (hud.passage_shown or hud.cleared)


func _hud() -> StageHud:
	return get_tree().get_first_node_in_group(&"stage_hud") as StageHud


func _duel_open() -> bool:
	var hud := _hud()
	return hud != null and hud.is_duel_open()


func _action_at(pos: Vector2) -> StringName:
	if _duel_open() and pos.distance_to(HINT_CENTER) <= HINT_RADIUS + 10.0:
		return &"hint"
	if pos.y < PAD_TOP:
		return &""
	if pos.x < MOVE_ZONE_RIGHT:
		return &"move_left" if pos.x < (LEFT_CENTER.x + RIGHT_CENTER.x) / 2.0 else &"move_right"
	if pos.x > JUMP_ZONE_LEFT:
		return &"jump"
	return &""


func _press(action: StringName) -> void:
	_counts[action] = int(_counts.get(action, 0)) + 1
	if _counts[action] == 1:
		_send(action, true)


func _release(action: StringName) -> void:
	var left := int(_counts.get(action, 0)) - 1
	if left > 0:
		_counts[action] = left
		return
	_counts.erase(action)
	_send(action, false)


func _release_all() -> void:
	for action: StringName in _counts.keys():
		_send(action, false)
	_counts.clear()
	_held.clear()


func _send(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func _is_held(action: StringName) -> bool:
	return _counts.has(action)


func _draw_pad() -> void:
	if active and _portrait():
		_draw_turn_banner()
	if not _shown:
		return
	_draw_button(LEFT_CENTER, MOVE_RADIUS, _is_held(&"move_left"))
	_draw_arrow(LEFT_CENTER, -1.0)
	_draw_button(RIGHT_CENTER, MOVE_RADIUS, _is_held(&"move_right"))
	_draw_arrow(RIGHT_CENTER, 1.0)
	_draw_button(JUMP_CENTER, JUMP_RADIUS, _is_held(&"jump"))
	var c := JUMP_CENTER
	_pad.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -11), c + Vector2(11, 5), c + Vector2(-11, 5)]), GLYPH)
	if _duel_open():
		_draw_button(HINT_CENTER, HINT_RADIUS, _is_held(&"hint"))
		_pad.draw_string(FONT, HINT_CENTER + Vector2(-8, 5), "?", HORIZONTAL_ALIGNMENT_CENTER, 16, 14, GLYPH)


func _draw_button(center: Vector2, radius: float, held: bool) -> void:
	_pad.draw_circle(center, radius, LIT if held else FILL)
	_pad.draw_arc(center, radius, 0.0, TAU, 32, RIM, 1.5)


func _draw_arrow(center: Vector2, dir: float) -> void:
	var tip := center + Vector2(9.0 * dir, 0)
	var back := center - Vector2(7.0 * dir, 0)
	_pad.draw_colored_polygon(PackedVector2Array([tip, back + Vector2(0, -10), back + Vector2(0, 10)]), GLYPH)


func _portrait() -> bool:
	var size := get_window().size
	return size.y > size.x


## Held upright, a phone shows the game as a thin strip; ask for landscape.
func _draw_turn_banner() -> void:
	var text := "Turn your phone sideways to play"
	var view := _pad.get_viewport_rect().size
	_pad.draw_rect(Rect2(0, 0, view.x, 18), Color(0.08, 0.06, 0.16, 0.85))
	_pad.draw_string(FONT, Vector2(0, 13), text, HORIZONTAL_ALIGNMENT_CENTER, view.x, 11, Color(1.0, 0.84, 0.5))
