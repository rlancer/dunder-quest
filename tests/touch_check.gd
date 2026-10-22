extends Node

## Plays a few seconds of Amber Hollow by touch through the on-screen pad:
## hold the right button and the pebble runs right, slide onto the left one
## and it turns, tap the jump button and it leaves the ground, lift every
## finger and nothing stays held. A key press puts the pad away again.
## godot --headless --path . res://tests/touch_check.tscn   ->  TOUCH result=ok

var _fails: PackedStringArray = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameProgression.persist = false
	GameProgression.came_from_map = false
	GameProgression.load_data()
	StageAudio.web_audio_unlocked = true
	_run.call_deferred()


func _run() -> void:
	# The pad shows only when a stage is the current scene, as in real play.
	var stage := (load("res://levels/level_01.tscn") as PackedScene).instantiate() as StageLevel
	get_tree().root.add_child(stage)
	get_tree().current_scene = stage
	await _frames(40)
	var player := stage.player

	var hud := get_tree().get_first_node_in_group(&"stage_hud") as StageHud

	_touch(0, TouchControls.RIGHT_CENTER, true)
	await _frames(4)
	_check(TouchControls.active, "a touch turns the pad on")
	_check(Input.is_action_pressed(&"move_right"), "holding the right button holds move_right")
	var ran_from := player.global_position.x
	# The first lore scroll lies a few steps in; its card pauses play.
	for i in 240:
		await _frames(1)
		if hud.is_card_open():
			break
	_check(player.global_position.x > ran_from + 4.0, "the pebble runs right (%.1f -> %.1f)" % [ran_from, player.global_position.x])
	_check(hud.is_card_open(), "running right reaches the first scroll")
	await _frames(2)
	_check(not Input.is_action_pressed(&"move_right"), "a card lets go of the pad")
	_touch(0, TouchControls.RIGHT_CENTER, false)
	await _frames(30)
	_touch(3, Vector2(240, 135), true)
	_touch(3, Vector2(240, 135), false)
	await _frames(4)
	_check(not hud.is_card_open(), "a tap closes the card")
	_check(not get_tree().paused, "closing the card resumes play")

	_touch(0, TouchControls.RIGHT_CENTER, true)
	await _frames(4)
	_drag(0, TouchControls.LEFT_CENTER)
	await _frames(2)
	_check(Input.is_action_pressed(&"move_left") and not Input.is_action_pressed(&"move_right"), "sliding onto the left button turns")
	_touch(0, TouchControls.LEFT_CENTER, false)
	await _frames(2)
	_check(not Input.is_action_pressed(&"move_left"), "lifting the finger releases move_left")

	await _frames(30)
	_touch(1, TouchControls.jump_center(), true)
	await _frames(12)
	_check(Input.is_action_pressed(&"jump"), "holding the jump button holds jump")
	_check(not player.is_on_floor(), "the pebble jumps")
	_touch(1, TouchControls.jump_center(), false)
	await _frames(2)
	_check(not Input.is_action_pressed(&"jump"), "lifting the finger releases jump")

	_touch(2, TouchControls.RIGHT_CENTER, true)
	await _frames(2)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_D
	key.keycode = KEY_D
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(2)
	_check(not TouchControls.active, "a key press puts the pad away")
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	await _frames(2)
	_check(not Input.is_action_pressed(&"move_right"), "putting the pad away lets go of its buttons")
	_finish()


func _finish() -> void:
	for fail in _fails:
		print("TOUCH fail ", fail)
	print("TOUCH result=%s fails=%d" % ["ok" if _fails.is_empty() else "fail", _fails.size()])
	get_tree().quit(0 if _fails.is_empty() else 1)


## Touches arrive in window pixels; the pad reads them in the 480x270 view.
func _to_window(view_pos: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * view_pos


func _touch(index: int, view_pos: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = _to_window(view_pos)
	event.pressed = pressed
	Input.parse_input_event(event)


func _drag(index: int, view_pos: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = _to_window(view_pos)
	Input.parse_input_event(event)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails.append(what)
