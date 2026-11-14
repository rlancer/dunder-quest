extends CanvasLayer

## On-screen pad for phones and tablets: run left and right, jump, and draw
## the dagger. It turns on with the first touch (or from the start on a
## mobile browser) and off again when a key or gamepad button is pressed.
## Presses go in as actions, so the Prince reads them exactly like keys.
## Cards, menus and the dagger's console take taps directly.
##
## Playing by touch, the picture scales smoothly to fill the screen, and in a
## room the view widens to the phone's shape instead of showing black bars
## (the room stays 480 wide in the middle; the pad sits in the margins).

## Drawn buttons, in viewport pixels. Jump and the dagger sit this far in
## from the right edge, which moves when a room widens the view.
const LEFT_CENTER := Vector2(26.0, 238.0)
const RIGHT_CENTER := Vector2(74.0, 238.0)
const JUMP_FROM_RIGHT := Vector2(34.0, 232.0)
const DAGGER_FROM_RIGHT := Vector2(84.0, 244.0)
const MOVE_RADIUS := 20.0
const JUMP_RADIUS := 26.0
const DAGGER_RADIUS := 18.0
## Touches below this line in the outer columns drive the pad.
const PAD_TOP := 150.0
const MOVE_ZONE_RIGHT := 140.0
const RIGHT_ZONE_WIDTH := 130.0
const FILL := Color(0.07, 0.07, 0.16, 0.22)
const RIM := Color(0.91, 0.73, 0.29, 0.65)
const LIT := Color(0.91, 0.73, 0.29, 0.45)
const GLYPH := Color(1.0, 0.95, 0.8, 0.85)

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
	_fit_screen()
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


func _room() -> Node:
	var scene := get_tree().current_scene
	return scene if scene != null and scene.is_in_group(&"room") else null


## The pad shows in a room while the Prince can move. The dagger's console,
## cards and menus are tapped.
func _pad_wanted() -> bool:
	var room := _room()
	return room != null and bool(room.get(&"pad_wanted"))


## Keys and gamepads keep the crisp whole-number scale and 16:9 view.
func _fit_screen() -> void:
	var window := get_window()
	var stretch := Window.CONTENT_SCALE_STRETCH_FRACTIONAL if active else Window.CONTENT_SCALE_STRETCH_INTEGER
	var aspect := Window.CONTENT_SCALE_ASPECT_EXPAND if active and _room() != null else Window.CONTENT_SCALE_ASPECT_KEEP
	if window.content_scale_stretch != stretch:
		window.content_scale_stretch = stretch
	if window.content_scale_aspect != aspect:
		window.content_scale_aspect = aspect


func jump_center() -> Vector2:
	return Vector2(_view_width() - JUMP_FROM_RIGHT.x, JUMP_FROM_RIGHT.y)


func dagger_center() -> Vector2:
	return Vector2(_view_width() - DAGGER_FROM_RIGHT.x, DAGGER_FROM_RIGHT.y)


func _view_width() -> float:
	return _pad.get_viewport_rect().size.x


func _action_at(pos: Vector2) -> StringName:
	if pos.y < PAD_TOP:
		return &""
	if pos.x < MOVE_ZONE_RIGHT:
		return &"move_left" if pos.x < (LEFT_CENTER.x + RIGHT_CENTER.x) / 2.0 else &"move_right"
	if pos.x > _view_width() - RIGHT_ZONE_WIDTH:
		# Whichever of the two buttons the finger is nearer.
		return &"jump" if pos.distance_to(jump_center()) - JUMP_RADIUS < pos.distance_to(dagger_center()) - DAGGER_RADIUS else &"dagger"
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
	var c := jump_center()
	_draw_button(c, JUMP_RADIUS, _is_held(&"jump"))
	_pad.draw_string(Palette.pixel(), c + Vector2(-20, 4), "JUMP", HORIZONTAL_ALIGNMENT_CENTER, 40, 10, GLYPH)
	c = dagger_center()
	_draw_button(c, DAGGER_RADIUS, _is_held(&"dagger"))
	_pad.draw_string(Palette.pixel(), c + Vector2(-20, 3), "GIT", HORIZONTAL_ALIGNMENT_CENTER, 40, 10, GLYPH)


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
	_pad.draw_rect(Rect2(0, 0, view.x, 18), Color(0.07, 0.07, 0.16, 0.85))
	_pad.draw_string(Palette.pixel(), Vector2(0, 13), text, HORIZONTAL_ALIGNMENT_CENTER, view.x, 11, Palette.SAND)
