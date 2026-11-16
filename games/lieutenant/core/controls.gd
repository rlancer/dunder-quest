extends Node

## Registers every input action at startup, so project.godot carries no
## hand-serialized InputEvents. Keys go by physical position.

const KEYS: Dictionary = {
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"move_up": [KEY_W, KEY_UP],
	&"move_down": [KEY_S, KEY_DOWN],
	## Talk to someone, look at a record, pick a chip.
	&"edit": [KEY_E],
	&"confirm": [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER],
	## Pick a chip in the notebook, or put it back.
	&"pick": [KEY_SPACE],
	## Call Records.
	&"run": [KEY_R],
	&"pause": [KEY_ESCAPE, KEY_P],
}
const BUTTONS: Dictionary = {
	&"move_left": [JOY_BUTTON_DPAD_LEFT],
	&"move_right": [JOY_BUTTON_DPAD_RIGHT],
	&"move_up": [JOY_BUTTON_DPAD_UP],
	&"move_down": [JOY_BUTTON_DPAD_DOWN],
	&"edit": [JOY_BUTTON_X],
	&"confirm": [JOY_BUTTON_A],
	&"pick": [JOY_BUTTON_A],
	&"run": [JOY_BUTTON_Y, JOY_BUTTON_LEFT_SHOULDER],
	&"pause": [JOY_BUTTON_START],
}
const AXES: Dictionary = {
	&"move_left": [JOY_AXIS_LEFT_X, -1.0],
	&"move_right": [JOY_AXIS_LEFT_X, 1.0],
	&"move_up": [JOY_AXIS_LEFT_Y, -1.0],
	&"move_down": [JOY_AXIS_LEFT_Y, 1.0],
}


func _init() -> void:
	for action: StringName in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.5)
		for key: Key in KEYS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	for action: StringName in BUTTONS:
		for button: JoyButton in BUTTONS[action]:
			var event := InputEventJoypadButton.new()
			event.button_index = button
			InputMap.action_add_event(action, event)
	for action: StringName in AXES:
		var event := InputEventJoypadMotion.new()
		event.axis = AXES[action][0]
		event.axis_value = AXES[action][1]
		InputMap.action_add_event(action, event)


## "E", "X" or "Tap": how prompts name the talk-and-look button on this device.
static func talk_key() -> String:
	if TouchControls.active:
		return "Tap TALK"
	return "X" if not Input.get_connected_joypads().is_empty() else "E"
